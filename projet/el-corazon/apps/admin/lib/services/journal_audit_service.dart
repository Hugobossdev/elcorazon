import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Le journal des décisions — qui a changé quoi, et depuis quelle valeur.
///
/// Écrit depuis longtemps, il ne se lisait nulle part : ni route, ni écran, ni
/// administration Django. Le jour où les frais d'un quartier changeaient sans
/// explication, ou qu'un rôle gagnait le droit de rembourser, la trace
/// existait et personne ne pouvait l'ouvrir.
class JournalAuditService extends ChangeNotifier {
  JournalAuditService({eccore.AuditJournalRepository? depot}) : _depotInjecte = depot;

  final eccore.AuditJournalRepository? _depotInjecte;

  eccore.AuditJournalRepository get _depot =>
      _depotInjecte ?? eccore.AuditJournalRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.AuditRecord> _entrees = const [];
  String? _suivante;
  int _total = 0;
  bool _chargement = false;
  String? _erreur;

  /// Préfixe d'action (`staff.`, `zone.`…), ou `null` pour tout.
  String? famille;
  String recherche = '';

  List<eccore.AuditRecord> get entrees => List.unmodifiable(_entrees);
  int get total => _total;
  bool get chargement => _chargement;
  String? get erreur => _erreur;
  bool get aUneSuite => _suivante != null;

  Future<void> charger({String? famille, bool effacerFamille = false, String? recherche}) async {
    if (effacerFamille) {
      this.famille = null;
    } else if (famille != null) {
      this.famille = famille;
    }
    if (recherche != null) this.recherche = recherche;

    _chargement = true;
    _erreur = null;
    notifyListeners();
    try {
      final page = await _depot.entries(famille: this.famille, recherche: this.recherche);
      _entrees = page.results;
      _suivante = page.next;
      _total = page.count;
    } on eccore.ApiException catch (e) {
      _erreur = messageErreur(e);
    } finally {
      _chargement = false;
      notifyListeners();
    }
  }

  /// Ajoute la page suivante à la liste — on lit un journal en remontant.
  Future<void> chargerLaSuite() async {
    final url = _suivante;
    if (url == null || _chargement) return;
    _chargement = true;
    notifyListeners();
    try {
      final page = await _depot.pageAt(url);
      _entrees = [..._entrees, ...page.results];
      _suivante = page.next;
    } on eccore.ApiException catch (e) {
      _erreur = messageErreur(e);
    } finally {
      _chargement = false;
      notifyListeners();
    }
  }
}

/// Une valeur du journal, lisible : une liste se joint, un booléen se dit.
///
/// Les valeurs sont du JSON brut, tel que le serveur l'a consigné ; rien ici
/// ne les interprète au-delà de leur forme.
String valeurLisible(Object? valeur) {
  if (valeur == null) return '—';
  if (valeur is bool) return valeur ? 'oui' : 'non';
  if (valeur is List) return valeur.isEmpty ? 'aucun' : valeur.map(valeurLisible).join(', ');
  if (valeur is Map) {
    return valeur.entries.map((e) => '${e.key} : ${valeurLisible(e.value)}').join(' · ');
  }
  return '$valeur';
}
