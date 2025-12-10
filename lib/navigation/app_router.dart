import 'package:flutter/material.dart';
import 'package:elcora_fast/models/user.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/services/paydunya_service.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/screens/splash_screen.dart';
import 'package:elcora_fast/screens/auth_screen.dart';
import 'package:elcora_fast/screens/home_screen.dart';
import 'package:elcora_fast/screens/client/main_navigation_screen.dart';
import 'package:elcora_fast/screens/client/cart_screen.dart';
import 'package:elcora_fast/screens/client/checkout_screen.dart';
import 'package:elcora_fast/screens/client/delivery_tracking_screen.dart';
import 'package:elcora_fast/screens/client/wallet_screen.dart';
import 'package:elcora_fast/screens/client/rewards_screen.dart';
import 'package:elcora_fast/screens/client/cake_order_screen.dart';
import 'package:elcora_fast/screens/client/notifications_screen.dart';
import 'package:elcora_fast/screens/client/address_management_screen.dart';
import 'package:elcora_fast/screens/client/address_selector_screen.dart';
import 'package:elcora_fast/screens/client/menu_screen.dart';
import 'package:elcora_fast/screens/client/group_order_screen.dart';
import 'package:elcora_fast/screens/client/enhanced_item_customization_screen.dart';
import 'package:elcora_fast/screens/client/order_details_screen.dart';
import 'package:elcora_fast/screens/client/payment_screen.dart';
import 'package:elcora_fast/screens/client/promo_codes_screen.dart';
import 'package:elcora_fast/screens/client/shared_payment_screen.dart';
import 'package:elcora_fast/screens/client/product_reviews_screen.dart';
import 'package:elcora_fast/screens/client/support_screen.dart';
import 'package:elcora_fast/screens/client/advanced_search_screen.dart';
import 'package:elcora_fast/screens/client/enhanced_orders_screen.dart';
import 'package:elcora_fast/screens/otp_verification_screen.dart';
import 'package:elcora_fast/models/promo_code.dart';
import 'package:elcora_fast/screens/client/driver_rating_screen.dart';

/// Routeur principal de l'application
class AppRouter {
  static const String splash = '/';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String clientHome = '/client/home';
  static const String menu = '/client/menu';
  static const String orders = '/client/orders';
  static const String profile = '/client/profile';
  static const String cart = '/client/cart';
  static const String checkout = '/client/checkout';
  static const String deliveryTracking = '/client/delivery-tracking';
  static const String wallet = '/client/wallet';
  static const String rewards = '/client/rewards';
  static const String cakeOrder = '/client/cake-order';
  static const String notifications = '/client/notifications';
  static const String addressManagement = '/client/address-management';
  static const String addressSelector = '/client/address-selector';
  static const String enhancedMenu = '/client/enhanced-menu';
  static const String groupOrder = '/client/group-order';
  static const String itemCustomization = '/client/item-customization';
  static const String orderDetails = '/client/order-details';
  static const String payment = '/client/payment';
  static const String promoCodes = '/client/promo-codes';
  static const String sharedPayment = '/client/shared-payment';
  static const String productReviews = '/client/product-reviews';
  static const String support = '/client/support';
  static const String advancedSearch = '/client/advanced-search';
  static const String enhancedOrders = '/client/enhanced-orders';
  static const String otpVerification = '/auth/otp-verification';
  static const String driverRating = '/client/driver-rating';

