import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Ce que la liste montre : ce qui attend un geste, ou tout l'historique.
enum FiltreVersements {
  aTraiter('À traiter'),
  tous('Tout l’historique');

  const FiltreVersements(this.libelle);
  final String libelle;
}

/// Les sorties d'argent à instruire — retraits livreurs et remboursements
/// (`/payments/manage/*`).
///
/// Les deux s'arrêtaient à mi-chemin : un retrait livreur débitait les gains
/// et attendait pour toujours un constat que rien ne pouvait poser ; un
/// remboursement demandé ici ne se clôturait que dans l'administration Django.
///
/// Rien ici ne verse : on **constate** un virement fait chez le prestataire.
/// Les écrans le disent, et la référence du virement est exigée pour un
/// retrait — c'est la preuve qu'on cherchera.
class VersementsService extends ChangeNotifier {
  VersementsService({eccore.ManagedPayoutRepository? depot}) : _depotInjecte = depot;

  final eccore.ManagedPayoutRepository? _depotInjecte;

  eccore.ManagedPayoutRepository get _depot =>
      _depotInjecte ?? eccore.ManagedPayoutRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.ManagedWithdrawal> _retraits = const [];
  List<eccore.ManagedRefund> _remboursements = const [];
  int _totalRetraits = 0;
  int _totalRemboursements = 0;
  FiltreVersements _filtreRetraits = FiltreVersements.aTraiter;
  FiltreVersements _filtreRemboursements = FiltreVersements.aTraiter;
  bool _chargementRetraits = false;
  bool _chargementRemboursements = false;
  String? _erreurRetraits;
  String? _erreurRemboursements;

  /// Identifiants en cours d'envoi — pour neutraliser le bouton pendant
  /// l'aller-retour : un second clic signerait deux fois.
  final Set<String> _enCours = {};

  List<eccore.ManagedWithdrawal> get retraits => List.unmodifiable(_retraits);
  List<eccore.ManagedRefund> get remboursements => List.unmodifiable(_remboursements);
  int get totalRetraits => _totalRetraits;
  int get totalRemboursements => _totalRemboursements;
  FiltreVersements get filtreRetraits => _filtreRetraits;
  FiltreVersements get filtreRemboursements => _filtreRemboursements;
  bool get chargementRetraits => _chargementRetraits;
  bool get chargementRemboursements => _chargementRemboursements;
  String? get erreurRetraits => _erreurRetraits;
  String? get erreurRemboursements => _erreurRemboursements;
  bool enCours(String id) => _enCours.contains(id);

  /// Somme à verser de la page affichée, par devise.
  ///
  /// Par devise, jamais additionnée d'une devise à l'autre : un réseau à
  /// plusieurs pays paie en francs CFA et en cedis, et un total unique serait
  /// un nombre sans unité.
  Map<String, int> get aVerserParDevise {
    final totaux = <String, int>{};
    for (final retrait in _retraits.where((r) => r.aInstruire)) {
      totaux.update(
        retrait.amount.currency,
        (cumul) => cumul + retrait.amount.amountMinor,
        ifAbsent: () => retrait.amount.amountMinor,
      );
    }
    return totaux;
  }

  // ----------------------------------------------------------- retraits

  Future<void> chargerRetraits({FiltreVersements? filtre}) async {
    _filtreRetraits = filtre ?? _filtreRetraits;
    _chargementRetraits = true;
    _erreurRetraits = null;
    notifyListeners();
    try {
      final page = await _depot.withdrawals(
        // « À traiter » = en attente. `processing` n'est jamais posé par le
        // serveur aujourd'hui : le constat passe directement à `completed`.
        status: _filtreRetraits == FiltreVersements.aTraiter
            ? eccore.StatutVersement.enAttente
            : null,
      );
      _retraits = page.results;
      _totalRetraits = page.count;
    } on eccore.ApiException catch (e) {
      _erreurRetraits = messageErreur(e);
    } finally {
      _chargementRetraits = false;
      notifyListeners();
    }
  }

  /// Rend `null` en cas de succès, sinon la phrase du refus.
  Future<String?> constaterRetrait(String id, {required String reference}) =>
      _geste(id, () async {
        final maj = await _depot.settleWithdrawal(withdrawalId: id, providerReference: reference);
        _remplacerRetrait(maj);
      });

  Future<String?> refuserRetrait(String id, {required String motif}) => _geste(id, () async {
        final maj = await _depot.rejectWithdrawal(withdrawalId: id, reason: motif);
        _remplacerRetrait(maj);
      });

  void _remplacerRetrait(eccore.ManagedWithdrawal maj) {
    // Dans « À traiter », une demande instruite **sort** de la liste : la
    // garder ferait croire qu'il reste un geste à faire.
    if (_filtreRetraits == FiltreVersements.aTraiter && !maj.aInstruire) {
      _retraits = [for (final r in _retraits) if (r.id != maj.id) r];
      _totalRetraits = (_totalRetraits - 1).clamp(0, _totalRetraits);
    } else {
      _retraits = [for (final r in _retraits) r.id == maj.id ? maj : r];
    }
  }

  // ------------------------------------------------------- remboursements

  Future<void> chargerRemboursements({FiltreVersements? filtre}) async {
    _filtreRemboursements = filtre ?? _filtreRemboursements;
    _chargementRemboursements = true;
    _erreurRemboursements = null;
    notifyListeners();
    try {
      final page = await _depot.refunds(
        status: _filtreRemboursements == FiltreVersements.aTraiter
            ? eccore.StatutVersement.enAttente
            : null,
      );
      _remboursements = page.results;
      _totalRemboursements = page.count;
    } on eccore.ApiException catch (e) {
      _erreurRemboursements = messageErreur(e);
    } finally {
      _chargementRemboursements = false;
      notifyListeners();
    }
  }

  Future<String?> constaterRemboursement(String id, {String reference = ''}) =>
      _geste(id, () async {
        _remplacerRemboursement(
          await _depot.settleRefund(refundId: id, providerReference: reference),
        );
      });

  /// Abandonne une demande qui ne sera pas versée — motif exigé.
  ///
  /// Sans elle, une demande saisie par erreur restait en attente pour toujours
  /// et consommait le plafond du remboursable : la commande ne pouvait plus
  /// être remboursée du bon montant, et le seul recours était l'administration
  /// Django.
  Future<String?> abandonnerRemboursement(String id, {required String motif}) =>
      _geste(id, () async {
        _remplacerRemboursement(await _depot.cancelRefund(refundId: id, reason: motif));
      });

  void _remplacerRemboursement(eccore.ManagedRefund maj) {
    if (_filtreRemboursements == FiltreVersements.aTraiter && !maj.aVerser) {
      _remboursements = [for (final r in _remboursements) if (r.id != maj.id) r];
      _totalRemboursements = (_totalRemboursements - 1).clamp(0, _totalRemboursements);
    } else {
      _remboursements = [for (final r in _remboursements) r.id == maj.id ? maj : r];
    }
  }

  // -------------------------------------------------------------- interne

  Future<String?> _geste(String id, Future<void> Function() action) async {
    if (_enCours.contains(id)) return 'Envoi déjà en cours.';
    _enCours.add(id);
    notifyListeners();
    try {
      await action();
      return null;
    } on eccore.ApiException catch (e) {
      return messageErreur(e);
    } finally {
      _enCours.remove(id);
      notifyListeners();
    }
  }
}
