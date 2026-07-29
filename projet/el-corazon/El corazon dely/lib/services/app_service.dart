import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Import conditionnel pour File (mobile vs web)
import 'dart:io' if (dart.library.html) 'dart:html' as io;
// Alias explicite : `eccore.User` (backend Django) et le `User` local
// (Supabase, ci-dessous) portent le même nom mais pas la même forme — voir
// `_fromDjangoUser`, qui traduit le premier vers le second.
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import '../models/user.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/message.dart';
import '../repositories/django_delivery_repository.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'gamification_service.dart';
import 'realtime_tracking_service.dart';
import 'database_service.dart';
import 'storage_service.dart';
import 'paydunya_service.dart';

class AppService extends ChangeNotifier {
  static AppService? _instance;

  /// Le conteneur Riverpod est celui créé une fois dans `main()` — voir
  /// `UncontrolledProviderScope`. Un seul appelant (le premier) le fournit
  /// réellement ; les suivants (le `ChangeNotifierProvider` lui-même, sur un
  /// éventuel rebuild du widget racine) retrouvent la même instance.
  factory AppService(ProviderContainer container) {
    return _instance ??= AppService._internal(container);
  }

  AppService._internal(this._container) {
    // Le transport temps réel ne connaît ni les courses ni les repositories :
    // il faut lui rendre les deux gestes qui en demandent la connaissance
    // avant que la moindre session ne s'ouvre.
    _bindTrackingService();

    // `fireImmediately` peuple `_currentUser` dès la construction si une
    // session a déjà été restaurée avant que ce service n'existe — sinon la
    // toute première frame verrait un utilisateur nul qui redevient non nul
    // juste après, sans qu'aucun événement ne l'ait annoncé.
    _sessionSubscription = _container.listen<AsyncValue<eccore.User?>>(
      eccore.sessionProvider,
      (previous, next) => _onSessionChanged(next),
      fireImmediately: true,
    );
  }

  final ProviderContainer _container;
  late final ProviderSubscription<AsyncValue<eccore.User?>> _sessionSubscription;

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

  /// Courses du livreur (Phase 6), indexées par identifiant de **commande** :
  /// c'est ainsi que les écrans les désignent, alors que toutes les actions
  /// s'adressent à l'affectation. Cette table est le pont entre les deux.
  final Map<String, Course> _coursesByOrderId = {};
  DjangoDeliveryRepository? _deliveryRepository;
  eccore.CourierProfile? _courierProfile;
  StreamSubscription<eccore.AssignmentOffer>? _courseOffersSubscription;

  /// Construit à la demande : l'`ApiClient` vit dans le conteneur Riverpod créé
  /// par `main()`, et le lire au constructeur d'`AppService` le figerait avant
  /// que les surcharges de test aient pu s'appliquer.
  DjangoDeliveryRepository get _delivery =>
      _deliveryRepository ??= DjangoDeliveryRepository(
        apiClient: _container.read(eccore.apiClientProvider),
      );

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

  @override
  void dispose() {
    _sessionSubscription.close();
    unawaited(_courseOffersSubscription?.cancel());
    super.dispose();
  }

  /// Pont entre la session Riverpod (backend Django, source de vérité de
  /// l'identité — Phase 6) et le `_currentUser` local que le reste de cette
  /// classe lit encore. C'est le seul endroit qui traduit l'un vers l'autre :
  /// tout le reste d'`AppService` continue de lire `_currentUser` sans savoir
  /// d'où il vient.
  void _onSessionChanged(AsyncValue<eccore.User?> next) {
    final djangoUser = next.value;
    final wasConnected = _currentUser != null;
    _currentUser = djangoUser == null ? null : _fromDjangoUser(djangoUser);

    // La file des courses et l'émission de position suivent la session, pas un
    // écran : un livreur connecté reste joignable et reste suivi même quand il
    // n'a aucune carte ouverte.
    if (_currentUser != null && !wasConnected) {
      unawaited(trackingService.startCourierSession());
    } else if (_currentUser == null && wasConnected) {
      _coursesByOrderId.clear();
      _courierProfile = null;
      unawaited(trackingService.stopCourierSession());
    }

    notifyListeners();
  }

