import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'services/app_service.dart';
import 'services/promotion_service.dart';
import 'services/social_service.dart';
import 'services/ai_service.dart';
import 'services/customization_service.dart';
import 'services/marketing_service.dart';
import 'services/group_delivery_service.dart';
import 'services/realtime_tracking_service.dart';
// Admin services
import 'services/admin_auth_service.dart';
import 'services/order_management_service.dart';
import 'services/driver_management_service.dart';
import 'services/analytics_service.dart';
import 'services/paydunya_service.dart';
import 'services/client_management_service.dart';
import 'services/audit_log_service.dart';
import 'services/gamification_service.dart';
import 'screens/admin/admin_navigation_screen.dart';
import 'supabase/supabase_config.dart';

// Web-compatible service stubs
class WebCompatibleLocationService extends ChangeNotifier {
  // Stub implementation for web
  Future<bool> requestLocationPermission() async => false;
  Future<dynamic> getCurrentLocation() async => null;
}

class WebCompatibleNotificationService extends ChangeNotifier {
  // Stub implementation for web
  Future<void> initialize() async {}
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (kDebugMode) {
      print('Web Notification: $title - $body');
    }
  }
}

class WebCompatibleGamificationService extends ChangeNotifier {
  // Stub implementation for web
}

class WebCompatibleVoiceService extends ChangeNotifier {
  // Stub implementation for web
}

class WebCompatibleARService extends ChangeNotifier {
  // Stub implementation for web
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Charger les variables d'environnement depuis le fichier .env
  try {
    await dotenv.load(fileName: '.env');
    if (kDebugMode) {
      print('✅ Fichier .env chargé pour le web');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Erreur de chargement du fichier .env pour le web: $e');
    }
  }

  // Initialiser Supabase avant de créer les services
  try {
    await SupabaseConfig.initialize();
    if (kDebugMode) {
      print('✅ Supabase initialisé pour le web');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Erreur d\'initialisation de Supabase pour le web: $e');
    }
  }

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services
        ChangeNotifierProvider(create: (_) => AppService()),
        ChangeNotifierProvider(create: (_) => WebCompatibleLocationService()),
        ChangeNotifierProvider(
          create: (_) => WebCompatibleNotificationService(),
        ),
        ChangeNotifierProvider(
          create: (_) => WebCompatibleGamificationService(),
        ),
        ChangeNotifierProvider(create: (_) => PromotionService()),
        ChangeNotifierProvider(create: (_) => SocialService()),
        ChangeNotifierProvider(create: (_) => WebCompatibleVoiceService()),
        ChangeNotifierProvider(create: (_) => WebCompatibleARService()),
        ChangeNotifierProvider(create: (_) => AIService()),
        ChangeNotifierProvider(create: (_) => CustomizationService()),
        ChangeNotifierProvider(create: (_) => MarketingService()),
        ChangeNotifierProvider(create: (_) => GroupDeliveryService()),
        ChangeNotifierProvider(create: (_) => RealtimeTrackingService()),
        // Admin services
        ChangeNotifierProvider(create: (_) => AdminAuthService()),
        ChangeNotifierProvider(create: (_) => OrderManagementService()),
        ChangeNotifierProvider(create: (_) => DriverManagementService()),
        ChangeNotifierProvider(create: (_) => AnalyticsService()),
        ChangeNotifierProvider(create: (_) => PayDunyaService()),
        ChangeNotifierProvider(
          create: (_) => ClientManagementService()..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => AuditLogService()..initialize()),
        ChangeNotifierProvider(
          create: (_) => GamificationService()..initialize(),
        ),
      ],
      child: MaterialApp(
        title: 'El Corazón - Admin (Web)',
        theme: lightTheme,
        home: const AdminNavigationScreen(),
        debugShowCheckedModeBanner: false,
        // Améliorer la gestion de l'accessibilité pour réduire les erreurs
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              // Éviter les problèmes d'accessibilité avec les text scalers
              textScaler: MediaQuery.of(
                context,
              ).textScaler.clamp(minScaleFactor: 0.8, maxScaleFactor: 1.2),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
