import 'package:flutter/foundation.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/menu_category.dart';
import 'package:elcora_fast/repositories/django_menu_repository.dart';
import 'package:elcora_fast/repositories/menu_repository.dart';

/// Modèle pour un élément de menu en cache
class CachedMenuItem {
  final MenuItem item;
  final DateTime cachedAt;
  final String? categoryId;

  CachedMenuItem({
    required this.item,
    required this.cachedAt,
    this.categoryId,
  });

  bool isExpired(Duration expiryDuration) {
    return DateTime.now().difference(cachedAt) > expiryDuration;
  }
}

/// Modèle pour une catégorie en cache
class CachedCategory {
  final MenuCategory category;
  final DateTime cachedAt;

  CachedCategory({
    required this.category,
    required this.cachedAt,
  });

  bool isExpired(Duration expiryDuration) {
    return DateTime.now().difference(cachedAt) > expiryDuration;
  }
}

/// Service de cache intelligent pour les menu items et catégories
class MenuItemCacheService {
  static final MenuItemCacheService _instance = MenuItemCacheService._internal();
  factory MenuItemCacheService() => _instance;
  MenuItemCacheService._internal();

  final MenuRepository _menuRepository = DjangoMenuRepository();

  // Cache des menu items
  final Map<String, CachedMenuItem> _menuItemsCache = {};
  DateTime? _menuItemsLastUpdate;
  
  // Cache des catégories
  final Map<String, CachedCategory> _categoriesCache = {};
  DateTime? _categoriesLastUpdate;

  // Durées d'expiration par défaut
  static const Duration _defaultMenuItemsExpiry = Duration(minutes: 5);
  static const Duration _defaultCategoriesExpiry = Duration(minutes: 10);
  
  // Durées d'expiration configurables
  Duration _menuItemsExpiry = _defaultMenuItemsExpiry;
  Duration _categoriesExpiry = _defaultCategoriesExpiry;

  /// Configure la durée d'expiration pour les menu items
  void setMenuItemsExpiry(Duration duration) {
    _menuItemsExpiry = duration;
  }

  /// Configure la durée d'expiration pour les catégories
  void setCategoriesExpiry(Duration duration) {
    _categoriesExpiry = duration;
  }

  /// Récupère les menu items depuis le cache ou la base de données
  Future<List<MenuItem>> getMenuItems({
    String? categoryId,
    bool forceRefresh = false,
    Duration? customExpiry,
  }) async {
    final expiry = customExpiry ?? _menuItemsExpiry;
    
    // Vérifier si on peut utiliser le cache
    if (!forceRefresh && 
        _menuItemsLastUpdate != null && 
        !_isCacheExpired(_menuItemsLastUpdate!, expiry)) {
      
      // Filtrer par catégorie si demandé
      List<MenuItem> items = _menuItemsCache.values
          .where((cached) => !cached.isExpired(expiry))
          .map((cached) => cached.item)
          .toList();
      
      if (categoryId != null) {
        items = items.where((item) => item.categoryId == categoryId).toList();
      }
      
      if (items.isNotEmpty) {
        debugPrint('📦 ${items.length} menu items chargés depuis le cache');
        return items;
      }
    }

    // Charger depuis le backend (avec requête optimisée)
    debugPrint('🔄 Chargement des menu items depuis le backend...');
    final items = await _menuRepository.getMenuItems(categoryId: categoryId);

    // Mettre à jour le cache
    _updateMenuItemsCache(items);
    
    // Filtrer par catégorie si demandé
    if (categoryId != null) {
      return items.where((item) => item.categoryId == categoryId).toList();
    }
    
    debugPrint('✅ ${items.length} menu items chargés depuis la base de données');
    return items;
  }

  /// Récupère un menu item spécifique par ID
  Future<MenuItem?> getMenuItemById(String id, {bool forceRefresh = false}) async {
    // Vérifier le cache d'abord
    if (!forceRefresh && _menuItemsCache.containsKey(id)) {
      final cached = _menuItemsCache[id]!;
      if (!cached.isExpired(_menuItemsExpiry)) {
        debugPrint('📦 Menu item $id chargé depuis le cache');
        return cached.item;
      }
    }

    // Charger depuis le backend
    try {
      final item = await _menuRepository.getMenuItemById(id);
      if (item == null) return null;

      // Mettre en cache
      _menuItemsCache[id] = CachedMenuItem(
        item: item,
        cachedAt: DateTime.now(),
        categoryId: item.categoryId,
      );
      
      return item;
    } catch (e) {
      debugPrint('❌ Erreur chargement menu item $id: $e');
      return null;
    }
  }

