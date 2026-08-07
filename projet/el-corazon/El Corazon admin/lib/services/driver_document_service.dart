import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/models/driver_document.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Pièces justificatives des livreurs — `/delivery/couriers/` (Phase 6).
///
/// Le modèle a changé, et la différence porte tout ce fichier : **la décision
/// est prise sur le dossier, pas sur chaque pièce**.
///
/// Côté Supabase, chaque document avait son propre statut : on pouvait
/// approuver le permis, rejeter la carte grise, et le compte restait dans un
/// état que personne ne savait lire — le livreur pouvait-il travailler ? La
/// réponse dépendait d'une agrégation refaite dans chaque écran.
///
/// Côté v2, un dossier porte trois pièces et **un** statut de vérification.
/// C'est lui qui décide de l'éligibilité (L1), et il n'y a donc qu'une réponse
/// possible. Instruire un dossier, c'est le regarder en entier puis trancher,
/// avec un motif.
///
/// Trois choses ont disparu, faute d'équivalent — et parce qu'elles ne tenaient
/// pas :
///
/// * **les dates d'expiration.** Saisies à la main, et rien ne les vérifiait :
///   `checkExpiredDocuments` devait être appelée par un écran pour que
///   l'expiration prenne effet. Un permis périmé restait donc valide tant que
///   personne n'ouvrait le tableau de bord ;
/// * **l'historique de validation.** Une table écrite depuis le navigateur,
///   avec l'identifiant de l'auteur fourni par le client — une trace que son
///   auteur pouvait choisir. Elle est maintenant sur le dossier
///   (`verified_by`, `verified_at`), écrite par le serveur ;
/// * **le dépôt de pièces depuis le back-office.** C'est le livreur qui a ses
///   documents et qui les dépose depuis son application ; tout dépôt repasse le
///   dossier en attente (L5), sans quoi un dossier validé sur des pièces
///   ensuite remplacées resterait validé.
///
/// Les fichiers arrivent en **URL signées, qui expirent** : le stockage est
/// privé. L'ancienne version les publiait dans un compartiment public, où une
/// pièce d'identité restait lisible par quiconque connaissait l'adresse.
class DriverDocumentService extends ChangeNotifier {
  eccore.ManagedCourierRepository get _fleet =>
      eccore.ManagedCourierRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.CourierProfile> _couriers = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<eccore.CourierProfile> get couriers => _couriers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Dossiers en attente d'instruction.
  List<eccore.CourierProfile> get pendingCouriers =>
      _couriers.where((c) => c.verificationStatus == 'pending').toList();

  /// Dossiers en attente **auxquels il manque une pièce** : il n'y a rien à
  /// instruire tant que le livreur n'a pas fini de déposer.
  List<eccore.CourierProfile> get incompleteCouriers => _couriers
      .where((c) => c.verificationStatus == 'pending' && !c.hasAllDocuments)
      .toList();

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _couriers = await _fleet.list();
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('Dossiers livreurs : chargement impossible — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Les trois pièces d'un dossier, sous la forme qu'affichent les écrans.
  ///
  /// Le statut porté par chaque ligne est celui **du dossier** : c'est la seule
  /// décision qui existe, et faire semblant qu'il y en a trois laisserait
  /// croire qu'on peut approuver une pièce isolément.
  List<DriverDocument> documentsOf(eccore.CourierProfile courier) {
    final statut = _statut(courier.verificationStatus);
    final maintenant = DateTime.now();

    DriverDocument ligne(DocumentType type, String? url) {
      return DriverDocument(
        id: '${courier.id}:${type.name}',
        userId: courier.id,
        type: type,
        status: statut,
        fileUrl: url,
        validationNotes: courier.verificationNotes.isEmpty
            ? null
            : courier.verificationNotes,
        validatedAt: courier.verifiedAt,
        rejectionReason: statut == DocumentValidationStatus.rejected
            ? courier.verificationNotes
            : null,
        uploadedAt: courier.createdAt,
        createdAt: courier.createdAt,
        updatedAt: maintenant,
        driverName: courier.fullName,
        driverEmail: courier.email,
      );
    }

    return [
      ligne(DocumentType.identity, courier.idDocument),
      ligne(DocumentType.license, courier.licenceDocument),
      ligne(DocumentType.registration, courier.vehicleDocument),
    ];
  }

  eccore.CourierProfile? courierById(String courierId) {
    for (final courier in _couriers) {
      if (courier.id == courierId) return courier;
    }
    return null;
  }

  /// Valide un dossier — le livreur devient éligible aux courses (L1).
  Future<bool> approveCourier(String courierId, {String notes = ''}) =>
      _decider(courierId, 'approved', notes);

  /// Rejette un dossier, avec un motif.
  ///
  /// Le motif est rendu au livreur, qui doit savoir quelle pièce redéposer. Un
  /// rejet muet le laisse redéposer la même chose.
  Future<bool> rejectCourier(String courierId, String reason) =>
      _decider(courierId, 'rejected', reason);

  /// Suspend un dossier déjà validé.
  Future<bool> suspendCourier(String courierId, String reason) =>
      _decider(courierId, 'suspended', reason);

  Future<bool> _decider(String courierId, String status, String notes) async {
    try {
      final maj = await _fleet.setVerification(
        courierId: courierId,
        status: status,
        notes: notes,
      );
      final index = _couriers.indexWhere((c) => c.id == courierId);
      if (index != -1) _couriers[index] = maj;
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      // La machine à états refuse les transitions impossibles : un dossier
      // rejeté ne repasse pas « validé » sans nouveau dépôt du livreur.
      _error = e.detail;
      eccore.Journal.trace('Dossiers livreurs : décision refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  DocumentValidationStatus _statut(String verification) {
    switch (verification) {
      case 'approved':
        return DocumentValidationStatus.approved;
      case 'rejected':
      case 'suspended':
        return DocumentValidationStatus.rejected;
      default:
        return DocumentValidationStatus.pending;
    }
  }
}
