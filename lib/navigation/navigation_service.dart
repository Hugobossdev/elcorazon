import 'package:flutter/material.dart';
import 'package:elcora_fast/models/user.dart';
import 'package:elcora_fast/navigation/app_router.dart';

/// Service de navigation centralisé pour gérer la navigation entre les différents rôles
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  /// Naviguer vers l'écran approprié selon le rôle de l'utilisateur
  static void navigateBasedOnRole(BuildContext context, User user) {
    switch (user.role) {
      case UserRole.client:
        _navigateToClientApp(context);
        break;
      case UserRole.admin:
        _navigateToAdminApp(context);
        break;
      case UserRole.delivery:
        _navigateToDeliveryApp(context);
        break;
    }
  }

  /// Naviguer vers l'application client
  static void _navigateToClientApp(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.clientHome,
      (route) => false,
    );
  }

  /// Naviguer vers l'application admin
  static void _navigateToAdminApp(BuildContext context) {
    // Pour l'instant, rediriger vers l'interface client
    // TODO: Implémenter l'interface admin dédiée
    Navigator.of(context).pushReplacementNamed(AppRouter.clientHome);
  }

  /// Naviguer vers l'application delivery
  static void _navigateToDeliveryApp(BuildContext context) {
    // Pour l'instant, rediriger vers l'interface client
    // TODO: Implémenter l'interface delivery dédiée
    Navigator.of(context).pushReplacementNamed(AppRouter.clientHome);
  }

  /// Naviguer vers l'écran d'authentification
  static void navigateToAuth(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(AppRouter.auth);
  }

  /// Naviguer vers l'écran d'accueil
  static void navigateToHome(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.clientHome,
      (route) => false,
    );
  }

  /// Naviguer vers l'écran de splash
  static void navigateToSplash(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.splash,
      (route) => false,
    );
  }

  /// Vérifier si l'utilisateur peut naviguer vers un écran spécifique
  static bool canNavigateToScreen(
      BuildContext context, String routeName, User? user,) {
    // Logique simple de validation des routes
    if (user == null) return false;

    // Routes publiques accessibles à tous
    final publicRoutes = [AppRouter.auth, AppRouter.splash, AppRouter.home];
    if (publicRoutes.contains(routeName)) return true;

    // Routes spécifiques selon le rôle
    switch (user.role) {
      case UserRole.client:
        return routeName.startsWith('/client');
      case UserRole.admin:
        return routeName.startsWith('/admin');
      case UserRole.delivery:
        return routeName.startsWith('/delivery');
    }
  }

  /// Naviguer avec des arguments
  static Future<T?> pushNamedWithArgs<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed<T>(
      routeName,
      arguments: arguments,
    );
  }

  /// Naviguer et remplacer avec des arguments
  static Future<T?>
      pushReplacementNamedWithArgs<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    TO? result,
  }) {
    return Navigator.of(context).pushReplacementNamed<T, TO>(
      routeName,
      arguments: arguments,
      result: result,
    );
  }

  /// Naviguer et supprimer toutes les routes précédentes
  static Future<T?> pushNamedAndRemoveUntilWithArgs<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    bool Function(Route<dynamic>)? predicate,
  }) {
    return Navigator.of(context).pushNamedAndRemoveUntil<T>(
      routeName,
      predicate ?? (route) => false,
      arguments: arguments,
    );
  }
}

/// Extension pour faciliter l'utilisation du service de navigation
extension NavigationServiceExtension on BuildContext {
  /// Naviguer basé sur le rôle
  void navigateBasedOnRole(User user) {
    NavigationService.navigateBasedOnRole(this, user);
  }

  /// Naviguer vers l'authentification
  void navigateToAuth() {
    NavigationService.navigateToAuth(this);
  }

  /// Naviguer vers l'accueil
  void navigateToHome() {
    NavigationService.navigateToHome(this);
  }

  /// Naviguer vers le splash
  void navigateToSplash() {
    NavigationService.navigateToSplash(this);
  }

  /// Vérifier si on peut naviguer
  bool canNavigateTo(String routeName, User? user) {
    return NavigationService.canNavigateToScreen(this, routeName, user);
  }
}
