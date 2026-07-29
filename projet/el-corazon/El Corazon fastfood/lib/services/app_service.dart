import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
// Alias explicite : `eccore.User` (backend Django) et le `User` local
// (Supabase, ci-dessous) portent le même nom mais pas la même forme — voir
// `_fromDjangoUser`, qui traduit le premier vers le second.
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
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
// import 'package:elcora_fast/services/wallet_service.dart'; // Portefeuille désactivé temporairement
import 'package:elcora_fast/services/realtime_sync_service.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/offline_sync_service.dart';
import 'package:elcora_fast/services/menu_item_cache_service.dart';
import 'package:elcora_fast/services/notification_database_service.dart';
import 'package:elcora_fast/services/push_notification_service.dart';
import 'package:elcora_fast/repositories/django_order_repository.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/services/socket_service.dart';

class AppService extends ChangeNotifier {
  static AppService? _instance;

  /// Le conteneur Riverpod est celui créé une fois dans `main()` — voir
  /// `UncontrolledProviderScope`. Seul `main.dart` le fournit réellement
  /// (`ChangeNotifierProvider(create: (_) => AppService(container))`) ; les
  /// nombreux autres appels `AppService()` sans argument, déjà présents
  /// ailleurs dans le code (mêmes conventions que `DatabaseService()`), n'ont
  /// pas besoin d'être réécrits — ils retrouvent l'instance déjà construite.
  factory AppService([ProviderContainer? container]) {
    final existing = _instance;
    if (existing != null) return existing;

    if (container == null) {
      throw StateError(
        'AppService() a été appelé avant sa première construction avec un '
        'ProviderContainer (voir main.dart).',
      );
    }
    return _instance = AppService._internal(container);
  }

  AppService._internal(this._container) {
    // `fireImmediately` peuple `_currentUser` dès la construction si une
    // session a déjà été restaurée avant que ce service n'existe.
    _sessionSubscription = _container.listen<AsyncValue<eccore.User?>>(
      eccore.sessionProvider,
      (previous, next) => _onSessionChanged(next),
      fireImmediately: true,
    );

    // FCM renouvelle le jeton d'appareil de son propre chef : sans
    // ré-enregistrement, l'appareil cesse de recevoir quoi que ce soit, en
    // silence. Ne fait rien tant que personne n'est connecté — l'appel
    // échouerait en 401 et est déjà best-effort.
    _tokenRefreshSubscription =
        PushNotificationService().tokenRefreshStream.listen((_) {
      if (_currentUser != null) {
        unawaited(_registerPushDeviceBestEffort());
      }
    });
  }

  final ProviderContainer _container;
  late final ProviderSubscription<AsyncValue<eccore.User?>> _sessionSubscription;
  late final StreamSubscription<String> _tokenRefreshSubscription;

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

  /// Nettoie l'adresse en supprimant les emojis et caractères non autorisés
  /// Garde uniquement les lettres, chiffres, espaces et caractères de ponctuation sûrs
  String _cleanAddressString(String address) {
    if (address.isEmpty) return address;

    String cleaned = address;

    // Supprimer les emojis (plages Unicode communes)
    cleaned = cleaned.replaceAll(
      RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true),
      '',
    ); // Emojis
    cleaned = cleaned.replaceAll(
      RegExp(r'[\u{2600}-\u{26FF}]', unicode: true),
      '',
    ); // Symboles divers
    cleaned = cleaned.replaceAll(
      RegExp(r'[\u{2700}-\u{27BF}]', unicode: true),
      '',
    ); // Symboles Dingbats
    cleaned = cleaned.replaceAll(
      RegExp(r'[\u{1F600}-\u{1F64F}]', unicode: true),
      '',
    ); // Emojis visages
    cleaned = cleaned.replaceAll(
      RegExp(r'[\u{1F680}-\u{1F6FF}]', unicode: true),
      '',
    ); // Emojis transport
    cleaned = cleaned.replaceAll(
      RegExp(r'[\u{1F900}-\u{1F9FF}]', unicode: true),
      '',
    ); // Emojis supplémentaires