  /// Génère les routes de l'application
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );

      case auth:
        return MaterialPageRoute(
          builder: (_) => const AuthScreen(),
          settings: settings,
        );

      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );

      // Routes client
      case clientHome:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
          settings: settings,
        );

      case menu:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(initialIndex: 1),
          settings: settings,
        );

      case orders:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(initialIndex: 2),
          settings: settings,
        );

      case profile:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(initialIndex: 3),
          settings: settings,
        );

      case cart:
        return MaterialPageRoute(
          builder: (_) => const CartScreen(),
          settings: settings,
        );

      case checkout:
        return MaterialPageRoute(
          builder: (_) => const CheckoutScreen(),
          settings: settings,
        );

      case deliveryTracking:
        final args = settings.arguments as Map<String, dynamic>?;
        final orderId = args?['orderId'] as String? ?? '';
        if (orderId.isEmpty) {
          // Si l'ID est vide, rediriger vers la page des commandes
          return MaterialPageRoute(
            builder: (_) => const MainNavigationScreen(initialIndex: 2),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => DeliveryTrackingScreen(
            orderId: orderId,
          ),
          settings: settings,
        );

      case wallet:
        return MaterialPageRoute(
          builder: (_) => const WalletScreen(),
          settings: settings,
        );

      case rewards:
        return MaterialPageRoute(
          builder: (_) => const RewardsScreen(),
          settings: settings,
        );

      case cakeOrder:
        return MaterialPageRoute(
          builder: (_) => const CakeOrderScreen(),
          settings: settings,
        );

      case notifications:
        return MaterialPageRoute(
          builder: (_) => const NotificationsScreen(),
          settings: settings,
        );

      case addressManagement:
        return MaterialPageRoute(
          builder: (_) => const AddressManagementScreen(),
          settings: settings,
        );

      case addressSelector:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => AddressSelectorScreen(
            onAddressSelected: args?['onAddressSelected'],
          ),
          settings: settings,
        );

      case enhancedMenu:
        return MaterialPageRoute(
          builder: (_) => const MenuScreen(),
          settings: settings,
        );

      case groupOrder:
        return MaterialPageRoute(
          builder: (_) => const GroupOrderScreen(),
          settings: settings,
        );

      case itemCustomization:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => EnhancedItemCustomizationScreen(
            item: args?['item'] as MenuItem,
            onAddToCart: args?['onAddToCart'] as Function(
                MenuItem, int, Map<String, dynamic>)?,
          ),
          settings: settings,
        );

      case orderDetails:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(
            order: args?['order'] as Order,
          ),
          settings: settings,
        );

      case payment:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => PaymentScreen(
            orderId: args?['orderId'] ?? '',
            amount: args?['amount'] ?? 0.0,
            paymentMethod: args?['paymentMethod'] ?? PaymentMethod.mobileMoney,
            customerName: args?['customerName'] ?? '',
            customerEmail: args?['customerEmail'] ?? '',
            customerPhone: args?['customerPhone'] ?? '',
          ),
          settings: settings,
        );

      case promoCodes:
        final args = settings.arguments as Map<String, dynamic>?;
        final onPromoCodeApplied =
            args?['onPromoCodeApplied'] as Function(PromoCode, double)?;
        return MaterialPageRoute(
          builder: (_) => PromoCodesScreen(
            orderAmount: args?['orderAmount'] ?? 0.0,
            onPromoCodeApplied: onPromoCodeApplied ?? (_, __) {},
          ),
          settings: settings,
        );

      case sharedPayment:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => SharedPaymentScreen(
            groupId: args?['groupId'] ?? '',
            orderId: args?['orderId'] ?? '',
            totalAmount: args?['totalAmount'] ?? 0.0,
            participants:
                (args?['participants'] as List<PaymentParticipant>?) ?? [],
          ),
          settings: settings,
        );

      case productReviews:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ProductReviewsScreen(
            menuItem: args?['menuItem'] as MenuItem,
          ),
          settings: settings,
        );

      case support:
        return MaterialPageRoute(
          builder: (_) => const SupportScreen(),
          settings: settings,
        );

      case advancedSearch:
        return MaterialPageRoute(
          builder: (_) => const AdvancedSearchScreen(),
          settings: settings,
        );

      case enhancedOrders:
        return MaterialPageRoute(
          builder: (_) => const EnhancedOrdersScreen(),
          settings: settings,
        );

      case otpVerification:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => OTPVerificationScreen(
            phone: args?['phone'] ?? '',
          ),
          settings: settings,
        );

      case driverRating:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => DriverRatingScreen(
            orderId: args?['orderId'] ?? '',
            driverId: args?['driverId'] ?? '',
            driverName: args?['driverName'],
          ),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const NotFoundScreen(),
          settings: settings,
        );
    }
  }

  /// Navigation contextuelle basée sur le rôle utilisateur
  static void navigateBasedOnRole(BuildContext context, User user) {
    // Utiliser le service de navigation centralisé
    NavigationService.navigateBasedOnRole(context, user);
  }
}

/// Écran 404 pour les routes non trouvées
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Page non trouvée'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBack(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 100,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 20),
                Text(
                  '404',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Page non trouvée',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'La page que vous recherchez n\'existe pas ou a été déplacée.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _goToHome(context),
                  icon: const Icon(Icons.home),
                  label: const Text('Retour à l\'accueil'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _handleBack(context),
                  child: const Text('Retour en arrière'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleBack(BuildContext context) {
    // Essayer de revenir en arrière si possible
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // Sinon, aller à l'accueil client
      _goToHome(context);
    }
  }

  void _goToHome(BuildContext context) {
    // Aller à l'accueil client au lieu de l'accueil générique
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.clientHome,
      (route) => false, // Supprimer toutes les routes précédentes
    );
  }
}

/// Extension pour faciliter la navigation
extension AppNavigation on BuildContext {
  /// Naviguer vers une route avec des arguments
  Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(this).pushNamed<T>(routeName, arguments: arguments);
  }

  /// Naviguer et remplacer la route actuelle
  Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    Object? arguments,
    TO? result,
  }) {
    return Navigator.of(this).pushReplacementNamed<T, TO>(
      routeName,
      arguments: arguments,
      result: result,
    );
  }

  /// Naviguer et supprimer toutes les routes précédentes
  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String routeName, {
    Object? arguments,
    bool Function(Route<dynamic>)? predicate,
  }) {
    return Navigator.of(this).pushNamedAndRemoveUntil<T>(
      routeName,
      predicate ?? (route) => false,
      arguments: arguments,
    );
  }

  /// Retourner à la route précédente
  void pop<T extends Object?>([T? result]) {
    Navigator.of(this).pop<T>(result);
  }

  /// Vérifier si on peut revenir en arrière
  bool canPop() {
    return Navigator.of(this).canPop();
  }
}
