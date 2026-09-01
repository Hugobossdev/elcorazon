import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:elcora_dely/l10n/app_localizations.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:elcora_dely/theme.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/services/location_service.dart';
import 'package:elcora_dely/services/notification_service.dart';
import 'package:elcora_dely/services/realtime_tracking_service.dart';
import 'package:elcora_dely/services/error_handler_service.dart';
import 'package:elcora_dely/services/performance_service.dart';
import 'package:elcora_dely/services/chat_service.dart';
import 'package:elcora_dely/services/agora_call_service.dart';
import 'package:elcora_dely/screens/splash_screen.dart';
import 'package:elcora_dely/screens/auth/driver_auth_screen.dart';
import 'package:elcora_dely/screens/delivery/delivery_navigation_screen.dart';
import 'package:elcora_dely/screens/delivery/real_time_tracking_screen.dart';
import 'package:elcora_dely/screens/communication/chat_screen.dart';
import 'package:elcora_dely/screens/payments/earnings_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:elcora_dely/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    await dotenv.load();
    Journal.trace('✅ Environment variables loaded');

    // Initialize core services only
    await _initializeCoreServices();

    Journal.trace('✅ Core services initialized successfully');
  } catch (e, stackTrace) {
    final errorMessage = e.toString();
    Journal.trace('❌ Error initializing services: $errorMessage');
    Journal.trace('Stack trace: $stackTrace');
    // Continue with app launch even if some services fail
    // The app can work in offline mode or with cached data
  }

  // Backend Django v2 (Phase 6). L'app n'a plus aucun accès direct à une base
  // de données : tout passe par `/api/v1/` et les WebSockets `ws/`.
  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(
    baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1',
    tokenStorage: tokenStorage,
  );
  final container = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(tokenStorage),
      apiClientProvider.overrideWithValue(apiClient),
      expectedUserTypeProvider.overrideWithValue(UserAccountType.courier),
    ],
  );
  // Lancée sans bloquer ce `runApp` : `SplashScreen` attend elle-même ce
  // futur (voir `sessionReady`) avant de décider où naviguer, pendant que
  // l'animation d'accueil tourne déjà.
  final sessionReady = container.read(sessionProvider.notifier).restoreSession();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: DeliverApp(container: container, sessionReady: sessionReady),
    ),
  );
}

/// Initialize only essential services at startup
Future<void> _initializeCoreServices() async {
  try {
    // Initialize performance monitoring
    await PerformanceService().initialize();
  } catch (e) {
    Journal.trace('⚠️ Failed to initialize PerformanceService: ${e.toString()}');
  }

  try {
    // Initialize error handling
    await ErrorHandlerService().initialize();
  } catch (e) {
    Journal.trace('⚠️ Failed to initialize ErrorHandlerService: ${e.toString()}');
  }

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    Journal.trace('✅ Firebase initialized successfully');
  } catch (e) {
    Journal.trace('⚠️ Failed to initialize Firebase: ${e.toString()}');
  }

  try {
    // Après Firebase, et jamais avant : `FirebaseMessaging.instance` exige
    // l'application initialisée.
    //
    // Cet appel manquait. `NotificationService.initialize()` n'avait aucun
    // appelant dans tout `lib/` : aucune permission n'était demandée, aucun
    // jeton FCM obtenu, et `AppService` n'enregistrait donc jamais l'appareil
    // auprès de `/auth/devices/`. Le serveur poussait ses offres de course
    // vers une liste d'appareils vide, et une course proposée n'atteignait le
    // livreur que si l'application était au premier plan au bon moment.
    await NotificationService().initialize();
  } catch (e) {
    Journal.trace('⚠️ Failed to initialize NotificationService: ${e.toString()}');
  }
}

class DeliverApp extends StatelessWidget {
  const DeliverApp({required this.container, required this.sessionReady, super.key});

  final ProviderContainer container;
  final Future<void> sessionReady;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // Onze services de plus étaient construits ici à chaque démarrage —
      // réalité augmentée, panier, portefeuille, recommandation, commande
      // groupée, synchronisation hors ligne, voix — sans qu'aucun écran ne les
      // lise : `main.dart` en était le seul importateur. Une application de
      // livreur n'a ni panier ni portefeuille ; ces services venaient d'un
      // copier-coller de l'application cliente. Ils sont supprimés, et le
      // démarrage ne les instancie plus.
      providers: [
        ChangeNotifierProvider(create: (_) => AppService(container)),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => RealtimeTrackingService()),
        ChangeNotifierProvider(create: (_) => ErrorHandlerService()),
        ChangeNotifierProvider(create: (_) => PerformanceService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => AgoraCallService()),
      ],
      child: MaterialApp(
        title: 'El Corazon Dely',
        theme: lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr'), Locale('en')],
        home: SplashScreen(sessionReady: sessionReady),
        debugShowCheckedModeBanner: false,
        routes: {
          '/delivery-home': (context) => const DeliveryNavigationScreen(),
          '/earnings': (context) => const EarningsScreen(),
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/tracking':
              final order = settings.arguments as dynamic;
              return MaterialPageRoute(
                builder: (context) => RealTimeTrackingScreen(order: order),
              );
            case '/chat':
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (context) => ChatScreen(order: args['order']),
              );
            default:
              return MaterialPageRoute(
                builder: (context) => const DriverAuthScreen(),
              );
          }
        },
      ),
    );
  }
}
