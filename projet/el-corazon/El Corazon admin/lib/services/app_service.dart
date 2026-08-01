import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import '../models/category.dart' as app_models;
import '../models/menu_models.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../repositories/django_order_mapper.dart';
import 'admin_auth_service.dart';

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
  List<MenuItem> _menuItems = [];
  List<app_models.Category> _categories = [];
  List<Order> _allOrders = [];
  String? _error;

  bool get isInitialized => _isInitialized;
  String? get error => _error;

  List<MenuItem> get menuItems => _menuItems;
  List<app_models.Category> get categoriesList => _categories;
  List<Order> get allOrders => _allOrders;

  List<Order> get pendingOrders =>
      _allOrders.where((order) => order.status == OrderStatus.pending).toList();

  List<Order> get activeOrders => _allOrders
      .where(
        (order) =>
            order.status != OrderStatus.delivered &&
            order.status != OrderStatus.cancelled,
      )
      .toList();

  List<String> get categories => _categories.map((c) => c.name).toList();

  /// Compte connecté — celui de la session, traduit une seule fois par
  /// [AdminAuthService].
  ///
  /// `null` tant que personne n'est authentifié ; les écrans d'administration
  /// ne sont de toute façon atteignables qu'après connexion.
  User? get currentUser => AdminAuthService().currentAdmin;

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
      _allOrders = commandes.map(DjangoOrderMapper.toLocal).toList();

      final articles = await _catalog.menuItems(restaurantSlug: _restaurantSlug);
      _menuItems = articles.map(_toLocalMenuItem).toList();

      final categories = await _catalog.categories(
        restaurantSlug: _restaurantSlug,
      );
      _categories = categories.map(_toLocalCategory).toList();
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Contexte : chargement partiel — ${e.code}');
    } finally {
      // Marqué initialisé même en cas d'échec : sans cela, l'écran resterait
      // en chargement perpétuel sur une erreur de droits, sans rien afficher
      // ni expliquer.
      _isInitialized = true;
      notifyListeners();
    }
  }

  // --------------------------------------------------------- traduction

  MenuItem _toLocalMenuItem(eccore.MenuItem remote) {
    return MenuItem(
      id: remote.id,
      categoryId: remote.categorySlug,
      name: remote.name,
      description: remote.description.isEmpty ? null : remote.description,
      basePrice: remote.price.toMajorUnits(),
      imageUrl: remote.image,
      isPopular: remote.isPopular,
      isVegetarian: remote.dietaryTags.contains('vegetarian'),
      isVegan: remote.dietaryTags.contains('vegan'),
      isAvailable: remote.isAvailable,
      sortOrder: remote.sortOrder,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  app_models.Category _toLocalCategory(eccore.Category remote) {
    return app_models.Category(
      id: remote.id,
      name: remote.name,
      description: remote.description.isEmpty ? null : remote.description,
      emoji: remote.emoji.isEmpty ? null : remote.emoji,
      displayOrder: remote.sortOrder,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