  /// Rend au transport temps réel les deux gestes qui demandent de connaître
  /// les courses : relire une commande, et déposer un relevé sur l'affectation
  /// en cours. Lui passer `AppService` entier créerait un cycle entre les deux
  /// fichiers pour deux appels.
  void _bindTrackingService() {
    final tracking = trackingService;

    tracking.bind(
      readOrder: (orderId) async {
        final known = _coursesByOrderId[orderId];
        if (known == null) return null;

        final refreshed = await _delivery.loadCourse(known.assignmentId);
        _rememberCourse(refreshed);
        return refreshed.order;
      },
      reportPosition: (position) async {
        final course = activeCourse;
        if (course == null) return;

        await updateDeliveryLocation(
          orderId: course.orderId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
          heading: position.heading,
        );
      },
    );

    // Une course proposée arrive par la file : la liste se recharge pour que
    // l'écran la montre avec tout ce qu'il lui faut (montants, articles,
    // transitions permises), que le message d'alerte ne porte pas.
    _courseOffersSubscription = tracking.courseOffers.listen((offer) {
      debugPrint('📨 Course proposée : ${offer.reference} (${offer.restaurant})');
      unawaited(loadAvailableOrders(forceRefresh: true));
    });
  }

  /// Le compte de fidélité, les badges et le statut « en ligne » n'existent
  /// pas dans `UserSerializer` — ce sont des domaines pas encore migrés
  /// (fidélité, livraison). Ils gardent leur valeur par défaut tant que ces
  /// domaines n'ont pas leur tour ; ce n'est pas un oubli.
  User _fromDjangoUser(eccore.User djangoUser) {
    return User(
      id: djangoUser.id,
      name: djangoUser.fullName,
      email: djangoUser.email,
      phone: djangoUser.phone ?? '',
      role: UserRole.delivery,
      profileImage: djangoUser.avatar,
      createdAt: djangoUser.createdAt,
    );
  }

