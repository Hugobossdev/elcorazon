import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/presentation/echec.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Ce qu'un compte client peut être, du point de vue du back-office.
enum EtatDuClient {
  tous('Tous', null),
  actifs('Actifs', true),
  suspendus('Suspendus', false);

  const EtatDuClient(this.libelle, this.actif);

  final String libelle;

  /// Ce qui part au serveur (`is_active`), `null` pour « tous ».
  final bool? actif;
}

/// Comptes clients — `/administration/customers/` (Phase 6).
///
/// ## Ce qui a changé
///
/// * **La liste était téléchargée entière**, page après page, et filtrée dans
///   l'écran : sur une plateforme à cinquante mille comptes, l'écran chargeait
///   cinquante mille lignes pour en montrer vingt, et la recherche ne portait
///   que sur ce qui avait été chargé. Le serveur pagine, cherche et filtre ;
///   l'écran demande **une page**.
/// * **Réactiver un compte était impossible.** `reactivateClient` existait et
///   n'avait aucun site d'appel : un client suspendu le restait, et le menu
///   proposait « Suspendre » sur un compte déjà suspendu.
/// * Les écritures laissent remonter l'`ApiException` : le motif de refus
///   s'affiche au lieu d'un échec silencieux.
class ClientManagementService extends ChangeNotifier {
  ClientManagementService({eccore.AdministrationRepository? depot}) : _depot = depot;

  final eccore.AdministrationRepository? _depot;

  eccore.AdministrationRepository get _admin =>
      _depot ?? eccore.AdministrationRepository(apiClient: AdminAuthService().apiClient);

  eccore.Page<eccore.Customer>? _page;
  int _numeroDePage = 1;
  String _recherche = '';
  EtatDuClient _etat = EtatDuClient.tous;
  bool _enCours = false;
  Echec? _echec;

  List<eccore.Customer> get clients => _page?.results ?? const [];
  int get total => _page?.count ?? 0;
  int get numeroDePage => _numeroDePage;
  bool get aPageSuivante => _page?.hasNext ?? false;
  bool get aPagePrecedente => _page?.hasPrevious ?? false;
  bool get isLoading => _enCours;
  Echec? get echec => _echec;
  String get recherche => _recherche;
  EtatDuClient get etat => _etat;

  static const int tailleDePage = 20;

  int get nombreDePages => total == 0 ? 1 : (total + tailleDePage - 1) ~/ tailleDePage;

  /// Charge la première page pour la recherche et le filtre donnés.
  ///
  /// Un changement de critère **remet la pagination à zéro** : rester en page 4
  /// après avoir changé de filtre montrerait la page 4 d'une autre liste.
  Future<void> chercher({String? recherche, EtatDuClient? etat}) async {
    _recherche = recherche ?? _recherche;
    _etat = etat ?? _etat;
    _numeroDePage = 1;
    await _lire(
      () => _admin.customersPage(
        search: _recherche.trim().isEmpty ? null : _recherche.trim(),
        isActive: _etat.actif,
        pageSize: tailleDePage,
      ),
    );
  }

  Future<void> initialize() async {
    if (_page == null && !_enCours) await chercher();
  }

  Future<void> refresh() => _lire(() => _relirePage(_numeroDePage));

  Future<void> pageSuivante() async {
    final suivante = _page?.next;
    if (suivante == null) return;
    _numeroDePage += 1;
    await _lire(() => _admin.customersAt(suivante));
  }

  Future<void> pagePrecedente() async {
    final precedente = _page?.previous;
    if (precedente == null) return;
    _numeroDePage -= 1;
    await _lire(() => _admin.customersAt(precedente));
  }

  Future<eccore.Page<eccore.Customer>> _relirePage(int numero) => _admin.customersPage(
        search: _recherche.trim().isEmpty ? null : _recherche.trim(),
        isActive: _etat.actif,
        pageSize: tailleDePage,
        page: numero,
      );

  Future<void> _lire(Future<eccore.Page<eccore.Customer>> Function() lecture) async {
    _enCours = true;
    _echec = null;
    notifyListeners();
    try {
      _page = await lecture();
    } on eccore.ApiException catch (e) {
      _echec = Echec.de(e);
      eccore.Journal.trace('Clients : lecture impossible — ${e.code}');
    } finally {
      _enCours = false;
      notifyListeners();
    }
  }

  /// Un compte client, par son identifiant — lève `ApiException`. Sert à
  /// ouvrir la fiche d'un client trouvé ailleurs que dans la liste (la
  /// recherche globale ne rend qu'un identifiant et deux libellés).
  Future<eccore.Customer> client(String clientId) => _admin.customer(clientId);

  /// La fiche agrégée d'un client — lève `ApiException`.
  Future<eccore.CustomerStats> fiche(String clientId) => _admin.customerStats(clientId);

  /// Les commandes d'un client, **une page**, les plus récentes d'abord.
  Future<eccore.Page<eccore.Order>> commandes(String clientId, {int pageSize = 20}) =>
      eccore.ManagedOrderRepository(apiClient: AdminAuthService().apiClient)
          .listPage(customerId: clientId, pageSize: pageSize);

  Future<List<eccore.InternalNote>> notesOf(String clientId) => _admin.customerNotes(clientId);

  Future<eccore.InternalNote> addNote(String clientId, String contenu) =>
      _admin.addCustomerNote(customerId: clientId, content: contenu);

  /// Ferme un compte (permission `customers.block`). Le motif est exigé par le
  /// serveur, et conservé au journal d'audit. Lève `ApiException`.
  Future<void> suspendre(String clientId, {required String motif}) async {
    _remplacer(await _admin.blockCustomer(customerId: clientId, reason: motif));
  }

  /// Rouvre un compte (permission `customers.block`). Lève `ApiException`.
  Future<void> reactiver(String clientId) async {
    _remplacer(await _admin.unblockCustomer(clientId));
  }

  void _remplacer(eccore.Customer client) {
    final page = _page;
    if (page == null) return;
    _page = eccore.Page<eccore.Customer>(
      results: [for (final existant in page.results) existant.id == client.id ? client : existant],
      count: page.count,
      next: page.next,
      previous: page.previous,
    );
    notifyListeners();
  }
}
