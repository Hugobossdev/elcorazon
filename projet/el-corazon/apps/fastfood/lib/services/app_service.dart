import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/messages_erreur.dart';
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
import 'package:elcora_fast/services/kitchen_context_service.dart';
import 'package:elcora_fast/repositories/django_order_repository.dart';
import 'package:elcora_fast/models/cart_item.dart';

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

    // La carte est **celle de la cuisine courante**. Elle change quand le
    // client en choisit une autre, mais aussi quand la géographie en désigne
    // une autre pour son adresse, ou quand celle qu'il parcourait est
    // suspendue. Seul le sélecteur rechargeait la carte : les deux autres
    // changements laissaient les plats de l'ancienne cuisine sous le nom de la
    // nouvelle.
    _finDuSuiviDeCuisine = KitchenContextService().ecouterLeChangement(
      (_, __) => unawaited(rechargerLeCatalogue()),
    );
  }

  late final VoidCallback _finDuSuiviDeCuisine;

  final ProviderContainer _container;
  late final ProviderSubscription<AsyncValue<eccore.User?>> _sessionSubscription;
  late final StreamSubscription<String> _tokenRefreshSubscription;

  eccore.User? _currentUser;

  bool _isInitialized = false;
  List<eccore.MenuItem> _menuItems = [];
  List<Order> _orders = [];
  List<String> _menuCategoryDisplayNames = [];
  List<eccore.Category> _menuCategories = [];

  // Service de cache intelligent pour les menu items et catégories
  final MenuItemCacheService _menuItemCache = MenuItemCacheService();

  // Services intégrés
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final GamificationService _gamificationService = GamificationService();
  final ErrorHandlerService _errorHandler = ErrorHandlerService();
  final OfflineSyncService _offlineSyncService = OfflineSyncService();

  // Getters
  eccore.User? get currentUser => _currentUser;
  List<eccore.MenuItem> get menuItems => _menuItems.isNotEmpty ? _menuItems : [];
  List<Order> get orders => _orders;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;

  /// La session n'a pas pu être **vérifiée** — elle n'est pas fermée.
  ///
  /// L'écran doit alors proposer de réessayer plutôt que de se connecter : les
  /// identifiants sont mémorisés, c'est le serveur qui manque.
  bool get sessionHorsLigne => _sessionHorsLigne;
  bool _sessionHorsLigne = false;

  /// Rejoue la restauration de session — le geste du bouton « Réessayer ».
  Future<void> reprendreLaSession() async {
    await _container.read(eccore.sessionProvider.notifier).restoreSession();
    if (_currentUser != null) await _loadUserOrders();
  }

  /// Pourquoi le catalogue est vide, quand il l'est parce que le chargement a
  /// échoué. `null` quand il a abouti — fût-ce sur une carte réellement vide.
  ///
  /// Les deux se confondaient : `_loadMenuItems` rattrapait toute panne en
  /// posant une liste vide, et l'écran du menu affichait alors « Aucun plat
  /// trouvé — aucun plat ne correspond à ces filtres » avec un bouton
  /// « Réinitialiser les filtres ». Une coupure réseau, un backend arrêté ou un
  /// 500 se lisaient donc comme une erreur de manipulation du client, et le
  /// seul recours proposé — retirer des filtres — n'y pouvait rien.
  ///
  /// C'est une [SituationCuisine] et non plus une phrase. La phrase unique
  /// — « la carte n'a pas pu être chargée, vérifiez votre connexion » —
  /// envoyait vérifier le Wi-Fi quelqu'un dont le quartier n'a pas de cuisine,
  /// ou dont le serveur rendait 500.
  SituationCuisine? get erreurCatalogue => _erreurCatalogue;
  SituationCuisine? _erreurCatalogue;

  /// La phrase du serveur qui accompagne [erreurCatalogue], quand il en a donné
  /// une qui s'adresse au client.
  String? get motifErreurCatalogue => _motifErreurCatalogue;
  String? _motifErreurCatalogue;

  /// La situation qui correspond à un échec du catalogue.
  ///
  /// `CuisineIndisponible` porte déjà la sienne — c'est le contexte de cuisine
  /// qui sait si l'annuaire a répondu vide ou n'a pas répondu. Tout autre échec
  /// est classé **par sa nature**, jamais présumé « aucune cuisine ».
  static ({SituationCuisine situation, String? motif}) situationDeLEchec(Object erreur) {
    if (erreur is CuisineIndisponible) {
      return (situation: erreur.situation, motif: null);
    }
    final nature = eccore.ApiFailure.of(erreur);
    return (
      situation: SituationCuisine.depuisEchec(nature),
      motif: nature == eccore.ApiFailure.rejected && erreur is eccore.ApiException
          ? erreur.detail
          : null,
    );
  }

  /// Pourquoi l'historique est vide, quand il l'est parce que le chargement a
  /// échoué. `null` quand il a abouti — fût-ce sur un historique réellement
  /// vide.
  ///
  /// Exactement le défaut que [erreurCatalogue] corrige, laissé en place sur
  /// les commandes : `_loadUserOrders` rattrapait **toute** panne en posant une
  /// liste vide, sans même prévenir ses auditeurs. L'écran affichait alors
  /// « Aucune commande passée — votre historique apparaîtra ici », ce qu'un
  /// client lit comme un fait sur son compte. Réseau coupé, session expirée,
  /// 500 : ses commandes lui étaient déclarées inexistantes.
  ///
  /// Le catalogue a un repli hors-ligne qui adoucit sa panne ; l'historique n'en
  /// a aucun, ce qui rend l'aveu plus nécessaire encore, pas moins.
  String? get erreurHistorique => _erreurHistorique;
  String? _erreurHistorique;
  List<String> get menuCategoryDisplayNames => _menuCategoryDisplayNames;
  List<eccore.Category> get menuCategories => _menuCategories;

  // Obtenir les catégories uniques des items du menu
  List<String> get categories {
    if (_menuItems.isEmpty) return [];
    return _menuItems
        .where((item) => item.categoryName.isNotEmpty)
        .map((item) => item.categoryName)
        .toSet()
        .toList();
  }

  // Services getters
  LocationService get locationService => _locationService;
  NotificationService get notificationService => _notificationService;
  GamificationService get gamificationService => _gamificationService;
  RealtimeTrackingService get trackingService => RealtimeTrackingService();
  ErrorHandlerService get errorHandler => _errorHandler;

  @override
  void dispose() {
    _finDuSuiviDeCuisine();
    _sessionSubscription.close();
    unawaited(_tokenRefreshSubscription.cancel());
    super.dispose();
  }

  /// Pont entre la session Riverpod (backend Django, source de vérité de
  /// l'identité — Phase 6) et le `_currentUser` que le reste de cette
  /// classe lit encore. C'est le seul endroit qui traduit l'un vers l'autre.
  void _onSessionChanged(AsyncValue<eccore.User?> next) {
    // Une session en cours de restauration n'est pas une session fermée : agir
    // sur `next.value` pendant le chargement viderait le carnet d'adresses au
    // démarrage, avant même de savoir qui est connecté.
    if (next.isLoading) return;

    // « Hors ligne » n'est pas « déconnecté » : les jetons sont là, c'est la
    // vérification qui n'a pas abouti. Sans cette distinction, l'application
    // repassait en visiteur au démarrage sur un simple manque de réseau.
    _sessionHorsLigne = next.hasError && next.error is eccore.SessionHorsLigne;

    final etaitConnecte = _currentUser != null;
    final djangoUser = next.value;
    _currentUser = djangoUser;
    unawaited(_followSessionInAddressBook(djangoUser?.id));
    unawaited(_followSessionInCart(djangoUser?.id));

    // Le push suit la **session**, pas un écran : c'est ici que la permission
    // est demandée, et c'est le seul endroit qui couvre les deux ouvertures —
    // la connexion et la restauration au démarrage. Un client qui rouvre
    // l'application sans se reconnecter (le cas courant) doit réenregistrer
    // son appareil : un jeton qui a tourné pendant que l'application était
    // fermée n'est annoncé à personne, la rotation ne prévenant que les
    // applications qui tournent. `/auth/devices/` est un upsert, prévu pour
    // être rappelé au lancement.
    if (djangoUser != null && !etaitConnecte) {
      unawaited(_activerLePushPourLeCompte(djangoUser.id));
      // L'historique suit la session, comme le panier et le carnet.
      //
      // Il n'était lu qu'au **démarrage** (`_ouvrir`), et seulement si une
      // session existait déjà. Quelqu'un qui ouvrait l'application en visiteur
      // puis se connectait lisait donc « Aucune commande passée » sur un compte
      // qui en avait, jusqu'à ce qu'il pense à tirer la liste vers le bas.
      unawaited(_loadUserOrders());
    } else if (djangoUser == null && etaitConnecte) {
      _oublierLeCompte();
    }

    notifyListeners();
  }

  /// Efface ce qui appartenait au compte qui vient de partir.
  ///
  /// ## Pourquoi ce n'est pas seulement du rangement
  ///
  /// `_orders` survivait à la déconnexion. Sur un téléphone partagé — le cas
  /// courant ici — le compte suivant voyait donc l'historique du précédent
  /// jusqu'au premier rechargement : le récapitulatif du profil en comptait les
  /// commandes, et les recommandations s'en nourrissaient.
  ///
  /// La cuisine courante part avec : son choix est mémorisé par compte dans la
  /// tête du client, pas dans celle de l'application. La documentation de
  /// `KitchenContextService.reset()` annonçait « à la déconnexion » — personne
  /// ne l'appelait.
  void _oublierLeCompte() {
    _orders = [];
    _erreurHistorique = null;
    _historiqueLu = false;
    KitchenContextService().reset();
  }

  /// Demande la permission puis enregistre l'appareil, dans cet ordre.
  ///
  /// Best-effort de bout en bout : un refus de permission, un appareil sans
  /// services Google ou un réseau coupé laissent l'application parfaitement
  /// utilisable. Le suivi temps réel et l'historique
  /// (`/api/v1/notifications/`) ne dépendent ni de FCM ni d'une permission.
  Future<void> _activerLePushPourLeCompte(String userId) async {
    await PushNotificationService().enableForUser(userId);
    await _registerPushDeviceBestEffort();
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

  /// Identité dont le panier est actuellement ouvert.
  ///
  /// Même oubli que pour le carnet d'adresses, et même conséquence un cran
  /// plus loin : `CartService.initializeForUser` n'était appelé de nulle part,
  /// donc `_userId` y restait nul, donc `_persistChanges` s'arrêtait au
  /// stockage local et `ensureSynced` rendait la main sans rien attendre —
  /// `/carts/` ne recevait jamais la moindre ligne. Or le devis lit le panier
  /// **serveur** (`POST /orders/preview/`, invariants C1/C2) : il chiffrait un
  /// panier vide, et le barème de zone refusait la commande au motif d'un
  /// minimum que zéro ne pouvait pas atteindre. L'écran, lui, affichait bien
  /// les articles, et le message accusait le montant du panier.
  String? _cartUserId;

  Future<void> _followSessionInCart(String? userId) async {
    if (_cartUserId == userId) return;
    _cartUserId = userId;

    try {
      if (userId == null) {
        await CartService().clearForLogout();
      } else {
        await CartService().initializeForUser(userId);
      }
    } catch (e) {
      // Le panier local reste affichable : un échec de synchronisation ne doit
      // pas empêcher la connexion d'aboutir. La commande, elle, ne partira pas
      // sur un panier serveur périmé — `ensureSynced` la précède.
      eccore.Journal.trace('Panier non synchronisé : $e');
    }
  }

  /// Les points de fidélité et les badges n'existent pas dans
  /// `UserSerializer` — domaine pas encore migré. Ils gardent leur valeur par
  /// défaut tant que la fidélité n'a pas son tour ; ce n'est pas un oubli.

  /// Verrou de ré-entrance de [initialize].
  ///
  /// Deux appelants la déclenchaient au démarrage, sans se connaître :
  /// `ServiceInitializationWidget` (posé dans `MaterialApp.builder`) et
  /// `SplashScreen` (première route). Le catalogue partait donc **deux fois**,
  /// et le journal montrait la seconde salve enchaîner sur la première comme
  /// si l'application se relançait. Ce n'était pas un rechargement : c'était le
  /// second appelant.
  ///
  /// Le doublon lui-même est supprimé — `ServiceInitializationWidget`
  /// n'initialise plus `AppService` — mais le verrou reste : il y a d'autres
  /// entrées (le tirer-pour-rafraîchir, une reprise de session) et rien ne
  /// garantit qu'elles ne se croiseront jamais. `??=` fait partager le même
  /// futur aux appels concurrents ; il est libéré à la fin, si bien qu'un
  /// rafraîchissement **ultérieur** rejoue bien un vrai chargement.
  Future<void>? _ouvertureEnCours;

  Future<void> initialize() {
    return _ouvertureEnCours ??= _ouvrir().whenComplete(() {
      _ouvertureEnCours = null;
    });
  }

  Future<void> _ouvrir() async {
    try {
      // Mesurer le temps d'initialisation pour le monitoring
      final stopwatch = Stopwatch()..start();

      // Les catégories et les articles ne se conditionnent plus l'un l'autre :
      // le contrat porte `category` et `category_name` sur l'article, et plus
      // rien ici ne recolle les deux. Les enchaîner coûtait la somme de leurs
      // deux latences — et, quand le serveur ne répondait pas, la somme de
      // leurs deux délais d'abandon : 15 s + 15 s, d'où les 32,5 s mesurées.
      await Future.wait([
        _loadMenuCategories(),
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

  /// Charge l'historique **si le pont de session ne l'a pas déjà fait**.
  ///
  /// Depuis que l'ouverture de session déclenche la lecture (`_onSessionChanged`),
  /// un démarrage avec session restaurée les lançait toutes les deux : deux
  /// parcours complets de `/orders/` à l'ouverture de l'application. La
  /// condition n'est donc plus « y a-t-il quelqu'un » mais « a-t-on déjà lu » —
  /// l'historique vaut `null` tant qu'aucune lecture n'a abouti ni échoué.
  Future<void> _loadUserSession() async {
    try {
      if (_currentUser != null && !_historiqueLu) {
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

  /// Une lecture de l'historique a-t-elle abouti — ou échoué — pour ce compte ?
  bool _historiqueLu = false;

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
        // `kIsWeb` **avant** `defaultTargetPlatform`, et non l'inverse : dans
        // un navigateur, `defaultTargetPlatform` rend le système **hôte** —
        // `TargetPlatform.android` pour Chrome sur Android, `iOS` pour Safari
        // sur iPhone. Un jeton FCM Web partait donc au serveur étiqueté
        // « android », et l'appareil était rangé sous une plateforme dont il
        // n'a ni le format de jeton ni le mode de livraison.
        platform: kIsWeb
            ? 'web'
            : switch (defaultTargetPlatform) {
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

  /// Met à jour le nom et le téléphone du compte connecté.
  ///
  /// ## Pourquoi cette méthode manquait
  ///
  /// La boîte « Modifier le profil » du profil fermait sur un message de
  /// succès — « Profil mis à jour avec succès ! » — **sans rien envoyer**.
  /// Le champ retrouvait son ancienne valeur à la réouverture, et personne ne
  /// pouvait savoir si le serveur avait refusé ou si l'app n'avait rien
  /// demandé. `AuthRepository.updateProfile` existait depuis le début.
  ///
  /// La session est relue ensuite plutôt que `_currentUser` corrigé sur place :
  /// l'identité vit dans `sessionProvider`, et deux écritures pour un même
  /// fait finissent toujours par diverger.
  Future<void> updateProfile({String? fullName, String? phone}) async {
    await _container.read(eccore.authRepositoryProvider).updateProfile(
          fullName: fullName,
          phone: phone,
        );
    await _container.read(eccore.sessionProvider.notifier).restoreSession();
  }

  Future<void> logout() async {
    try {
      // Avant la révocation : `/auth/devices/` exige la session qu'on est en
      // train de fermer. Sans cela, l'appareil resterait rattaché au compte et
      // continuerait de recevoir ses notifications.
      await _unregisterPushDeviceBestEffort();
      // Puis côté appareil : sans cela le jeton reste valide, et un téléphone
      // partagé continuerait de recevoir les notifications du compte précédent
      // si le détachement côté serveur avait échoué. `dely` le faisait déjà ;
      // l'app cliente ne le faisait pas.
      await PushNotificationService().deleteToken();
      await _container.read(eccore.sessionProvider.notifier).logout();
      // Ni le panier ni le carnet d'adresses ne sont fermés ici : ils suivent
      // la session, via `_followSessionInCart` et
      // `_followSessionInAddressBook`. Les fermer aussi depuis cet endroit
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

  /// Passe la commande, et **laisse remonter ce qui l'en empêche**.
  ///
  /// ## Ce que le silence coûtait
  ///
  /// Cette méthode rattrapait toute exception pour rendre la chaîne vide. Le
  /// seul appelant — `CheckoutScreen._placeOrder` — n'agit que si
  /// l'identifiant rendu n'est pas vide, et son propre `catch` ne voyait
  /// jamais rien puisque plus rien n'était lancé. Résultat : sur un article
  /// devenu indisponible, un minimum de commande non atteint, un 429 ou une
  /// coupure réseau, le client appuyait sur « Commander », le voyant tournait,
  /// s'arrêtait — et **rien ne se passait, sans un mot**. Le bouton paraissait
  /// mort à l'étape la plus coûteuse du parcours, celle où l'on abandonne.
  ///
  /// Le serveur, lui, disait précisément pourquoi : `problem+json` porte un
  /// `detail` lisible (`common/exceptions.py`). Il était jeté ici.
  /// [idempotencyKey] identifie **la tentative**, pas l'appel.
  ///
  /// Elle vient de l'écran de caisse et ne change qu'entre deux tentatives
  /// distinctes. Ce service ne la fabrique pas : il ne sait pas si l'appel
  /// qu'on lui demande est un premier envoi ou le réessai d'un envoi dont la
  /// réponse s'est perdue — l'écran, lui, le sait.
  Future<String> placeOrderFromCartService(
    eccore.Address? deliveryAddress,
    PaymentMethod paymentMethod,
    List<dynamic> cartItems,
    double subtotal,
    double deliveryFee,
    double discount, {
    required String idempotencyKey,
    String? notes,
  }) async {
    if (cartItems.isEmpty) {
      throw Exception('Votre panier est vide.');
    }
    if (_currentUser == null) {
      throw Exception('Connectez-vous pour passer commande.');
    }

    // Le point n'est plus vérifié ici : une `eccore.Address` en porte toujours un, et
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
        idempotencyKey: idempotencyKey,
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
      await _notificationService.showOrderReceivedNotification(
        remoteOrder.reference.isNotEmpty ? remoteOrder.reference : remoteOrder.id,
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
      // Tracé **et** relancé : la trace sert au diagnostic, le relancement
      // sert au client. L'avaler ne faisait ni l'un ni l'autre à l'écran.
      eccore.Journal.trace('Error placing order from cart service: $e');
      rethrow;
    }
  }

  // Finalize an existing order (e.g. group order)
  // Helper methods

  /// Relit le catalogue depuis le serveur, cache court-circuité.
  ///
  /// C'est ce que propose l'écran du menu quand le chargement a échoué : sans
  /// elle, un cache vide écrit par une tentative malheureuse restait en place
  /// jusqu'à son expiration, et réessayer ne rapportait rien.
  Future<void> rechargerLeCatalogue() async {
    await Future.wait([
      _loadMenuCategories(forcerLeReseau: true),
      _loadMenuItems(forcerLeReseau: true),
    ]);
  }

  Future<void> _loadMenuItems({bool forcerLeReseau = false}) async {
    try {
      // Utiliser le nouveau service de cache intelligent
      _menuItems =
          await _menuItemCache.getMenuItems(forceRefresh: forcerLeReseau);
      _erreurCatalogue = null;
      _motifErreurCatalogue = null;

      // Plus de recollement de catégorie : le contrat rend `category` et
      // `category_name` sur l'article lui-même. La boucle qui rattachait
      // l'objet retombait de surcroît sur `_menuCategories.first` quand elle
      // ne trouvait pas la bonne — un article se voyait rangé dans la
      // première catégorie venue.

      // Mettre en cache dans OfflineSyncService pour le mode hors ligne
      await _offlineSyncService.cacheMenuItems(_menuItems);

      notifyListeners();
    } catch (e) {
      final echec = situationDeLEchec(e);
      eccore.Journal.trace(
        '❌ Catalogue illisible (GET /catalog/items/) — ${echec.situation.code} : $e',
      );
      _errorHandler.logError('Erreur lors du chargement du menu', details: e);

      // Le repli hors ligne ne vaut que pour une **panne**. Servir la carte de la
      // veille à quelqu'un dont l'adresse n'est plus desservie, ou dont la
      // cuisine a été suspendue, lui ferait composer un panier qu'aucune cuisine
      // ne préparera.
      if (!echec.situation.estUnePanne) {
        _menuItems = [];
        _erreurCatalogue = echec.situation;
        _motifErreurCatalogue = echec.motif;
        notifyListeners();
        return;
      }

      // Le cache hors ligne était **écrit à chaque succès et relu par
      // personne** : `loadCachedMenuItems` n'avait aucun appelant dans toute
      // l'application. Une carte parfaitement conservée de la veille était
      // ainsi jetée au premier serveur muet, et l'écran affichait un catalogue
      // vide alors qu'il avait de quoi le remplir. C'est ici qu'elle sert.
      final replis = await _offlineSyncService.loadCachedMenuItems();
      if (replis != null && replis.isNotEmpty) {
        _menuItems = replis;
        _erreurCatalogue = null;
        _motifErreurCatalogue = null;
        eccore.Journal.trace(
          '📦 Carte servie depuis le cache local (${replis.length} articles) '
          '— le serveur n’a pas répondu.',
        );
        notifyListeners();
        return;
      }

      // Faute de cache, la liste est vidée comme avant — un catalogue à moitié
      // lu vaut moins que pas de catalogue — mais la raison est désormais
      // conservée, pour que l'écran dise « la carte n'a pas pu être chargée »
      // plutôt que « aucun plat ne correspond à vos filtres ».
      _menuItems = [];
      _erreurCatalogue = echec.situation;
      _motifErreurCatalogue = echec.motif;
      notifyListeners();
    }
  }

  Future<void> _loadMenuCategories({bool forcerLeReseau = false}) async {
    try {
      // Le cache des catégories vaut 10 minutes. Sans ce court-circuit, le
      // bouton « réessayer » de l'écran du menu et le tirer-pour-rafraîchir
      // relisaient ce cache — donc, après un échec, le vide qu'il venait d'y
      // écrire — au lieu d'interroger le serveur.
      _menuCategories =
          await _menuItemCache.getCategories(forceRefresh: forcerLeReseau);

      // Le catalogue public ne rend que les catégories actives — le filtre
      // `isActive` du modèle local portait sur un champ que le serveur
      // n'envoie pas, et qui valait donc toujours `true`.
      _menuCategoryDisplayNames = _menuCategories
          .map((c) => c.name)
          .where((nom) => nom.isNotEmpty)
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
      eccore.Journal.trace(
        '❌ Catégories illisibles (GET /catalog/categories/) — '
        '${situationDeLEchec(e).situation.code} : $e',
      );
      _errorHandler.logError(
        'Erreur lors du chargement des catégories',
        details: e,
      );

      // Même repli que pour les articles, et pour les mêmes raisons : le cache
      // était rempli sans jamais être relu — et il ne sert que pour une panne.
      final replis = situationDeLEchec(e).situation.estUnePanne
          ? await _offlineSyncService.loadCachedCategories()
          : null;
      if (replis != null && replis.isNotEmpty) {
        _menuCategories = replis;
        _menuCategoryDisplayNames = replis
            .map((c) => c.name)
            .where((nom) => nom.isNotEmpty)
            .toList();
        eccore.Journal.trace(
          '📦 Catégories servies depuis le cache local (${replis.length}) '
          '— le serveur n’a pas répondu.',
        );
        notifyListeners();
        return;
      }

      _menuCategories = [];
      _menuCategoryDisplayNames = [];
      notifyListeners();
    }
  }

  Future<void> _loadUserOrders() async {
    if (_currentUser == null) return;

    try {
      _orders = await DjangoOrderRepository().getUserOrders(_currentUser!.id);
      _erreurHistorique = null;
      _historiqueLu = true;
    } catch (e) {
      eccore.Journal.trace('Error loading user orders: $e');
      _orders = [];
      // Le motif du serveur quand il y en a un, une phrase sur la panne sinon.
      // Sans lui, l'écran ne peut que montrer un historique vide — c'est-à-dire
      // affirmer quelque chose de faux sur le compte du client.
      _erreurHistorique = messageErreur(e);
      // Lu, quoique sans succès : le démarrage n'a pas à relancer une seconde
      // lecture derrière celle du pont de session. C'est « Réessayer » qui la
      // relance, à la demande.
      _historiqueLu = true;
    }
    // Hors du `try` : la branche d'échec ne prévenait personne, si bien qu'un
    // écran déjà construit gardait indéfiniment l'état d'avant la panne.
    notifyListeners();
  }

  /// La référence lisible d'une commande connue — « EC000123 ».
  ///
  /// Les écrans affichaient l'identifiant technique, un UUID de trente-six
  /// caractères, dans les bandeaux et les notifications. C'est la référence que
  /// le serveur fabrique pour être lue, redite au téléphone et retrouvée dans
  /// le back-office. Repli sur l'identifiant tant que la commande n'est pas
  /// connue localement — mieux vaut un identifiant qu'un vide.
  String referenceDe(String orderId) {
    for (final commande in _orders) {
      if (commande.id == orderId) {
        return commande.reference.isNotEmpty ? commande.reference : commande.id;
      }
    }
    return orderId;
  }

  /// Relit l'historique — pour le bouton « Réessayer » de l'écran des commandes.
  Future<void> rechargerHistorique() => _loadUserOrders();

  /// Annule une commande, et **laisse remonter le refus**.
  ///
  /// `POST /orders/{id}/cancel/` existe depuis l'origine et aucun écran ne
  /// l'appelait : le centre d'aide promettait une annulation que l'application
  /// ne savait pas faire.
  ///
  /// Le refus du serveur — commande trop avancée — porte la phrase à afficher.
  /// La rattraper ici pour rendre un booléen la perdrait, et l'écran devrait
  /// alors deviner entre « trop tard », « pas votre commande » et « réseau
  /// coupé ». La commande rendue remplace celle qu'on tenait : son statut,
  /// son horodatage d'annulation et son motif viennent du serveur.
  Future<Order> annulerLaCommande(String orderId, {String reason = ''}) async {
    final annulee = await DjangoOrderRepository().cancelOrder(orderId, reason: reason);

    final index = _orders.indexWhere((commande) => commande.id == orderId);
    if (index != -1) {
      _orders[index] = annulee;
    } else {
      _orders.insert(0, annulee);
    }
    notifyListeners();
    return annulee;
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
