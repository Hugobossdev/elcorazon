import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  Map<String, dynamic> _analyticsData = {};
  String? _error;

  bool get isLoading => _isLoading;
  Map<String, dynamic> get analyticsData => _analyticsData;
  String? get error => _error;

  void _setLoading(bool value) {
    _isLoading = value;
    Future.microtask(() => notifyListeners());
  }

  /// Récupérer toutes les données analytiques
  Future<void> loadAnalyticsData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_isLoading) return;
    
    _setLoading(true);
    _error = null;
    
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        if (retryCount > 0) {
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
        }

        // 1. Revenus
        final revenueData = await _supabase
            .from('orders')
            .select('total, created_at')
            .eq('status', 'delivered')
            .gte('created_at', startDate.toIso8601String())
            .lte('created_at', endDate.toIso8601String());

        // Pause pour laisser respirer la connexion
        await Future.delayed(const Duration(milliseconds: 300));

        // 2. Commandes
        final ordersData = await _supabase
            .from('orders')
            .select('status, created_at')
            .gte('created_at', startDate.toIso8601String())
            .lte('created_at', endDate.toIso8601String());

        // Pause
        await Future.delayed(const Duration(milliseconds: 300));

        // 3. Catégories
        final categoryData = await _supabase
            .from('order_items')
            .select('quantity, menu_items(category_id, menu_categories(name))')
            .gte('created_at', startDate.toIso8601String())
            .lte('created_at', endDate.toIso8601String());

        // Traitement des données
        final revenueResult = _processRevenueData(revenueData, startDate, endDate);
        final orderResult = _processOrderData(ordersData, startDate, endDate);
        final categoryResult = _processCategoryData(categoryData, startDate, endDate);

        _analyticsData = {
          'revenue': revenueResult,
          'orders': orderResult,
          'categories': categoryResult,
        };
        
        _setLoading(false);
        return;
      } catch (e) {
        retryCount++;
        debugPrint('Error fetching all analytics (Attempt $retryCount/$maxRetries): $e');
        
        if (retryCount >= maxRetries) {
          _error = 'Impossible de récupérer les données: ${e.toString()}';
          _setLoading(false);
        }
      }
    }
  }

  /// Ancienne méthode conservée pour compatibilité mais dépréciée
  Future<Map<String, dynamic>> fetchAllAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await loadAnalyticsData(startDate: startDate, endDate: endDate);
    if (_error != null) {
      return {'error': _error};
    }
    return _analyticsData;
  }

  Map<String, dynamic> _processRevenueData(List<dynamic> data, DateTime startDate, DateTime endDate) {
    double totalRevenue = 0.0;
    final Map<String, double> dailyRevenue = {};

    for (final order in data) {
      final total = (order['total'] as num?)?.toDouble() ?? 0.0;
      totalRevenue += total;

      final date = DateTime.parse(order['created_at']).toIso8601String().split('T')[0];
      dailyRevenue[date] = (dailyRevenue[date] ?? 0.0) + total;
    }

    return {
      'totalRevenue': totalRevenue,
      'dailyRevenue': dailyRevenue,
      'period': {
        'start': startDate.toIso8601String(),
        'end': endDate.toIso8601String(),
      },
    };
  }

  Map<String, dynamic> _processOrderData(List<dynamic> data, DateTime startDate, DateTime endDate) {
    final Map<String, int> statusCounts = {};
    final Map<String, int> dailyOrders = {};

    for (final order in data) {
      final status = order['status'] as String;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;

      final date = DateTime.parse(order['created_at']).toIso8601String().split('T')[0];
      dailyOrders[date] = (dailyOrders[date] ?? 0) + 1;
    }

    return {
      'totalOrders': data.length,
      'statusCounts': statusCounts,
      'dailyOrders': dailyOrders,
      'period': {
        'start': startDate.toIso8601String(),
        'end': endDate.toIso8601String(),
      },
    };
  }

  Map<String, dynamic> _processCategoryData(List<dynamic> data, DateTime startDate, DateTime endDate) {
    final Map<String, int> categoryCounts = {};
    final Map<String, double> categoryRevenue = {};

    for (final item in data) {
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      final menuItem = item['menu_items'] as Map<String, dynamic>?;
      final category = menuItem?['menu_categories'] as Map<String, dynamic>?;
      final categoryName = category?['name'] as String? ?? 'Inconnue';

      categoryCounts[categoryName] = (categoryCounts[categoryName] ?? 0) + quantity;
      categoryRevenue[categoryName] = (categoryRevenue[categoryName] ?? 0.0) + 0.0;
    }

    return {
      'categoryCounts': categoryCounts,
      'categoryRevenue': categoryRevenue,
      'period': {
        'start': startDate.toIso8601String(),
        'end': endDate.toIso8601String(),
      },
    };
  }

  /// Obtenir les revenus par période
  Future<Map<String, dynamic>> getRevenueAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      _setLoading(true);

      // Ajouter une pause pour éviter les problèmes de concurrence lors de l'initialisation
      await Future.delayed(const Duration(milliseconds: 100));

      final response = await _supabase
          .from('orders')
          .select('total, created_at')
          .eq('status', 'delivered')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String());

      double totalRevenue = 0.0;
      final Map<String, double> dailyRevenue = {};

      for (final order in response) {
        final total = (order['total'] as num?)?.toDouble() ?? 0.0;
        totalRevenue += total;

        final date =
            DateTime.parse(order['created_at']).toIso8601String().split('T')[0];
        dailyRevenue[date] = (dailyRevenue[date] ?? 0.0) + total;
      }

      _setLoading(false);

      return {
        'totalRevenue': totalRevenue,
        'dailyRevenue': dailyRevenue,
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
      };
    } catch (e) {
      debugPrint('Error getting revenue analytics: $e');
      _setLoading(false);
      return {
        'totalRevenue': 0.0,
        'dailyRevenue': <String, double>{},
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
      };
    }
  }

  /// Obtenir les statistiques des commandes
  Future<Map<String, dynamic>> getOrderAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      _setLoading(true);

      // Pause pour décaler l'appel réseau
      await Future.delayed(const Duration(milliseconds: 300));

      final response = await _supabase
          .from('orders')
          .select('status, created_at')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String());

      final Map<String, int> statusCounts = {};
      final Map<String, int> dailyOrders = {};

      for (final order in response) {
        final status = order['status'] as String;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        final date =
            DateTime.parse(order['created_at']).toIso8601String().split('T')[0];
        dailyOrders[date] = (dailyOrders[date] ?? 0) + 1;
      }

      _setLoading(false);

      return {
        'totalOrders': response.length,
        'statusCounts': statusCounts,
        'dailyOrders': dailyOrders,
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
      };
    } catch (e) {
      debugPrint('Error getting order analytics: $e');
      _setLoading(false);
      return {
        'totalOrders': 0,
        'statusCounts': <String, int>{},
        'dailyOrders': <String, int>{},
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
      };
    }
  }

  /// Obtenir les statistiques des catégories
  Future<Map<String, dynamic>> getCategoryAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      _setLoading(true);

      // Pause pour décaler l'appel réseau
      await Future.delayed(const Duration(milliseconds: 500));

      final response = await _supabase
          .from('order_items')
          .select('quantity, menu_items(category_id, menu_categories(name))')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String());

      final Map<String, int> categoryCounts = {};
      final Map<String, double> categoryRevenue = {};

      for (final item in response) {
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        final menuItem = item['menu_items'] as Map<String, dynamic>?;
        final category = menuItem?['menu_categories'] as Map<String, dynamic>?;
        final categoryName = category?['name'] as String? ?? 'Inconnue';

        categoryCounts[categoryName] =
            (categoryCounts[categoryName] ?? 0) + quantity;
        // Note: Pour le revenu par catégorie, il faudrait récupérer le prix des items
        categoryRevenue[categoryName] =
            (categoryRevenue[categoryName] ?? 0.0) + 0.0;
      }

      _setLoading(false);

      return {
        'categoryCounts': categoryCounts,
        'categoryRevenue': categoryRevenue,
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
      };
    } catch (e) {
      debugPrint('Error getting category analytics: $e');
      _setLoading(false);
      return {
        'categoryCounts': <String, int>{},
        'categoryRevenue': <String, double>{},
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
      };
    }
  }

  /// Obtenir les statistiques des livreurs
  Future<Map<String, dynamic>> getDriverAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      _setLoading(true);

      final response = await _supabase
          .from('orders')
          .select(
              'delivery_person_id, users!orders_delivery_person_id_fkey(name, email), status')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .not('delivery_person_id', 'is', null);

      final Map<String, int> driverDeliveries = {};
      final Map<String, double> driverRatings = {};

      for (final order in response) {
        final deliveryPersonId = order['delivery_person_id'] as String?;
        final user = order['users'] as Map<String, dynamic>?;
        final driverName = user?['name'] as String? ?? 'Livreur inconnu';
        // Note: rating n'est pas disponible dans la table users, on utilise 0.0 par défaut
        final rating = 0.0;

        if (deliveryPersonId != null) {
          driverDeliveries[driverName] =
              (driverDeliveries[driverName] ?? 0) + 1;
          driverRatings[driverName] = rating;
        }
      }

      _setLoading(false);

      return {
        'driverDeliveries': driverDeliveries,
        'driverRatings': driverRatings,
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
      };
    } catch (e) {
      debugPrint('Error getting driver analytics: $e');
      _setLoading(false);
      return {
        'driverDeliveries': <String, int>{},
        'driverRatings': <String, double>{},
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
      };
    }
  }

  /// Obtenir les statistiques générales
  Future<Map<String, dynamic>> getGeneralStats() async {
    try {
      _setLoading(true);

      // Statistiques des commandes
      final ordersResponse =
          await _supabase.from('orders').select('status, total, created_at');

      // Statistiques des utilisateurs
      final usersResponse = await _supabase.from('users').select('role');

      // Statistiques des produits
      final productsResponse =
          await _supabase.from('menu_items').select('is_available');

      // Statistiques des livreurs
      // Il existe deux relations drivers → users (user_id et verified_by),
      // on précise la bonne clé de relation pour éviter l'erreur PGRST201.
      final driversResponse = await _supabase
          .from('drivers')
          .select('status, users!drivers_user_id_fkey(is_active)');

      // Calculer les statistiques
      final totalOrders = ordersResponse.length;
      final completedOrders =
          ordersResponse.where((o) => o['status'] == 'delivered').length;
      final totalRevenue = ordersResponse
          .where((o) => o['status'] == 'delivered')
          .fold(
              0.0,
              (sum, order) =>
                  sum + ((order['total'] as num?)?.toDouble() ?? 0.0));

      final totalUsers = usersResponse.length;
      final adminUsers =
          usersResponse.where((u) => u['role'] == 'admin').length;
      final customerUsers =
          usersResponse.where((u) => u['role'] == 'customer').length;

      final totalProducts = productsResponse.length;
      final availableProducts =
          productsResponse.where((p) => p['is_available'] == true).length;

      final totalDrivers = driversResponse.length;
      final activeDrivers =
          driversResponse.where((d) => (d['users'] as Map<String, dynamic>)['is_active'] == true).length;
      final availableDrivers =
          driversResponse.where((d) => d['status'] == 'available').length;

      _setLoading(false);

      return {
        'orders': {
          'total': totalOrders,
          'completed': completedOrders,
          'completionRate':
              totalOrders > 0 ? (completedOrders / totalOrders) * 100 : 0.0,
        },
        'revenue': {
          'total': totalRevenue,
          'averageOrderValue':
              completedOrders > 0 ? totalRevenue / completedOrders : 0.0,
        },
        'users': {
          'total': totalUsers,
          'admins': adminUsers,
          'customers': customerUsers,
        },
        'products': {
          'total': totalProducts,
          'available': availableProducts,
          'availabilityRate': totalProducts > 0
              ? (availableProducts / totalProducts) * 100
              : 0.0,
        },
        'drivers': {
          'total': totalDrivers,
          'active': activeDrivers,
          'available': availableDrivers,
        },
      };
    } catch (e) {
      debugPrint('Error getting general stats: $e');
      _setLoading(false);
      return {
        'orders': {'total': 0, 'completed': 0, 'completionRate': 0.0},
        'revenue': {'total': 0.0, 'averageOrderValue': 0.0},
        'users': {'total': 0, 'admins': 0, 'customers': 0},
        'products': {'total': 0, 'available': 0, 'availabilityRate': 0.0},
        'drivers': {'total': 0, 'active': 0, 'available': 0},
      };
    }
  }
}
