import 'package:flutter/material.dart';

/// Helper pour utiliser BuildContext de manière sécurisée après des opérations asynchrones
class ContextHelper {
  ContextHelper._();

  /// Vérifie si le widget est toujours monté avant d'utiliser le context
  /// Usage: if (ContextHelper.isMounted(context)) { ... }
  static bool isMounted(BuildContext? context) {
    if (context == null) return false;
    
    // Pour StatefulWidget, vérifier si le widget est monté
    if (context is StatefulElement) {
      final state = context.state;
      if (!state.mounted) {
        return false;
      }
    }
    
    return true;
  }

  /// Utilise le context de manière sécurisée après une opération asynchrone
  /// Retourne null si le widget n'est plus monté
  static T? safeUse<T>(BuildContext? context, T Function() action) {
    if (!isMounted(context)) return null;
    try {
      return action();
    } catch (e) {
      return null;
    }
  }
}

/// Extension pour BuildContext pour faciliter l'utilisation
extension SafeContextExtension on BuildContext {
  /// Vérifie si le context peut être utilisé de manière sécurisée
  bool get canUse {
    return ContextHelper.isMounted(this);
  }

  /// Utilise le context de manière sécurisée
  T? safeUse<T>(T Function() action) {
    return ContextHelper.safeUse(this, action);
  }
}




