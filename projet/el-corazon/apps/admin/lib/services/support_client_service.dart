import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Les statuts qui attendent encore un geste, par file.
///
/// Partent au serveur en `status__in` : « à traiter » en couvre plusieurs, et
/// deux pages recollées côté écran feraient mentir la pagination.
abstract final class ATraiter {
  static const tickets = ['open', 'in_progress'];
  static const reclamations = ['pending', 'under_review'];
  static const retours = ['pending', 'approved'];
}

/// Le service client du back-office — tickets, réclamations, retours
/// (`/support/manage/*`).
///
/// Les routes du support n'étaient ouvertes qu'aux clients. Un client écrivait
/// et n'apprenait jamais qu'on l'avait lu : le back-office ne pouvait ni lire
/// son ticket ni lui répondre. Chaque geste d'ici lui parvient en notification.
class SupportClientService extends ChangeNotifier {
  SupportClientService({eccore.ManagedSupportRepository? depot}) : _depotInjecte = depot;

  final eccore.ManagedSupportRepository? _depotInjecte;

  eccore.ManagedSupportRepository get _depot =>
      _depotInjecte ?? eccore.ManagedSupportRepository(apiClient: AdminAuthService().apiClient);

  /// Vrai : seules les demandes qui attendent un geste. Faux : tout.
  bool seulementATraiter = true;

  List<eccore.ManagedTicket> _tickets = const [];
  List<eccore.ManagedComplaint> _reclamations = const [];
  List<eccore.ManagedReturn> _retours = const [];
  bool _chargement = false;
  String? _erreur;
  final Set<String> _enCours = {};

  List<eccore.ManagedTicket> get tickets => List.unmodifiable(_tickets);
  List<eccore.ManagedComplaint> get reclamations => List.unmodifiable(_reclamations);
  List<eccore.ManagedReturn> get retours => List.unmodifiable(_retours);
  bool get chargement => _chargement;
  String? get erreur => _erreur;
  bool enCours(String id) => _enCours.contains(id);

  /// Recharge les trois files, en parallèle : elles s'affichent ensemble, et
  /// les enchaîner triplerait l'attente.
  Future<void> charger({bool? aTraiter}) async {
    seulementATraiter = aTraiter ?? seulementATraiter;
    _chargement = true;
    _erreur = null;
    notifyListeners();
    try {
      final resultats = await Future.wait([
        _depot.tickets(statuts: seulementATraiter ? ATraiter.tickets : null),
        _depot.complaints(statuts: seulementATraiter ? ATraiter.reclamations : null),
        _depot.returns(statuts: seulementATraiter ? ATraiter.retours : null),
      ]);
      _tickets = (resultats[0] as eccore.Page<eccore.ManagedTicket>).results;
      _reclamations = (resultats[1] as eccore.Page<eccore.ManagedComplaint>).results;
      _retours = (resultats[2] as eccore.Page<eccore.ManagedReturn>).results;
    } on eccore.ApiException catch (e) {
      _erreur = messageErreur(e);
    } finally {
      _chargement = false;
      notifyListeners();
    }
  }

  /// Le ticket et son fil, relu au serveur.
  Future<eccore.ManagedTicket?> ouvrirTicket(String id) async {
    try {
      final complet = await _depot.ticket(id);
      _remplacerTicket(complet);
      return complet;
    } on eccore.ApiException catch (e) {
      _erreur = messageErreur(e);
      notifyListeners();
      return null;
    }
  }

  /// Rend `null` en cas de succès, sinon la phrase du refus.
  Future<String?> repondre(String ticketId, String contenu) => _geste(ticketId, () async {
        await _depot.reply(ticketId: ticketId, content: contenu);
        await ouvrirTicket(ticketId);
      });

  Future<String?> changerStatutTicket(String ticketId, String statut, {String resolution = ''}) =>
      _geste(ticketId, () async {
        final maj = await _depot.setTicketStatus(
          ticketId: ticketId,
          status: statut,
          resolution: resolution,
        );
        _remplacerTicket(maj, garderLeFil: true);
      });

  Future<String?> statuerReclamation(String id, String statut, {String resolution = ''}) =>
      _geste(id, () async {
        final maj = await _depot.decideComplaint(
          complaintId: id,
          status: statut,
          resolution: resolution,
        );
        _reclamations = _sansLesTraitees(
          [for (final r in _reclamations) r.id == id ? maj : r],
          (r) => ATraiter.reclamations.contains(r.status),
        );
      });

  Future<String?> statuerRetour(String id, String statut, {String resolution = ''}) =>
      _geste(id, () async {
        final maj = await _depot.decideReturn(returnId: id, status: statut, resolution: resolution);
        _retours = _sansLesTraitees(
          [for (final r in _retours) r.id == id ? maj : r],
          (r) => ATraiter.retours.contains(r.status),
        );
      });

  void _remplacerTicket(eccore.ManagedTicket maj, {bool garderLeFil = false}) {
    _tickets = _sansLesTraitees(
      [
        for (final t in _tickets)
          if (t.id != maj.id)
            t
          else if (garderLeFil && maj.messages.isEmpty)
            // La réponse à un changement de statut ne porte pas le fil : on
            // garde celui qu'on a, plutôt que de vider l'écran ouvert.
            eccore.ManagedTicket(
              id: maj.id,
              customerId: maj.customerId,
              customerName: maj.customerName,
              customerEmail: maj.customerEmail,
              customerPhone: maj.customerPhone,
              category: maj.category,
              subject: maj.subject,
              description: maj.description,
              attachments: maj.attachments,
              status: maj.status,
              resolution: maj.resolution,
              resolvedAt: maj.resolvedAt,
              messagesCount: maj.messagesCount,
              messages: t.messages,
              createdAt: maj.createdAt,
            )
          else
            maj,
      ],
      (t) => ATraiter.tickets.contains(t.status),
    );
  }

  /// Dans « à traiter », une demande traitée sort de la file.
  List<T> _sansLesTraitees<T>(List<T> liste, bool Function(T) aTraiter) =>
      seulementATraiter ? liste.where(aTraiter).toList() : liste;

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
