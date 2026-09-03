import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/firebase_options.dart';
// `Provider`/`Consumer` existent dans les deux packages : ceux de
// `package:provider` sont ceux réellement utilisés dans ce fichier
// (`ChangeNotifierProvider`, `Consumer<ThemeService>`) — seuls
// `ProviderContainer`/`UncontrolledProviderScope` viennent de Riverpod ici.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/services/notification_service.dart';
import 'package:elcora_fast/services/notification_database_service.dart';
import 'package:elcora_fast/services/gamification_service.dart';
import 'package:elcora_fast/services/group_cart_service.dart';
import 'package:elcora_fast/services/voice_service.dart';
import 'package:elcora_fast/services/customization_service.dart';
import 'package:elcora_fast/services/realtime_tracking_service.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/ai_recommendation_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/offline_sync_service.dart';
import 'package:elcora_fast/services/push_notification_service.dart';
import 'package:elcora_fast/services/subscription_service.dart';
import 'package:elcora_fast/services/error_handler_service.dart';
import 'package:elcora_fast/services/performance_service.dart';
import 'package:elcora_fast/services/form_validation_service.dart';
import 'package:elcora_fast/services/favorites_service.dart';
import 'package:elcora_fast/services/review_rating_service.dart';
import 'package:elcora_fast/services/support_service.dart';
import 'package:elcora_fast/services/delivery_fee_service.dart';
import 'package:elcora_fast/services/theme_service.dart';
import 'package:elcora_fast/widgets/error_boundary.dart';
import 'package:elcora_fast/widgets/service_initialization_widget.dart';
import 'package:elcora_fast/widgets/incoming_call_handler.dart';
import 'package:elcora_fast/widgets/push_notification_router.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/services/social_service.dart';

/// Backend Django v2 (Phase 6). L'app n'a plus aucun accès direct à une base de
/// données : tout passe par `/api/v1/` et les WebSockets `ws/`.
late final ProviderContainer _providerContainer;

/// Résolu quand `sessionProvider.restoreSession()` a fini de décider si un
/// jeton valide était stocké — `SplashScreen` l'attend avant d'appeler
/// `AppService.initialize()`. Global plutôt que passé en paramètre de
/// constructeur : `AppRouter.generateRoute` construit `SplashScreen` depuis
/// une fonction statique (`onGenerateRoute`), qui ne peut pas recevoir de
/// dépendance autrement — cohérent avec les autres singletons du projet
/// (`AppService()`).
late final Future<void> sessionReadyFuture;

/// Accès à l'`ApiClient` construit dans `main()`, pour les composants hors du
/// graphe Riverpod (`DjangoMenuRepository`, lu depuis `MenuItemCacheService`)
/// — même convention que `sessionReadyFuture` ci-dessus.
ApiClient get apiClient => _providerContainer.read(apiClientProvider);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables from .env file
    await dotenv.load();
    Journal.trace('✅ Environment variables loaded');

    // Initialize only essential services at startup for better performance
    await _initializeEssentialServices();

    Journal.trace('✅ Essential services initialized successfully');
  } catch (e) {
    Journal.trace('❌ Error initializing essential services: $e');
    // Continue with app launch even if some services fail
  }

  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(
    baseUrl: adresseDeLApi(dotenv.env['API_BASE_URL']),
    tokenStorage: tokenStorage,
  );
  _providerContainer = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(tokenStorage),
      apiClientProvider.overrideWithValue(apiClient),
      expectedUserTypeProvider.overrideWithValue(UserAccountType.customer),
    ],
  );
  sessionReadyFuture = _providerContainer.read(sessionProvider.notifier).restoreSession();

  runApp(
    UncontrolledProviderScope(
      container: _providerContainer,
      child: ClientApp(container: _providerContainer),
    ),
  );
}

