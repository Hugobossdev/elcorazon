import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Alias explicite : `eccore.User` (backend Django) et le `User` local
// (Supabase, ci-dessous) portent le même nom mais pas la même forme — voir
// `_fromDjangoUser`, qui traduit le premier vers le second.
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_dely/models/user.dart';
import 'package:elcora_dely/models/order.dart';
import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcora_dely/services/location_service.dart';
import 'package:elcora_dely/services/notification_service.dart';
import 'package:elcora_dely/services/realtime_tracking_service.dart';

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

    // FCM renouvelle le jeton d'appareil de son propre chef : sans
    // ré-enregistrement, le livreur cesse de recevoir ses offres de course, en
    // silence. Ne fait rien tant que personne n'est connecté — l'appel
    // échouerait en 401, et le jeton sera enregistré à la connexion.
    _tokenRefreshSubscription =
        _notificationService.tokenRefreshStream.listen((_) {
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
  List<Order> _orders = [];

  // Services intégrés
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();

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
  List<Order> get orders => _orders;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;

  // Services getters
  LocationService get locationService => _locationService;
  NotificationService get notificationService => _notificationService;
  RealtimeTrackingService get trackingService => RealtimeTrackingService();
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isDeliveryStaff => _currentUser?.role == UserRole.delivery;
  bool get isClient => _currentUser?.role == UserRole.client;

  @override
  void dispose() {
    _sessionSubscription.close();
    unawaited(_courseOffersSubscription?.cancel());
    unawaited(_tokenRefreshSubscription.cancel());
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
      eccore.Journal.trace('📨 Course proposée : ${offer.reference} (${offer.restaurant})');
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
      eccore.Journal.trace('⚠️ Échec de l\'enregistrement du jeton FCM: $e');
    }
  }

  /// Détache le jeton du compte au moment de la déconnexion.
  ///
  /// Sans ce geste, le téléphone reste rattaché au livreur qui vient de partir
  /// et continue de recevoir ses offres de course — sur un appareil où plus
  /// personne n'est connecté, et souvent partagé entre deux tournées.
  Future<void> _unregisterPushDeviceBestEffort() async {
    final token = _notificationService.fcmToken;
    if (token == null || token.isEmpty) return;

    try {
      await _container.read(eccore.authRepositoryProvider).unregisterDevice(token);
    } catch (e) {
      eccore.Journal.trace('⚠️ Échec du retrait du jeton FCM: $e');
    }
  }

  Future<void> initialize() async {
    try {
      // Le livreur ne voit que ses courses. Le catalogue ne le concerne pas —
      // il transporte, il ne compose pas de commande — et la liste de *toutes*
      // les commandes, que l'implémentation Supabase chargeait quand personne
      // n'était connecté, n'était visible que parce que la base était ouverte.
      if (_currentUser?.role == UserRole.delivery) {
        await loadAvailableOrders();
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      eccore.Journal.trace('Error initializing AppService: $e');
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

  Future<void> logout() async {
    try {
      // Avant la révocation : `/auth/devices/` exige la session qu'on est en
      // train de fermer.
      await _unregisterPushDeviceBestEffort();
      // Révoque le jeton de rafraîchissement côté serveur et efface le
      // stockage sécurisé (Phase 6) ; `_currentUser` repasse à `null` via le
      // pont d'écoute (`_onSessionChanged`), pas ici directement.
      await _container.read(eccore.sessionProvider.notifier).logout();
      notifyListeners();
    } catch (e) {
      eccore.Journal.trace('Logout error: $e');
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
      eccore.Journal.trace('⚠️ loadAvailableOrders already in progress, skipping...');
      return;
    }

    // Cache: Ne pas recharger si chargé il y a moins de 10 secondes (sauf si forceRefresh)
    if (!forceRefresh &&
        _lastOrdersLoadTime != null &&
        DateTime.now().difference(_lastOrdersLoadTime!) <
            const Duration(seconds: 10)) {
      eccore.Journal.trace(
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
        eccore.Journal.trace('⚠️ Dossier livreur illisible : $e');
      }

      notifyListeners();
      eccore.Journal.trace('✅ ${courses.length} courses chargées');
    } catch (e) {
      eccore.Journal.trace('❌ Erreur de chargement des courses: $e');
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
    eccore.Journal.trace('✅ Course acceptée pour la commande $orderId');
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

  /// Met à jour son propre nom et son téléphone (`PATCH /auth/me/`).
  Future<void> updateOwnProfile({required String fullName, required String phone}) async {
    try {
      final updated = await _container
          .read(eccore.authRepositoryProvider)
          .updateProfile(fullName: fullName, phone: phone);
      _currentUser = _fromDjangoUser(updated);
      notifyListeners();
    } on eccore.ApiException catch (e) {
      throw Exception(e.detail);
    }
  }

  /// Demande le retrait de ses gains — `POST /payments/withdrawals/`.
  ///
  /// L'app ne verse plus rien. Elle appelait auparavant l'API de décaissement
  /// PayDunya depuis le téléphone, avec un montant qu'elle calculait
  /// elle-même, puis écrivait la ligne « payé » en base : le bénéficiaire
  /// décidait de ce qu'il touchait. Le serveur débite désormais les gains sous
  /// verrou et enregistre une intention de versement, que l'exploitation
  /// exécute — la demande naît donc « en attente ».
  ///
  /// Les montants sont en unité mineure (ADR-007) ; en francs CFA, l'unité
  /// mineure est le franc.
  Future<void> requestWithdrawal(double amount) async {
    final payments = eccore.PaymentRepository(
      apiClient: _container.read(eccore.apiClientProvider),
    );

    try {
      await payments.requestWithdrawal(
        eccore.Money(amountMinor: amount.round(), currency: 'XOF'),
      );
      // Le solde affiché vient du dossier livreur (`total_earnings`), que le
      // serveur vient de débiter : le relire évite d'afficher un montant que le
      // backend ne confirmerait pas.
      try {
        _courierProfile = await _delivery.profile();
        notifyListeners();
      } catch (e) {
        eccore.Journal.trace('Dossier livreur illisible après retrait : $e');
      }
    } on eccore.ApiException catch (e) {
      throw Exception(e.detail);
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
      eccore.Journal.trace('❌ Erreur mise à jour position: $e');
      // Ne pas throw pour éviter de bloquer le suivi GPS
    }
  }

  /// Téléphone du destinataire d'une course — pour l'appeler ou lui écrire.
  ///
  /// Lu sur la **course**, seul endroit où le contrat le porte
  /// (`recipient_phone` de l'affectation). L'ancienne version lisait la fiche de l'utilisateur
  /// par son identifiant : le backend v2 n'a pas d'endpoint pour ça, et c'est
  /// délibéré — un livreur n'a pas à consulter le profil d'un compte, seulement
  /// à joindre la personne qu'il livre, pendant qu'il la livre.
  String? recipientPhoneFor(String orderId) {
    final phone = _coursesByOrderId[orderId]?.assignment.recipientPhone;
    return (phone == null || phone.isEmpty) ? null : phone;
  }
}
