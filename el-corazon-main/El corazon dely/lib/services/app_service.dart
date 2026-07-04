import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import conditionnel pour File (mobile vs web)
import 'dart:io' if (dart.library.html) 'dart:html' as io;
import '../models/user.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/message.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'gamification_service.dart';
import 'realtime_tracking_service.dart';
import 'database_service.dart';
import 'storage_service.dart';
import 'paydunya_service.dart';

class AppService extends ChangeNotifier {
  static final AppService _instance = AppService._internal();
  factory AppService() => _instance;
  AppService._internal();

  User? _currentUser;
  bool _isInitialized = false;
  List<MenuItem> _menuItems = [];
  List<Order> _orders = [];
  final List<MenuItem> _cartItems = [];

  // Services intégrés
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final GamificationService _gamificationService = GamificationService();
  final DatabaseService _databaseService = DatabaseService();

  // Getters
  User? get currentUser => _currentUser;
  List<MenuItem> get menuItems => _menuItems.isNotEmpty ? _menuItems : [];
  List<Order> get orders => _orders;
  List<MenuItem> get cartItems => _cartItems;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;

  // Obtenir les catégories uniques des items du menu
  List<String> get categories {
    if (_menuItems.isEmpty) return ['Burgers', 'Pizzas', 'Drinks', 'Desserts'];
    return _menuItems.map((item) => item.category.displayName).toSet().toList();
  }

  // Services getters
  LocationService get locationService => _locationService;
  NotificationService get notificationService => _notificationService;
  GamificationService get gamificationService => _gamificationService;
  RealtimeTrackingService get trackingService => RealtimeTrackingService();
  DatabaseService get databaseService => _databaseService;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isDeliveryStaff => _currentUser?.role == UserRole.delivery;
  bool get isClient => _currentUser?.role == UserRole.client;

  double get cartTotal {
    return _cartItems.fold(0.0, (sum, item) => sum + item.price);
  }

  int get cartItemCount {
    return _cartItems.length;
  }