/// Initialize only essential services at startup for optimal performance
/// Adresse de l'API, telle que `.env` la déclare.
///
/// ## Pourquoi ce contrôle existe
///
/// `API_BASE_URL` a été écrit un jour `localhost:8000/api/v1`, sans `http://`.
/// Le navigateur lit alors `localhost:` comme un **nom de protocole** et
/// refuse la requête avec « Cross origin requests are only supported for
/// protocol schemes… » — un message qui accuse le CORS alors que la requête
/// n'a jamais quitté l'onglet. Le serveur, lui, répondait parfaitement.
///
/// Sur mobile, la même omission passe encore plus mal : l'erreur est un
/// `SocketException` sur un hôte introuvable.
///
/// ## Le préfixe manquant
///
/// Le même fichier a ensuite porté `localhost:8000` tout court. Le schéma,
/// lui, était rattrapé ci-dessous — mais pas le `/api/v1`, et l'API n'est
/// montée que sous ce préfixe (`config/urls.py`). Le client demandait alors
/// `/catalog/items/` à un serveur qui ne sert que `/api/v1/catalog/items/` :
/// **404 sur absolument tout**, catalogue compris, sur un backend parfaitement
/// sain. Une panne totale, et un symptôme qui ressemble à une base vide.
///
/// Les deux oublis sont de la même famille — une adresse de base incomplète
/// — et se rattrapent donc au même endroit. Un chemin **déjà déclaré** est
/// laissé intact : `/api/v2` un jour, ou un préfixe de proxy, sont des choix,
/// pas des oublis.
///
/// L'oubli est donc rattrapé ici, et **tracé** : un réglage corrigé en silence
/// est un réglage qui reste faux dans le fichier.
@visibleForTesting
String adresseDeLApi(String? valeurDeclaree) {
  const prefixe = '/api/v1';
  const repli = 'http://10.0.2.2:8000$prefixe';
  final declaree = valeurDeclaree?.trim();

  if (declaree == null || declaree.isEmpty) return repli;

  var retenue = declaree;

  final uri = Uri.tryParse(declaree);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    retenue = 'http://$declaree';
    Journal.trace(
      "⚠️ API_BASE_URL ne porte pas de schéma : '$declaree'. "
      "Utilisation de '$retenue'. Corrigez .env, puis **relancez** — "
      'le fichier est embarqué comme asset au moment de la compilation, '
      'un rechargement à chaud ne le renouvelle pas.',
    );
  }

  // La barre finale est retirée avant tout examen : `http://h:8000/` déclare
  // un chemin `/`, c'est-à-dire aucun, et la garder produirait `//api/v1`.
  // Les chemins des dépôts commencent tous par `/` (`packages/elcorazon_core`),
  // l'adresse de base ne doit donc jamais finir par une.
  while (retenue.endsWith('/')) {
    retenue = retenue.substring(0, retenue.length - 1);
  }

  final chemin = Uri.tryParse(retenue)?.path ?? '';
  if (chemin.isEmpty) {
    final rattrapee = '$retenue$prefixe';
    Journal.trace(
      "⚠️ API_BASE_URL ne porte pas le préfixe '$prefixe' : '$declaree'. "
      "Utilisation de '$rattrapee'. Sans lui, l'API répond 404 à **toutes** "
      "les routes — elle n'est montée que sous ce préfixe. Corrigez .env, "
      'puis **relancez**.',
    );
    return rattrapee;
  }

  return retenue;
}

/// Adresse d'un canal WebSocket, dérivée de celle de l'API.
///
/// ## Pourquoi cette fonction existe
///
/// Les quatre services temps réel — conversation, suivi, appels, panier de
/// groupe — dérivaient chacun leur adresse en relisant `API_BASE_URL` **brut**,
/// sans passer par [adresseDeLApi]. Le rattrapage du schéma manquant ne les
/// atteignait donc pas, et l'omission que [adresseDeLApi] existe précisément
/// pour absorber les cassait en silence :
///
///     Uri.parse('localhost:8000/api/v1')
///       → scheme: 'localhost', host: '', port: 0
///       → 'ws:///ws/me/'   ← aucun hôte
///
/// Le REST continuait de fonctionner, réparé par [adresseDeLApi] ; seul le
/// temps réel tombait. Une panne partielle est plus coûteuse à diagnostiquer
/// qu'une panne franche : l'application s'ouvre, le menu s'affiche, et seuls
/// le chat et le suivi restent muets — on cherche alors du côté des
/// consumers Django, qui n'y sont pour rien.
///
/// Le `path` n'emporte pas `/api/v1` : Channels monte `ws/` à la racine
/// (`config/routing.py`), pas sous le préfixe de l'API.
///
/// Publique, contrairement à [adresseDeLApi] : les services temps réel
/// l'appellent. C'est le but — une seule dérivation, au lieu de quatre copies
/// qui divergent.
String adresseWebSocket(String? valeurDeclaree, String chemin) {
  final api = Uri.parse(adresseDeLApi(valeurDeclaree));
  return Uri(
    scheme: api.scheme == 'https' ? 'wss' : 'ws',
    host: api.host,
    port: api.port,
    path: chemin,
  ).toString();
}

