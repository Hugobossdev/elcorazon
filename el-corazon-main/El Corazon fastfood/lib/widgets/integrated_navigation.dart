import 'package:flutter/material.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/models/user.dart';

/// Widget de navigation intégré pour tous les écrans
class IntegratedNavigation extends StatelessWidget {
  final Widget child;
  final User? currentUser;
  final String? currentRoute;

  const IntegratedNavigation({
    required this.child, super.key,
    this.currentUser,
    this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationErrorBoundary(
      currentUser: currentUser,
      child: child,
    );
  }
}

/// Widget pour gérer les erreurs de navigation
class NavigationErrorBoundary extends StatefulWidget {
  final Widget child;
  final User? currentUser;

  const NavigationErrorBoundary({
    required this.child, super.key,
    this.currentUser,
  });

  @override
  State<NavigationErrorBoundary> createState() =>
      _NavigationErrorBoundaryState();
}

class _NavigationErrorBoundaryState extends State<NavigationErrorBoundary> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    // Écouter les erreurs de navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNavigationErrorHandling();
    });
  }

  void _setupNavigationErrorHandling() {
    // Configuration de la gestion d'erreurs de navigation
    // Cette méthode peut être étendue pour gérer des erreurs spécifiques
  }
}

/// Mixin pour ajouter la navigation intégrée aux écrans
mixin IntegratedNavigationMixin<T extends StatefulWidget> on State<T> {
  User? get currentUser => null; // À surcharger dans les écrans
  String? get currentRoute => null; // À surcharger dans les écrans

  /// Naviguer avec gestion d'erreurs intégrée
  Future<void> navigateSafely(
    String routeName, {
    Object? arguments,
    bool replace = false,
  }) async {
    try {
      if (replace) {
        await NavigationService.pushReplacementNamedWithArgs(
          context,
          routeName,
          arguments: arguments,
        );
      } else {
        await NavigationService.pushNamedWithArgs(
          context,
          routeName,
          arguments: arguments,
        );
      }
    } catch (e) {
      _handleNavigationError(
          'Erreur lors de la navigation vers $routeName: $e',);
    }
  }

  /// Gérer les erreurs de navigation
  void _handleNavigationError(String error) {
    debugPrint('Navigation Error: $error');

    // Afficher un message d'erreur à l'utilisateur
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'Réessayer',
            onPressed: () {
              // Logique de retry si nécessaire
            },
          ),
        ),
      );
    }
  }

  /// Naviguer vers l'écran approprié selon le rôle
  void navigateBasedOnRole() {
    if (currentUser != null) {
      NavigationService.navigateBasedOnRole(context, currentUser!);
    } else {
      NavigationService.navigateToAuth(context);
    }
  }

  /// Vérifier si l'utilisateur peut accéder à une route
  bool canAccessRoute(String routeName) {
    return NavigationService.canNavigateToScreen(
        context, routeName, currentUser,);
  }
}

/// Widget de navigation rapide pour les actions communes
class QuickNavigationBar extends StatelessWidget {
  final User? currentUser;
  final String? currentRoute;

  const QuickNavigationBar({
    super.key,
    this.currentUser,
    this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context,
            icon: Icons.home,
            label: 'Accueil',
            route: AppRouter.clientHome,
            onTap: () => context.goToHome(currentUser),
          ),
          _buildNavItem(
            context,
            icon: Icons.restaurant_menu,
            label: 'Menu',
            route: AppRouter.menu,
            onTap: () => context.navigateToMenu(),
          ),
          _buildNavItem(
            context,
            icon: Icons.shopping_cart,
            label: 'Panier',
            route: AppRouter.cart,
            onTap: () => context.navigateToCart(),
          ),
          _buildNavItem(
            context,
            icon: Icons.receipt_long,
            label: 'Commandes',
            route: AppRouter.orders,
            onTap: () => context.navigateToOrders(),
          ),
          _buildNavItem(
            context,
            icon: Icons.person,
            label: 'Profil',
            route: AppRouter.profile,
            onTap: () => context.navigateToProfile(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required VoidCallback onTap,
  }) {
    final isActive = currentRoute == route;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget de navigation contextuelle
class ContextualNavigation extends StatelessWidget {
  final Widget child;
  final User? currentUser;
  final String? currentRoute;
  final List<NavigationAction>? actions;

  const ContextualNavigation({
    required this.child, super.key,
    this.currentUser,
    this.currentRoute,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        if (actions != null && actions!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: actions!
                  .map((action) => _buildActionButton(context, action))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, NavigationAction action) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: action.onPressed,
          icon: Icon(action.icon),
          label: Text(action.label),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                action.color ?? Theme.of(context).colorScheme.primary,
            foregroundColor:
                action.textColor ?? Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}

/// Classe pour définir les actions de navigation
class NavigationAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;

  const NavigationAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.textColor,
  });
}

/// Extension pour faciliter l'utilisation de la navigation intégrée
extension IntegratedNavigationExtension on BuildContext {
  /// Envelopper un widget avec la navigation intégrée
  Widget withIntegratedNavigation({
    required Widget child,
    User? currentUser,
    String? currentRoute,
  }) {
    return IntegratedNavigation(
      currentUser: currentUser,
      currentRoute: currentRoute,
      child: child,
    );
  }

  /// Ajouter une barre de navigation rapide
  Widget withQuickNavigation({
    required Widget child,
    User? currentUser,
    String? currentRoute,
  }) {
    return Column(
      children: [
        Expanded(child: child),
        QuickNavigationBar(
          currentUser: currentUser,
          currentRoute: currentRoute,
        ),
      ],
    );
  }

  /// Ajouter une navigation contextuelle
  Widget withContextualNavigation({
    required Widget child,
    User? currentUser,
    String? currentRoute,
    List<NavigationAction>? actions,
  }) {
    return ContextualNavigation(
      currentUser: currentUser,
      currentRoute: currentRoute,
      actions: actions,
      child: child,
    );
  }
}