  /// Appelée par `SplashScreen` une fois que `sessionProvider` a fini de
  /// restaurer la session (Phase 6) — `_currentUser` est donc déjà à jour via
  /// le pont ci-dessus, il n'y a plus à interroger Supabase pour savoir si un
  /// livreur est connecté.
  /// Enregistre le jeton FCM déjà obtenu par `NotificationService` auprès de
  /// `/api/v1/auth/devices/` (Phase 6). Best-effort : un échec ici (réseau,
  /// jeton pas encore disponible) ne doit pas faire échouer la connexion —
  /// les notifications restent secondaires à l'authentification elle-même.
  Future<void> _registerPushDeviceBestEffort() async {
    final token = _notificationService.fcmToken;
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

  Future<void> initialize() async {
    try {
      // Load menu items from database
      await _loadMenuItems();

      if (_currentUser != null && _currentUser!.role == UserRole.delivery) {
        await loadAvailableOrders();
      } else if (_currentUser == null) {
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
  //
  // `login()` (Supabase) a été supprimé avec cette tranche : il n'avait plus
  // aucun appelant depuis que `loginDriver` passe par `sessionProvider`
  // (Phase 6, tranche auth), et il ouvrait encore le suivi temps réel sur une
  // identité que le backend Django ne connaît pas.

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
      // Révoque le jeton de rafraîchissement côté serveur et efface le
      // stockage sécurisé (Phase 6) ; `_currentUser` repasse à `null` via le
      // pont d'écoute (`_onSessionChanged`), pas ici directement.
      await _container.read(eccore.sessionProvider.notifier).logout();
      _cartItems.clear();
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

  /// Recharge les courses du livreur depuis `/delivery/*` (Phase 6).
  ///
  /// Le nom est celui d'avant — quatre écrans l'appellent — mais ce qu'il
  /// charge a changé de nature : plus un vivier de commandes ouvertes, mais
  /// **mes** courses (proposées, en cours, et l'historique récent des livrées,
  /// dont vivent les écrans de gains et de statistiques).
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
      final courses = await _delivery.loadCourses().timeout(
        const Duration(seconds: 20),
      );

      // Remplacement plutôt que fusion : le serveur rend l'état complet des
      // courses qui me concernent. Une course absente de cette réponse ne
      // m'est plus proposée (un collègue l'a prise) ou est sortie de
      // l'historique récent — la garder à l'écran la ferait accepter dans le
      // vide.
      _coursesByOrderId
        ..clear()
        ..addEntries(courses.map((course) => MapEntry(course.orderId, course)));
      _syncOrdersFromCourses();

      // Le dossier porte l'éligibilité (L1) et les compteurs officiels : il ne
      // se déduit pas des courses, il se lit.
      try {
        _courierProfile = await _delivery.profile();
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(isOnline: _courierProfile!.isOnline);
        }
      } catch (e) {
        debugPrint('⚠️ Dossier livreur illisible : $e');
      }

      notifyListeners();
      debugPrint('✅ ${courses.length} courses chargées');
    } catch (e) {
      debugPrint('❌ Erreur de chargement des courses: $e');
      // Ne pas vider la liste en cas d'erreur, garder les données en cache
      rethrow;
    } finally {
      _isLoadingOrders = false;
    }
  }

  /// Reflète les courses dans `_orders`, que les écrans généralistes
  /// (`allOrders`, `activeOrders`) lisent encore.
  void _syncOrdersFromCourses() {
    _orders = [
      for (final course in _coursesByOrderId.values) course.order,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Enregistre une course rendue par le serveur après une action, et rafraîchit
  /// ce que les écrans affichent.
  void _rememberCourse(Course course) {
    _coursesByOrderId[course.orderId] = course;
    _syncOrdersFromCourses();
    notifyListeners();
  }

  /// La course désignée par une commande, ou une erreur explicite.
  ///
  /// Toutes les actions du livreur s'adressent à l'affectation ; ne pas la
  /// retrouver signifie que l'écran travaille sur une liste périmée, et
  /// inventer un identifiant serait pire que de le dire.
  Course _requireCourse(String orderId) {
    final course = _coursesByOrderId[orderId];
    if (course == null) {
      throw StateError(
        'Aucune course connue pour la commande $orderId — liste à recharger.',
      );
    }
    return course;
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

  /// Fait avancer la **course** correspondante.
  ///
  /// Le livreur n'écrit jamais le statut de la commande : celle-ci suit par
  /// projection déclarée côté serveur quand la course progresse. Aucune mise à
  /// jour optimiste non plus — la machine à états peut refuser la transition,
  /// et afficher une étape que le serveur n'a pas accordée est précisément ce
  /// qui rendait l'ancien écran incohérent après un refus.
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final course = _requireCourse(orderId);
    final target = _toDeliveryTarget(newStatus);

    if (target == eccore.DeliveryStatus.accepted) {
      await acceptDelivery(orderId);
      return;
    }

    _rememberCourse(await _delivery.advanceTo(course.assignmentId, target));
  }

  /// Statut affiché → étape de course demandée au serveur.
  static String _toDeliveryTarget(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return eccore.DeliveryStatus.accepted;
      case OrderStatus.pickedUp:
        return eccore.DeliveryStatus.pickedUp;
      case OrderStatus.onTheWay:
        return eccore.DeliveryStatus.onTheWay;
      case OrderStatus.delivered:
        return eccore.DeliveryStatus.delivered;
      case OrderStatus.cancelled:
        return eccore.DeliveryStatus.cancelled;
      case OrderStatus.pending:
      case OrderStatus.preparing:
      case OrderStatus.ready:
        // Ces trois-là décrivent la cuisine, pas la course : rien ne permet au
        // livreur de les provoquer, et le serveur les refuserait de toute
        // façon. Échouer ici plutôt que d'émettre une requête vouée au 409.
        throw ArgumentError(
          'Étape « ${status.displayName} » hors du ressort du livreur.',
        );
    }
  }

  // ------------------------------------------------------------- Livraison
  //
  // Le vivier de commandes à se disputer n'existe plus : le personnel propose
  // une course à un livreur nommé (`AssignmentService.offer`), et celui-ci ne
  // voit que ce qui lui est adressé. « Disponible » veut donc dire « proposée
  // à moi », et rien d'autre.

  /// Le dossier du livreur, tel que le serveur le rend. Nul tant que
  /// [loadAvailableOrders] n'a pas tourné.
  eccore.CourierProfile? get courierProfile => _courierProfile;

  /// L1 — l'éligibilité est décidée par le serveur : être « en ligne » ne
  /// suffit pas si le dossier n'est pas validé. Ne jamais la recomposer ici.
  bool get canAcceptOrders => _courierProfile?.canAcceptOrders ?? false;

  List<Course> get courses => _coursesByOrderId.values.toList();

  Course? courseForOrder(String orderId) => _coursesByOrderId[orderId];

  /// La course que le livreur est en train de faire — celle qu'il a acceptée et
  /// pas encore terminée. C'est elle, et elle seule, que les relevés de position
  /// concernent.
  ///
  /// Une course simplement *proposée* n'en est pas une : se faire suivre sur une
  /// course qu'on n'a pas prise n'aurait aucun sens. Le contrat n'en autorise
  /// qu'une active à la fois (`AssignmentService._active_for`), il n'y a donc
  /// pas à arbitrer entre plusieurs.
  Course? get activeCourse {
    for (final course in _coursesByOrderId.values) {
      final assignment = course.assignment;
      if (assignment.isActive &&
          assignment.status != eccore.DeliveryStatus.offered) {
        return course;
      }
    }
    return null;
  }

  /// Les courses qu'on me propose et auxquelles je n'ai pas encore répondu.
  List<Order> get pendingOffers => _ordersWhereCourse(
    (course) => course.assignment.status == eccore.DeliveryStatus.offered,
  );

  /// Mes courses : acceptées, en cours, et l'historique récent des livrées.
  List<Order> get assignedDeliveries => _ordersWhereCourse(
    (course) => course.assignment.status != eccore.DeliveryStatus.offered,
  );

  List<Order> _ordersWhereCourse(bool Function(Course) predicate) {
    if (_currentUser?.role != UserRole.delivery) return [];
    return [
      for (final course in _coursesByOrderId.values)
        if (predicate(course)) course.order,
    ]..sort((a, b) => b.orderTime.compareTo(a.orderTime));
  }

  /// Accepte la course proposée pour cette commande.
  ///
  /// L2 — l'acceptation est exclusive côté serveur : si un collègue a été plus
  /// rapide, l'appel échoue par une règle métier, pas par une incohérence. Rien
  /// n'est donc affiché comme acquis avant la réponse.
  Future<void> acceptDelivery(String orderId) async {
    final course = _requireCourse(orderId);
    _rememberCourse(await _delivery.accept(course.assignmentId));
    debugPrint('✅ Course acceptée pour la commande $orderId');
  }

  /// Refuse une course proposée. Distinct d'une annulation : décliner une
  /// proposition n'incrémente pas le compteur d'annulations du livreur.
  Future<void> declineDelivery(String orderId, {String reason = ''}) async {
    final course = _requireCourse(orderId);
    _rememberCourse(await _delivery.decline(course.assignmentId, reason: reason));
  }

  /// Marque la course comme récupérée au restaurant (`picked_up`).
  Future<void> markOrderPickedUp(String orderId) =>
      updateOrderStatus(orderId, OrderStatus.pickedUp);

  /// Marque la course comme partie chez le client (`on_the_way`).
  Future<void> markOrderOnTheWay(String orderId) =>
      updateOrderStatus(orderId, OrderStatus.onTheWay);

  /// Marque la course comme livrée (`delivered`).
  ///
  /// C'est le serveur, et lui seul, qui incrémente alors les compteurs et
  /// crédite la rémunération : la machine étant acyclique, rejouer cette étape
  /// est refusé au lieu d'être compté deux fois (C3).
  Future<void> markOrderDelivered(String orderId) =>
      updateOrderStatus(orderId, OrderStatus.delivered);

  // Driver authentication methods
  ///
  /// Authentifie contre le backend Django (Phase 6) — plus Supabase. `login`
  /// refuse déjà, en interne, un compte dont le `user_type` n'est pas
  /// `courier` (garde de rôle portée par `sessionProvider`, pas ici) ; un tel
  /// compte est déconnecté avant même que cette méthode ne reçoive une
  /// exception.
  Future<void> loginDriver(String email, String password) async {
    try {
      await _container.read(eccore.sessionProvider.notifier).login(
        email: email,
        password: password,
      );
      // `_currentUser` est déjà à jour ici (le pont d'écoute est synchrone
      // par rapport au changement d'état) ; les orchestrations Supabase qui
      // suivaient (statut en ligne, courses disponibles) sont différées au
      // domaine livraison (pas encore migré) plutôt qu'appelées avec un
      // identifiant Django qu'aucune ligne Supabase ne connaît.
      await _registerPushDeviceBestEffort();
      notifyListeners();
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

  /// Bascule de disponibilité (`/delivery/me/online/`).
  ///
  /// Le serveur rend le dossier à jour ; c'est [canAcceptOrders], pas
  /// `isOnline`, qui dit si des courses arriveront — un dossier en attente de
  /// validation reste inéligible même « en ligne » (L1). L'écran doit donc
  /// relire le dossier après cet appel plutôt que supposer.
  Future<void> updateOnlineStatus(bool isOnline) async {
    _courierProfile = await _delivery.setOnline(isOnline: isOnline);

    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(isOnline: _courierProfile!.isOnline);
    }
    notifyListeners();
  }

  /// Émet une position sur la course en cours (`/tracking/assignments/{id}/pings/`).
  ///
  /// Par HTTP, et non par le WebSocket : `ws/couriers/me/` est une file de
  /// propositions en lecture seule, rien n'y remonte. Un relevé perdu n'a de
  /// toute façon aucune valeur — c'est le suivant qui compte — d'où le fait de
  /// ne rien relancer ici en cas d'échec.
  Future<void> updateDeliveryLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
  }) async {
    final course = _coursesByOrderId[orderId];
    if (course == null || !course.assignment.isActive) {
      // Émettre sur une course terminée reviendrait à continuer de se faire
      // suivre après la livraison.
      return;
    }

    try {
      await _delivery.sendPing(
        assignmentId: course.assignmentId,
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracy,
        speedMetersPerSecond: speed,
        headingDegrees: heading,
      );
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