Future<void> _initializeEssentialServices() async {
  // Firebase (Phase 6) — requis avant tout usage de `FirebaseMessaging`.
  // Non bloquant : aucun projet Firebase réel n'est encore configuré (voir
  // `lib/firebase_options.dart`), et l'app doit démarrer sans push.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    Journal.trace('✅ Firebase initialisé');
  } catch (e) {
    Journal.trace('⚠️ Firebase indisponible, notifications push désactivées: $e');
  }

  // Initialize performance monitoring first
  await PerformanceService().initialize();

  // Initialize error handling
  await ErrorHandlerService().initialize();

  await FormValidationService().initialize();

  // Notifications push — **cet appel manquait**, et son absence rendait toute
  // la chaîne inerte : pas de gestionnaire d'arrière-plan, pas de canal
  // Android, aucune des trois écoutes de réception, donc aucun jeton et aucun
  // appareil enregistré côté serveur. Le serveur poussait vers une liste vide.
  //
  // `prepare()` et non `initialize()` : la permission n'est pas demandée ici.
  // Elle l'est à l'ouverture de session (`AppService._onSessionChanged`), quand
  // « suivre ma commande » veut dire quelque chose — sur Android 13+, une
  // demande faite devant l'écran d'accueil se solde par un refus, et un refus
  // y est définitif.
  await PushNotificationService().prepare();

  // `_initializeDatabaseAsync()` a été retiré, avec `database/init_database.dart`.
  // L'application n'a plus de base locale à préparer depuis le retrait de
  // Supabase, et le code ne le faisait plus depuis longtemps : il posait un
  // drapeau dans `SharedPreferences` après un `Future.delayed(1 s)` commenté
  // « Simulate work ». Au premier lancement, c'était une seconde d'attente pour
  // ne rien faire ; aux suivants, une lecture de drapeau pour ne rien faire.

  // Other services will be initialized lazily when needed
  // This significantly improves app startup time
}

class ClientApp extends StatelessWidget {
  const ClientApp({required this.container, super.key});

  final ProviderContainer container;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services essentiels uniquement - chargés immédiatement
        //
        // `ConnectivityService` a été retiré : il n'était lu par aucun écran, et
        // `OfflineSyncService` — qui a bien des lecteurs — s'abonne directement
        // à `connectivity_plus`. C'était une seconde implémentation du même
        // guet, initialisée à chaque démarrage pour personne.
        ChangeNotifierProvider(create: (_) => AppService(container)),
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => NotificationDatabaseService()),

        // Services optionnels - chargés à la demande (lazy) pour optimiser les performances
        // Ces services ne seront créés que lorsqu'ils sont accédés pour la première fois
        ChangeNotifierProvider(
          create: (_) => GamificationService(),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => GroupCartService(), lazy: true),
        ChangeNotifierProvider(create: (_) => SocialService(), lazy: true),
        ChangeNotifierProvider(create: (_) => VoiceService(), lazy: true),
        ChangeNotifierProvider(
          create: (_) => CustomizationService(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => RealtimeTrackingService(),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => AddressService(), lazy: true),
        ChangeNotifierProvider(
          create: (_) => AIRecommendationService(),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => OfflineSyncService(), lazy: true),
        ChangeNotifierProvider(
          create: (_) => PushNotificationService(),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => SubscriptionService(), lazy: true),
        // Services système - toujours disponibles mais lazy
        ChangeNotifierProvider(
          create: (_) => ErrorHandlerService(),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => PerformanceService(), lazy: true),
        ChangeNotifierProvider(
          create: (_) => FormValidationService(),
          lazy: true,
        ),
        // Services avec initialisation immédiate nécessaire
        ChangeNotifierProvider(
          create: (_) => FavoritesService()..initialize(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => ReviewRatingService(),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => SupportService(), lazy: true),
        // Aucune initialisation : le service n'a plus d'état à préparer, il
        // interroge le serveur à la demande.
        ChangeNotifierProvider(create: (_) => DeliveryFeeService(), lazy: true),
        ChangeNotifierProvider(create: (_) => ThemeService(), lazy: true),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'El corazon',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeService.themeMode,
            initialRoute: AppRouter.splash,
            onGenerateRoute: AppRouter.generateRoute,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              return ErrorBoundary(
                child: IncomingCallHandler(
                  // Sous le `Navigator` de `MaterialApp` : ce guet en a besoin
                  // pour ouvrir l'écran que désigne une notification touchée.
                  child: PushNotificationRouter(
                    child: ServiceInitializationWidget(child: child!),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
