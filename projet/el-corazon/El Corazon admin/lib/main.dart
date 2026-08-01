import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/modern_theme.dart';
// Admin services uniquement
import 'services/admin_auth_service.dart';
import 'services/order_management_service.dart';
import 'services/driver_management_service.dart';
import 'services/analytics_service.dart';
import 'services/role_management_service.dart';
import 'services/category_management_service.dart';
import 'services/customization_management_service.dart';
import 'services/menu_service.dart';
import 'services/app_service.dart';
import 'services/promotion_service.dart';
import 'services/marketing_service.dart';
import 'services/payments_service.dart';
import 'services/client_management_service.dart';
import 'services/gamification_service.dart';
import 'services/driver_schedule_service.dart';
import 'services/driver_document_service.dart';
import 'services/socket_service.dart';
import 'screens/admin/admin_navigation_screen.dart';
import 'screens/auth/admin_auth_screen.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;

// Classe pour ignorer les erreurs de certificat SSL en développement
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('Env file loaded successfully');
  } catch (e) {
    debugPrint('Error loading env file: $e');
  }

  // Override global HTTP client pour accepter les certificats (fix handshake error)
  HttpOverrides.global = MyHttpOverrides();

  // Backend Django v2 (Phase 6). Le back-office n'a plus d'accès direct à une
  // base de données : tout passe par `/api/v1/`, et les permissions du
  // personnel sont appliquées par le serveur (ADR-005).
  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(
    baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api/v1',
    tokenStorage: tokenStorage,
  );
  final container = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(tokenStorage),
      apiClientProvider.overrideWithValue(apiClient),
      // Un compte client qui se connecterait ici est rejeté à l'ouverture de
      // session, pas par une condition d'écran.
      expectedUserTypeProvider.overrideWithValue(UserAccountType.staff),
    ],
  );

  final adminAuthService = AdminAuthService(container);
  await adminAuthService.initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: AdminApp(container: container),
    ),
  );
}

class AdminApp extends StatelessWidget {
  const AdminApp({required this.container, super.key});

  final ProviderContainer container;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services admin uniquement
        ChangeNotifierProvider(create: (_) => AdminAuthService(container)),
        ChangeNotifierProvider(create: (_) => OrderManagementService()),
        ChangeNotifierProvider(create: (_) => DriverManagementService()),
        ChangeNotifierProvider(create: (_) => AnalyticsService()),
        ChangeNotifierProvider(create: (_) => RoleManagementService()),
        ChangeNotifierProvider(create: (_) => CategoryManagementService()),
        ChangeNotifierProvider(create: (_) => CustomizationManagementService()),
        ChangeNotifierProvider(create: (_) => MenuService()),
        ChangeNotifierProvider(create: (_) => PromotionService()..initialize()),
        ChangeNotifierProvider(create: (_) => MarketingService()..initialize()),
        ChangeNotifierProvider(create: (_) => AppService()),
        ChangeNotifierProvider(create: (_) => PaymentsService()),
        ChangeNotifierProvider(
          create: (_) => ClientManagementService()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => GamificationService()..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => DriverScheduleService()),
        ChangeNotifierProvider(create: (_) => DriverScheduleService()),
        ChangeNotifierProvider(create: (_) => DriverDocumentService()),
        // Initialize SocketService immediately
        Provider<SocketService>(
          create: (_) => SocketService()..init(),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        title: 'El Corazón - Admin',
        theme: ModernTheme.lightTheme,
        darkTheme: ModernTheme.darkTheme,
        themeMode: ThemeMode.light,
        routes: {
          '/admin-dashboard': (context) => const AdminNavigationScreen(),
          '/admin-login': (context) => const AdminAuthScreen(),
        },
        home: Consumer<AdminAuthService>(
          builder: (context, adminAuthService, child) {
            // Afficher l'écran de connexion si l'utilisateur n'est pas authentifié
            if (!adminAuthService.isAuthenticated) {
              return const AdminAuthScreen();
            }
            return const AdminNavigationScreen();
          },
        ),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          // Gestion globale des erreurs de rendu
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
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
