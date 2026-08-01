import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../models/user.dart';
import '../repositories/django_order_mapper.dart';
import 'admin_auth_service.dart';

/// Dossiers clients — `/administration/customers/` (Phase 6).
///
/// Ce service a beaucoup maigri, et chaque méthode disparue correspond à un
/// geste que le back-office ne devait pas faire :
///
/// * **créditer des points de fidélité.** L'ancien code écrivait le solde du
///   client puis insérait à la main une ligne dans le journal des points : deux
///   écritures sans transaction, et surtout un back-office capable de frapper
///   monnaie. Les points s'acquièrent en commandant (`apps.loyalty`) ;
/// * **modifier le profil d'un client** avec un dictionnaire libre, où rien
///   n'interdisait `email` — c'est-à-dire un chemin de reprise de compte par
///   « mot de passe oublié » ;
/// * **recalculer ses statistiques dans le navigateur**, à partir des pages de
///   commandes qui avaient bien voulu se charger. Le panier moyen changeait
///   quand on tournait la page. C'est désormais un agrégat serveur
///   ([eccore.CustomerStats]).
///
/// Reste ce qui appartient vraiment au guichet : consulter, chercher, bloquer.
class ClientManagementService extends ChangeNotifier {
  static final ClientManagementService _instance =
      ClientManagementService._internal();
  factory ClientManagementService() => _instance;
  ClientManagementService._internal();

  eccore.AdministrationRepository get _admin =>
      eccore.AdministrationRepository(apiClient: AdminAuthService().apiClient);

  eccore.ManagedOrderRepository get _orders =>
      eccore.ManagedOrderRepository(apiClient: AdminAuthService().apiClient);

  List<User> _clients = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<User> get clients => _clients;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await loadClients();
  }

  /// Charge les comptes clients.
  ///
  /// [search] est transmis au serveur plutôt que filtré ici : la liste est
  /// paginée, et une recherche faite à l'écran ne trouverait que ce que la
  /// première page contenait déjà.
  Future<void> loadClients({bool force = false, String? search}) async {
    if (_isLoading && !force) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final comptes = await _admin.customers(search: search);
      _clients = comptes.map(_toLocal).toList();
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Clients : chargement impossible — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadClients(force: true);

  Future<void> searchClients(String query) =>
      loadClients(force: true, search: query);

  /// Fiche chiffrée — commandes, dépense, adresses, points.
  Future<eccore.CustomerStats?> getClientStats(String clientId) async {
    try {
      return await _admin.customerStats(clientId);
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Clients : fiche indisponible — ${e.code}');
      return null;
    }
  }

  /// Commandes d'un client, dans le périmètre d'établissements du compte
  /// connecté — c'est le serveur qui l'applique.
  Future<List<Order>> getClientOrders(String clientId) async {
    try {
      final commandes = await _orders.list(customerId: clientId);
      return commandes.map(DjangoOrderMapper.toLocal).toList();
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Clients : historique indisponible — ${e.code}');
      return [];
    }
  }

  /// Ferme un compte — le serveur **révoque ses jetons** dans la foulée.
  ///
  /// Le motif n'est plus facultatif : un compte fermé sans motif est un litige
  /// qu'on ne saura pas instruire six mois plus tard, quand le client
  /// rappellera. Le serveur le refuse à vide.
  Future<bool> suspendClient(String clientId, {required String reason}) async {
    try {
      final maj = await _admin.blockCustomer(
        customerId: clientId,
        reason: reason,
      );
      _remplacer(_toLocal(maj));
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Clients : blocage refusé — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  /// Rouvre un compte. L'utilisateur devra se reconnecter.
  Future<bool> reactivateClient(String clientId) async {
    try {
      final maj = await _admin.unblockCustomer(clientId);
      _remplacer(_toLocal(maj));
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Clients : déblocage refusé — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  void _remplacer(User client) {
    final index = _clients.indexWhere((c) => c.id == client.id);
    if (index != -1) _clients[index] = client;
    notifyListeners();
  }

  /// Traduit un dossier serveur vers le modèle local des écrans.
  ///
  /// `loyaltyPoints`, `badges` et `stats` restent vides : ce sont des agrégats
  /// que la liste ne porte pas, et les remplir article par article coûterait
  /// une requête par ligne affichée. La fiche détaillée les demande au serveur
  /// quand on l'ouvre.
  User _toLocal(eccore.Customer remote) {
    return User(
      id: remote.id,
      authUserId: remote.id,
      name: remote.fullName,
      email: remote.email,
      phone: remote.phone ?? '',
      role: UserRole.client,
      profileImageUrl: remote.avatar,
      createdAt: remote.createdAt,
      lastLoginAt: remote.lastSeenAt,
      isActive: remote.isActive,
    );
  }
}
