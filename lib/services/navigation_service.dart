import 'package:flutter/material.dart';
import 'package:elcora_fast/models/user.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/cart_item.dart';

/// Service de navigation amélioré avec gestion d'état
class NavigationService extends ChangeNotifier {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final List<String> _navigationHistory = [];
  String _currentRoute = '/';
  Map<String, dynamic> _routeArguments = {};

  // Getters
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;
  String get currentRoute => _currentRoute;
  Map<String, dynamic> get routeArguments => _routeArguments;
  List<String> get navigationHistory => List.unmodifiable(_navigationHistory);

  /// Naviguer vers une route
  Future<T?> navigateTo<T extends Object?>(
    String route, {
    Object? arguments,
    bool replace = false,
    bool clearStack = false,
  }) async {
    try {
      _routeArguments = arguments as Map<String, dynamic>? ?? {};

      if (clearStack) {
        _navigationHistory.clear();
        return _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          route,
          (route) => false,
          arguments: arguments,
        ) as Future<T?>;
      } else if (replace) {
        _navigationHistory.removeLast();
        _navigationHistory.add(route);
        return _navigatorKey.currentState?.pushReplacementNamed(
          route,
          arguments: arguments,
        ) as Future<T?>;
      } else {
        _navigationHistory.add(route);
        return _navigatorKey.currentState?.pushNamed(
          route,
          arguments: arguments,
        ) as Future<T?>;
      }
    } catch (e) {
      debugPrint('Erreur de navigation: $e');
      return null;
    } finally {
      _currentRoute = route;
      notifyListeners();
    }
  }

  /// Naviguer en arrière
  void goBack<T extends Object?>([T? result]) {
    if (_navigationHistory.isNotEmpty) {
      _navigationHistory.removeLast();
      _navigatorKey.currentState?.pop<T>(result);
      _currentRoute =
          _navigationHistory.isNotEmpty ? _navigationHistory.last : '/';
      notifyListeners();
    }
  }

  /// Vérifier si on peut revenir en arrière
  bool canGoBack() {
    return _navigatorKey.currentState?.canPop() ?? false;
  }

  /// Naviguer vers l'écran d'accueil
  Future<void> goToHome() async {
    await navigateTo('/client/home', clearStack: true);
  }

  /// Naviguer vers le menu
  Future<void> goToMenu() async {
    await navigateTo('/client/menu');
  }

  /// Naviguer vers le panier
  Future<void> goToCart() async {
    await navigateTo('/client/cart');
  }

  /// Naviguer vers les commandes
  Future<void> goToOrders() async {
    await navigateTo('/client/orders');
  }

  /// Naviguer vers le profil
  Future<void> goToProfile() async {
    await navigateTo('/client/profile');
  }

  /// Naviguer vers la personnalisation d'un item
  Future<void> goToItemCustomization(MenuItem item) async {
    await navigateTo('/client/item-customization', arguments: {
      'item': item,
    },);
  }

  /// Naviguer vers les détails d'une commande
  Future<void> goToOrderDetails(Order order) async {
    await navigateTo('/client/order-details', arguments: {
      'order': order,
    },);
  }

  /// Naviguer vers le paiement
  Future<void> goToPayment({
    required List<CartItem> cartItems,
    required double totalAmount,
    required String orderId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String deliveryAddress,
  }) async {
    await navigateTo('/client/payment', arguments: {
      'cartItems': cartItems,
      'totalAmount': totalAmount,
      'orderId': orderId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
    },);
  }

  /// Naviguer vers le suivi de livraison
  Future<void> goToDeliveryTracking(String orderId) async {
    await navigateTo('/client/delivery-tracking', arguments: {
      'orderId': orderId,
    },);
  }

  /// Naviguer vers le portefeuille
  Future<void> goToWallet() async {
    await navigateTo('/client/wallet');
  }

  /// Naviguer vers les récompenses
  Future<void> goToRewards() async {
    await navigateTo('/client/rewards');
  }

  /// Naviguer vers la commande de gâteaux
  Future<void> goToCakeOrder() async {
    await navigateTo('/client/cake-order');
  }

  /// Naviguer vers les notifications
  Future<void> goToNotifications() async {
    await navigateTo('/client/notifications');
  }

  /// Naviguer vers la gestion des adresses
  Future<void> goToAddressManagement() async {
    await navigateTo('/client/address-management');
  }

  /// Naviguer vers les codes promo
  Future<void> goToPromoCodes({
    required double orderAmount,
    required Function(String, double) onPromoCodeApplied,
  }) async {
    await navigateTo('/client/promo-codes', arguments: {
      'orderAmount': orderAmount,
      'onPromoCodeApplied': onPromoCodeApplied,
    },);
  }

  /// Naviguer vers la commande groupée
  Future<void> goToGroupOrder() async {
    await navigateTo('/client/group-order');
  }

  /// Naviguer vers le paiement partagé
  Future<void> goToSharedPayment({
    required String groupId,
    required String orderId,
    required double totalAmount,
    required List<dynamic> participants,
  }) async {
    await navigateTo('/client/shared-payment', arguments: {
      'groupId': groupId,
      'orderId': orderId,
      'totalAmount': totalAmount,
      'participants': participants,
    },);
  }

  /// Naviguer vers l'authentification
  Future<void> goToAuth() async {
    await navigateTo('/auth', clearStack: true);
  }

  /// Naviguer vers l'écran de démarrage
  Future<void> goToSplash() async {
    await navigateTo('/', clearStack: true);
  }

  /// Navigation basée sur le rôle utilisateur
  Future<void> navigateBasedOnRole(User user) async {
    switch (user.role) {
      case UserRole.client:
        await goToHome();
        break;
      case UserRole.admin:
        // TODO: Implémenter l'interface admin
        await goToHome();
        break;
      case UserRole.delivery:
        // TODO: Implémenter l'interface delivery
        await goToHome();
        break;
    }
  }

  /// Obtenir les arguments de la route actuelle
  T? getRouteArgument<T>(String key) {
    return _routeArguments[key] as T?;
  }

  /// Vérifier si on est sur une route spécifique
  bool isCurrentRoute(String route) {
    return _currentRoute == route;
  }

  /// Obtenir la route précédente
  String? getPreviousRoute() {
    if (_navigationHistory.length > 1) {
      return _navigationHistory[_navigationHistory.length - 2];
    }
    return null;
  }

  /// Nettoyer l'historique de navigation
  void clearHistory() {
    _navigationHistory.clear();
    _currentRoute = '/';
    notifyListeners();
  }

  /// Obtenir la profondeur de navigation
  int get navigationDepth => _navigationHistory.length;

  /// Vérifier si on est à la racine
  bool get isAtRoot => _navigationHistory.length <= 1;

  /// Navigation avec animation personnalisée
  Future<T?> navigateWithAnimation<T extends Object?>(
    String route, {
    Object? arguments,
    RouteTransitionsBuilder? transitionBuilder,
    Duration transitionDuration = const Duration(milliseconds: 300),
  }) async {
    try {
      _routeArguments = arguments as Map<String, dynamic>? ?? {};
      _navigationHistory.add(route);

      return _navigatorKey.currentState?.push<T>(
        PageRouteBuilder<T>(
          pageBuilder: (context, animation, secondaryAnimation) {
            // Cette partie sera gérée par le routeur
            return Container(); // Placeholder
          },
          transitionDuration: transitionDuration,
          transitionsBuilder: transitionBuilder ??
              (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                        .chain(CurveTween(curve: Curves.easeInOut)),
                  ),
                  child: child,
                );
              },
        ),
      );
    } catch (e) {
      debugPrint('Erreur de navigation avec animation: $e');
      return null;
    } finally {
      _currentRoute = route;
      notifyListeners();
    }
  }

  /// Navigation avec retour conditionnel
  Future<T?> navigateWithConditionalBack<T extends Object?>(
    String route, {
    Object? arguments,
    bool Function()? canNavigate,
  }) async {
    if (canNavigate != null && !canNavigate()) {
      return null;
    }

    return navigateTo<T>(route, arguments: arguments);
  }

  /// Navigation avec confirmation
  Future<T?> navigateWithConfirmation<T extends Object?>(
    String route, {
    Object? arguments,
    String? confirmationMessage,
    String confirmText = 'Continuer',
    String cancelText = 'Annuler',
  }) async {
    if (confirmationMessage != null) {
      final context = _navigatorKey.currentContext;
      if (context != null) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmation'),
            content: Text(confirmationMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmText),
              ),
            ],
          ),
        );

        if (confirmed != true) {
          return null;
        }
      }
    }

    return navigateTo<T>(route, arguments: arguments);
  }
}
