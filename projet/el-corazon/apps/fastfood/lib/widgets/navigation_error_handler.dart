import 'package:flutter/material.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

/// Widget pour gérer les erreurs de navigation
class NavigationErrorHandler extends StatelessWidget {
  final Widget child;
  final eccore.User? currentUser;

  const NavigationErrorHandler({
    required this.child, super.key,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        // Gérer les erreurs de navigation ici
        return child;
      },
    );
  }

  /// Afficher une erreur de navigation
  static void showNavigationError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        action: SnackBarAction(
          label: 'Réessayer',
          onPressed: () {
            // Logique de retry
          },
        ),
      ),
    );
  }

  /// Gérer une erreur de navigation et rediriger
  static void handleNavigationError(
    BuildContext context,
    String error,
    eccore.User? user,
  ) {
    Journal.trace('Navigation Error: $error');

    // Afficher l'erreur à l'utilisateur
    showNavigationError(context, 'Erreur de navigation: $error');

    // Rediriger vers l'écran approprié
    if (user != null) {
      NavigationService.navigateBasedOnRole(context, user);
    } else {
      NavigationService.navigateToAuth(context);
    }
  }
}

/// Mixin pour ajouter la gestion d'erreurs de navigation aux widgets
mixin NavigationErrorMixin<T extends StatefulWidget> on State<T> {
  /// Gérer une erreur de navigation
  void handleNavigationError(String error, {eccore.User? user}) {
    NavigationErrorHandler.handleNavigationError(context, error, user);
  }

  /// Naviguer avec gestion d'erreurs
  Future<void> navigateSafely(
    String routeName, {
    Object? arguments,
    eccore.User? user,
  }) async {
    try {
      await Navigator.of(context).pushNamed(routeName, arguments: arguments);
    } catch (e) {
      handleNavigationError('Erreur lors de la navigation vers $routeName: $e',
          user: user,);
    }
  }

  /// Naviguer et remplacer avec gestion d'erreurs
  Future<void> navigateReplacementSafely(
    String routeName, {
    Object? arguments,
    eccore.User? user,
  }) async {
    try {
      await Navigator.of(context)
          .pushReplacementNamed(routeName, arguments: arguments);
    } catch (e) {
      handleNavigationError('Erreur lors de la navigation vers $routeName: $e',
          user: user,);
    }
  }
}
