import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/user.dart' as app_models;
import '../supabase/supabase_config.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  SupabaseClient get _supabase {
    if (!SupabaseConfig.isInitialized) {
      throw Exception(
          'Supabase not initialized. Please call SupabaseConfig.initialize() first.');
    }
    return SupabaseConfig.client;
  }

  // =====================================================
  // AUTHENTICATION
  // =====================================================

  Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required app_models.UserRole role,
  }) async {
    try {
      // Check if Supabase is initialized
      if (!SupabaseConfig.isInitialized) {
        throw Exception(
            'Supabase n\'est pas initialisé. Veuillez vérifier votre connexion internet et réessayer.');
      }

      final supabaseClient = _supabase;

      // 1. VÉRIFICATIONS PRÉALABLES - Vérifier email et téléphone AVANT de créer le compte auth
      try {
        // Vérifier si l'email existe déjà dans users
        final existingEmail = await supabaseClient
            .from('users')
            .select('id, auth_user_id')
            .eq('email', email)
            .maybeSingle();

        if (existingEmail != null && existingEmail['auth_user_id'] != null) {
          throw Exception('Cet email est déjà utilisé par un autre compte');
        }

        // Vérifier si le téléphone existe déjà
        final existingPhone = await supabaseClient
            .from('users')
            .select('id, auth_user_id')
            .eq('phone', phone)
            .maybeSingle();

        if (existingPhone != null && existingPhone['auth_user_id'] != null) {
          throw Exception(
              'Ce numéro de téléphone est déjà utilisé par un autre compte');
        }
      } catch (e) {
        // Si c'est déjà une Exception avec un message clair, la relancer
        if (e is Exception &&
            (e.toString().contains('déjà utilisé') ||
                e.toString().contains('email') ||
                e.toString().contains('téléphone'))) {
          rethrow;
        }
        // Autres erreurs de vérification
        debugPrint('⚠️ Erreur lors de la vérification préalable: $e');
        throw Exception('Erreur lors de la vérification des informations: $e');
      }

      // 2. CRÉER LE COMPTE AUTH
      final response = await supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': phone,
          'role': role.toString().split('.').last,
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception(
            'Échec de la création du compte. Aucun utilisateur retourné.');
      }

      // 3. CRÉER LE PROFIL UTILISATEUR
      try {
        // Vérifier à nouveau si le profil existe (au cas où il aurait été créé entre-temps)
        final existingProfile = await supabaseClient
            .from('users')
            .select()
            .eq('auth_user_id', user.id)
            .maybeSingle();

        if (existingProfile != null) {
          // Le profil existe déjà, mettre à jour
          debugPrint('ℹ️ Profil utilisateur déjà existant, mise à jour...');
          await supabaseClient.from('users').update({
            'name': name,
            'email': email,
            'phone': phone,
            'role': role.toString().split('.').last,
            'is_active': true,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('auth_user_id', user.id);
        } else {
          // Créer le nouveau profil
          await supabaseClient.from('users').insert({
            'auth_user_id': user.id,
            'name': name,
            'email': email,
            'phone': phone,
            'role': role.toString().split('.').last,
            'loyalty_points': 0,
            'badges': [],
            'is_online': false,
            'is_active': true,
          });
          debugPrint('✅ Profil utilisateur créé avec succès pour: $email');
        }
      } on PostgrestException catch (e) {
        // Gérer spécifiquement les erreurs de contrainte unique
        if (e.code == '23505') {
          // Duplicate key error - peut arriver en cas de race condition
          String errorMessage;
          if (e.message.contains('phone') ||
              e.message.contains('users_phone_key')) {
            errorMessage =
                'Ce numéro de téléphone est déjà utilisé par un autre compte';
          } else if (e.message.contains('email') ||
              e.message.contains('users_email_key')) {
            errorMessage = 'Cet email est déjà utilisé par un autre compte';
          } else {
            errorMessage =
                'Un compte avec ces informations existe déjà. Veuillez vous connecter.';
          }
          debugPrint('❌ Erreur de clé dupliquée: ${e.message}');
          throw Exception(errorMessage);
        } else {
          // Autre erreur Postgres - CRITIQUE : relancer l'erreur
          debugPrint(
              '❌ Erreur Postgres lors de la création du profil: ${e.code} - ${e.message}');
          throw Exception('Erreur lors de la création du profil: ${e.message}');
        }
      } catch (e) {
        // Si c'est une Exception avec un message clair, la relancer
        if (e is Exception &&
            (e.toString().contains('téléphone') ||
                e.toString().contains('email') ||
                e.toString().contains('déjà utilisé'))) {
          rethrow;
        }
        // Autres erreurs - CRITIQUE : relancer pour ne pas laisser un compte auth orphelin
        debugPrint('❌ Erreur lors de la création du profil utilisateur: $e');
        throw Exception(
            'Erreur lors de la création du profil utilisateur. Veuillez réessayer.');
      }

      return response;
    } on AuthException catch (e) {
      // Handle Supabase auth errors
      String message = 'Erreur d\'authentification';
      if (e.message.contains('Invalid') || e.message.contains('invalid')) {
        message = 'Email ou mot de passe invalide';
      } else if (e.message.contains('already registered') ||
          e.message.contains('already exists') ||
          e.message.contains('User already registered')) {
        message = 'Cet email est déjà enregistré';
      } else if (e.message.contains('password') ||
          e.message.contains('Password')) {
        message = 'Le mot de passe doit contenir au moins 6 caractères';
      } else if (e.message.contains('Email rate limit') ||
          e.message.contains('rate limit')) {
        message = 'Trop de tentatives. Veuillez patienter quelques minutes.';
      } else {
        message =
            e.message.isNotEmpty ? e.message : 'Erreur d\'authentification';
      }
      throw Exception(message);
    } catch (e) {
      // Handle network and other errors
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('err_name_not_resolved') ||
          errorString.contains('name not resolved') ||
          errorString.contains('failed to resolve')) {
        throw Exception(
            'Impossible de se connecter au serveur. Vérifiez que l\'URL Supabase est correcte dans la configuration et que votre connexion internet fonctionne.');
      } else if (errorString.contains('failed to fetch') ||
          errorString.contains('network') ||
          errorString.contains('connection')) {
        throw Exception(
            'Erreur de connexion. Vérifiez votre connexion internet et réessayez. Si le problème persiste, cela peut être un problème de configuration CORS sur le serveur.');
      } else if (errorString.contains('timeout')) {
        throw Exception(
            'La requête a expiré. Vérifiez votre connexion internet et réessayez.');
      } else if (errorString.contains('cors')) {
        throw Exception(
            'Erreur de configuration serveur (CORS). Contactez le support technique.');
      }

      // Si c'est déjà une Exception avec un message, la relancer
      if (e is Exception) {
        rethrow;
      }

      throw Exception('Erreur lors de l\'inscription: ${e.toString()}');
    }
  }

  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Erreur lors de la connexion: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Erreur lors de la déconnexion: $e');
    }
  }

  User? get currentUser => _supabase.auth.currentUser;

  // =====================================================
  // USER MANAGEMENT
  // =====================================================

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('auth_user_id', userId)
          .maybeSingle();
      return response;
    } on PostgrestException catch (e) {
      // PGRST116: No rows returned - user profile doesn't exist yet
      // This is a normal case, not an error
      if (e.code == 'PGRST116' ||
          e.message.contains('0 rows') ||
          e.message
              .contains('Cannot coerce the result to a single JSON object')) {
        debugPrint(
            'ℹ️ User profile not found for userId: $userId (this is normal for new users)');
        return null;
      }
      debugPrint(
          '❌ PostgrestException in getUserProfile: ${e.code} - ${e.message}');
      throw Exception('Erreur lors de la récupération du profil: ${e.message}');
    } catch (e) {
      // Catch any other exceptions, including if maybeSingle() still throws
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('pgrst116') ||
          errorString.contains('0 rows') ||
          errorString.contains('cannot coerce')) {
        debugPrint(
            'ℹ️ User profile not found for userId: $userId (handled in catch)');
        return null;
      }
      debugPrint('❌ Error in getUserProfile: $e');
      throw Exception('Erreur lors de la récupération du profil: $e');
    }
  }

  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('users').update(updates).eq('auth_user_id', userId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du profil: $e');
    }
  }

  Future<void> updateUserOnlineStatus(String userId, bool isOnline) async {
    try {
      await _supabase.from('users').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('auth_user_id', userId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du statut: $e');
    }
  }

  // =====================================================
  // MENU MANAGEMENT
  // =====================================================

  Future<List<Map<String, dynamic>>> getMenuCategories() async {
    try {
      final response = await _supabase
          .from('menu_categories')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des catégories: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMenuItems({String? categoryId}) async {
    try {
      var query = _supabase.from('menu_items').select('''
            *,
            menu_categories!inner(name, display_name, emoji)
          ''').eq('is_available', true);

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      final response = await query.order('sort_order');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération du menu: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCustomizationOptions(
      String menuItemId) async {
    try {
      final response = await _supabase
          .from('menu_item_customizations')
          .select('''
            *,
            customization_options!inner(*)
          ''')
          .eq('menu_item_id', menuItemId)
          .eq('customization_options.is_active', true)
          .order('sort_order');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des options: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllCustomizationOptions() async {
    try {
      final response =
          await _supabase.from('menu_item_customizations').select('''
            *,
            customization_options!inner(*)
          ''').order('menu_item_id').order('sort_order');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors du chargement global des options: $e');
    }
  }

  // =====================================================
  // ORDER MANAGEMENT
  // =====================================================

  Future<String> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _supabase
          .from('orders')
          .insert(orderData)
          .select('id')
          .single();
      return response['id'];
    } catch (e) {
      throw Exception('Erreur lors de la création de la commande: $e');
    }
  }

  Future<void> addOrderItems(
      String orderId, List<Map<String, dynamic>> items) async {
    try {
      final itemsWithOrderId = items
          .map((item) => {
                ...item,
                'order_id': orderId,
              })
          .toList();

      await _supabase.from('order_items').insert(itemsWithOrderId);
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout des articles: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserOrders(String userId) async {
    try {
      final response = await _supabase.from('orders').select('''
            *,
            order_items(*)
          ''').eq('user_id', userId).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des commandes: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableOrders() async {
    try {
      // First, get all orders to see what we have (with error handling)
      List<Map<String, dynamic>> allOrders = [];
      try {
        final allOrdersResponse = await _supabase
            .from('orders')
            .select('id, status, delivery_person_id')
            .order('created_at', ascending: false)
            .limit(50)
            .timeout(const Duration(seconds: 10));

        allOrders = List<Map<String, dynamic>>.from(allOrdersResponse);
        debugPrint('📊 Total orders in database: ${allOrders.length}');

        if (allOrders.isNotEmpty) {
          final statusCounts = <String, int>{};
          final withDelivery =
              allOrders.where((o) => o['delivery_person_id'] != null).length;
          final withoutDelivery =
              allOrders.where((o) => o['delivery_person_id'] == null).length;

          for (var order in allOrders) {
            final status = order['status'] as String? ?? 'unknown';
            statusCounts[status] = (statusCounts[status] ?? 0) + 1;
          }

          debugPrint('📊 Orders by status: $statusCounts');
          debugPrint('📊 Orders with delivery person: $withDelivery');
          debugPrint('📊 Orders without delivery person: $withoutDelivery');
        }
      } catch (e) {
        debugPrint('⚠️ Could not fetch order statistics (non-critical): $e');
        // Continue even if statistics fail
      }

      // Get orders that are available for delivery
      // According to the workflow:
      // - Orders must have status: pending, confirmed, preparing, or ready
      // - Orders must NOT have a delivery_person_id assigned (NULL)
      // - Orders must NOT have an active delivery in active_deliveries table
      final response = await _supabase.from('orders').select('''
            *,
            order_items(*)
          ''').inFilter('status', [
        'pending',
        'ready',
        'confirmed',
        'preparing'
      ]).order('created_at', ascending: false);

      // Filter orders with null delivery_person_id in code
      final ordersWithStatus = List<Map<String, dynamic>>.from(response);
      final ordersWithoutDelivery = ordersWithStatus
          .where((order) => order['delivery_person_id'] == null)
          .toList();

      // Check active_deliveries to exclude orders that are already being delivered
      // (even if delivery_person_id is null, they might be in active_deliveries)
      List<String> activeOrderIds = [];
      try {
        final activeDeliveriesResponse = await _supabase
            .from('active_deliveries')
            .select('order_id')
            .inFilter('status', [
          'assigned',
          'accepted',
          'picked_up',
          'on_the_way'
        ]).timeout(const Duration(seconds: 5));

        activeOrderIds = (activeDeliveriesResponse as List)
            .map((ad) => ad['order_id'] as String)
            .toList();

        debugPrint('📋 Found ${activeOrderIds.length} active deliveries');
      } catch (e) {
        debugPrint('⚠️ Could not check active_deliveries (non-critical): $e');
        // Continue without filtering by active_deliveries
      }

      // Filter out orders that are in active_deliveries
      final orders = ordersWithoutDelivery
          .where((order) => !activeOrderIds.contains(order['id'] as String))
          .toList();

      debugPrint(
          '✅ Found ${orders.length} available orders (pending/confirmed/preparing/ready without delivery person and not in active_deliveries)');
      if (orders.isNotEmpty) {
        debugPrint(
            '📦 Available order IDs: ${orders.map((o) => o['id'].toString().substring(0, 8)).toList()}');
        debugPrint(
            '📦 Available order statuses: ${orders.map((o) => o['status']).toList()}');
      } else {
        debugPrint('⚠️ No available orders found.');
        if (ordersWithoutDelivery.isNotEmpty) {
          debugPrint(
              'ℹ️ ${ordersWithoutDelivery.length} orders found without delivery person, but they are in active_deliveries');
        } else {
          debugPrint(
              'ℹ️ All orders have a delivery person assigned or are in a non-available status');
          debugPrint(
              '💡 Tip: Create new orders or reset delivery_person_id to make orders available');
        }
      }

      return orders;
    } catch (e) {
      debugPrint('❌ Error in getAvailableOrders: $e');
      throw Exception(
          'Erreur lors de la récupération des commandes disponibles: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllOrders() async {
    try {
      final response = await _supabase.from('orders').select('''
            *,
            order_items(*)
          ''').order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception(
          'Erreur lors de la récupération de toutes les commandes: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, String status,
      {String? deliveryPersonId}) async {
    try {
      final updates = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (deliveryPersonId != null) {
        updates['delivery_person_id'] = deliveryPersonId;
      }

      await _supabase
          .from('orders')
          .update(updates)
          .eq('id', orderId)
          .timeout(const Duration(seconds: 10));

      // If assigning a delivery person, create/update active_deliveries entry
      // According to the workflow document, active_deliveries should be created when order is assigned
      if (deliveryPersonId != null) {
        try {
          // Check if active_delivery already exists
          final existingDelivery = await _supabase
              .from('active_deliveries')
              .select('id')
              .eq('order_id', orderId)
              .maybeSingle();

          // Determine active_delivery status based on order status
          // Workflow: assigned → accepted → picked_up → on_the_way → delivered
          String activeDeliveryStatus = 'assigned';
          if (status == 'confirmed') {
            // 'confirmed' in orders means 'accepted' in active_deliveries
            activeDeliveryStatus = 'accepted';
          } else if (status == 'picked_up') {
            activeDeliveryStatus = 'picked_up';
          } else if (status == 'on_the_way') {
            activeDeliveryStatus = 'on_the_way';
          } else if (status == 'delivered') {
            activeDeliveryStatus = 'delivered';
          }

          if (existingDelivery == null) {
            // Create new active_delivery entry according to workflow
            final insertData = {
              'delivery_id': deliveryPersonId,
              'order_id': orderId,
              'status': activeDeliveryStatus,
              'assigned_at': DateTime.now().toIso8601String(),
            };

            // Add timestamp based on status
            if (activeDeliveryStatus == 'accepted') {
              insertData['accepted_at'] = DateTime.now().toIso8601String();
            } else if (activeDeliveryStatus == 'picked_up') {
              insertData['picked_up_at'] = DateTime.now().toIso8601String();
            } else if (activeDeliveryStatus == 'on_the_way') {
              insertData['started_delivery_at'] =
                  DateTime.now().toIso8601String();
            } else if (activeDeliveryStatus == 'delivered') {
              insertData['delivered_at'] = DateTime.now().toIso8601String();
            }

            await _supabase.from('active_deliveries').insert(insertData);
            debugPrint(
                '✅ Created active_delivery entry for order $orderId with status $activeDeliveryStatus');
          } else {
            // Update existing entry
            final updateData = {
              'delivery_id': deliveryPersonId,
              'status': activeDeliveryStatus,
            };

            // Add timestamp based on status if not already set
            if (activeDeliveryStatus == 'accepted') {
              updateData['accepted_at'] = DateTime.now().toIso8601String();
            } else if (activeDeliveryStatus == 'picked_up') {
              updateData['picked_up_at'] = DateTime.now().toIso8601String();
            } else if (activeDeliveryStatus == 'on_the_way') {
              updateData['started_delivery_at'] =
                  DateTime.now().toIso8601String();
            } else if (activeDeliveryStatus == 'delivered') {
              updateData['delivered_at'] = DateTime.now().toIso8601String();
            }

            await _supabase
                .from('active_deliveries')
                .update(updateData)
                .eq('order_id', orderId);
            debugPrint(
                '✅ Updated active_delivery entry for order $orderId to status $activeDeliveryStatus');
          }
        } catch (e) {
          debugPrint(
              '⚠️ Could not create/update active_delivery (non-critical): $e');
          // Don't fail the whole operation if active_deliveries update fails
        }
      }
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du statut: $e');
    }
  }

  // =====================================================
  // DRIVER ADVANCED FEATURES (Ratings, Badges)
  // =====================================================

  Future<List<Map<String, dynamic>>> getDriverRatings(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_ratings')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la récupération des avis: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDriverBadges(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_earned_badges')
          .select('*, driver_badges(*)')
          .eq('driver_id', driverId)
          .order('earned_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la récupération des badges: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getDriverDetailedStats(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_detailed_stats_view')
          .select()
          .eq('driver_id', driverId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la récupération des stats détaillées: $e');
      return null;
    }
  }

  // =====================================================
  // DELIVERY MANAGEMENT
  // =====================================================

  Future<List<Map<String, dynamic>>> getActiveDeliveries(
      String deliveryId) async {
    try {
      final response = await _supabase
          .from('active_deliveries')
          .select('''
            *,
            orders!inner(*, order_items(*))
          ''')
          .eq('delivery_id', deliveryId)
          .inFilter(
              'status', ['assigned', 'accepted', 'picked_up', 'on_the_way'])
          .order('assigned_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des livraisons: $e');
    }
  }

  /// Récupère les commandes assignées à un livreur
  Future<List<Map<String, dynamic>>> getAssignedOrders(
      String deliveryId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            order_items(*)
          ''')
          .eq('delivery_person_id', deliveryId)
          .inFilter('status', [
            'confirmed', // accepted
            'preparing',
            'ready',
            'picked_up',
            'on_the_way'
          ])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error in getAssignedOrders: $e');
      throw Exception(
          'Erreur lors de la récupération des commandes assignées: $e');
    }
  }

  /// Met à jour le statut d'une livraison active dans active_deliveries
  /// Selon le workflow: assigned → accepted → picked_up → on_the_way → delivered
  Future<void> updateActiveDeliveryStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Ajouter les timestamps selon le statut
      switch (status) {
        case 'accepted':
          updates['accepted_at'] = DateTime.now().toIso8601String();
          break;
        case 'picked_up':
          updates['picked_up_at'] = DateTime.now().toIso8601String();
          break;
        case 'on_the_way':
          updates['started_delivery_at'] = DateTime.now().toIso8601String();
          break;
        case 'delivered':
          updates['delivered_at'] = DateTime.now().toIso8601String();
          break;
      }

      await _supabase
          .from('active_deliveries')
          .update(updates)
          .eq('order_id', orderId)
          .timeout(const Duration(seconds: 10));

      debugPrint(
          '✅ Updated active_delivery status to $status for order $orderId');
    } catch (e) {
      debugPrint('❌ Error updating active_delivery status: $e');
      throw Exception(
          'Erreur lors de la mise à jour du statut de livraison: $e');
    }
  }

  Future<void> updateDeliveryLocation({
    required String orderId,
    required String deliveryId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
  }) async {
    try {
      await _supabase.from('delivery_locations').insert({
        'order_id': orderId,
        'delivery_id': deliveryId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la position: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDeliveryLocations(
      String orderId) async {
    try {
      final response = await _supabase
          .from('delivery_locations')
          .select()
          .eq('order_id', orderId)
          .order('timestamp', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des positions: $e');
    }
  }

  // =====================================================
  // NOTIFICATIONS
  // =====================================================

  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des notifications: $e');
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase.from('notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', notificationId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la notification: $e');
    }
  }

  // =====================================================
  // SOCIAL FEATURES
  // =====================================================

  Future<List<Map<String, dynamic>>> getSocialGroups(String userId) async {
    try {
      final response = await _supabase.from('group_members').select('''
            *,
            social_groups!inner(*)
          ''').eq('user_id', userId).eq('is_active', true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des groupes: $e');
    }
  }

  Future<String> createSocialGroup({
    required String name,
    required String description,
    required String groupType,
    required String creatorId,
  }) async {
    try {
      final inviteCode =
          DateTime.now().millisecondsSinceEpoch.toString().substring(8);

      final response = await _supabase
          .from('social_groups')
          .insert({
            'name': name,
            'description': description,
            'group_type': groupType,
            'creator_id': creatorId,
            'invite_code': inviteCode,
            'is_private': false,
            'max_members': 50,
            'member_count': 1,
            'is_active': true,
          })
          .select('id')
          .single();

      // Add creator as member
      await _supabase.from('group_members').insert({
        'group_id': response['id'],
        'user_id': creatorId,
        'role': 'creator',
        'is_active': true,
      });

      return response['id'];
    } catch (e) {
      throw Exception('Erreur lors de la création du groupe: $e');
    }
  }

  Future<void> joinGroup(String groupId, String userId) async {
    try {
      await _supabase.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'role': 'member',
        'is_active': true,
      });
    } catch (e) {
      throw Exception('Erreur lors de l\'adhésion au groupe: $e');
    }
  }

  // Social Posts
  Future<List<Map<String, dynamic>>> getSocialPosts(
      {String? userId, String? groupId}) async {
    try {
      var query = _supabase.from('social_posts').select('''
            *,
            users!inner(name, email)
          ''').eq('is_public', true);

      if (userId != null) {
        query = query.eq('user_id', userId);
      }
      if (groupId != null) {
        query = query.eq('group_id', groupId);
      }

      final response =
          await query.order('created_at', ascending: false).limit(50);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des posts: $e');
    }
  }

  Future<String> createSocialPost({
    required String userId,
    required String content,
    required String postType,
    String? groupId,
    String? orderId,
    String? imageUrl,
  }) async {
    try {
      final response = await _supabase
          .from('social_posts')
          .insert({
            'user_id': userId,
            'group_id': groupId,
            'content': content,
            'post_type': postType,
            'order_id': orderId,
            'image_url': imageUrl,
            'is_public': groupId == null,
            'likes_count': 0,
            'comments_count': 0,
          })
          .select('id')
          .single();
      return response['id'];
    } catch (e) {
      throw Exception('Erreur lors de la création du post: $e');
    }
  }

  Future<void> likePost(String postId, String userId) async {
    try {
      // Check if already liked
      final existing = await _supabase
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': userId,
        });
        // Update likes count manually
        final current = await _supabase
            .from('social_posts')
            .select('likes_count')
            .eq('id', postId)
            .single();
        await _supabase
            .from('social_posts')
            .update({'likes_count': (current['likes_count'] ?? 0) + 1}).eq(
                'id', postId);
      }
    } catch (e) {
      // Try manual update if RPC fails
      try {
        final current = await _supabase
            .from('social_posts')
            .select('likes_count')
            .eq('id', postId)
            .single();
        await _supabase
            .from('social_posts')
            .update({'likes_count': (current['likes_count'] ?? 0) + 1}).eq(
                'id', postId);
      } catch (e2) {
        throw Exception('Erreur lors du like: $e');
      }
    }
  }

  Future<String> addPostComment(
      String postId, String userId, String content) async {
    try {
      final response = await _supabase
          .from('post_comments')
          .insert({
            'post_id': postId,
            'user_id': userId,
            'content': content,
          })
          .select('id')
          .single();

      // Update comments count
      try {
        final current = await _supabase
            .from('social_posts')
            .select('comments_count')
            .eq('id', postId)
            .single();
        await _supabase.from('social_posts').update({
          'comments_count': (current['comments_count'] ?? 0) + 1
        }).eq('id', postId);
      } catch (e) {
        debugPrint('Error updating comments count: $e');
      }

      return response['id'];
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout du commentaire: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPostComments(String postId) async {
    try {
      final response = await _supabase.from('post_comments').select('''
            *,
            users!inner(name, email)
          ''').eq('post_id', postId).order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des commentaires: $e');
    }
  }

  // =====================================================
  // PROMOTIONS
  // =====================================================

  Future<List<Map<String, dynamic>>> getActivePromotions() async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('promotions')
          .select()
          .eq('is_active', true)
          .gte('end_date', now)
          .lte('start_date', now)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des promotions: $e');
    }
  }

  Future<Map<String, dynamic>?> validatePromoCode(String promoCode) async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('promotions')
          .select()
          .eq('promo_code', promoCode)
          .eq('is_active', true)
          .gte('end_date', now)
          .lte('start_date', now)
          .maybeSingle();
      return response;
    } catch (e) {
      throw Exception('Erreur lors de la validation du code: $e');
    }
  }

  // =====================================================
  // ANALYTICS
  // =====================================================

  Future<void> trackEvent({
    required String eventType,
    required Map<String, dynamic> eventData,
    String? userId,
    String? sessionId,
  }) async {
    try {
      await _supabase.from('analytics_events').insert({
        'user_id': userId,
        'event_type': eventType,
        'event_data': eventData,
        'session_id': sessionId,
      });
    } catch (e) {
      // Analytics errors should not break the app
      print('Erreur analytics: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMenuStats() async {
    try {
      final response = await _supabase
          .from('menu_stats')
          .select()
          .order('total_revenue', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des statistiques: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRevenueStats() async {
    try {
      final response = await _supabase
          .from('revenue_stats')
          .select()
          .order('date', ascending: false)
          .limit(30);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des revenus: $e');
    }
  }

  // =====================================================
  // REALTIME SUBSCRIPTIONS
  // =====================================================

  RealtimeChannel subscribeToOrderUpdates(
      String orderId, Function(Map<String, dynamic>) onUpdate) {
    return _supabase
        .channel('order_updates_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: orderId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  RealtimeChannel subscribeToDeliveryLocations(
      String orderId, Function(Map<String, dynamic>) onLocationUpdate) {
    return _supabase
        .channel('delivery_locations_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'delivery_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: orderId,
          ),
          callback: (payload) => onLocationUpdate(payload.newRecord),
        )
        .subscribe();
  }

  RealtimeChannel subscribeToNotifications(
      String userId, Function(Map<String, dynamic>) onNotification) {
    return _supabase
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onNotification(payload.newRecord),
        )
        .subscribe();
  }

  // =====================================================
  // MESSAGES / CHAT
  // =====================================================

  Future<List<Map<String, dynamic>>> getMessages(String orderId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des messages: $e');
    }
  }

  Future<String> sendMessage({
    required String orderId,
    required String senderId,
    required String senderName,
    required String content,
    required bool isFromDriver,
    String? imageUrl,
    String type = 'text',
  }) async {
    try {
      final response = await _supabase
          .from('messages')
          .insert({
            'order_id': orderId,
            'sender_id': senderId,
            'sender_name': senderName,
            'content': content,
            'is_from_driver': isFromDriver,
            'image_url': imageUrl,
            'type': type,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();
      return response['id'] as String;
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi du message: $e');
    }
  }

  RealtimeChannel subscribeToMessages(
      String orderId, Function(Map<String, dynamic>) onMessage) {
    return _supabase
        .channel('messages_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: orderId,
          ),
          callback: (payload) => onMessage(payload.newRecord),
        )
        .subscribe();
  }

  // =====================================================
  // FILE UPLOAD (Supabase Storage)
  // =====================================================

  Future<String> uploadFile({
    required File file,
    required String bucketName,
    required String fileName,
    String? folder,
  }) async {
    try {
      final fileBytes = await file.readAsBytes();
      final path = folder != null ? '$folder/$fileName' : fileName;

      await _supabase.storage.from(bucketName).uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      throw Exception('Erreur lors de l\'upload du fichier: $e');
    }
  }

  Future<String> uploadFileBytes({
    required Uint8List fileBytes,
    required String bucketName,
    required String fileName,
    String? folder,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final path = folder != null ? '$folder/$fileName' : fileName;

      await _supabase.storage.from(bucketName).uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
            ),
          );

      final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      throw Exception('Erreur lors de l\'upload du fichier: $e');
    }
  }

  /// Crée ou met à jour le profil livreur et enregistre les documents dans driver_documents
  Future<void> createDriverProfile({
    required String authUserId,
    required String name,
    required String email,
    required String phone,
    required String licenseNumber,
    required String idNumber,
    required String vehicleType,
    required String vehicleNumber,
    String? profilePhotoUrl,
    String? licensePhotoUrl,
    String? idCardPhotoUrl,
    String? vehiclePhotoUrl,
    String? licenseFileName,
    String? idCardFileName,
    String? vehicleFileName,
    int? licenseFileSize,
    int? idCardFileSize,
    int? vehicleFileSize,
    String? licenseFileType,
    String? idCardFileType,
    String? vehicleFileType,
  }) async {
    try {
      // 1. Récupérer l'ID de l'utilisateur depuis la table users
      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_user_id', authUserId)
          .single();

      final userId = userResponse['id'] as String;

      // 2. Mettre à jour les informations de base dans users
      await _supabase.from('users').update({
        'name': name,
        'phone': phone,
        'profile_image': profilePhotoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('auth_user_id', authUserId);

      // 3. Créer ou mettre à jour le profil dans la table drivers
      final existingDriver = await _supabase
          .from('drivers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existingDriver != null) {
        // Mettre à jour le profil livreur existant
        await _supabase.from('drivers').update({
          'profile_photo_url': profilePhotoUrl,
          'license_number': licenseNumber,
          'id_number': idNumber,
          'vehicle_type': vehicleType,
          'vehicle_number': vehicleNumber,
          'license_photo_url': licensePhotoUrl,
          'id_card_photo_url': idCardPhotoUrl,
          'vehicle_photo_url': vehiclePhotoUrl,
          'verification_status':
              'pending', // Remettre en attente si nouveau fichier
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', userId);
        debugPrint('✅ Profil livreur mis à jour dans la table drivers');
      } else {
        // Créer un nouveau profil livreur
        await _supabase.from('drivers').insert({
          'user_id': userId,
          'profile_photo_url': profilePhotoUrl,
          'license_number': licenseNumber,
          'id_number': idNumber,
          'vehicle_type': vehicleType,
          'vehicle_number': vehicleNumber,
          'license_photo_url': licensePhotoUrl,
          'id_card_photo_url': idCardPhotoUrl,
          'vehicle_photo_url': vehiclePhotoUrl,
          'verification_status': 'pending',
        });
        debugPrint('✅ Profil livreur créé dans la table drivers');
      }

      // 4. Créer ou mettre à jour les documents dans driver_documents
      final documents = <Map<String, dynamic>>[];

      // Document permis de conduire
      if (licensePhotoUrl != null && licensePhotoUrl.isNotEmpty) {
        documents.add({
          'user_id': userId,
          'document_type': 'license',
          'status': 'pending',
          'file_url': licensePhotoUrl,
          'file_name': licenseFileName ??
              'license_${DateTime.now().millisecondsSinceEpoch}.jpg',
          'file_type': licenseFileType ?? 'image/jpeg',
          'file_size': licenseFileSize,
          'uploaded_at': DateTime.now().toIso8601String(),
        });
      }

      // Document carte d'identité
      if (idCardPhotoUrl != null && idCardPhotoUrl.isNotEmpty) {
        documents.add({
          'user_id': userId,
          'document_type': 'identity',
          'status': 'pending',
          'file_url': idCardPhotoUrl,
          'file_name': idCardFileName ??
              'identity_${DateTime.now().millisecondsSinceEpoch}.jpg',
          'file_type': idCardFileType ?? 'image/jpeg',
          'file_size': idCardFileSize,
          'uploaded_at': DateTime.now().toIso8601String(),
        });
      }

      // Document véhicule
      if (vehiclePhotoUrl != null && vehiclePhotoUrl.isNotEmpty) {
        documents.add({
          'user_id': userId,
          'document_type': 'vehicle',
          'status': 'pending',
          'file_url': vehiclePhotoUrl,
          'file_name': vehicleFileName ??
              'vehicle_${DateTime.now().millisecondsSinceEpoch}.jpg',
          'file_type': vehicleFileType ?? 'image/jpeg',
          'file_size': vehicleFileSize,
          'uploaded_at': DateTime.now().toIso8601String(),
        });
      }

      // 5. Insérer ou mettre à jour chaque document (upsert avec ON CONFLICT)
      for (final doc in documents) {
        try {
          // Vérifier si le document existe déjà
          final existingDoc = await _supabase
              .from('driver_documents')
              .select('id')
              .eq('user_id', userId)
              .eq('document_type', doc['document_type'])
              .maybeSingle();

          if (existingDoc != null) {
            // Mettre à jour le document existant
            await _supabase.from('driver_documents').update({
              'file_url': doc['file_url'],
              'file_name': doc['file_name'],
              'file_type': doc['file_type'],
              'file_size': doc['file_size'],
              'status': 'pending', // Remettre en attente si nouveau fichier
              'uploaded_at': doc['uploaded_at'],
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', existingDoc['id']);
            debugPrint('✅ Document ${doc['document_type']} mis à jour');
          } else {
            // Créer un nouveau document
            await _supabase.from('driver_documents').insert(doc);
            debugPrint('✅ Document ${doc['document_type']} créé');
          }
        } catch (e) {
          debugPrint(
              '⚠️ Erreur lors de l\'enregistrement du document ${doc['document_type']}: $e');
          // Continuer avec les autres documents même si un échoue
        }
      }

      debugPrint(
          '✅ Profil livreur créé/mis à jour avec ${documents.length} documents');
    } catch (e) {
      debugPrint('❌ Erreur lors de la création du profil livreur: $e');
      throw Exception('Erreur lors de la création du profil livreur: $e');
    }
  }

  /// Récupère le profil livreur complet avec les informations utilisateur
  Future<Map<String, dynamic>?> getDriverProfile(String userId) async {
    try {
      final response = await _supabase
          .from('drivers_with_user_info')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération du profil livreur: $e');
      throw Exception('Erreur lors de la récupération du profil livreur: $e');
    }
  }

  /// Récupère le profil livreur par auth_user_id
  Future<Map<String, dynamic>?> getDriverProfileByAuthId(
      String authUserId) async {
    try {
      // D'abord récupérer l'ID utilisateur
      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_user_id', authUserId)
          .maybeSingle();

      if (userResponse == null) {
        return null;
      }

      final userId = userResponse['id'] as String;
      return await getDriverProfile(userId);
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération du profil livreur: $e');
      throw Exception('Erreur lors de la récupération du profil livreur: $e');
    }
  }

  /// Récupère les documents d'un livreur
  Future<List<Map<String, dynamic>>> getDriverDocuments(String userId) async {
    try {
      final response = await _supabase
          .from('driver_documents')
          .select()
          .eq('user_id', userId)
          .order('uploaded_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des documents: $e');
      throw Exception('Erreur lors de la récupération des documents: $e');
    }
  }

  /// Valide ou rejette un document (admin seulement)
  Future<void> validateDriverDocument({
    required String documentId,
    required String status, // 'approved' ou 'rejected'
    String? validationNotes,
    String? rejectionReason,
    String? validatedByUserId,
  }) async {
    try {
      final updateData = {
        'status': status,
        'validated_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (validatedByUserId != null) {
        updateData['validated_by'] = validatedByUserId;
      }

      if (validationNotes != null && validationNotes.isNotEmpty) {
        updateData['validation_notes'] = validationNotes;
      }

      if (status == 'rejected' && rejectionReason != null) {
        updateData['rejection_reason'] = rejectionReason;
      }

      await _supabase
          .from('driver_documents')
          .update(updateData)
          .eq('id', documentId);

      debugPrint('✅ Document $documentId validé avec statut: $status');
    } catch (e) {
      debugPrint('❌ Erreur lors de la validation du document: $e');
      throw Exception('Erreur lors de la validation du document: $e');
    }
  }

  /// Récupère tous les documents en attente de validation (admin)
  Future<List<Map<String, dynamic>>> getPendingDriverDocuments() async {
    try {
      final response = await _supabase
          .from('pending_driver_documents_view')
          .select()
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint(
          '❌ Erreur lors de la récupération des documents en attente: $e');
      throw Exception(
          'Erreur lors de la récupération des documents en attente: $e');
    }
  }

  /// Récupère tous les livreurs en attente de vérification (admin)
  Future<List<Map<String, dynamic>>> getPendingDriverVerifications() async {
    try {
      final response = await _supabase
          .from('pending_driver_verifications')
          .select()
          .order('registration_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint(
          '❌ Erreur lors de la récupération des livreurs en attente: $e');
      throw Exception(
          'Erreur lors de la récupération des livreurs en attente: $e');
    }
  }

  /// Met à jour la disponibilité d'un livreur
  Future<void> updateDriverAvailability({
    required String userId,
    required bool isAvailable,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'is_available': isAvailable,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (latitude != null && longitude != null) {
        updateData['current_location_latitude'] = latitude;
        updateData['current_location_longitude'] = longitude;
        updateData['last_location_update'] = DateTime.now().toIso8601String();
      }

      await _supabase.from('drivers').update(updateData).eq('user_id', userId);

      debugPrint('✅ Disponibilité livreur mise à jour: $isAvailable');
    } catch (e) {
      debugPrint('❌ Erreur lors de la mise à jour de la disponibilité: $e');
      throw Exception('Erreur lors de la mise à jour de la disponibilité: $e');
    }
  }

  /// Enregistre une transaction de retrait
  Future<void> recordWithdrawal({
    required String userId,
    required double amount,
    required String transactionId,
    required String status,
  }) async {
    try {
      // Si la table withdrawals n'existe pas, on peut utiliser une table générique
      // ou créer une entrée dans une table de transactions
      await _supabase.from('withdrawals').insert({
        'user_id': userId,
        'amount': amount,
        'transaction_id': transactionId,
        'status': status,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 10));

      debugPrint('✅ Retrait enregistré: $transactionId pour $amount XOF');
    } catch (e) {
      // Si la table n'existe pas, on peut logger l'erreur mais ne pas bloquer
      debugPrint(
          '⚠️ Impossible d\'enregistrer le retrait (table peut ne pas exister): $e');
      // Ne pas throw pour éviter de bloquer le processus de retrait
    }
  }
}
