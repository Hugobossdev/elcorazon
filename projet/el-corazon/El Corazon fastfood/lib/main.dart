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
import 'package:elcora_fast/services/paydunya_service.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/promo_code_service.dart';
import 'package:elcora_fast/services/ai_recommendation_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/offline_sync_service.dart';
import 'package:elcora_fast/services/connectivity_service.dart';
import 'package:elcora_fast/services/push_notification_service.dart';
import 'package:elcora_fast/services/subscription_service.dart';
import 'package:elcora_fast/services/error_handler_service.dart';
import 'package:elcora_fast/services/performance_service.dart';
import 'package:elcora_fast/services/form_validation_service.dart';
import 'package:elcora_fast/services/form_manager_service.dart';
import 'package:elcora_fast/services/favorites_service.dart';
import 'package:elcora_fast/services/review_rating_service.dart';
import 'package:elcora_fast/services/support_service.dart';
import 'package:elcora_fast/services/complaints_returns_service.dart';
import 'package:elcora_fast/services/alert_service.dart';
import 'package:elcora_fast/services/delivery_fee_service.dart';
import 'package:elcora_fast/services/theme_service.dart';
import 'package:elcora_fast/database/init_database.dart';
import 'package:elcora_fast/widgets/error_boundary.dart';
import 'package:elcora_fast/widgets/service_initialization_widget.dart';
import 'package:elcora_fast/widgets/incoming_call_handler.dart';
import 'package:elcora_fast/navigation/app_router.dart';

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
    debugPrint('✅ Environment variables loaded');

    // Initialize only essential services at startup for better performance
    await _initializeEssentialServices();

    debugPrint('✅ Essential services initialized successfully');
  } catch (e) {
    debugPrint('❌ Error initializing essential services: $e');
    // Continue with app launch even if some services fail
  }

  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(
    baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1',
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
Future<void> _initializeEssentialServices() async {
  // Firebase (Phase 6) — requis avant tout usage de `FirebaseMessaging`.
  // Non bloquant : aucun projet Firebase réel n'est encore configuré (voir
  // `lib/firebase_options.dart`), et l'app doit démarrer sans push.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✅ Firebase initialisé');
  } catch (e) {
    debugPrint('⚠️ Firebase indisponible, notifications push désactivées: $e');
  }

  // Initialize performance monitoring first
  await PerformanceService().initialize();

  // Initialize error handling
  await ErrorHandlerService().initialize();

  await FormValidationService().initialize();
  await FormManagerService().initialize();

  // Initialize database with real data (async to not block UI)
  _initializeDatabaseAsync();

  // Other services will be initialized lazily when needed
  // This significantly improves app startup time
}

/// Initialize database asynchronously without blocking the UI
void _initializeDatabaseAsync() async {
  try {
    final isInitialized = await DatabaseInitializer.isDatabaseInitialized();
    if (!isInitialized) {
      debugPrint('🗄️ Initialisation de la base de données...');
      await DatabaseInitializer.initializeDatabase();
    } else {
      debugPrint('✅ Base de données déjà initialisée');
    }
  } catch (e) {
    debugPrint('⚠️ Erreur lors de l\'initialisation de la base de données: $e');
    // Continue without failing the app
  }
}

class ClientApp extends StatelessWidget {
  const ClientApp({required this.container, super.key});

  final ProviderContainer container;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services essentiels uniquement - chargés immédiatement
        ChangeNotifierProvider(
          create: (_) => ConnectivityService()..initialize(),
        ),
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
        ChangeNotifierProvider(create: (_) => VoiceService(), lazy: true),
        ChangeNotifierProvider(
          create: (_) => CustomizationService(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => RealtimeTrackingService(),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => PayDunyaService(), lazy: true),
        ChangeNotifierProvider(create: (_) => AddressService(), lazy: true),
        ChangeNotifierProvider(create: (_) => PromoCodeService(), lazy: true),
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
        ChangeNotifierProvider(create: (_) => FormManagerService(), lazy: true),
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
        ChangeNotifierProvider(
          create: (_) => ComplaintsReturnsService(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => AlertService()..initialize(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => DeliveryFeeService()..initialize(),
          lazy: true,
        ),
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
                  child: ServiceInitializationWidget(child: child!),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