    // Garder uniquement les caractères sûrs pour une adresse :
    // - Lettres (a-z, A-Z) et caractères accentués français (é, è, à, etc.)
    // - Chiffres (0-9)
    // - Espaces
    // - Caractères de ponctuation sûrs : virgule, point, tiret, parenthèses
    // Exclure : !, @, #, $, %, ^, &, *, etc. qui peuvent être considérés comme dangereux
    cleaned = cleaned.replaceAll(
      RegExp(
        r'[^a-zA-Z0-9\s,\-\.\(\)àáâãäåèéêëìíîïòóôõöùúûüýÿçñÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝŸÇÑ]',
      ),
      '',
    );

    // Nettoyer les espaces multiples
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
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
  SocketService get socketService => SocketService();
  ErrorHandlerService get errorHandler => _errorHandler;
  bool get isClient => _currentUser?.role == UserRole.client;

  double get cartTotal {
    return _cartItems.fold(0.0, (sum, item) => sum + item.price);
  }

  int get cartItemCount {
    return _cartItems.length;
  }

  @override
  void dispose() {
    _sessionSubscription.close();
    unawaited(_tokenRefreshSubscription.cancel());
    super.dispose();
  }

  /// Pont entre la session Riverpod (backend Django, source de vérité de
  /// l'identité — Phase 6) et le `_currentUser` local que le reste de cette
  /// classe lit encore. C'est le seul endroit qui traduit l'un vers l'autre.
  void _onSessionChanged(AsyncValue<eccore.User?> next) {
    final djangoUser = next.value;
    _currentUser = djangoUser == null ? null : _fromDjangoUser(djangoUser);
    notifyListeners();
  }

