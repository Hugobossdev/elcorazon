import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/statut_commande.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Contexte partagé des écrans d'administration (Phase 6).
///
/// Ce service pesait 600 lignes et faisait le travail de trois applications :
/// connexion et inscription de **clients**, panier, passage de commande,
/// écriture du catalogue. Autant de code injoignable depuis le back-office —
/// les écrans qui l'appelaient (`auth_screen`, `home_screen`, le panier)
/// n'étaient reliés à aucune route de l'application — et adossé à Supabase.
///
/// Ce qui reste est ce que les écrans lui demandent réellement : la commande du
/// jour, la carte, les catégories, et l'identité du compte connecté. Chaque
/// donnée vient de son domaine, par le serveur.
///
/// L'utilisateur courant est **celui de la session** (`AdminAuthService`), et
/// non un administrateur fictif fabriqué localement. L'ancienne version en
/// créait un — nom « Administrateur », UUID nul — quand aucune session n'était
/// trouvée : les écrans affichaient alors un compte qui n'existait pas, et le
/// premier appel serveur échouait sans que rien n'explique pourquoi.
class AppService extends ChangeNotifier {
  static final AppService _instance = AppService._internal();
  factory AppService() => _instance;
  AppService._internal();

  eccore.ManagedOrderRepository get _orders =>
      eccore.ManagedOrderRepository(apiClient: AdminAuthService().apiClient);

  eccore.ManagedCatalogRepository get _catalog =>
      eccore.ManagedCatalogRepository(apiClient: AdminAuthService().apiClient);

  /// Établissement supervisé — une seule enseigne pour l'instant.
  static const String _restaurantSlug = 'el-corazon-lome';

  bool _isInitialized = false;
  List<eccore.ManagedMenuItem> _menuItems = [];
  List<eccore.ManagedCategory> _categories = [];
  List<eccore.Order> _allOrders = [];
  String? _error;

  bool get isInitialized => _isInitialized;
  String? get error => _error;

  List<eccore.ManagedMenuItem> get menuItems => _menuItems;
  List<eccore.ManagedCategory> get categoriesList => _categories;
  List<eccore.Order> get allOrders => _allOrders;

  List<eccore.Order> get pendingOrders =>
      _allOrders.where((order) => order.statut == StatutCommande.enAttente).toList();

  List<eccore.Order> get activeOrders => _allOrders
      .where(
        (order) =>
            order.statut != StatutCommande.livree &&
            order.statut != StatutCommande.annulee,
      )
      .toList();

  List<String> get categories => _categories.map((c) => c.name).toList();

  /// Compte connecté — celui de la session, traduit une seule fois par
  /// [AdminAuthService].
  ///
  /// `null` tant que personne n'est authentifié ; les écrans d'administration
  /// ne sont de toute façon atteignables qu'après connexion.
  eccore.User? get currentUser => AdminAuthService().currentAdmin;

  bool get isLoggedIn => currentUser != null;
  bool get isAdmin => isLoggedIn;

  Future<void> initializeWithAdminUser() async {
    if (_isInitialized) return;
    await refresh();
  }

  Future<void> refresh() async {
    _error = null;

    try {
      final commandes = await _orders.list();
      _allOrders = commandes;

      final articles = await _catalog.menuItems(restaurantSlug: _restaurantSlug);
      _menuItems = articles;

      final categories = await _catalog.categories(
        restaurantSlug: _restaurantSlug,
      );
      _categories = categories;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('Contexte : chargement partiel — ${e.code}');
    } finally {
      // Marqué initialisé même en cas d'échec : sans cela, l'écran resterait
      // en chargement perpétuel sur une erreur de droits, sans rien afficher
      // ni expliquer.
      _isInitialized = true;
      notifyListeners();
    }
  }

  // --------------------------------------------------------- traduction

}
