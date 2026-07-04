import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/menu_models.dart';
import '../models/category.dart' as app_models;
import '../models/order.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'gamification_service.dart';
import 'realtime_tracking_service.dart';
import 'database_service.dart';

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

  List<String> get categories {
    if (_menuItems.isEmpty) return ['Burgers', 'Pizzas', 'Drinks', 'Desserts'];
    return _menuItems
        .map((item) =>
            item.name) // Fallback if needed, but we prefer using _categories
        .toSet()
        .toList();
  }

  List<app_models.Category> _categories = [];
  List<app_models.Category> get categoriesList => _categories;

  // Services getters
  LocationService get locationService => _locationService;
  NotificationService get notificationService => _notificationService;
  GamificationService get gamificationService => _gamificationService;
  RealtimeTrackingService get trackingService => RealtimeTrackingService();
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isDeliveryStaff => _currentUser?.role == UserRole.delivery;
  bool get isClient => _currentUser?.role == UserRole.client;

  double get cartTotal {
    return _cartItems.fold(0.0, (sum, item) {
      // Safely handle invalid prices
      final price = item.basePrice;
      if (price.isNaN || price.isInfinite) {
        return sum + 0.0;
      }
      return sum + price;
    });
  }

  int get cartItemCount {
    return _cartItems.length;
  }

  Future<void> initialize() async {
    try {
      // Load menu items from database
      await _loadMenuItems();
      await _loadCategories();

      // Check if user is already logged in
      final currentAuthUser = _databaseService.currentUser;
      if (currentAuthUser != null) {
        await _loadUserProfile(currentAuthUser.id);
      }

      // Load user orders if logged in
      await _loadUserOrders();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing AppService: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> initializeWithAdminUser() async {
    try {
      // Check if user is already logged in
      final currentAuthUser = _databaseService.currentUser;

      if (currentAuthUser != null) {
        // Load the actual admin user from the database
        await _loadUserProfile(currentAuthUser.id);
      } else {
        // Create a default admin user for the admin panel (offline mode)
        _currentUser = User(
          id: '00000000-0000-0000-0000-000000000000', // Valid UUID format
          authUserId: '00000000-0000-0000-0000-000000000000',
          name: 'Administrateur',
          email: 'admin@elcorazon.ci',
          phone: '+225 07 00 00 00',
          role: UserRole.admin,
          isOnline: false,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          profileImageUrl: null,
          preferences: UserPreferences(
            notifications: true,
            darkMode: false,
            language: 'fr',
          ),
          stats: UserStats(
            totalOrders: 0,
            completedOrders: 0,
            totalSpent: 0.0,
            loyaltyPoints: 0,
            level: 1,
          ),
        );
      }

      // Load menu items from database
      await _loadMenuItems();
      await _loadCategories();

      // Load all orders for admin (not just user orders)
      await _loadAllOrders();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing AppService with admin user: $e');
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

      if (response.user != null) {
        // Load user profile from database
        await _loadUserProfile(response.user!.id);

        // Update online status for delivery staff
        if (_currentUser?.role == UserRole.delivery) {
          await _databaseService.updateUserOnlineStatus(
            response.user!.id,
            true,
          );
        }

        // Initialize tracking service
        await trackingService.initialize(
          userId: _currentUser!.id,
          userRole: _currentUser!.role,
        );

        // Track login event
        await _databaseService.trackEvent(
          userId: _currentUser!.id,
          eventType: 'user_login',
          eventData: {'role': role.toString()},
        );

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

      if (response.user != null) {
        // Load user profile from database
        await _loadUserProfile(response.user!.id);

        // Track registration event
        await _databaseService.trackEvent(
          userId: _currentUser!.id,
          eventType: 'user_register',
          eventData: {'role': 'client'},
        );

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
      const deliveryFee = 1000.0;
      final total = subtotal + deliveryFee;

      // Create order data for database
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
              'unit_price': item.basePrice,
              'total_price': item.basePrice,
            },
          )
          .toList();

      await _databaseService.addOrderItems(orderId, orderItems);

      // Create local order object
      final order = Order(
        id: orderId,
        userId: _currentUser!.id,
        items: _cartItems
            .map(
              (item) => OrderItem(
                menuItemId: item.id,
                menuItemName: item.name,
                name: item.name,
                categoryId:
                    item /* .categoryName - REMOVED */ .name.toLowerCase(),
                menuItemImage: item.imageUrl ?? '',
                quantity: 1,
                unitPrice: item.basePrice,
                totalPrice: item.basePrice,
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
      if (_currentUser?.role == UserRole.client) {
        final pointsEarned = (total / 100).round(); // 1 point per 100 CFA
        _currentUser = _currentUser!.copyWith(
          loyaltyPoints: _currentUser!.loyaltyPoints + pointsEarned,
        );
        await _databaseService.updateUserProfile(_currentUser!.id, {
          'loyalty_points': _currentUser!.loyaltyPoints,
        });
      }

      _cartItems.clear();

      // Track order event
      await _databaseService.trackEvent(
        eventType: 'order_placed',
        eventData: {
          'order_id': orderId,
          'total_amount': total,
          'item_count': _cartItems.length,
        },
        userId: _currentUser!.id,
      );

      // Déclencher les notifications et gamification
      await _notificationService.showOrderConfirmationNotification(
        orderId,
        cartItems.map((item) => item.name).join(', '),
      );

      // Note: Gamification est géré par le service client, pas par l'admin
      // _gamificationService.onOrderPlaced(total);

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
      final menuData = await _databaseService.getMenuItems();
      final items = menuData.map((data) => MenuItem.fromMap(data)).toList();

      // Supprimer les doublons basés sur l'ID
      final seenIds = <String>{};
      _menuItems = items.where((item) {
        if (seenIds.contains(item.id)) {
          debugPrint('Doublon détecté et supprimé: ${item.name} (${item.id})');
          return false;
        }
        seenIds.add(item.id);
        return true;
      }).toList();

      debugPrint(
          'Chargé ${_menuItems.length} éléments de menu (${items.length - _menuItems.length} doublons supprimés)');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading menu items: $e');
      // Fallback to empty list if database fails
      _menuItems = [];
    }
  }

  Future<void> _loadUserProfile(String authUserId) async {
    try {
      final userData = await _databaseService.getUserProfile(authUserId);
      if (userData != null) {
        _currentUser = User.fromMap(userData);
        // Load user orders after setting current user
        await _loadUserOrders();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _loadUserOrders() async {
    if (_currentUser == null) return;

    try {
      final ordersData = await _databaseService.getUserOrders(_currentUser!.id);
      _orders = ordersData.map((data) => Order.fromMap(data)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user orders: $e');
      _orders = [];
    }
  }

  /// Charge toutes les commandes pour l'admin
  Future<void> _loadAllOrders() async {
    try {
      final ordersData = await _databaseService.getAllOrdersWithMenuDetails();
      _orders = ordersData.map((data) => Order.fromMap(data)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading all orders: $e');
      _orders = [];
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categoriesData = await _databaseService.getMenuCategories();
      _categories = categoriesData
          .map((data) => app_models.Category.fromMap(data))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading categories: $e');
      _categories = [];
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
      // Update in database
      await _databaseService.updateOrderStatus(
        orderId,
        newStatus.toString().split('.').last,
      );

      // Update local state
      final index = _orders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(status: newStatus);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating order status: $e');
    }
  }

  // Delivery methods
  List<Order> get assignedDeliveries {
    if (_currentUser?.role != UserRole.delivery) return [];
    return _orders
        .where((o) => o.deliveryPersonId == _currentUser!.id)
        .toList();
  }

  Future<void> acceptDelivery(String orderId) async {
    try {
      // Update in database
      await _databaseService.updateOrderStatusWithDeliveryPerson(
        orderId,
        'picked_up',
        _currentUser!.id,
      );

      // Update local state
      final index = _orders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(
          deliveryPersonId: _currentUser!.id,
          status: OrderStatus.pickedUp,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error accepting delivery: $e');
    }
  }

  // Admin authentication methods
  Future<void> loginAdmin(String email, String password, AdminRole role) async {
    try {
      // Simulate admin login
      await Future.delayed(const Duration(seconds: 1));

      // In real app, authenticate with Supabase
      final adminId = 'admin_${DateTime.now().millisecondsSinceEpoch}';
      _currentUser = User(
        id: adminId,
        authUserId: adminId,
        name: 'Admin ${role.displayName}',
        email: email,
        phone: '+225 07 12 34 56 78',
        role: UserRole.admin,
        isOnline: true,
        profileImage: null,
        createdAt: DateTime.now(),
      );

      notifyListeners();
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
}

// Admin role enum
enum AdminRole {
  superAdmin('Super Admin', 'Accès complet au système'),
  manager('Manager', 'Gestion des opérations quotidiennes'),
  operator('Opérateur', 'Gestion des commandes et livreurs');

  const AdminRole(this.displayName, this.description);

  final String displayName;
  final String description;
}