  Future<void> initialize() async {
    try {
      // Load menu items from database
      await _loadMenuItems();

      // Check if user is already logged in
      final currentAuthUser = _databaseService.currentUser;
      if (currentAuthUser != null) {
        await _loadUserProfile(currentAuthUser.id);
        // Load user orders after profile is loaded
        await _loadUserOrders();

        // If user is delivery staff, also load available orders
        if (_currentUser?.role == UserRole.delivery) {
          await loadAvailableOrders();
        }
      } else {
        // Load all orders for delivery staff to see available orders
        await _loadAllOrders();
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing AppService: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Authentication methods
  Future<bool> login(String email, String password, UserRole role) async {
    try {
      // Authenticate with Supabase
      final response = await _databaseService.signIn(
        email: email,
        password: password,
      );

      if (response?.user != null) {
        // Load user profile from database
        await _loadUserProfile(response!.user!.id);

        // Update online status for delivery staff
        if (_currentUser?.role == UserRole.delivery) {
          await _databaseService.updateUserOnlineStatus(
            response.user!.id,
            true,
          );
        }

        // Initialize tracking service
        if (_currentUser != null) {
          await trackingService.initialize(
            userId: _currentUser!.id,
            userRole: _currentUser!.role,
          );
        }

        // Track login event
        if (_currentUser != null) {
          await _databaseService.trackEvent(
            eventType: 'user_login',
            eventData: {'role': role.toString()},
            userId: _currentUser!.id,
          );
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<bool> register(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    try {
      // Register with Supabase
      final response = await _databaseService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: UserRole.client,
      );

      if (response?.user != null) {
        // Load user profile from database
        await _loadUserProfile(response!.user!.id);

        // Track registration event
        if (_currentUser != null) {
          await _databaseService.trackEvent(
            eventType: 'user_register',
            eventData: {'role': 'client'},
            userId: _currentUser!.id,
          );
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      // Update online status for delivery staff
      if (_currentUser?.role == UserRole.delivery) {
        final currentAuthUser = _databaseService.currentUser;
        if (currentAuthUser != null) {
          await _databaseService.updateUserOnlineStatus(
            currentAuthUser.id,
            false,
          );
        }
      }

      // Sign out from Supabase
      await _databaseService.signOut();

      _currentUser = null;
      _cartItems.clear();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');

      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  // Cart methods
  void addToCart(MenuItem menuItem) {
    _cartItems.add(menuItem);
    notifyListeners();
  }

  void removeFromCart(MenuItem menuItem) {
    _cartItems.remove(menuItem);
    notifyListeners();
  }

  void updateCartItemQuantity(MenuItem menuItem, int newQuantity) {
    if (newQuantity <= 0) {
      _cartItems.remove(menuItem);
    }
    // Pour simplifier, on ne gère pas les quantités différentes pour le moment
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  // Order methods
  Future<String> placeOrder(
    String address,
    PaymentMethod paymentMethod, {
    String? notes,
  }) async {
    if (_cartItems.isEmpty || _currentUser == null) return '';

    try {
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();
      final subtotal = cartTotal;
      const deliveryFee = 5.0;
      final total = subtotal + deliveryFee;

      // Create order data for database
      if (_currentUser == null) {
        throw Exception('User must be logged in to create an order');
      }

      final orderData = {
        'id': orderId,
        'user_id': _currentUser!.id,
        'status': 'pending',
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'total': total,
        'payment_method': paymentMethod.toString().split('.').last,
        'delivery_address': address,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Save order to database
      await _databaseService.createOrder(orderData);

      // Create order items
      final orderItems = _cartItems
          .map(
            (item) => {
              'menu_item_id': item.id,
              'menu_item_name': item.name,
              'quantity': 1,
              'unit_price': item.price,
              'total_price': item.price,
            },
          )
          .toList();

      await _databaseService.addOrderItems(orderId, orderItems);

      // Create local order object
      if (_currentUser == null) {
        throw Exception('User must be logged in to create an order');
      }

      final order = Order(
        id: orderId,
        userId: _currentUser!.id,
        items: _cartItems
            .map(
              (item) => OrderItem(
                menuItemId: item.id,
                menuItemName: item.name,
                name: item.name,
                category: item.category.displayName.toLowerCase(),
                menuItemImage: item.imageUrl ?? '',
                quantity: 1,
                unitPrice: item.price,
                totalPrice: item.price,
              ),
            )
            .toList(),
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: total,
        paymentMethod: paymentMethod,
        orderTime: DateTime.now(),
        createdAt: DateTime.now(),
        deliveryAddress: address,
      );

      _orders.insert(0, order);

      // Award loyalty points for clients
      if (_currentUser?.role == UserRole.client && _currentUser != null) {
        final pointsEarned = (total / 1000).round(); // 1 point per 1000 FCFA
        _currentUser = _currentUser!.copyWith(
          loyaltyPoints: _currentUser!.loyaltyPoints + pointsEarned,
        );
        await _databaseService.updateUserProfile(_currentUser!.id, {
          'loyalty_points': _currentUser!.loyaltyPoints,
        });
      }

      final itemCount = _cartItems.length;
      _cartItems.clear();

      // Track order event
      if (_currentUser != null) {
        await _databaseService.trackEvent(
          eventType: 'order_placed',
          eventData: {
            'order_id': orderId,
            'total_amount': total,
            'item_count': itemCount,
          },
          userId: _currentUser!.id,
        );
      }

      // Déclencher les notifications et gamification
      await _notificationService.showOrderConfirmationNotification(
        orderId,
        cartItems.map((item) => item.name).join(', '),
      );

      _gamificationService.onOrderPlaced(total);

      // Démarrer le suivi de livraison
      _locationService.startDeliveryTracking(orderId);

      notifyListeners();

      return orderId;
    } catch (e) {
      debugPrint('Error placing order: $e');
      return '';
    }
  }

  // Helper methods

  Future<void> _loadMenuItems() async {
    try {
      final menuData = await _databaseService.getMenuItems().timeout(
        const Duration(seconds: 15),
      );
      _menuItems = menuData.map((data) => MenuItem.fromMap(data)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading menu items: $e');
      // Fallback to empty list if database fails
      _menuItems = [];
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile(String authUserId) async {
    try {
      final userData = await _databaseService
          .getUserProfile(authUserId)
          .timeout(const Duration(seconds: 15));
      if (userData != null) {
        _currentUser = User.fromMap(userData);
        // Load user orders after setting current user
        await _loadUserOrders();
        notifyListeners();
      } else {
        // User profile doesn't exist yet - this is normal for new users
        // Don't throw an error, just log it
        debugPrint(
          'ℹ️ User profile not found for authUserId: $authUserId (profile may not be created yet)',
        );
        // Optionally, you could create a default profile here if needed
      }
    } catch (e) {
      // Only log and rethrow if it's not a "profile not found" error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('pgrst116') ||
          errorString.contains('0 rows') ||
          errorString.contains('cannot coerce')) {
        debugPrint('ℹ️ User profile not found (handled): $authUserId');
        // Don't rethrow - this is a normal case
        return;
      }
      debugPrint('❌ Error loading user profile: $e');
      rethrow;
    }
  }

  Future<void> _loadUserOrders() async {
    if (_currentUser == null) return;

    try {
      final ordersData = await _databaseService
          .getUserOrders(_currentUser!.id)
          .timeout(const Duration(seconds: 15));
      _orders = ordersData.map((data) => Order.fromMap(data)).toList();
      // Trier par date de création (plus récentes en premier)
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading user orders: $e');
      // Ne pas vider la liste en cas d'erreur réseau, garder les données en cache
      if (_orders.isEmpty) {
        _orders = [];
        notifyListeners();
      }
    }
  }

  Future<void> _loadAllOrders() async {
    try {
      final ordersData = await _databaseService.getAllOrders().timeout(
        const Duration(seconds: 15),
      );
      _orders = ordersData.map((data) => Order.fromMap(data)).toList();
      // Trier par date de création (plus récentes en premier)
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading all orders: $e');
      // Ne pas vider la liste en cas d'erreur réseau, garder les données en cache
      if (_orders.isEmpty) {
        _orders = [];
        notifyListeners();
      }
    }
  }

  bool _isLoadingOrders = false;
  DateTime? _lastOrdersLoadTime;

  Future<void> loadAvailableOrders({bool forceRefresh = false}) async {
    // Éviter les appels simultanés
    if (_isLoadingOrders) {
      debugPrint('⚠️ loadAvailableOrders already in progress, skipping...');
      return;
    }

    // Cache: Ne pas recharger si chargé il y a moins de 10 secondes (sauf si forceRefresh)
    if (!forceRefresh &&
        _lastOrdersLoadTime != null &&
        DateTime.now().difference(_lastOrdersLoadTime!) <
            const Duration(seconds: 10)) {
      debugPrint(
        '📦 Using cached orders (last loaded ${DateTime.now().difference(_lastOrdersLoadTime!).inSeconds}s ago)',
      );
      return;
    }

    _isLoadingOrders = true;
    _lastOrdersLoadTime = DateTime.now();

    try {
      // Charger les commandes disponibles
      final ordersData = await _databaseService.getAvailableOrders().timeout(
        const Duration(seconds: 15),
      );

      final availableOrders = ordersData
          .map((data) => Order.fromMap(data))
          .toList();

      // Charger aussi les commandes assignées au livreur actuel
      List<Order> assignedOrders = [];
      if (_currentUser != null && _currentUser!.role == UserRole.delivery) {
        try {
          final assignedData = await _databaseService
              .getAssignedOrders(_currentUser!.id)
              .timeout(const Duration(seconds: 10));
          assignedOrders = assignedData
              .map((data) => Order.fromMap(data))
              .toList();
          debugPrint('✅ Loaded ${assignedOrders.length} assigned orders');
        } catch (e) {
          debugPrint('⚠️ Error loading assigned orders: $e');
          // Continuer même si le chargement des commandes assignées échoue
        }
      }

      // Fusionner les commandes disponibles et assignées
      final allOrdersMap = <String, Order>{};

      // Ajouter les commandes disponibles
      for (final order in availableOrders) {
        allOrdersMap[order.id] = order;
      }

      // Ajouter les commandes assignées (elles ont priorité si elles existent dans les deux)
      for (final order in assignedOrders) {
        allOrdersMap[order.id] = order;
      }

      // Créer un Set pour une fusion plus efficace avec les commandes existantes
      final existingOrderIds = _orders.map((o) => o.id).toSet();
      final newOrderIds = allOrdersMap.keys.toSet();

      // Mettre à jour les commandes existantes
      for (int i = 0; i < _orders.length; i++) {
        if (newOrderIds.contains(_orders[i].id)) {
          _orders[i] = allOrdersMap[_orders[i].id]!;
        }
      }

      // Ajouter les nouvelles commandes
      for (final order in allOrdersMap.values) {
        if (!existingOrderIds.contains(order.id)) {
          _orders.add(order);
        }
      }

      // Retirer les commandes qui ne sont plus disponibles ni assignées au livreur
      _orders.removeWhere(
        (order) =>
            !newOrderIds.contains(order.id) &&
            (order.deliveryPersonId == null ||
                order.deliveryPersonId != _currentUser?.id),
      );

      // Trier par date de création (plus récentes en premier)
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      notifyListeners();
      debugPrint('✅ Loaded ${availableOrders.length} available orders');
      debugPrint('✅ Loaded ${assignedOrders.length} assigned orders');
      debugPrint('📦 Total orders in memory: ${_orders.length}');
    } catch (e) {
      debugPrint('❌ Error loading available orders: $e');
      // Ne pas vider la liste en cas d'erreur, garder les données en cache
      rethrow;
    } finally {
      _isLoadingOrders = false;
    }
  }

  // Admin methods
  Future<void> addMenuItem(MenuItem item) async {
    try {
      // In a real implementation, this would save to database
      _menuItems.add(item);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding menu item: $e');
    }
  }

  Future<void> updateMenuItem(MenuItem item) async {
    try {
      final index = _menuItems.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _menuItems[index] = item;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating menu item: $e');
    }
  }

  Future<void> deleteMenuItem(String id) async {
    try {
      _menuItems.removeWhere((item) => item.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting menu item: $e');
    }
  }

  List<Order> get allOrders => _orders;
  List<Order> get pendingOrders =>
      _orders.where((o) => o.status == OrderStatus.pending).toList();
  List<Order> get activeOrders => _orders
      .where(
        (o) =>
            o.status != OrderStatus.delivered &&
            o.status != OrderStatus.cancelled,
      )
      .toList();

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      // Update local state first for immediate UI feedback (optimistic update)
      final index = _orders.indexWhere((order) => order.id == orderId);
      Order? previousOrder;
      if (index != -1) {
        previousOrder = _orders[index];
        _orders[index] = _orders[index].copyWith(status: newStatus);
        notifyListeners();
      }

      // Update in database
      try {
        await _databaseService
            .updateOrderStatus(orderId, newStatus.toDbString)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        // Rollback en cas d'erreur
        if (previousOrder != null && index != -1 && index < _orders.length) {
          _orders[index] = previousOrder;
          notifyListeners();
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('❌ Error updating order status: $e');
      rethrow;
    }
  }

  // Delivery methods
  List<Order> get assignedDeliveries {
    if (_currentUser?.role != UserRole.delivery || _currentUser == null) {
      return [];
    }
    return _orders
        .where((o) => o.deliveryPersonId == _currentUser!.id)
        .toList();
  }

  Future<void> acceptDelivery(String orderId) async {
    if (_currentUser == null) {
      throw Exception('User must be logged in to accept delivery');
    }

    // Vérifier si la commande existe et n'est pas déjà assignée
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex == -1) {
      throw Exception('Order not found: $orderId');
    }

    final order = _orders[orderIndex];
    if (order.deliveryPersonId != null &&
        order.deliveryPersonId != _currentUser!.id) {
      throw Exception('Order already assigned to another driver');
    }

    Order? previousOrder;

    try {
      // Optimistic update: Update local state first
      // According to workflow: accepted → picked_up → on_the_way → delivered
      previousOrder = order;
      _orders[orderIndex] = order.copyWith(
        deliveryPersonId: _currentUser!.id,
        status: OrderStatus
            .confirmed, // Use confirmed as accepted (since OrderStatus doesn't have 'accepted')
      );
      notifyListeners();

      // Update in database: set status to 'confirmed' (which represents accepted in our workflow)
      // and update active_deliveries to 'accepted'
      await _databaseService
          .updateOrderStatus(
            orderId,
            'confirmed', // This represents 'accepted' in the workflow
            deliveryPersonId: _currentUser!.id,
          )
          .timeout(const Duration(seconds: 10));

      // Update active_deliveries to 'accepted' status
      await _databaseService.updateActiveDeliveryStatus(
        orderId: orderId,
        status: 'accepted',
      );

      debugPrint('✅ Delivery accepted: $orderId');
    } catch (e) {
      // Rollback en cas d'erreur
      if (previousOrder != null && orderIndex < _orders.length) {
        _orders[orderIndex] = previousOrder;
        notifyListeners();
      }
      debugPrint('❌ Error accepting delivery: $e');
      rethrow;
    }
  }

  /// Marque la commande comme récupérée au restaurant (picked_up)
  Future<void> markOrderPickedUp(String orderId) async {
    if (_currentUser == null) {
      throw Exception('User must be logged in');
    }

    try {
      await updateOrderStatus(orderId, OrderStatus.pickedUp);
      await _databaseService.updateActiveDeliveryStatus(
        orderId: orderId,
        status: 'picked_up',
      );
      debugPrint('✅ Order marked as picked up: $orderId');
    } catch (e) {
      debugPrint('❌ Error marking order as picked up: $e');
      rethrow;
    }
  }

  /// Marque la commande comme en route (on_the_way)
  Future<void> markOrderOnTheWay(String orderId) async {
    if (_currentUser == null) {
      throw Exception('User must be logged in');
    }

    try {
      await updateOrderStatus(orderId, OrderStatus.onTheWay);
      await _databaseService.updateActiveDeliveryStatus(
        orderId: orderId,
        status: 'on_the_way',
      );
      debugPrint('✅ Order marked as on the way: $orderId');
    } catch (e) {
      debugPrint('❌ Error marking order as on the way: $e');
      rethrow;
    }
  }

  /// Marque la commande comme livrée (delivered)
  Future<void> markOrderDelivered(String orderId) async {
    if (_currentUser == null) {
      throw Exception('User must be logged in');
    }

    try {
      await updateOrderStatus(orderId, OrderStatus.delivered);
      await _databaseService.updateActiveDeliveryStatus(
        orderId: orderId,
        status: 'delivered',
      );
      debugPrint('✅ Order marked as delivered: $orderId');
    } catch (e) {
      debugPrint('❌ Error marking order as delivered: $e');
      rethrow;
    }
  }

  // Driver authentication methods
  Future<void> loginDriver(String email, String password) async {
    try {
      // Authenticate with Supabase
      final response = await _databaseService.signIn(
        email: email,
        password: password,
      );

      if (response?.user != null) {
        // Load user profile from database
        try {
          await _loadUserProfile(response!.user!.id);
        } catch (e) {
          // If profile loading fails, sign out and throw
          await _databaseService.signOut();
          throw Exception(
            'Impossible de charger le profil. Contactez le support si le problème persiste. ($e)',
          );
        }

        if (_currentUser == null) {
          // If _loadUserProfile completed but _currentUser is still null (e.g. not found)
          await _databaseService.signOut();
          throw Exception(
            'Profil utilisateur introuvable. Veuillez contacter le support.',
          );
        }

        // Update online status for delivery staff
        if (_currentUser?.role == UserRole.delivery) {
          await _databaseService.updateUserOnlineStatus(
            response.user!.id,
            true,
          );
          // Load available orders for delivery staff
          await loadAvailableOrders();
        }

        notifyListeners();
      } else {
        throw Exception('Échec de la connexion');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<void> registerDriver(String email, String password) async {
    try {
      // Register with Supabase
      final response = await _databaseService.signUp(
        email: email,
        password: password,
        name: 'Livreur',
        phone: '',
        role: UserRole.delivery,
      );

      if (response?.user != null) {
        // Load user profile from database
        await _loadUserProfile(response!.user!.id);
        notifyListeners();
      } else {
        throw Exception('Échec de l\'inscription: Aucun utilisateur créé');
      }
    } catch (e) {
      // Re-throw with better error message (already formatted in database_service)
      rethrow;
    }
  }

  Future<void> registerDriverWithDocumentsBytes({
    required String name,
    required String email,
    required String phone,
    required String licenseNumber,
    required String idNumber,
    required String vehicleType,
    required String vehicleNumber,
    required Uint8List profilePhotoBytes,
    required Uint8List licensePhotoBytes,
    required Uint8List idCardPhotoBytes,
    required Uint8List vehiclePhotoBytes,
    String? password,
  }) async {
    try {
      // If user is not authenticated, create account first
      var currentAuthUser = _databaseService.currentUser;
      if (currentAuthUser == null) {
        if (password == null || password.isEmpty) {
          throw Exception('Un mot de passe est requis pour créer un compte');
        }
        // Sign up the user first
        final signUpResponse = await _databaseService.signUp(
          email: email,
          password: password,
          name: name,
          phone: phone,
          role: UserRole.delivery,
        );

        if (signUpResponse?.user == null) {
          throw Exception('Échec de la création du compte utilisateur');
        }

        currentAuthUser = signUpResponse!.user!;
      }

      // Upload documents to Supabase Storage using bytes
      String? profilePhotoUrl;
      String? licensePhotoUrl;
      String? idCardPhotoUrl;
      String? vehiclePhotoUrl;

      // Utiliser StorageService pour l'upload
      final storageService = StorageService();

      try {
        // Upload avec progression et gestion d'erreurs améliorée
        profilePhotoUrl = await storageService.uploadDriverDocument(
          userId: currentAuthUser.id,
          fileBytes: profilePhotoBytes,
          documentType: 'profile',
          onProgress: (progress) {
            debugPrint(
              'Upload photo profil: ${(progress * 100).toStringAsFixed(0)}%',
            );
          },
        );

        licensePhotoUrl = await storageService.uploadDriverDocument(
          userId: currentAuthUser.id,
          fileBytes: licensePhotoBytes,
          documentType: 'license',
          onProgress: (progress) {
            debugPrint(
              'Upload permis: ${(progress * 100).toStringAsFixed(0)}%',
            );
          },
        );

        idCardPhotoUrl = await storageService.uploadDriverDocument(
          userId: currentAuthUser.id,
          fileBytes: idCardPhotoBytes,
          documentType: 'idcard',
          onProgress: (progress) {
            debugPrint(
              'Upload carte identité: ${(progress * 100).toStringAsFixed(0)}%',
            );
          },
        );

        vehiclePhotoUrl = await storageService.uploadDriverDocument(
          userId: currentAuthUser.id,
          fileBytes: vehiclePhotoBytes,
          documentType: 'vehicle',
          onProgress: (progress) {
            debugPrint(
              'Upload véhicule: ${(progress * 100).toStringAsFixed(0)}%',
            );
          },
        );
      } catch (uploadError) {
        debugPrint('❌ Erreur lors de l\'upload des documents: $uploadError');
        // Ne pas continuer si l'upload échoue - les documents sont essentiels
        throw Exception('Échec de l\'upload des documents: $uploadError');
      }

      // Create driver profile with uploaded document URLs
      // Extraire les informations des fichiers pour les enregistrer dans driver_documents
      await _databaseService.createDriverProfile(
        authUserId: currentAuthUser.id,
        name: name,
        email: email,
        phone: phone,
        licenseNumber: licenseNumber,
        idNumber: idNumber,
        vehicleType: vehicleType,
        vehicleNumber: vehicleNumber,
        profilePhotoUrl: profilePhotoUrl,
        licensePhotoUrl: licensePhotoUrl,
        idCardPhotoUrl: idCardPhotoUrl,
        vehiclePhotoUrl: vehiclePhotoUrl,
        licenseFileName:
            'license_${currentAuthUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        idCardFileName:
            'identity_${currentAuthUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        vehicleFileName:
            'vehicle_${currentAuthUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        licenseFileSize: licensePhotoBytes.length,
        idCardFileSize: idCardPhotoBytes.length,
        vehicleFileSize: vehiclePhotoBytes.length,
        licenseFileType: 'image/jpeg',
        idCardFileType: 'image/jpeg',
        vehicleFileType: 'image/jpeg',
      );

      // Reload user profile
      await _loadUserProfile(currentAuthUser.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur d\'inscription livreur: $e');
      // Ne pas emballer l'exception dans une autre Exception pour éviter les messages dupliqués
      // Si c'est déjà une Exception avec un message clair, la relancer telle quelle
      if (e is Exception) {
        // Vérifier si le message contient déjà des informations utiles
        final errorString = e.toString();
        // Si le message contient des informations utiles, le relancer tel quel
        // (même s'il commence par "Exception:", l'écran d'inscription le nettoiera)
        if (errorString.contains('téléphone') ||
            errorString.contains('déjà utilisé') ||
            errorString.contains('email') ||
            errorString.contains('mot de passe') ||
            errorString.contains('requis') ||
            errorString.length > 20) {
          // Si le message est assez long, il contient probablement des infos utiles
          rethrow;
        }
        // Si le message commence par "Exception:" mais est court, extraire le message
        if (errorString.startsWith('Exception: ')) {
          final message = errorString.substring('Exception: '.length).trim();
          if (message.isNotEmpty && message.length > 10) {
            throw Exception(message);
          }
        }
      }
      // Sinon, créer une Exception avec un message simple
      throw Exception('Erreur lors de l\'inscription. Veuillez réessayer.');
    }
  }

  Future<void> registerDriverWithDocuments({
    required String name,
    required String email,
    required String phone,
    required String licenseNumber,
    required String idNumber,
    required String vehicleType,
    required String vehicleNumber,
    required io.File profilePhoto,
    required io.File licensePhoto,
    required io.File idCardPhoto,
    required io.File vehiclePhoto,
    String? password,
  }) async {
    try {
      // If user is not authenticated, create account first
      var currentAuthUser = _databaseService.currentUser;
      if (currentAuthUser == null) {
        if (password == null || password.isEmpty) {
          throw Exception('Un mot de passe est requis pour créer un compte');
        }
        // Sign up the user first
        final signUpResponse = await _databaseService.signUp(
          email: email,
          password: password,
          name: name,
          phone: phone,
          role: UserRole.delivery,
        );

        if (signUpResponse?.user == null) {
          throw Exception('Échec de la création du compte utilisateur');
        }

        currentAuthUser = signUpResponse!.user!;
      }

      // Upload documents to Supabase Storage
      String? profilePhotoUrl;
      String? licensePhotoUrl;
      String? idCardPhotoUrl;
      String? vehiclePhotoUrl;

      // Utiliser StorageService pour l'upload
      final storageService = StorageService();

      try {
        // Upload avec progression et gestion d'erreurs améliorée
        profilePhotoUrl = await storageService.uploadFile(
          file: profilePhoto,
          bucketName: 'driver-documents',
          folder: 'profiles',
          onProgress: (progress) {
            debugPrint(
              'Upload photo profil: ${(progress * 100).toStringAsFixed(0)}%',
            );
          },
        );

        licensePhotoUrl = await storageService.uploadFile(
          file: licensePhoto,
          bucketName: 'driver-documents',
          folder: 'licenses',
          onProgress: (progress) {
            debugPrint(
              'Upload permis: ${(progress * 100).toStringAsFixed(0)}%',
            );
          },
        );

        idCardPhotoUrl = await storageService.uploadFile(
          file: idCardPhoto,
          bucketName: 'driver-documents',
          folder: 'id-cards',
          onProgress: (progress) {
            debugPrint(
              'Upload carte identité: ${(progress * 100).toStringAsFixed(0)}%',
            );
          },
        );

        vehiclePhotoUrl = await storageService.uploadFile(
          file: vehiclePhoto,
          bucketName: 'driver-documents',
          folder: 'vehicles',
          onProgress: (progress) {
            debugPrint(
              'Upload véhicule: ${(progress * 100).toStringAsFixed(0)}%',
            );
          },
        );
      } catch (uploadError) {
        debugPrint('❌ Erreur lors de l\'upload des documents: $uploadError');
        // Ne pas continuer si l'upload échoue - les documents sont essentiels
        throw Exception('Échec de l\'upload des documents: $uploadError');
      }

      // Create driver profile with uploaded document URLs
      // Extraire les informations des fichiers pour les enregistrer dans driver_documents
      // Obtenir la taille des fichiers
      int licenseFileSize = 0;
      int idCardFileSize = 0;
      int vehicleFileSize = 0;

      try {
        if (!kIsWeb) {
          // Sur mobile, les fichiers sont dart:io.File qui ont la méthode length()
          final licenseFile = licensePhoto as dynamic;
          final idCardFile = idCardPhoto as dynamic;
          final vehicleFile = vehiclePhoto as dynamic;
          licenseFileSize = await licenseFile.length();
          idCardFileSize = await idCardFile.length();
          vehicleFileSize = await vehicleFile.length();
        } else {
          // Sur web, dart:html.File n'a pas de méthode length()
          // On peut utiliser la propriété size si disponible, sinon estimation
          try {
            final licenseFile = licensePhoto as dynamic;
            final idCardFile = idCardPhoto as dynamic;
            final vehicleFile = vehiclePhoto as dynamic;
            licenseFileSize = licenseFile.size ?? 1000000;
            idCardFileSize = idCardFile.size ?? 1000000;
            vehicleFileSize = vehicleFile.size ?? 1000000;
          } catch (_) {
            // Estimation par défaut si size n'est pas disponible
            licenseFileSize = 1000000;
            idCardFileSize = 1000000;
            vehicleFileSize = 1000000;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Impossible de récupérer la taille des fichiers: $e');
        // Valeurs par défaut en cas d'erreur
        licenseFileSize = 1000000;
        idCardFileSize = 1000000;
        vehicleFileSize = 1000000;
      }

      await _databaseService.createDriverProfile(
        authUserId: currentAuthUser.id,
        name: name,
        email: email,
        phone: phone,
        licenseNumber: licenseNumber,
        idNumber: idNumber,
        vehicleType: vehicleType,
        vehicleNumber: vehicleNumber,
        profilePhotoUrl: profilePhotoUrl,
        licensePhotoUrl: licensePhotoUrl,
        idCardPhotoUrl: idCardPhotoUrl,
        vehiclePhotoUrl: vehiclePhotoUrl,
        licenseFileName:
            'license_${currentAuthUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        idCardFileName:
            'identity_${currentAuthUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        vehicleFileName:
            'vehicle_${currentAuthUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        licenseFileSize: licenseFileSize,
        idCardFileSize: idCardFileSize,
        vehicleFileSize: vehicleFileSize,
        licenseFileType: 'image/jpeg',
        idCardFileType: 'image/jpeg',
        vehicleFileType: 'image/jpeg',
      );

      // Reload user profile
      await _loadUserProfile(currentAuthUser.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur d\'inscription livreur: $e');
      // Ne pas emballer l'exception dans une autre Exception pour éviter les messages dupliqués
      // Si c'est déjà une Exception avec un message clair, la relancer telle quelle
      if (e is Exception) {
        // Vérifier si le message contient déjà des informations utiles
        final errorString = e.toString();
        // Si le message contient des informations utiles, le relancer tel quel
        // (même s'il commence par "Exception:", l'écran d'inscription le nettoiera)
        if (errorString.contains('téléphone') ||
            errorString.contains('déjà utilisé') ||
            errorString.contains('email') ||
            errorString.contains('mot de passe') ||
            errorString.contains('requis') ||
            errorString.length > 20) {
          // Si le message est assez long, il contient probablement des infos utiles
          rethrow;
        }
        // Si le message commence par "Exception:" mais est court, extraire le message
        if (errorString.startsWith('Exception: ')) {
          final message = errorString.substring('Exception: '.length).trim();
          if (message.isNotEmpty && message.length > 10) {
            throw Exception(message);
          }
        }
      }
      // Sinon, créer une Exception avec un message simple
      throw Exception('Erreur lors de l\'inscription. Veuillez réessayer.');
    }
  }

  // Message methods
  Future<void> sendMessage(Message message) async {
    try {
      await _databaseService.sendMessage(
        orderId: message.orderId,
        senderId: message.senderId,
        senderName: message.senderName,
        content: message.content,
        isFromDriver: message.isFromDriver,
        imageUrl: message.imageUrl,
        type: message.type.name,
      );
    } catch (e) {
      throw Exception('Erreur d\'envoi: $e');
    }
  }

  // Withdrawal methods
  Future<void> requestWithdrawal(double amount) async {
    try {
      if (_currentUser == null) {
        throw Exception('Utilisateur non authentifié');
      }

      // Vérifier que l'utilisateur a un solde suffisant
      // (Dans une vraie implémentation, on vérifierait le solde réel)

      // Utiliser PayDunyaService pour effectuer le retrait
      final payDunyaService = PayDunyaService();

      if (!payDunyaService.isInitialized) {
        throw Exception(
          'Service PayDunya non initialisé. Veuillez configurer les clés API.',
        );
      }

      // Effectuer le retrait via PayDunya Disbursement API
      // Note: PayDunya utilise l'API de disbursement pour les retraits
      final withdrawalResult = await payDunyaService.processWithdrawal(
        userId: _currentUser!.id,
        amount: amount,
        phoneNumber: _currentUser!.phone,
        accountName: _currentUser!.name,
      );

      if (!withdrawalResult.success) {
        throw Exception(withdrawalResult.error ?? 'Erreur lors du retrait');
      }

      // Enregistrer la transaction de retrait dans la base de données
      await _databaseService.recordWithdrawal(
        userId: _currentUser!.id,
        amount: amount,
        transactionId: withdrawalResult.transactionId ?? '',
        status: 'pending', // Le statut sera mis à jour via webhook
      );

      debugPrint('✅ Retrait demandé avec succès: $amount XOF');
    } catch (e) {
      debugPrint('❌ Erreur de retrait: $e');
      throw Exception('Erreur de retrait: $e');
    }
  }

  // Online status methods
  Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      final currentAuthUser = _databaseService.currentUser;
      if (currentAuthUser == null) {
        throw Exception('Utilisateur non authentifié');
      }

      await _databaseService.updateUserOnlineStatus(
        currentAuthUser.id,
        isOnline,
      );

      // Mettre à jour le statut local
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(isOnline: isOnline);
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du statut: $e');
    }
  }

  // Delivery location methods
  Future<void> updateDeliveryLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
  }) async {
    try {
      final currentAuthUser = _databaseService.currentUser;
      if (currentAuthUser == null) {
        throw Exception('Utilisateur non authentifié');
      }

      // S'assurer que le profil utilisateur est chargé pour avoir le bon ID (public.users.id)
      if (_currentUser == null) {
        await _loadUserProfile(currentAuthUser.id);
      }

      if (_currentUser == null) {
        // Si le profil n'existe pas encore, on ne peut pas mettre à jour la position
        // car la table delivery_locations attend une clé étrangère vers public.users
        debugPrint(
          '⚠️ Profil utilisateur introuvable, impossible de mettre à jour la position',
        );
        return;
      }

      await _databaseService.updateDeliveryLocation(
        orderId: orderId,
        deliveryId: _currentUser!.id,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        speed: speed,
        heading: heading,
      );

      debugPrint('✅ Position mise à jour pour la commande $orderId');
    } catch (e) {
      debugPrint('❌ Erreur mise à jour position: $e');
      // Ne pas throw pour éviter de bloquer le suivi GPS
    }
  }

  // User profile methods
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      return await _databaseService.getUserProfile(userId);
    } catch (e) {
      debugPrint('Erreur récupération profil utilisateur: $e');
      return null;
    }
  }
}
