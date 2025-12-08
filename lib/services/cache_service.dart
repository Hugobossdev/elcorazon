import 'dart:async';
import 'dart:convert';
// import 'dart:io'; // Non utilisé
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:path_provider/path_provider.dart'; // Non utilisé
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/user.dart';

/// Service de cache et de synchronisation des données
class CacheService extends ChangeNotifier {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Cache en mémoire
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Configuration du cache
  static const Duration _defaultCacheExpiry = Duration(hours: 1);
  static const Duration _menuCacheExpiry = Duration(hours: 6);
  static const Duration _userCacheExpiry = Duration(days: 1);
  static const Duration _orderCacheExpiry = Duration(hours: 2);

  // Getters
  bool get isInitialized => _isInitialized;
  int get cacheSize => _memoryCache.length;

  /// Initialiser le service de cache
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();

      // Charger le cache depuis le stockage local
      await _loadCacheFromStorage();

      _isInitialized = true;
      notifyListeners();

      debugPrint('✅ CacheService initialisé');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation du CacheService: $e');
    }
  }

  /// Charger le cache depuis le stockage local de manière optimisée
  Future<void> _loadCacheFromStorage() async {
    try {
      // Charger les données de cache en parallèle
      final cacheData = _prefs?.getString('cache_data');
      final timestampData = _prefs?.getString('cache_timestamps');

      if (cacheData != null) {
        final Map<String, dynamic> data = json.decode(cacheData);
        _memoryCache.addAll(data);
      }

      if (timestampData != null) {
        final Map<String, dynamic> timestamps = json.decode(timestampData);
        timestamps.forEach((key, value) {
          _cacheTimestamps[key] = DateTime.parse(value);
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement du cache: $e');
    }
  }

  /// Sauvegarder le cache dans le stockage local
  Future<void> _saveCacheToStorage() async {
    try {
      await _prefs?.setString('cache_data', json.encode(_memoryCache));
      final timestamps = _cacheTimestamps
          .map((key, value) => MapEntry(key, value.toIso8601String()));
      await _prefs?.setString('cache_timestamps', json.encode(timestamps));
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde du cache: $e');
    }
  }

  /// Mettre en cache une valeur
  Future<void> setCache(String key, dynamic value, {Duration? expiry}) async {
    if (!_isInitialized) await initialize();

    _memoryCache[key] = value;
    _cacheTimestamps[key] = DateTime.now();

    // Sauvegarder immédiatement pour les données importantes
    if (key.startsWith('user_') || key.startsWith('menu_')) {
      await _saveCacheToStorage();
    }

    notifyListeners();
  }

  /// Récupérer une valeur du cache
  T? getCache<T>(String key, {Duration? expiry}) {
    if (!_isInitialized) return null;

    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return null;

    final cacheExpiry = expiry ?? _defaultCacheExpiry;
    if (DateTime.now().difference(timestamp) > cacheExpiry) {
      _removeCache(key);
      return null;
    }

    return _memoryCache[key] as T?;
  }

  /// Vérifier si une clé existe dans le cache
  bool hasCache(String key, {Duration? expiry}) {
    return getCache(key, expiry: expiry) != null;
  }

  /// Supprimer une valeur du cache
  void _removeCache(String key) {
    _memoryCache.remove(key);
    _cacheTimestamps.remove(key);
    notifyListeners();
  }

  /// Supprimer une valeur du cache
  Future<void> removeCache(String key) async {
    _removeCache(key);
    await _saveCacheToStorage();
  }

  /// Nettoyer le cache expiré
  Future<void> cleanExpiredCache() async {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    _cacheTimestamps.forEach((key, timestamp) {
      final expiry = _getExpiryForKey(key);
      if (now.difference(timestamp) > expiry) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _removeCache(key);
    }

    if (expiredKeys.isNotEmpty) {
      await _saveCacheToStorage();
      debugPrint(
          '🧹 ${expiredKeys.length} entrées de cache expirées supprimées',);
    }
  }

  /// Obtenir la durée d'expiration pour une clé
  Duration _getExpiryForKey(String key) {
    if (key.startsWith('menu_')) return _menuCacheExpiry;
    if (key.startsWith('user_')) return _userCacheExpiry;
    if (key.startsWith('order_')) return _orderCacheExpiry;
    return _defaultCacheExpiry;
  }

  /// Nettoyer tout le cache
  Future<void> clearAllCache() async {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    await _prefs?.remove('cache_data');
    await _prefs?.remove('cache_timestamps');
    notifyListeners();
    debugPrint('🧹 Cache entièrement nettoyé');
  }

  /// Cache des items du menu
  Future<void> cacheMenuItems(List<MenuItem> items) async {
    final itemsJson = items.map((item) => item.toMap()).toList();
    await setCache('menu_items', itemsJson, expiry: _menuCacheExpiry);
  }

  /// Récupérer les items du menu du cache
  List<MenuItem>? getCachedMenuItems() {
    final itemsJson =
        getCache<List<dynamic>>('menu_items', expiry: _menuCacheExpiry);
    if (itemsJson == null) return null;

    try {
      return itemsJson.map((json) => MenuItem.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Erreur lors de la désérialisation du menu: $e');
      return null;
    }
  }

  /// Cache des commandes utilisateur
  Future<void> cacheUserOrders(String userId, List<Order> orders) async {
    final ordersJson = orders.map((order) => order.toMap()).toList();
    await setCache('user_orders_$userId', ordersJson,
        expiry: _orderCacheExpiry,);
  }

  /// Récupérer les commandes utilisateur du cache
  List<Order>? getCachedUserOrders(String userId) {
    final ordersJson = getCache<List<dynamic>>('user_orders_$userId',
        expiry: _orderCacheExpiry,);
    if (ordersJson == null) return null;

    try {
      return ordersJson.map((json) => Order.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Erreur lors de la désérialisation des commandes: $e');
      return null;
    }
  }

  /// Cache du profil utilisateur
  Future<void> cacheUserProfile(User user) async {
    await setCache('user_profile_${user.id}', user.toMap(),
        expiry: _userCacheExpiry,);
  }

  /// Récupérer le profil utilisateur du cache
  User? getCachedUserProfile(String userId) {
    final userJson = getCache<Map<String, dynamic>>('user_profile_$userId',
        expiry: _userCacheExpiry,);
    if (userJson == null) return null;

    try {
      return User.fromMap(userJson);
    } catch (e) {
      debugPrint('Erreur lors de la désérialisation du profil: $e');
      return null;
    }
  }

  /// Cache des favoris
  Future<void> cacheFavorites(String userId, List<String> favoriteIds) async {
    await setCache('favorites_$userId', favoriteIds, expiry: _userCacheExpiry);
  }

  /// Récupérer les favoris du cache
  List<String>? getCachedFavorites(String userId) {
    return getCache<List<String>>('favorites_$userId',
        expiry: _userCacheExpiry,);
  }

  /// Cache des items récents
  Future<void> cacheRecentItems(String userId, List<String> recentIds) async {
    await setCache('recent_items_$userId', recentIds, expiry: _userCacheExpiry);
  }

  /// Récupérer les items récents du cache
  List<String>? getCachedRecentItems(String userId) {
    return getCache<List<String>>('recent_items_$userId',
        expiry: _userCacheExpiry,);
  }

  /// Cache des préférences utilisateur
  Future<void> cacheUserPreferences(
      String userId, Map<String, dynamic> preferences,) async {
    await setCache('preferences_$userId', preferences,
        expiry: _userCacheExpiry,);
  }

  /// Récupérer les préférences utilisateur du cache
  Map<String, dynamic>? getCachedUserPreferences(String userId) {
    return getCache<Map<String, dynamic>>('preferences_$userId',
        expiry: _userCacheExpiry,);
  }

  /// Cache des codes promo
  Future<void> cachePromoCodes(List<Map<String, dynamic>> promoCodes) async {
    await setCache('promo_codes', promoCodes, expiry: const Duration(hours: 12));
  }

  /// Récupérer les codes promo du cache
  List<Map<String, dynamic>>? getCachedPromoCodes() {
    return getCache<List<Map<String, dynamic>>>('promo_codes',
        expiry: const Duration(hours: 12),);
  }

  /// Cache des adresses
  Future<void> cacheAddresses(
      String userId, List<Map<String, dynamic>> addresses,) async {
    await setCache('addresses_$userId', addresses, expiry: _userCacheExpiry);
  }

  /// Récupérer les adresses du cache
  List<Map<String, dynamic>>? getCachedAddresses(String userId) {
    return getCache<List<Map<String, dynamic>>>('addresses_$userId',
        expiry: _userCacheExpiry,);
  }

  /// Cache des recommandations IA
  Future<void> cacheAIRecommendations(
      String userId, List<MenuItem> recommendations,) async {
    final itemsJson = recommendations.map((item) => item.toMap()).toList();
    await setCache('ai_recommendations_$userId', itemsJson,
        expiry: const Duration(hours: 2),);
  }

  /// Récupérer les recommandations IA du cache
  List<MenuItem>? getCachedAIRecommendations(String userId) {
    final itemsJson = getCache<List<dynamic>>('ai_recommendations_$userId',
        expiry: const Duration(hours: 2),);
    if (itemsJson == null) return null;

    try {
      return itemsJson.map((json) => MenuItem.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Erreur lors de la désérialisation des recommandations: $e');
      return null;
    }
  }

  /// Obtenir les statistiques du cache
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int expiredCount = 0;
    int validCount = 0;

    _cacheTimestamps.forEach((key, timestamp) {
      final expiry = _getExpiryForKey(key);
      if (now.difference(timestamp) > expiry) {
        expiredCount++;
      } else {
        validCount++;
      }
    });

    return {
      'total_entries': _memoryCache.length,
      'valid_entries': validCount,
      'expired_entries': expiredCount,
      'memory_usage': _estimateMemoryUsage(),
    };
  }

  /// Estimer l'utilisation mémoire du cache
  int _estimateMemoryUsage() {
    int totalSize = 0;
    _memoryCache.forEach((key, value) {
      totalSize += key.length * 2; // UTF-16
      if (value is String) {
        totalSize += value.length * 2;
      } else if (value is List) {
        totalSize += value.length * 8; // Estimation
      } else if (value is Map) {
        totalSize += value.length * 16; // Estimation
      }
    });
    return totalSize;
  }

  /// Nettoyer le cache périodiquement
  Future<void> startPeriodicCleanup() async {
    // Nettoyer le cache expiré toutes les heures
    Timer.periodic(const Duration(hours: 1), (timer) async {
      await cleanExpiredCache();
    });
  }

  /// Sauvegarder le cache avant la fermeture de l'app
  Future<void> saveCacheOnExit() async {
    await _saveCacheToStorage();
    debugPrint('💾 Cache sauvegardé avant fermeture');
  }

  @override
  void dispose() {
    saveCacheOnExit();
    super.dispose();
  }
}
