import 'package:flutter/material.dart';

/// Helper pour afficher des dialogues de manière sécurisée
/// Évite l'erreur "Cannot hit test a render box with no size"
class DialogHelper {
  /// Affiche un dialogue de manière sécurisée avec toutes les vérifications nécessaires
  /// pour éviter l'erreur "Cannot hit test a render box with no size"
  static Future<T?> showSafeDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
    bool useRootNavigator = false,
    RouteSettings? routeSettings,
  }) {
    // Vérifier que le contexte est monté
    if (!context.mounted) {
      return Future.value(null);
    }

    // Utiliser showDialog directement mais avec un wrapper pour garantir les contraintes
    return showDialog<T>(
      context: context,
      builder: (dialogContext) {
        // IMPORTANT: Envelopper le dialogue dans un widget qui garantit les contraintes
        return SafeDialogWrapper(
          child: builder(dialogContext),
        );
      },
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black54,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
    );
  }
}

/// Widget wrapper qui garantit que les dialogues ont des contraintes de taille
/// avant d'être testés, évitant ainsi l'erreur "Cannot hit test a render box with no size"
class SafeDialogWrapper extends StatelessWidget {
  final Widget child;

  const SafeDialogWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Si les contraintes ne sont pas valides, retourner un widget avec contraintes minimales
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return const SizedBox(
            width: 300,
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Utiliser ConstrainedBox pour garantir les contraintes
        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 300,
            maxWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 600,
            minHeight: 200,
            maxHeight: constraints.maxHeight > 0 ? constraints.maxHeight : 800,
          ),
          child: child,
        );
      },
    );
  }
}
