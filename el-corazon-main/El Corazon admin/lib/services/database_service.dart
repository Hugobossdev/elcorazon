import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../supabase/supabase_config.dart';

class DatabaseService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  SupabaseClient get client => _supabase;

  /// Utilisateur actuellement authentifié (Supabase Auth)
  User? get currentUser => _supabase.auth.currentUser;

  // --- Auth Methods ---

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
    dynamic role,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        if (phone != null) 'phone': phone,
        'role': role?.toString() ?? 'user',
      },
    );
    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // --- User Methods ---

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response =
          await _supabase.from('users').select().eq('id', userId).maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    await _supabase.from('users').update(updates).eq('id', userId);
  }

  Future<void> updateUserOnlineStatus(String userId, bool isOnline) async {
    await _supabase.from('users').update({
      'is_online': isOnline,
      'last_seen': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  // --- Menu Methods ---

  Future<List<Map<String, dynamic>>> getMenuCategories() async {
    final response = await _supabase
        .from('menu_categories')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getMenuItems([String? categoryId]) async {
    var query = _supabase.from('menu_items').select().eq('is_available', true);
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    final response = await query.order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getCustomizationOptions(
      String menuItemId) async {
    final response = await _supabase
        .from('menu_item_options')
        .select('*, customization_options(*)')
        .eq('menu_item_id', menuItemId);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Récupérer toutes les options de personnalisation
  Future<List<Map<String, dynamic>>> getAllCustomizationOptions() async {
    final response = await _supabase.from('customization_options').select();
    return List<Map<String, dynamic>>.from(response);
  }

  // --- Order Methods ---

  Future<String> createOrder(Map<String, dynamic> orderData) async {
    final response =
        await _supabase.from('orders').insert(orderData).select().single();
    return response['id'];
  }

  Future<void> addOrderItems(
      String orderId, List<Map<String, dynamic>> items) async {
    final itemsWithOrderId = items.map((item) {
      return {...item, 'order_id': orderId};
    }).toList();
    await _supabase.from('order_items').insert(itemsWithOrderId);
  }

  Future<List<Map<String, dynamic>>> getUserOrders(String userId) async {
    final response = await _supabase
        .from('orders')
        .select('*, order_items(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Récupère les détails d'une commande avec les informations des articles
  Future<Map<String, dynamic>?> getOrderDetailsWithMenuItems(
      String orderId) async {
    try {
      // 1. Récupérer la commande
      final orderResponse =
          await _supabase.from('orders').select().eq('id', orderId).single();

      // 2. Récupérer les articles de la commande avec les détails du menu_item
      // Note: Supabase permet de faire des jointures imbriquées
      final itemsResponse = await _supabase
          .from('order_items')
          .select('*, menu_items(name, image_url)')
          .eq('order_id', orderId);

      // 3. Combiner les résultats
      final orderDetails = Map<String, dynamic>.from(orderResponse);
      orderDetails['order_items'] = itemsResponse;

      return orderDetails;
    } catch (e) {
      debugPrint('Error fetching order details: $e');
      return null;
    }
  }

  /// Récupérer toutes les commandes avec les détails des articles
  /// Utile pour l'admin et l'analyse
  Future<List<Map<String, dynamic>>> getAllOrdersWithMenuDetails() async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*, order_items(*, menu_items(name, category_id))')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching all orders: $e');
      return [];
    }
  }

  /// Récupérer les statistiques des articles commandés avec gestion de réessai et erreur
  Future<List<Map<String, dynamic>>> getMenuItemsOrderStatistics({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        // Pause incrémentale en cas de retry
        if (retryCount > 0) {
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
        }

        // Utiliser une requête simplifiée si possible pour alléger la charge
        dynamic query = _supabase.from('order_items').select(
              'menu_item_id, menu_item_name, quantity, total_price, created_at',
            );

        if (startDate != null) {
          query = query.gte('created_at', startDate.toIso8601String());
        }
        if (endDate != null) {
          query = query.lte('created_at', endDate.toIso8601String());
        }
        
        // Appliquer la limite seulement si aucune autre agrégation n'est faite côté DB
        // Ici on récupère brut, donc limit est ok
        if (limit != null) {
          query = query.limit(limit * 5); // Récupérer plus pour pouvoir agréger localement
        } else {
          // Limite par défaut de sécurité
          query = query.limit(1000); 
        }

        final response = await query;
        final List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(response);
        
        // Agrégation locale basique
        final Map<String, Map<String, dynamic>> aggregated = {};
        
        for (var item in rawData) {
          // Clé unique: ID ou Nom
          final key = item['menu_item_id']?.toString() ?? item['menu_item_name']?.toString() ?? 'unknown';
          final name = item['menu_item_name']?.toString() ?? 'Produit inconnu';
          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
          final revenue = (item['total_price'] as num?)?.toDouble() ?? 0.0;
          
          if (!aggregated.containsKey(key)) {
            aggregated[key] = {
              'menu_item_id': item['menu_item_id'],
              'menu_item_name': name,
              'total_quantity': 0,
              'total_revenue': 0.0,
            };
          }
          
          aggregated[key]!['total_quantity'] = (aggregated[key]!['total_quantity'] as int) + qty;
          aggregated[key]!['total_revenue'] = (aggregated[key]!['total_revenue'] as double) + revenue;
        }
        
        // Trier et limiter
        var result = aggregated.values.toList();
        result.sort((a, b) => (b['total_quantity'] as int).compareTo(a['total_quantity'] as int));
        
        if (limit != null && result.length > limit) {
          result = result.take(limit).toList();
        }
        
        return result;
      } catch (e) {
        retryCount++;
        debugPrint('Error fetching menu stats (Attempt $retryCount/$maxRetries): $e');
        if (retryCount >= maxRetries) {
          // Retourner une liste vide après tous les échecs pour éviter de bloquer l'UI
          return [];
        }
      }
    }
    return [];
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _supabase.from('orders').update({'status': status}).eq('id', orderId);
  }

  // --- Delivery Methods ---

  Future<List<Map<String, dynamic>>> getActiveDeliveries(String driverId) async {
    final response = await _supabase
        .from('orders')
        .select('*, order_items(*)')
        .eq('delivery_person_id', driverId)
        .neq('status', 'delivered')
        .neq('status', 'cancelled');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateDeliveryLocation(
      String driverId, double lat, double lng) async {
    await _supabase.from('delivery_locations').upsert({
      'driver_id': driverId,
      'latitude': lat,
      'longitude': lng,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getDeliveryLocations(String driverId) async {
    try {
      final response = await _supabase
          .from('delivery_locations')
          .select()
          .eq('driver_id', driverId)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  // NOUVELLES MÉTHODES AJOUTÉES

  /// Récupérer la liste des livreurs disponibles
  Future<List<Map<String, dynamic>>> getDeliveryPersons() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('role', 'delivery')
          .eq('is_active', true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching delivery persons: $e');
      return [];
    }
  }

  /// Récupérer les commandes prêtes à être livrées (pour les livreurs)
  Future<List<Map<String, dynamic>>> getOrdersReadyForDelivery() async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*, restaurant:restaurant_id(name, address, latitude, longitude)')
          .eq('status', 'ready_for_pickup');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching orders ready for delivery: $e');
      return [];
    }
  }

  /// Récupérer l'historique des commandes d'un livreur
  Future<List<Map<String, dynamic>>> getOrdersByDeliveryPerson(
      String driverId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('delivery_person_id', driverId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching driver orders: $e');
      return [];
    }
  }

  /// Mettre à jour le statut d'une commande par un livreur (avec validation)
  Future<void> updateOrderStatusWithDeliveryPerson(
      String orderId, String status, String driverId) async {
    // Vérifier que la commande est bien assignée à ce livreur
    // (ou qu'elle n'est pas assignée si le livreur veut la prendre)
    if (status == 'accepted_by_driver') {
      await _supabase.from('orders').update({
        'status': status,
        'delivery_person_id': driverId,
      }).eq('id', orderId);
    } else {
      await _supabase
          .from('orders')
          .update({'status': status})
          .eq('id', orderId)
          .eq('delivery_person_id', driverId);
    }
  }

  // --- Notifications ---

  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true}).eq('id', notificationId);
  }

  // --- Social Features ---

  Future<List<Map<String, dynamic>>> getSocialGroups(String userId) async {
    // Implement complex query for groups joined by user
    // This is a placeholder as schema might vary
    return [];
  }

  Future<String> createSocialGroup(
      String name, String creatorId, Map<String, dynamic> settings) async {
    final response = await _supabase.from('social_groups').insert({
      'name': name,
      'creator_id': creatorId,
      'settings': settings,
    }).select().single();
    return response['id'];
  }

  Future<void> joinGroup(String groupId, String userId) async {
    await _supabase.from('group_members').insert({
      'group_id': groupId,
      'user_id': userId,
      'role': 'member',
    });
  }

  // --- Promotions & Marketing ---

  Future<List<Map<String, dynamic>>> getActivePromotions() async {
    final now = DateTime.now().toIso8601String();
    final response = await _supabase
        .from('promotions')
        .select()
        .eq('is_active', true)
        .lte('start_date', now)
        .gte('end_date', now);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> validatePromoCode(String code) async {
    final now = DateTime.now().toIso8601String();
    try {
      final response = await _supabase
          .from('promo_codes')
          .select()
          .eq('code', code)
          .eq('is_active', true)
          .lte('start_date', now)
          .gte('end_date', now)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  // --- Analytics ---

  Future<void> trackEvent({
    required String userId,
    required String eventType,
    required Map<String, dynamic> eventData,
  }) async {
    await _supabase.from('analytics_events').insert({
      'user_id': userId,
      'event_type': eventType,
      'metadata': eventData,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> getMenuStats() async {
    // This would typically involve Supabase RPC calls for complex aggregations
    // Placeholder implementation
    return {};
  }

  Future<Map<String, dynamic>> getRevenueStats(
      DateTime start, DateTime end) async {
    // Placeholder
    return {};
  }

  // --- Realtime Subscriptions ---
  // Return stream for various realtime updates

  Stream<List<Map<String, dynamic>>> subscribeToOrderUpdates(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((event) => List<Map<String, dynamic>>.from(event));
  }

  Stream<List<Map<String, dynamic>>> subscribeToDeliveryLocations(
      String driverId) {
    return _supabase
        .from('delivery_locations')
        .stream(primaryKey: ['driver_id'])
        .eq('driver_id', driverId)
        .map((event) => List<Map<String, dynamic>>.from(event));
  }

  Stream<List<Map<String, dynamic>>> subscribeToNotifications(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((event) => List<Map<String, dynamic>>.from(event));
  }
}
