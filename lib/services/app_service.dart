import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:elcora_fast/models/user.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/menu_category.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/services/notification_service.dart';
import 'package:elcora_fast/services/gamification_service.dart';
import 'package:elcora_fast/services/realtime_tracking_service.dart';
import 'package:elcora_fast/services/database_service.dart';
import 'package:elcora_fast/services/paydunya_service.dart';
import 'package:elcora_fast/services/error_handler_service.dart';
import 'package:elcora_fast/services/wallet_service.dart';
import 'package:elcora_fast/services/realtime_sync_service.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/promo_code_service.dart';
import 'package:elcora_fast/services/offline_sync_service.dart';
import 'package:elcora_fast/services/menu_item_cache_service.dart';
import 'package:elcora_fast/services/data_validator_service.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/models/address.dart';

class AppService extends ChangeNotifier {
  static final AppService _instance = AppService._internal();
  factory AppService() => _instance;
  AppService._internal();

  final Uuid _uuid = const Uuid();
  User? _currentUser;

  // Helper method to convert PaymentMethod enum to database format
  String _paymentMethodToDbString(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.mobileMoney:
        return 'mobile_money';
      case PaymentMethod.creditCard:
        return 'credit_card';
      case PaymentMethod.debitCard:
        return 'debit_card';
      case PaymentMethod.wallet:
        return 'wallet';
      case PaymentMethod.cash:
        return 'cash';
    }
  }

  // Helper method to check if a string is a valid UUID
  bool _isValidUUID(String? id) {
    if (id == null || id.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(id);
  }

  Future<void> _ensureMenuItemExists(
    dynamic cartItem,
    String menuItemId,
  ) async {
    try {
      // Check if menu item already exists
      final existingItem = await _databaseService.getMenuItemById(menuItemId);
      if (existingItem != null) {
        return; // Menu item already exists
      }

      // Create the menu item if it doesn't exist
      final menuItemData = {
        'id': menuItemId,
        'name': cartItem.name,
        'description':
            cartItem.name, // Use name as description if not available
        'price': cartItem.price,
        'category_id': await _getDefaultCategoryId(),
        'image_url': cartItem.imageUrl,
        'is_popular': false,
        'is_vegetarian': false,
        'is_vegan': false,
        'is_available': true,
        'available_quantity': 100,
        'ingredients': <String>[],
        'calories': 0,
        'preparation_time': 15,
        'rating': 0.0,
        'review_count': 0,
        'sort_order': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _databaseService.createMenuItem(menuItemData);
      debugPrint('Created menu item: ${cartItem.name} with ID: $menuItemId');
    } catch (e) {
      debugPrint('Error ensuring menu item exists: $e');
      // Don't throw the error, just log it
    }
  }

  Future<String> _getDefaultCategoryId() async {
    try {
      // Try to get the first available category
      final categories = await _databaseService.getMenuCategories();
      if (categories.isNotEmpty) {
        return categories.first['id'] as String;
      }

      // If no categories exist, create a default one
      final defaultCategoryId = _uuid.v4();
      final categoryData = {
        'id': defaultCategoryId,
        'name': 'general',
        'display_name': 'Général',
        'emoji': '🍽️',
        'description': 'Catégorie générale',
        'sort_order': 0,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _databaseService.createMenuCategory(categoryData);
      return defaultCategoryId;
    } catch (e) {
      debugPrint('Error getting default category: $e');
      // Return a fallback UUID
      return _uuid.v4();
    }
  }

  bool _isInitialized = false;
  List<MenuItem> _menuItems = [];
  List<Order> _orders = [];
  final List<MenuItem> _cartItems = [];
  List<String> _menuCategoryDisplayNames = [];
  List<MenuCategory> _menuCategories = [];

  // Service de cache intelligent pour les menu items et catégories
  final MenuItemCacheService _menuItemCache = MenuItemCacheService();

  // Services intégrés
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final GamificationService _gamificationService = GamificationService();
  final DatabaseService _databaseService = DatabaseService();
  final PayDunyaService _payDunyaService = PayDunyaService();
  final ErrorHandlerService _errorHandler = ErrorHandlerService();
  final OfflineSyncService _offlineSyncService = OfflineSyncService();

  // Getters
  User? get currentUser => _currentUser;
  List<MenuItem> get menuItems => _menuItems.isNotEmpty ? _menuItems : [];
  List<Order> get orders => _orders;
  List<MenuItem> get cartItems => _cartItems;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;
  List<String> get menuCategoryDisplayNames => _menuCategoryDisplayNames;
  List<MenuCategory> get menuCategories => _menuCategories;

  // Obtenir les catégories uniques des items du menu
  List<String> get categories {
    if (_menuItems.isEmpty) return [];
    return _menuItems
        .where((item) => item.category != null)
        .map((item) => item.category!.displayName)
        .toSet()
        .toList();
  }

  // Services getters
  LocationService get locationService => _locationService;
  NotificationService get notificationService => _notificationService;
  GamificationService get gamificationService => _gamificationService;
  RealtimeTrackingService get trackingService => RealtimeTrackingService();
  DatabaseService get databaseService => _databaseService;
  PayDunyaService get payDunyaService => _payDunyaService;
  ErrorHandlerService get errorHandler => _errorHandler;
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
      // Mesurer le temps d'initialisation pour le monitoring
      final stopwatch = Stopwatch()..start();

      // Charger les catégories d'abord, puis les items (pour l'association)
      await _loadMenuCategories();
      await Future.wait([
        _loadMenuItems(),
        _loadUserSession(),
      ]);

      stopwatch.stop();

      // Démarrer la synchro temps réel (Supabase + Firestore si dispo)
      try {
        await RealtimeSyncService().initialize();
        RealtimeSyncService().menuItemsStream.listen((items) {
          _menuItems = items;
          notifyListeners();
        });
        RealtimeSyncService().ordersStream.listen((orders) {
          _orders = orders;
          notifyListeners();
        });
      } catch (e) {
        debugPrint('Realtime sync unavailable: $e');
      }

      if (kDebugMode) {
        debugPrint(
          '⚡ AppService initialisé en ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation AppService: $e');
      _errorHandler.logError(
        'Erreur lors de l\'initialisation AppService',
        details: e,
      );
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Charge la session utilisateur de manière optimisée
  Future<void> _loadUserSession() async {
    try {
      // Vérifier si l'utilisateur est déjà connecté
      final currentAuthUser = _databaseService.currentUser;
      if (currentAuthUser != null) {
        await _loadUserProfile(currentAuthUser.id);
        await _loadUserOrders();
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors du chargement de la session: $e');
      _errorHandler.logError(
        'Erreur lors du chargement de la session',
        details: e,
      );
    }
  }

  // Authentication methods
  Future<bool> login(String email, String password) async {
    try {
      final response = await _databaseService.signIn(
        email: email,
        password: password,
      );

      if (response?.user == null) {
        throw Exception('Connexion impossible. Veuillez réessayer.');
      }

      await _loadUserProfile(response!.user!.id);

      if (_currentUser?.role != UserRole.client) {
        await _databaseService.signOut();
        throw Exception(
          'Ce compte n\'est pas autorisé sur l\'application client.',
        );
      }

      await trackingService.initialize(
        userId: _currentUser!.id,
        userRole: _currentUser!.role,
      );

      await _databaseService.trackEvent(
        eventType: 'user_login',
        eventData: {'role': _currentUser!.role.toString()},
        userId: _currentUser!.id,
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
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
        await _databaseService.trackEvent(
          eventType: 'user_register',
          eventData: {'role': 'client'},
          userId: _currentUser!.id,
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
      await CartService().clearForLogout();
      AddressService().clearSession();
      _gamificationService.reset();

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
      final orderId = _uuid.v4();
      final subtotal = cartTotal;
      const deliveryFee = 5.0;
      final total = subtotal + deliveryFee;

      // Create order data for database
      final orderData = {
        'id': orderId,
        'user_id': _currentUser!.id,
        'status': 'pending',
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'total': total,
        'payment_method': _paymentMethodToDbString(paymentMethod),
        'delivery_address': address,
        'delivery_notes': notes ?? '',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Save order to database
      await _databaseService.createOrder(orderData);

      // Create order items
      final orderItems = _cartItems
          .map(
            (item) => {
              'id': _uuid.v4(),
              'menu_item_id': _isValidUUID(item.id) ? item.id : _uuid.v4(),
              'menu_item_name': item.name,
              'name': item.name,
              'category': 'Food', // Default category
              'menu_item_image': item.imageUrl ?? '',
              'quantity': 1,
              'unit_price': item.price,
              'total_price': item.price,
            },
          )
          .toList();

      await _databaseService.addOrderItems(orderId, orderItems);

      // Create local order object
      final order = Order(
        id: orderId,
        userId: _currentUser!.id,
        items: _cartItems
            .where(
              (item) => item.id.isNotEmpty && item.name.isNotEmpty,
            ) // Filter out invalid items
            .map(
              (item) => OrderItem(
                menuItemId: item.id,
                menuItemName: item.name,
                name: item.name,
                category: item.category?.displayName.toLowerCase() ??
                    'Non catégorisé',
                menuItemImage: item.imageUrl ?? '',
                quantity: 1,
                unitPrice: item.price,
                totalPrice: item.price,
              ),
            )
            .toList(),
        subtotal: subtotal,
        total: total,
        paymentMethod: paymentMethod,
        orderTime: DateTime.now(),
        createdAt: DateTime.now(),
        deliveryAddress: address,
      );

      _orders.insert(0, order);

      // Award loyalty points for clients
      if (_currentUser?.role == UserRole.client) {
        final pointsEarned = (total / 10).round(); // 1 point per 10€
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

  // New method to place order with CartService data
  Future<String> placeOrderFromCartService(
    Address? deliveryAddress,
    PaymentMethod paymentMethod,
    List<dynamic> cartItems,
    double subtotal,
    double deliveryFee,
    double discount, {
    String? notes,
  }) async {
    if (cartItems.isEmpty || _currentUser == null) return '';

    // Valider les données avant l'envoi
    final validator = DataValidatorService();

    // Convertir les cartItems en CartItem pour la validation
    final cartItemsForValidation =
        cartItems.whereType<CartItem>().map((item) => item).toList();

    if (cartItemsForValidation.isEmpty) {
      throw Exception('Aucun article valide dans le panier');
    }

    // Si l'adresse n'est pas fournie, créer une adresse temporaire à partir de l'adresse texte
    // Sinon utiliser l'adresse fournie
    final addressForValidation = deliveryAddress ??
        Address(
          id: 'temp',
          userId: _currentUser!.id,
          name: 'Livraison',
          address: '',
          city: '',
          postalCode: '',
          type: AddressType.other,
          isDefault: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    // Calculer le total avec les frais de livraison et remises
    final calculatedTotal = subtotal + deliveryFee - discount;

    final validationResult = validator.validateOrder(
      items: cartItemsForValidation,
      deliveryAddress: addressForValidation,
      paymentMethod: _paymentMethodToDbString(paymentMethod),
      total: calculatedTotal,
    );

    if (!validationResult.isValid) {
      final errorMessage = validationResult.errors.join('\n');
      _errorHandler.logError(
        'Erreur de validation de commande',
        code: 'ORDER_VALIDATION_ERROR',
        details: errorMessage,
      );
      throw Exception(errorMessage);
    }

    try {
      final orderId = _uuid.v4();
      final total = subtotal + deliveryFee - discount;

      // Récupérer le code promo depuis CartService
      final cartService = CartService();
      final promoCode = cartService.promoCode;

      // Create order data for database
      final addressString = addressForValidation.fullAddress;
      final orderData = {
        'id': orderId,
        'user_id': _currentUser!.id,
        'status': 'pending',
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'discount': discount,
        'total': total,
        'payment_method': _paymentMethodToDbString(paymentMethod),
        'delivery_address': addressString,
        'delivery_notes': notes ?? '',
        'promo_code': promoCode, // Ajouter le code promo à la commande
        'created_at': DateTime.now().toIso8601String(),
      };

      // Create local order object first (for offline mode)
      final order = Order(
        id: orderId,
        userId: _currentUser!.id,
        items: cartItems
            .where(
              (item) => item.id.isNotEmpty && item.name.isNotEmpty,
            ) // Filter out invalid items
            .map(
              (item) => OrderItem(
                menuItemId: item.id,
                menuItemName: item.name,
                name: item.name,
                category: 'Food', // Default category
                menuItemImage: item.imageUrl ?? '',
                quantity: item.quantity,
                unitPrice: item.price,
                totalPrice: item.totalPrice,
              ),
            )
            .toList(),
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: total,
        paymentMethod: paymentMethod,
        orderTime: DateTime.now(),
        createdAt: DateTime.now(),
        deliveryAddress: addressString,
        promoCode: cartService.promoCode,
        discount: discount,
        deliveryNotes: notes,
      );

      // Process payment first
      bool paymentSuccess = false;
      String? paymentTransactionId;

      if (paymentMethod == PaymentMethod.mobileMoney) {
        // Process mobile money payment
        final paymentResult = await _payDunyaService.processMobileMoneyPayment(
          orderId: orderId,
          amount: total,
          phoneNumber: _currentUser!.phone,
          operator: 'mtn', // Default to MTN, could be made configurable
          customerName: _currentUser!.name,
          customerEmail: _currentUser!.email,
        );

        paymentSuccess = paymentResult.success;
        paymentTransactionId = paymentResult.invoiceToken;
      } else if (paymentMethod == PaymentMethod.creditCard ||
          paymentMethod == PaymentMethod.debitCard) {
        // For card payments, we'll simulate success for now
        // In a real implementation, you'd collect card details from the user
        paymentSuccess = true;
        paymentTransactionId = 'TXN_${DateTime.now().millisecondsSinceEpoch}';
      } else if (paymentMethod == PaymentMethod.wallet) {
        // Process wallet payment
        final walletService = WalletService();
        paymentSuccess = await walletService.processPayment(total, orderId);
        paymentTransactionId =
            'WALLET_${DateTime.now().millisecondsSinceEpoch}';
      } else if (paymentMethod == PaymentMethod.cash) {
        // Cash payment - always succeeds
        paymentSuccess = true;
        paymentTransactionId = 'CASH_${DateTime.now().millisecondsSinceEpoch}';
      }

      if (!paymentSuccess) {
        throw Exception('Échec du paiement. Veuillez réessayer.');
      }

      // Add payment transaction ID to order data
      orderData['payment_transaction_id'] = paymentTransactionId ?? '';
      orderData['payment_status'] = 'completed';

      // Save order to database (ou hors ligne si pas de connexion)
      try {
        await _databaseService.createOrder(orderData);
      } catch (e) {
        // Si erreur de connexion, sauvegarder hors ligne
        if (!_offlineSyncService.isOnline) {
          debugPrint(
            '📴 Mode hors ligne: sauvegarde de la commande localement',
          );
          await _offlineSyncService.saveOrderOffline(order);
          // Retourner l'ID même si hors ligne
          _orders.insert(0, order);
          notifyListeners();
          return orderId;
        }
        rethrow;
      }

      // Create order items
      final orderItems = <Map<String, dynamic>>[];

      for (final item in cartItems) {
        // Ensure the menu item exists in the database
        String menuItemId = item.id;

        // Check if menu item exists, if not create it
        if (!_isValidUUID(item.id)) {
          menuItemId = _uuid.v4();
        }

        // Try to create the menu item if it doesn't exist
        try {
          await _ensureMenuItemExists(item, menuItemId);
        } catch (e) {
          debugPrint('Warning: Could not ensure menu item exists: $e');
          // Continue with the order anyway
        }

        orderItems.add({
          'id': _uuid.v4(),
          'menu_item_id': menuItemId,
          'menu_item_name': item.name,
          'name': item.name,
          'category': 'Food', // Default category
          'menu_item_image': item.imageUrl ?? '',
          'quantity': item.quantity,
          'unit_price': item.price,
          'total_price': item.totalPrice,
        });
      }

      await _databaseService.addOrderItems(orderId, orderItems);

      // Enregistrer l'utilisation du code promo si applicable
      if (cartService.promoCode != null && discount > 0) {
        try {
          // Récupérer le PromoCodeService (singleton)
          final promoCodeService = PromoCodeService();

          // S'assurer que le service est initialisé
          if (!promoCodeService.isInitialized) {
            await promoCodeService.initialize();
          }

          // Vérifier si un code promo est actuellement appliqué
          if (promoCodeService.currentPromoCode != null) {
            await promoCodeService.recordPromoCodeUsage(
              userId: _currentUser!.id,
              orderId: orderId,
              discountAmount: discount,
            );
            debugPrint(
              '✅ Utilisation du code promo enregistrée: ${cartService.promoCode}',
            );
          } else {
            // Si le code promo n'est pas dans le service mais est dans le panier,
            // essayer de le valider et l'enregistrer
            final validationResult =
                await promoCodeService.validateAndApplyPromoCode(
              code: cartService.promoCode!,
              orderAmount: subtotal + deliveryFee,
              userId: _currentUser!.id,
            );

            if (validationResult.isValid &&
                validationResult.promoCode != null) {
              await promoCodeService.recordPromoCodeUsage(
                userId: _currentUser!.id,
                orderId: orderId,
                discountAmount: discount,
              );
              debugPrint(
                '✅ Utilisation du code promo enregistrée après validation: ${cartService.promoCode}',
              );
            }
          }
        } catch (e) {
          debugPrint(
            '⚠️ Erreur lors de l\'enregistrement de l\'utilisation du code promo: $e',
          );
          // Ne pas bloquer la commande si l'enregistrement échoue
        }
      }

      // Consommer le repas gratuit si applicable
      if (cartService.isFreeMealApplied) {
        try {
          final walletService = WalletService();
          await walletService.useFreeMeal();
          debugPrint('✅ Repas gratuit consommé pour la commande $orderId');
        } catch (e) {
          debugPrint('⚠️ Erreur lors de la consommation du repas gratuit: $e');
        }
      }

      // Ajouter le code promo à la commande si applicable
      if (cartService.promoCode != null) {
        try {
          await _databaseService.updateOrder(orderId, {
            'promo_code': cartService.promoCode,
          });
        } catch (e) {
          debugPrint(
            '⚠️ Erreur lors de l\'ajout du code promo à la commande: $e',
          );
        }
      }

      _orders.insert(0, order);

      // Award loyalty points for clients
      if (_currentUser?.role == UserRole.client) {
        final pointsEarned = (total / 10).round(); // 1 point per 10€
        _currentUser = _currentUser!.copyWith(
          loyaltyPoints: _currentUser!.loyaltyPoints + pointsEarned,
        );
        try {
          await _databaseService.updateUserProfile(_currentUser!.id, {
            'loyalty_points': _currentUser!.loyaltyPoints,
          });
        } catch (e) {
          // Si erreur de connexion, sauvegarder hors ligne
          if (!_offlineSyncService.isOnline) {
            await _offlineSyncService.saveUserUpdateOffline(
              _currentUser!.id,
              {'loyalty_points': _currentUser!.loyaltyPoints},
            );
          } else {
            rethrow;
          }
        }
      }

      // Track order event (seulement si en ligne)
      if (_offlineSyncService.isOnline) {
        try {
          await _databaseService.trackEvent(
            eventType: 'order_placed',
            eventData: {
              'order_id': orderId,
              'total_amount': total,
              'item_count': cartItems.length,
            },
            userId: _currentUser!.id,
          );
        } catch (e) {
          debugPrint('⚠️ Erreur tracking event: $e');
        }
      }

      // Déclencher les notifications et gamification
      await _notificationService.showOrderConfirmationNotification(
        orderId,
        cartItems.isNotEmpty
            ? cartItems.map((item) => item.name).join(', ')
            : 'Commande',
      );

      _gamificationService.onOrderPlaced(total);

      // Démarrer le suivi de livraison
      _locationService.startDeliveryTracking(orderId);

      notifyListeners();
      return orderId;
    } catch (e) {
      debugPrint('Error placing order from cart service: $e');
      return '';
    }
  }

  // Helper methods

  Future<void> _loadMenuItems() async {
    try {
      // Utiliser le nouveau service de cache intelligent
      _menuItems = await _menuItemCache.getMenuItems();

      // Associer les catégories si nécessaire
      if (_menuCategories.isNotEmpty) {
        _menuItems = _menuItems.map((item) {
          if (item.category == null && item.categoryId.isNotEmpty) {
            final category = _menuCategories.firstWhere(
              (c) => c.id == item.categoryId,
              orElse: () => _menuCategories.first,
            );
            return item.copyWith(category: category);
          }
          return item;
        }).toList();
      }

      // Mettre en cache dans OfflineSyncService pour le mode hors ligne
      await _offlineSyncService.cacheMenuItems(_menuItems);

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading menu items: $e');
      _errorHandler.logError('Erreur lors du chargement du menu', details: e);
      _menuItems = [];
      notifyListeners();
    }
  }

  Future<void> _loadMenuCategories() async {
    try {
      // Utiliser le nouveau service de cache intelligent
      _menuCategories = await _menuItemCache.getCategories();

      // Extraire les display names pour la compatibilité
      _menuCategoryDisplayNames = _menuCategories
          .map((c) => c.displayName)
          .where((s) => s.isNotEmpty)
          .toList();

      // fallback si display_name manquant
      if (_menuCategoryDisplayNames.isEmpty) {
        _menuCategoryDisplayNames = _menuCategories
            .map((c) => c.name)
            .where((s) => s.isNotEmpty)
            .map((s) => s[0].toUpperCase() + s.substring(1))
            .toList();
      }

      // Mettre en cache dans OfflineSyncService pour le mode hors ligne
      await _offlineSyncService.cacheCategories(_menuCategories);

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading menu categories: $e');
      _errorHandler.logError(
        'Erreur lors du chargement des catégories',
        details: e,
      );
      _menuCategories = [];
      _menuCategoryDisplayNames = [];
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile(String authUserId) async {
    try {
      final userData = await _databaseService.getUserProfile(authUserId);
      if (userData != null) {
        _currentUser = User.fromMap(userData);
        // Load user orders after setting current user
        await _loadUserOrders();
        await AddressService().initializeForUser(_currentUser!.id);
        await CartService().initializeForUser(_currentUser!.id);
        await _gamificationService.initialize(
          userId: _currentUser!.id,
          forceRefresh: true,
        );
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
      await _databaseService.updateOrderStatus(
        orderId,
        'picked_up',
        deliveryPersonId: _currentUser!.id,
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

  // Payment methods
  Future<PaymentRequestResult> processPayment({
    required String orderId,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String paymentMethod,
    String? cardNumber,
    String? cardHolderName,
    String? expiryMonth,
    String? expiryYear,
    String? cvv,
    String? operator,
  }) async {
    try {
      if (paymentMethod == 'mobile_money') {
        final result = await _payDunyaService.processMobileMoneyPayment(
          orderId: orderId,
          amount: amount,
          phoneNumber: customerPhone,
          operator: operator ?? 'mtn',
          customerName: customerName,
          customerEmail: customerEmail,
        );

        return PaymentRequestResult(
          success: result.success,
          invoiceToken: result.invoiceToken,
          invoiceUrl: result.invoiceUrl,
          error: result.error,
          orderId: orderId,
        );
      } else if (paymentMethod == 'card') {
        final result = await _payDunyaService.processCardPayment(
          orderId: orderId,
          amount: amount,
          cardNumber: cardNumber!,
          cardHolderName: cardHolderName!,
          expiryMonth: expiryMonth!,
          expiryYear: expiryYear!,
          cvv: cvv!,
          customerName: customerName,
          customerEmail: customerEmail,
        );

        return PaymentRequestResult(
          success: result.success,
          invoiceToken: result.invoiceToken,
          invoiceUrl: result.invoiceUrl,
          error: result.error,
          orderId: orderId,
        );
      }

      return PaymentRequestResult(
        success: false,
        error: 'Méthode de paiement non supportée',
        orderId: orderId,
      );
    } catch (e) {
      debugPrint('Error processing payment: $e');
      return PaymentRequestResult(
        success: false,
        error: e.toString(),
        orderId: orderId,
      );
    }
  }

  Future<SharedPaymentResult> processSharedPayment({
    required String groupId,
    required String orderId,
    required double totalAmount,
    required List<PaymentParticipant> participants,
    required String organizerName,
    required String organizerEmail,
  }) async {
    try {
      return await _payDunyaService.processSharedPayment(
        orderId: orderId,
        totalAmount: totalAmount,
        participants: participants,
        organizerName: organizerName,
        organizerEmail: organizerEmail,
      );
    } catch (e) {
      debugPrint('Error processing shared payment: $e');
      return SharedPaymentResult(
        success: false,
        totalAmount: totalAmount,
        paidAmount: 0.0,
        participants: participants,
        results: [],
        orderId: orderId,
        error: e.toString(),
      );
    }
  }

  Future<bool> cancelPayment(String invoiceToken) async {
    try {
      return await _payDunyaService.cancelPayment(invoiceToken);
    } catch (e) {
      debugPrint('Error cancelling payment: $e');
      return false;
    }
  }

  Future<bool> processRefund({
    required String transactionId,
    required double amount,
    required String reason,
  }) async {
    try {
      return await _payDunyaService.processRefund(
        transactionId: transactionId,
        amount: amount,
        reason: reason,
      );
    } catch (e) {
      debugPrint('Error processing refund: $e');
      return false;
    }
  }

  Future<List<PaymentHistoryItem>> getPaymentHistory({
    int page = 1,
    int limit = 20,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _payDunyaService.getPaymentHistory(
        page: page,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('Error getting payment history: $e');
      return [];
    }
  }
}
