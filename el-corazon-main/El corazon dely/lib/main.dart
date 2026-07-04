import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:elcora_dely/l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme.dart';
import 'services/app_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/gamification_service.dart';
import 'services/promotion_service.dart';
import 'services/social_service.dart';
import 'services/voice_service.dart';
import 'services/ar_service.dart';
import 'services/ai_service.dart';
import 'services/customization_service.dart';
import 'services/marketing_service.dart';
import 'services/group_delivery_service.dart';
import 'services/realtime_tracking_service.dart';
import 'services/paydunya_service.dart';
import 'services/address_service.dart';
import 'services/promo_code_service.dart';
import 'services/advanced_gamification_service.dart';
import 'services/ai_recommendation_service.dart';
import 'services/cart_service.dart';
import 'services/offline_sync_service.dart';
import 'services/social_features_service.dart';
import 'services/supabase_realtime_service.dart';
import 'services/voice_command_service.dart';
import 'services/wallet_service.dart';
import 'services/error_handler_service.dart';
import 'services/performance_service.dart';
import 'services/chat_service.dart';
import 'services/agora_call_service.dart';
import 'screens/splash_screen.dart';
import 'package:elcora_dely/screens/auth/driver_auth_screen.dart';
import 'screens/delivery/delivery_navigation_screen.dart';
import 'screens/delivery/real_time_tracking_screen.dart';
import 'screens/communication/chat_screen.dart';
import 'screens/payments/earnings_screen.dart';
import 'supabase/supabase_config.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");
    debugPrint('✅ Environment variables loaded');

    // Initialize core services only
    await _initializeCoreServices();

    debugPrint('✅ Core services initialized successfully');
  } catch (e, stackTrace) {
    final errorMessage = e.toString();
    debugPrint('❌ Error initializing services: $errorMessage');
    debugPrint('Stack trace: $stackTrace');
    // Continue with app launch even if some services fail
    // The app can work in offline mode or with cached data
  }

  runApp(const DeliverApp());
}

/// Initialize only essential services at startup
Future<void> _initializeCoreServices() async {
  try {
    // Initialize performance monitoring
    await PerformanceService().initialize();
  } catch (e) {
    debugPrint('⚠️ Failed to initialize PerformanceService: ${e.toString()}');
  }

  try {
    // Initialize error handling
    await ErrorHandlerService().initialize();
  } catch (e) {
    debugPrint('⚠️ Failed to initialize ErrorHandlerService: ${e.toString()}');
  }

  try {
    // Initialize Supabase (essential)
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('⚠️ Failed to initialize Supabase: ${e.toString()}');
    // Continue without Supabase - app can work in offline mode
  }

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize Firebase: ${e.toString()}');
  }

  // Initialize other services lazily when needed
  // This improves startup performance
}

class DeliverApp extends StatelessWidget {
  const DeliverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services
        ChangeNotifierProvider(create: (_) => AppService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => GamificationService()),
        ChangeNotifierProvider(create: (_) => PromotionService()),
        ChangeNotifierProvider(create: (_) => SocialService()),
        ChangeNotifierProvider(create: (_) => VoiceService()),
        ChangeNotifierProvider(create: (_) => ARService()),
        ChangeNotifierProvider(create: (_) => AIService()),
        ChangeNotifierProvider(create: (_) => CustomizationService()),
        ChangeNotifierProvider(create: (_) => MarketingService()),
        ChangeNotifierProvider(create: (_) => GroupDeliveryService()),
        ChangeNotifierProvider(create: (_) => RealtimeTrackingService()),
        ChangeNotifierProvider(create: (_) => PayDunyaService()),
        ChangeNotifierProvider(create: (_) => AddressService()),
        ChangeNotifierProvider(create: (_) => PromoCodeService()),

        // Advanced services (only ChangeNotifier services)
        ChangeNotifierProvider(create: (_) => AIRecommendationService()),
        ChangeNotifierProvider(create: (_) => AdvancedGamificationService()),
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider(create: (_) => OfflineSyncService()),
        ChangeNotifierProvider(create: (_) => SocialFeaturesService()),
        ChangeNotifierProvider(create: (_) => SupabaseRealtimeService()),
        ChangeNotifierProvider(create: (_) => VoiceCommandService()),
        ChangeNotifierProvider(create: (_) => WalletService()),
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
        home: const SplashScreen(),
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
                builder: (context) => ChatScreen(
                  order: args['order'],
                  chatType: args['chatType'] ?? 'customer',
                ),
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