  /// Les points de fidélité et les badges n'existent pas dans
  /// `UserSerializer` — domaine pas encore migré. Ils gardent leur valeur par
  /// défaut tant que la fidélité n'a pas son tour ; ce n'est pas un oubli.
  User _fromDjangoUser(eccore.User djangoUser) {
    return User(
      id: djangoUser.id,
      name: djangoUser.fullName,
      email: djangoUser.email,
      phone: djangoUser.phone ?? '',
      role: UserRole.client,
      profileImage: djangoUser.avatar,
      createdAt: djangoUser.createdAt,
    );
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

  /// Appelée après que `sessionProvider` a fini de restaurer la session
  /// (Phase 6) — `_currentUser` est donc déjà à jour via le pont ci-dessus.
  Future<void> _loadUserSession() async {
    try {
      if (_currentUser != null) {
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

  // Authentication methods — Django (Phase 6), plus Supabase. Signatures
  // inchangées : les écrans qui appellent login/register n'ont pas eu
  // besoin de changer, seul l'intérieur bascule de backend.
  Future<bool> login(String email, String password) async {
    try {
      await _container.read(eccore.sessionProvider.notifier).login(
        email: email,
        password: password,
      );
      // `_currentUser` est déjà à jour ici (le pont d'écoute est synchrone
      // par rapport au changement d'état) ; la garde de rôle (customer) est
      // déjà appliquée par `sessionProvider`. Le suivi temps réel et
      // l'événement analytics qui suivaient dépendaient de l'identifiant
      // Supabase — différés au domaine correspondant (pas encore migré)
      // plutôt qu'appelés avec un identifiant Django qu'aucune ligne
      // Supabase ne connaît.
      notifyListeners();
      unawaited(_registerPushDeviceBestEffort());
      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  /// Enregistre le jeton FCM obtenu par `PushNotificationService` auprès de
  /// `/api/v1/auth/devices/` (Phase 6). Best-effort, comme côté `dely` : un
  /// échec (réseau, jeton pas encore disponible, aucun projet Firebase
  /// configuré) ne doit pas faire échouer la connexion — les notifications
  /// sont secondaires à l'authentification elle-même.
  Future<void> _registerPushDeviceBestEffort() async {
    final token = PushNotificationService().fcmToken;
    if (token == null || token.isEmpty) return;

    try {
      await _container.read(eccore.authRepositoryProvider).registerDevice(
        token: token,
        platform: switch (defaultTargetPlatform) {
          TargetPlatform.iOS => 'ios',
          TargetPlatform.android => 'android',
          _ => 'web',
        },
      );
    } catch (e) {
      debugPrint('⚠️ Échec de l\'enregistrement du jeton FCM: $e');
    }
  }

  Future<bool> register(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    // Les exceptions de s\u00e9curit\u00e9 doivent remonter \u00e0 l'UI (ne pas les
    // avaler silencieusement avec return false) \u2014 inchang\u00e9.
    await _container.read(eccore.sessionProvider.notifier).register(
      email: email,
      password: password,
      fullName: name,
      phone: phone,
    );
    notifyListeners();
    unawaited(_registerPushDeviceBestEffort());
    return true;
  }

  Future<void> logout() async {
    try {
      // Avant la révocation : `/auth/devices/` exige la session qu'on est en
      // train de fermer. Sans cela, l'appareil resterait rattaché au compte et
      // continuerait de recevoir ses notifications.
      await _unregisterPushDeviceBestEffort();
      await _container.read(eccore.sessionProvider.notifier).logout();
      _cartItems.clear();
      await CartService().clearForLogout();
      unawaited(AddressService().clearSession());
      _gamificationService.reset();
      NotificationDatabaseService().clearSession();
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  Future<void> _unregisterPushDeviceBestEffort() async {
    final token = PushNotificationService().fcmToken;
    if (token == null || token.isEmpty) return;

    try {
      await _container.read(eccore.authRepositoryProvider).unregisterDevice(token);
    } catch (e) {
      debugPrint('⚠️ Échec du retrait du jeton FCM: $e');
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
      const deliveryFee = 1000.0;
      final total = subtotal + deliveryFee;

      // Create order data for database
      // Nettoyer l'adresse pour supprimer les emojis et caractères non autorisés
      final cleanedAddress = _cleanAddressString(address);
      final orderData = {
        'id': orderId,
        'user_id': _currentUser!.id,
        'status': 'pending',
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'total': total,
        'payment_method': _paymentMethodToDbString(paymentMethod),
        'delivery_address': cleanedAddress,
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
  //
  // Backend Django (Phase 6, tranche commandes) : la commande naît du
  // **panier serveur**, jamais d'une liste d'articles envoyée par le client
  // (C1/C2, `OrderService.create_from_cart`) — `subtotal`/`deliveryFee`/
  // `discount` restent des paramètres pour compatibilité de signature avec
  // `checkout_screen.dart`, mais ne sont plus envoyés : le total affiché
  // avant validation est une estimation client, le total qui compte est
  // celui que Django renvoie. Le paiement réel (PayDunya via le backend) est
  // une tranche à venir — quel que soit le moyen choisi, la commande naît
  // `pending`, aucun paiement n'est déclenché ici (décision produit actée).
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

    if (deliveryAddress == null ||
        deliveryAddress.latitude == null ||
        deliveryAddress.longitude == null) {
      throw Exception(
        'Adresse de livraison invalide : sélectionnez une adresse géocodée avant de commander.',
      );
    }

    try {
      final cartService = CartService();
      // Le panier serveur doit refléter l'état local au moment exact où
      // `OrderService.create_from_cart` le lit — `_persistChanges` (dans
      // CartService) synchronise sans attendre, donc on s'assure ici que la
      // dernière écriture est bien passée avant de commander.
      await cartService.ensureSynced();

      final remoteOrder = await DjangoOrderRepository().createFromServerCart(
        address: deliveryAddress,
        paymentMethod: paymentMethod,
        instructions: notes,
        promoCode: cartService.promoCode ?? '',
      );

      _orders.insert(0, remoteOrder);

      // Award loyalty points for clients — domaine fidélité pas encore
      // migré (reste simulé côté client, inchangé par cette tranche).
      if (_currentUser?.role == UserRole.client) {
        final pointsEarned = (remoteOrder.total / 100).round();
        _currentUser = _currentUser!.copyWith(
          loyaltyPoints: _currentUser!.loyaltyPoints + pointsEarned,
        );
        try {
          await _databaseService.updateUserProfile(_currentUser!.id, {
            'loyalty_points': _currentUser!.loyaltyPoints,
          });
        } catch (e) {
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

      // Déclencher les notifications et gamification (inchangé, simulé
      // côté client — domaines pas encore migrés).
      await _notificationService.showOrderConfirmationNotification(
        remoteOrder.id,
        cartItems.isNotEmpty
            ? cartItems.map((item) => (item as CartItem).name).join(', ')
            : 'Commande',
      );

      _gamificationService.onOrderPlaced(remoteOrder.total);

      // Démarrer le suivi de livraison
      _locationService.startDeliveryTracking(remoteOrder.id);

      notifyListeners();
      return remoteOrder.id;
    } catch (e) {
      debugPrint('Error placing order from cart service: $e');
      return '';
    }
  }

  // Finalize an existing order (e.g. group order)
  Future<String> finalizeExistingOrder(
    String orderId,
    Address? deliveryAddress,
    PaymentMethod paymentMethod,
    double total, {
    String? notes,
    String? promoCode,
    double discount = 0.0,
  }) async {
    if (_currentUser == null) throw Exception('Utilisateur non connecté');

    try {
      // Valider l'adresse
      final addressString = deliveryAddress?.fullAddress ?? '';
      if (addressString.isEmpty) {
        throw Exception('Adresse de livraison requise');
      }

      // Nettoyer l'adresse pour supprimer les emojis et caractères non autorisés
      final cleanedAddress = _cleanAddressString(addressString);

      // Mettre à jour la commande existante
      final updates = {
        'status':
            'pending', // Reste en pending jusqu'à confirmation du paiement si nécessaire
        'payment_method': _paymentMethodToDbString(paymentMethod),
        'delivery_address': cleanedAddress,
        'delivery_notes': notes ?? '',
        'total': total,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (promoCode != null) {
        updates['promo_code'] = promoCode;
        updates['discount'] = discount;
      }

      await _databaseService.updateOrder(orderId, updates);

      // Traiter le paiement
      bool paymentSuccess = false;
      String? paymentTransactionId;

      if (paymentMethod == PaymentMethod.mobileMoney) {
        final result = await _payDunyaService.processMobileMoneyPayment(
          orderId: orderId,
          amount: total,
          phoneNumber: _currentUser!.phone,
          operator: 'mtn',
          customerName: _currentUser!.name,
          customerEmail: _currentUser!.email,
        );
        paymentSuccess = result.success;
        paymentTransactionId = result.invoiceToken;
      } else if (paymentMethod == PaymentMethod.cash) {
        paymentSuccess = true;
        paymentTransactionId = 'CASH_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        // Autres méthodes (simulation)
        paymentSuccess = true;
        paymentTransactionId = 'TXN_${DateTime.now().millisecondsSinceEpoch}';
      }

      if (!paymentSuccess) {
        throw Exception('Échec du paiement. Veuillez réessayer.');
      }

      // Mettre à jour statut post-paiement
      await _databaseService.updateOrder(orderId, {
        'payment_status': 'completed',
        'payment_transaction_id': paymentTransactionId,
        'status': 'confirmed', // Confirmer la commande
      });

      // Notifications et Tracking
      await _notificationService.showOrderConfirmationNotification(
        orderId,
        'Commande de groupe',
      );

      _locationService.startDeliveryTracking(orderId);

      // Mettre à jour la liste locale des commandes
      await _loadUserOrders();

      return orderId;
    } catch (e) {
      debugPrint('Error finalizing existing order: $e');
      rethrow;
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
          .where((c) => c.isActive)
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

  Future<void> _loadUserOrders() async {
    if (_currentUser == null) return;

    try {
      _orders = await DjangoOrderRepository().getUserOrders(_currentUser!.id);
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
