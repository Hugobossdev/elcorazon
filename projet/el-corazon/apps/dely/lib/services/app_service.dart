import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_dely/presentation/etat_compte.dart';
import 'package:elcora_dely/presentation/libelles_course.dart';
import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcora_dely/services/call_service.dart';
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

    // Une notification poussée annonce, elle ne fait pas foi : sa charge utile
    // ne porte que des identifiants (ADR-008). Elle déclenche donc une
    // relecture, seule à rendre l'étape, les transitions permises et les
    // montants. C'est ce qui fait qu'une course proposée pendant que
    // l'application dormait apparaît vraiment à l'écran quand le livreur
    // l'ouvre — et pas seulement dans le volet de notifications.
    _notificationOpenedSubscription =
        _notificationService.openedNotifications.listen((_) {
      if (_currentUser != null) {
        unawaited(loadAvailableOrders(forceRefresh: true));
      }
    });
  }

  final ProviderContainer _container;
  late final ProviderSubscription<AsyncValue<eccore.User?>> _sessionSubscription;
  late final StreamSubscription<String> _tokenRefreshSubscription;
  late final StreamSubscription<Map<String, dynamic>>
      _notificationOpenedSubscription;

  eccore.User? _currentUser;
  bool _isInitialized = false;
  List<Course> _courses = [];

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
  eccore.User? get currentUser => _currentUser;
  List<Course> get orders => _courses;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;

  // Services getters
  LocationService get locationService => _locationService;
  NotificationService get notificationService => _notificationService;
  RealtimeTrackingService get trackingService => RealtimeTrackingService();

  /// Signalisation des appels. Construit sur le même conteneur Riverpod que le
  /// reste — il est unique par application, et `CallService` en tient une seule
  /// instance.
  CallService get callService => CallService(_container);

  @override
  void dispose() {
    _sessionSubscription.close();
    unawaited(_courseOffersSubscription?.cancel());
    unawaited(_tokenRefreshSubscription.cancel());
    unawaited(_notificationOpenedSubscription.cancel());
    super.dispose();
  }

  /// Recopie la session Riverpod (source de vérité de l'identité) dans le
  /// champ que le reste de cette classe lit. Ce pont ne traduit plus rien
  /// depuis le lot 3 : c'est la même entité de part et d'autre.
  void _onSessionChanged(AsyncValue<eccore.User?> next) {
    final wasConnected = _currentUser != null;
    _currentUser = next.value;

    // La file des courses et l'émission de position suivent la session, pas un
    // écran : un livreur connecté reste joignable et reste suivi même quand il
    // n'a aucune carte ouverte.
    if (_currentUser != null && !wasConnected) {
      // Ouvre la file des courses — **pas** le GPS. Le suivi de position est
      // adossé à la course, pas à la session : voir [_accorderLeSuiviALaCourse].
      unawaited(trackingService.startCourierSession());
      // La file personnelle (`ws/me/`) s'ouvre ici et pas dans un widget : un
      // appel entrant doit joindre le livreur où qu'il soit dans
      // l'application, et une file accrochée au montage d'un écran se
      // refermerait au premier changement d'onglet.
      unawaited(callService.demarrer(userId: _currentUser!.id));
      // La permission de notification se demande **ici**, et pas au démarrage :
      // un livreur qui vient de se connecter pour travailler comprend sans
      // explication pourquoi on veut le joindre. Devant l'écran de connexion,
      // il refuse — et sur Android 13+ ce refus est définitif.
      unawaited(_notificationService.enableForUser());
      // À **chaque** ouverture de session, connexion comme restauration au
      // démarrage. L'enregistrement n'était fait qu'après `loginDriver` : un
      // livreur qui rouvrait l'application sans se reconnecter — le cas
      // courant — ne réenregistrait rien, et un jeton qui avait tourné
      // pendant que l'application était fermée n'était jamais rattrapé, la
      // rotation n'étant annoncée qu'aux applications qui tournent.
      // `/auth/devices/` est un upsert, prévu pour être rappelé au lancement.
      unawaited(_registerPushDeviceBestEffort());
    } else if (_currentUser == null && wasConnected) {
      _coursesByOrderId.clear();
      _courierProfile = null;
      unawaited(trackingService.stopCourierSession());
      // Referme la file **et raccroche** : un canal RTC laissé ouvert après une
      // déconnexion garderait le micro allumé sur un compte qui n'est plus là.
      unawaited(callService.arreter());
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
      readCourse: (orderId) async {
        final known = _coursesByOrderId[orderId];
        if (known == null) return null;

        final refreshed = await _delivery.loadCourse(known.assignmentId);
        _rememberCourse(refreshed);
        return refreshed;
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
      if (_currentUser != null) {
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
      // Puis côté appareil : sans cela le jeton reste valide, et le téléphone
      // resterait joignable pour le compte qui vient de partir si le
      // détachement serveur avait échoué. Un appareil de flotte passe de main
      // en main entre deux tournées.
      await _notificationService.deleteToken();
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
      // Le remplacement peut faire **disparaître** la course active — un
      // collègue l'a reprise, le siège l'a réaffectée. Sans cette relecture, le
      // GPS continuerait de tourner pour une course qui n'est plus la sienne.
      _accorderLeSuiviALaCourse();

      // Le dossier porte l'éligibilité (L1) et les compteurs officiels : il ne
      // se déduit pas des courses, il se lit.
      try {
        _courierProfile = await _delivery.profile();
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

  /// Liste ordonnée des courses connues, de la plus récente à la plus ancienne.
  void _syncOrdersFromCourses() {
    _courses = _coursesByOrderId.values.toList()
      ..sort((a, b) => b.assignment.createdAt.compareTo(a.assignment.createdAt));
  }

  /// Enregistre une course rendue par le serveur après une action, et rafraîchit
  /// ce que les écrans affichent.
  void _rememberCourse(Course course) {
    _coursesByOrderId[course.orderId] = course;
    _syncOrdersFromCourses();
    _accorderLeSuiviALaCourse();
    notifyListeners();
  }

  /// Allume le suivi GPS quand une course est en cours, l'éteint sinon.
  ///
  /// Appelée à chaque évolution de la liste des courses — acceptation,
  /// enlèvement, mise en route, livraison, annulation, réaffectation, et le
  /// rechargement complet qui suit une reconnexion. C'est le seul endroit qui
  /// décide, et il n'a qu'une règle : [activeCourse].
  ///
  /// Sans elle, le GPS tournait de la connexion à la déconnexion. Un livreur
  /// qui ouvre son application le matin et attend sa première course consommait
  /// alors autant de batterie qu'en pleine tournée, pour des relevés que le
  /// serveur n'a nulle part où écrire : un relevé appartient à une course
  /// (L3), et sans course active `updateDeliveryLocation` rendait la main sans
  /// rien envoyer.
  ///
  /// Le service est idempotent : la rappeler sans changement ne rouvre rien.
  void _accorderLeSuiviALaCourse() {
    unawaited(
      trackingService.suivreLaCourse(enCours: activeCourse != null),
    );
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
  Future<void> updateOrderStatus(String orderId, EtapeCourse etape) async {
    final course = _requireCourse(orderId);
    final target = etape.versServeur;

    if (target == eccore.DeliveryStatus.accepted) {
      await acceptDelivery(orderId);
      return;
    }

    _rememberCourse(await _delivery.advanceTo(course.assignmentId, target));
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

  /// Statut « en ligne » du livreur. Il vit dans le dossier livreur et nulle
  /// part ailleurs : il était auparavant recopié dans le `User` local à chaque
  /// lecture du dossier, une duplication qu'un troisième chemin d'écriture
  /// aurait laissée se désynchroniser en silence.
  bool get isOnline => _courierProfile?.isOnline ?? false;

  /// L1 — l'éligibilité est décidée par le serveur : être « en ligne » ne
  /// suffit pas si le dossier n'est pas validé. Ne jamais la recomposer ici.
  bool get canAcceptOrders => _courierProfile?.canAcceptOrders ?? false;

  /// Où en est le compte — compte actif, adresse vérifiée, dossier instruit.
  ///
  /// Nul tant que personne n'est connecté. La lecture des trois sources vit
  /// dans [EtatCompte], et nulle part ailleurs : chaque écran qui la
  /// recomposerait en oublierait un terme.
  EtatCompte? get etatCompte {
    final compte = _currentUser;
    return compte == null ? null : EtatCompte.depuis(compte, _courierProfile);
  }

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
  List<Course> get pendingOffers => _ordersWhereCourse(
    (course) => course.estProposee,
  );

  /// Mes courses : acceptées, en cours, et l'historique récent des livrées.
  List<Course> get assignedDeliveries => _ordersWhereCourse(
    (course) => course.estMienne,
  );

  List<Course> _ordersWhereCourse(bool Function(Course) predicate) {
    if (_currentUser == null) return [];
    return [
      for (final course in _coursesByOrderId.values)
        if (predicate(course)) course,
    ]..sort((a, b) => b.passeeLe.compareTo(a.passeeLe));
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
      updateOrderStatus(orderId, EtapeCourse.recuperee);

  /// Marque la course comme partie chez le client (`on_the_way`).
  Future<void> markOrderOnTheWay(String orderId) =>
      updateOrderStatus(orderId, EtapeCourse.enRoute);

  /// Marque la course comme livrée (`delivered`).
  ///
  /// C'est le serveur, et lui seul, qui incrémente alors les compteurs et
  /// crédite la rémunération : la machine étant acyclique, rejouer cette étape
  /// est refusé au lieu d'être compté deux fois (C3).
  Future<void> markOrderDelivered(String orderId) =>
      updateOrderStatus(orderId, EtapeCourse.livree);

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
      // L'enregistrement de l'appareil n'est plus fait ici : il suit
      // désormais l'ouverture de session (`_onSessionChanged`), qui couvre
      // aussi la restauration au démarrage. Le faire aux deux endroits
      // enverrait deux fois la même requête à chaque connexion.
      notifyListeners();
    } catch (_) {
      // Ré-émise telle quelle : l'écran la met en mots (`messageErreur`), et
      // c'est le `detail` du serveur qui doit arriver au livreur. L'emballage
      // qui était fait ici produisait « Exception: Erreur de connexion:
      // ApiException(401, invalid_credentials, …) » — trois couches devant
      // l'unique phrase utile.
      rethrow;
    }
  }

  // ------------------------------------------------- création de compte
  //
  // Le parcours complet tient en trois appels, dans cet ordre, et l'ordre
  // n'est pas une convention d'écran : il est imposé par le serveur.
  //
  //   deposerCandidature()  → compte + dossier en attente, **aucun jeton**
  //   verifierCompte()      → la session, contre le code reçu
  //   (instruction du dossier par El Corazón)  → les courses
  //
  // Un livreur ne passe **jamais** par `sessionProvider.register()` : cette
  // route ne crée que des comptes clients, imposé serveur.

  /// Les établissements auxquels un candidat peut se rattacher.
  ///
  /// Route publique — appelée avant même qu'un compte existe. La liste ne
  /// contient que les établissements ouverts, qui sont exactement ceux que le
  /// serveur acceptera dans la candidature.
  Future<List<eccore.RestaurantOption>> etablissementsOuverts() {
    return eccore.RestaurantDirectoryRepository(
      apiClient: _container.read(eccore.apiClientProvider),
    ).list();
  }

  /// Dépose une candidature de livreur (`POST /delivery/apply/`).
  ///
  /// Ne connecte personne, et c'est voulu : l'accusé rendu porte de quoi
  /// animer l'écran du code — où il est parti, jusqu'à quand il vaut, à partir
  /// de quand un renvoi est accepté — mais aucun jeton.
  Future<eccore.CourierApplicationReceipt> deposerCandidature(
    eccore.CourierApplication candidature,
  ) {
    return _delivery.apply(candidature);
  }

  /// Présente le code reçu et ouvre la session (`POST /auth/verify/`).
  ///
  /// Passe par `sessionProvider` et non par le dépôt directement : c'est là que
  /// vit la garde de rôle, et un compte client qui saisirait son code ici doit
  /// être refusé aussi sûrement qu'à la connexion.
  Future<void> verifierCompte({required String email, required String code}) async {
    await _container.read(eccore.sessionProvider.notifier).verifyAccount(
      email: email,
      code: code,
    );
    notifyListeners();
  }

  /// Redemande un code de vérification.
  ///
  /// Le serveur répond 202 même pour une adresse inconnue : ne jamais en
  /// déduire qu'un compte existe. Le délai rendu (`retryAfter`) est celui du
  /// serveur — c'est lui que le compte à rebours doit suivre.
  Future<eccore.VerificationChallenge> renvoyerCodeDeVerification(String email) {
    return _container.read(eccore.authRepositoryProvider).resendVerificationCode(email);
  }

  /// Demande un code de réinitialisation de mot de passe.
  Future<eccore.VerificationChallenge> demanderReinitialisation(String email) {
    return _container.read(eccore.authRepositoryProvider).requestPasswordReset(email);
  }

  /// Repose le mot de passe avec le code reçu, et ouvre la session.
  ///
  /// Toutes les sessions ouvertes ailleurs viennent d'être révoquées côté
  /// serveur ; celle-ci est la seule qui vaille.
  Future<void> reinitialiserMotDePasse({
    required String email,
    required String code,
    required String nouveauMotDePasse,
  }) async {
    await _container.read(eccore.sessionProvider.notifier).resetPassword(
      email: email,
      code: code,
      newPassword: nouveauMotDePasse,
    );
    notifyListeners();
  }

  /// Relit le dossier livreur seul (`GET /delivery/me/`).
  ///
  /// Sert aux écrans qui attendent une décision d'El Corazón : un dossier passé
  /// de « en attente » à « validé » pendant que l'application tourne ne
  /// s'annonce par aucun événement, et recharger toutes les courses pour lire
  /// un seul champ serait disproportionné.
  Future<void> rechargerDossier() async {
    _courierProfile = await _delivery.profile();
    notifyListeners();
  }

  /// Relit le compte lui-même (`GET /auth/me/`), sans toucher aux jetons.
  Future<void> rechargerCompte() async {
    await _container.read(eccore.sessionProvider.notifier).reload();
    notifyListeners();
  }

  /// Met à jour son propre nom et son téléphone (`PATCH /auth/me/`).
  ///
  /// Aucun `catch` : l'`ApiException` remonte telle quelle. Elle était
  /// réemballée dans une `Exception` nue portant son seul `detail`, ce qui en
  /// perdait le type — donc le statut et le code — et empêchait l'écran de
  /// distinguer une panne réseau d'un refus métier.
  Future<void> updateOwnProfile({required String fullName, required String phone}) async {
    _currentUser = await _container
        .read(eccore.authRepositoryProvider)
        .updateProfile(fullName: fullName, phone: phone);
    notifyListeners();
  }

  /// Solde réellement disponible au retrait, tel que le serveur le tient.
  ///
  /// C'est `total_earnings` du dossier livreur, débité sous verrou à chaque
  /// demande de retrait (`WithdrawalService.request`). Il ne se recalcule pas
  /// à partir des courses : l'historique rendu à l'application est **borné**
  /// (trois pages de livraisons récentes), et en additionner les
  /// rémunérations donne toujours moins que le solde — ou davantage, si des
  /// retraits ont déjà été demandés.
  eccore.Money? get soldeDisponible => _courierProfile?.totalEarnings;

  /// Les demandes de retrait déjà faites — `GET /payments/withdrawals/`.
  ///
  /// Un retrait naît « en attente » : c'est l'exploitation qui exécute le
  /// versement. Sans cette liste, le livreur demandait et n'avait plus aucun
  /// moyen de savoir ce qu'il était advenu de sa demande.
  Future<List<eccore.Withdrawal>> loadWithdrawals() {
    return eccore.PaymentRepository(
      apiClient: _container.read(eccore.apiClientProvider),
    ).getWithdrawals();
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
  /// [amount] est en **unité mineure** — le franc, en XOF (ADR-007).
  ///
  /// La devise n'est plus supposée : elle est celle des gains du dossier, que
  /// le serveur exige identique (`WithdrawalService.request` refuse un retrait
  /// dans une autre devise). `'XOF'` était écrit en dur ici.
  Future<void> requestWithdrawal(int amount) async {
    final payments = eccore.PaymentRepository(
      apiClient: _container.read(eccore.apiClientProvider),
    );
    final devise = _courierProfile?.totalEarnings?.currency ?? 'XOF';

    // L'`ApiException` d'un solde insuffisant remonte telle quelle : son
    // `detail` — « Le montant demandé dépasse les gains disponibles. » — est
    // ce que l'écran doit afficher.
    await payments.requestWithdrawal(
      eccore.Money(amountMinor: amount, currency: devise),
    );

    // Le solde affiché vient du dossier livreur (`total_earnings`), que le
    // serveur vient de débiter : le relire évite d'afficher un montant que le
    // backend ne confirmerait pas. Best-effort — le retrait, lui, est acquis.
    try {
      _courierProfile = await _delivery.profile();
      notifyListeners();
    } catch (e) {
      eccore.Journal.trace('Dossier livreur illisible après retrait : $e');
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