  /// Récupère les catégories depuis le cache ou la base de données
  Future<List<MenuCategory>> getCategories({
    bool forceRefresh = false,
    Duration? customExpiry,
  }) async {
    final expiry = customExpiry ?? _categoriesExpiry;
    
    // Vérifier si on peut utiliser le cache
    if (!forceRefresh && 
        _categoriesLastUpdate != null && 
        !_isCacheExpired(_categoriesLastUpdate!, expiry)) {
      
      final categories = _categoriesCache.values
          .where((cached) => !cached.isExpired(expiry))
          .map((cached) => cached.category)
          .toList();
      
      if (categories.isNotEmpty) {
        debugPrint('📦 ${categories.length} catégories chargées depuis le cache');
        return categories;
      }
    }

    // Charger depuis le backend
    debugPrint('🔄 Chargement des catégories depuis le backend...');
    final categories = await _menuRepository.getMenuCategories();

    // Mettre à jour le cache
    _updateCategoriesCache(categories);

    debugPrint('✅ ${categories.length} catégories chargées depuis le backend');
    return categories;
  }

  /// Met à jour le cache des menu items
  void _updateMenuItemsCache(List<MenuItem> items) {
    _menuItemsCache.clear();
    for (final item in items) {
      _menuItemsCache[item.id] = CachedMenuItem(
        item: item,
        cachedAt: DateTime.now(),
        categoryId: item.categoryId,
      );
    }
    _menuItemsLastUpdate = DateTime.now();
    debugPrint('💾 Cache des menu items mis à jour (${items.length} items)');
  }

  /// Met à jour le cache des catégories
  void _updateCategoriesCache(List<MenuCategory> categories) {
    _categoriesCache.clear();
    for (final category in categories) {
      _categoriesCache[category.id] = CachedCategory(
        category: category,
        cachedAt: DateTime.now(),
      );
    }
    _categoriesLastUpdate = DateTime.now();
    debugPrint('💾 Cache des catégories mis à jour (${categories.length} catégories)');
  }

  /// Vérifie si le cache est expiré
  bool _isCacheExpired(DateTime lastUpdate, Duration expiry) {
    return DateTime.now().difference(lastUpdate) > expiry;
  }

  /// Invalide le cache des menu items
  void invalidateMenuItemsCache() {
    _menuItemsCache.clear();
    _menuItemsLastUpdate = null;
    debugPrint('🗑️ Cache des menu items invalidé');
  }

  /// Invalide le cache des catégories
  void invalidateCategoriesCache() {
    _categoriesCache.clear();
    _categoriesLastUpdate = null;
    debugPrint('🗑️ Cache des catégories invalidé');
  }

  /// Invalide tout le cache
  void invalidateAllCache() {
    invalidateMenuItemsCache();
    invalidateCategoriesCache();
    debugPrint('🗑️ Tout le cache invalidé');
  }

  /// Met à jour un menu item dans le cache
  void updateMenuItemInCache(MenuItem item) {
    _menuItemsCache[item.id] = CachedMenuItem(
      item: item,
      cachedAt: DateTime.now(),
      categoryId: item.categoryId,
    );
    debugPrint('💾 Menu item ${item.id} mis à jour dans le cache');
  }

  /// Supprime un menu item du cache
  void removeMenuItemFromCache(String itemId) {
    _menuItemsCache.remove(itemId);
    debugPrint('🗑️ Menu item $itemId supprimé du cache');
  }

  /// Obtient les statistiques du cache
  Map<String, dynamic> getCacheStats() {
    final expiredMenuItems = _menuItemsCache.values
        .where((cached) => cached.isExpired(_menuItemsExpiry))
        .length;
    
    final expiredCategories = _categoriesCache.values
        .where((cached) => cached.isExpired(_categoriesExpiry))
        .length;

    return {
      'menu_items': {
        'total': _menuItemsCache.length,
        'expired': expiredMenuItems,
        'valid': _menuItemsCache.length - expiredMenuItems,
        'last_update': _menuItemsLastUpdate?.toIso8601String(),
        'expiry_duration_minutes': _menuItemsExpiry.inMinutes,
      },
      'categories': {
        'total': _categoriesCache.length,
        'expired': expiredCategories,
        'valid': _categoriesCache.length - expiredCategories,
        'last_update': _categoriesLastUpdate?.toIso8601String(),
        'expiry_duration_minutes': _categoriesExpiry.inMinutes,
      },
    };
  }

  /// Nettoie les entrées expirées du cache
  void cleanExpiredEntries() {
    final menuItemsBefore = _menuItemsCache.length;
    final categoriesBefore = _categoriesCache.length;

    _menuItemsCache.removeWhere((key, cached) => 
        cached.isExpired(_menuItemsExpiry),);
    
    _categoriesCache.removeWhere((key, cached) => 
        cached.isExpired(_categoriesExpiry),);

    final menuItemsRemoved = menuItemsBefore - _menuItemsCache.length;
    final categoriesRemoved = categoriesBefore - _categoriesCache.length;

    if (menuItemsRemoved > 0 || categoriesRemoved > 0) {
      debugPrint('🧹 Nettoyage du cache: $menuItemsRemoved menu items, $categoriesRemoved catégories supprimés');
    }
  }

  /// Précharge les menu items dans le cache
  Future<void> preloadMenuItems({String? categoryId}) async {
    debugPrint('🔄 Préchargement des menu items...');
    await getMenuItems(categoryId: categoryId, forceRefresh: true);
  }

  /// Précharge les catégories dans le cache
  Future<void> preloadCategories() async {
    debugPrint('🔄 Préchargement des catégories...');
    await getCategories(forceRefresh: true);
  }
}

