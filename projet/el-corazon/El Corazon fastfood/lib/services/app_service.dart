import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:elcora_fast/services/error_handler_service.dart';
// import 'package:elcora_fast/services/wallet_service.dart'; // Portefeuille désactivé temporairement
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/offline_sync_service.dart';
import 'package:elcora_fast/services/menu_item_cache_service.dart';
import 'package:elcora_fast/services/notification_database_service.dart';
import 'package:elcora_fast/services/push_notification_service.dart';
import 'package:elcora_fast/repositories/django_order_repository.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/models/address.dart';

class AppService extends ChangeNotifier {
  static AppService? _instance;

  /// Le conteneur Riverpod est celui créé une fois dans `main()` — voir
  /// `UncontrolledProviderScope`. Seul `main.dart` le fournit réellement
  /// (`ChangeNotifierProvider(create: (_) => AppService(container))`) ; les
  /// nombreux autres appels `AppService()` sans argument, déjà présents
  /// ailleurs dans le code, n'ont
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

  User? _currentUser;

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
    // Une session en cours de restauration n'est pas une session fermée : agir
    // sur `next.value` pendant le chargement viderait le carnet d'adresses au
    // démarrage, avant même de savoir qui est connecté.
    if (next.isLoading) return;

    final djangoUser = next.value;
    _currentUser = djangoUser == null ? null : _fromDjangoUser(djangoUser);
    unawaited(_followSessionInAddressBook(djangoUser?.id));
    notifyListeners();
  }

  /// Identité dont le carnet d'adresses est actuellement ouvert.
  ///
  /// Le carnet vit côté serveur et n'était relié à rien : `initializeForUser`,
  /// seul point d'entrée qui le branche sur le compte, n'était appelé par
  /// personne. Le service restait donc en mode « invité » pour tout le monde,
  /// et les adresses n'atteignaient jamais `/profiles/addresses/` — celles que
  /// l'écran de commande transmettait ensuite portaient un identifiant que le
  /// serveur n'avait jamais émis. C'est ici, et seulement ici, que la session
  /// pilote le carnet.
  String? _addressBookUserId;

  Future<void> _followSessionInAddressBook(String? userId) async {
    if (_addressBookUserId == userId) return;
    _addressBookUserId = userId;

    try {
      if (userId == null) {
        await AddressService().clearSession();
      } else {
        await AddressService().initializeForUser(userId);
      }
    } catch (e) {
      // Le carnet est secondaire par rapport à l'identité : son échec ne doit
      // pas empêcher la connexion d'aboutir.
      eccore.Journal.trace('Carnet d\'adresses non synchronisé : $e');
    }
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

      // Pas de synchro temps réel globale : l'ancienne version s'abonnait aux
      // tables `menu_items` et `orders` de Supabase en entier. Le backend Django
      // n'expose volontairement pas de canal catalogue (§3.3 du plan de
      // migration) — le menu est relu par `DjangoMenuRepository` et les
      // commandes par `ws/orders/{id}/tracking/`, par commande suivie.

      if (kDebugMode) {
        eccore.Journal.trace(
          '⚡ AppService initialisé en ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      eccore.Journal.trace('❌ Erreur lors de l\'initialisation AppService: $e');
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
      eccore.Journal.trace('⚠️ Erreur lors du chargement de la session: $e');
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
      eccore.Journal.trace('Login error: $e');
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
      eccore.Journal.trace('⚠️ Échec de l\'enregistrement du jeton FCM: $e');
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
      // Le carnet d'adresses n'est pas fermé ici : il suit la session, via
      // `_followSessionInAddressBook`. Le fermer aussi depuis cet endroit
      // donnait deux chemins pour la même chose, dont un seul couvrait
      // l'expiration du jeton — l'autre cas où la session tombe.
      _gamificationService.reset();
      NotificationDatabaseService().clearSession();
      notifyListeners();
    } catch (e) {
      eccore.Journal.trace('Logout error: $e');
    }
  }

  Future<void> _unregisterPushDeviceBestEffort() async {
    final token = PushNotificationService().fcmToken;
    if (token == null || token.isEmpty) return;

    try {
      await _container.read(eccore.authRepositoryProvider).unregisterDevice(token);
    } catch (e) {
      eccore.Journal.trace('⚠️ Échec du retrait du jeton FCM: $e');
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

    // Le point n'est plus vérifié ici : une `Address` en porte toujours un, et
    // elle provient toujours du carnet serveur.
    if (deliveryAddress == null) {
      throw Exception(
        'Adresse de livraison manquante : choisissez-en une avant de commander.',
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

      // Aucun point de fidélité crédité ici : le serveur les attribue à la
      // **livraison** (`apps/loyalty/receivers.py`). L'ancienne version les
      // ajoutait à la commande et écrivait le solde depuis le client — un
      // solde que le client choisissait, et qui doublait le crédit serveur.

      // Mesure d'usage. Best-effort et sans `await` bloquant le parcours : une
      // commande réussie ne doit pas échouer parce que la télémétrie est
      // indisponible. L'auteur n'est plus déclaré par le client — le serveur
      // le déduit du jeton.
      unawaited(
        eccore.AnalyticsRepository(apiClient: _container.read(eccore.apiClientProvider))
            .record(
              eventType: 'order_placed',
              eventData: {
                'order_id': remoteOrder.id,
                'total_amount': remoteOrder.total,
                'item_count': cartItems.length,
              },
            )
            .catchError((Object e) => eccore.Journal.trace('Analytics indisponible: $e')),
      );

      // Déclencher les notifications et gamification (inchangé, simulé
      // côté client — domaines pas encore migrés).
      await _notificationService.showOrderConfirmationNotification(
        remoteOrder.id,
        cartItems.isNotEmpty
            ? cartItems.map((item) => (item as CartItem).name).join(', ')
            : 'Commande',
      );

      _gamificationService.onOrderPlaced(remoteOrder.total);

      // Aucun suivi n'est « démarré » ici : l'avancement d'une commande vient
      // du serveur, que l'écran de suivi écoute sur `ws/orders/{id}/tracking/`.
      // La ligne précédente lançait une minuterie locale qui déclarait la
      // commande livrée quarante secondes après l'avoir passée.

      notifyListeners();
      return remoteOrder.id;
    } catch (e) {
      eccore.Journal.trace('Error placing order from cart service: $e');
      return '';
    }
  }

  // Finalize an existing order (e.g. group order)
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
      eccore.Journal.trace('❌ Error loading menu items: $e');
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
      eccore.Journal.trace('❌ Error loading menu categories: $e');
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
      eccore.Journal.trace('Error loading user orders: $e');
      _orders = [];
    }
  }

  // Admin methods
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

}
