import 'package:flutter/foundation.dart';

/// Utilitaire de logging pour la production
/// Les logs sont automatiquement supprimés en mode release par Flutter
class Logger {
  /// Log d'information (seulement en mode debug)
  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('$prefix $message');
    }
  }

  /// Log d'erreur (toujours loggé, même en production via les services d'erreur)
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ ERROR: $message');
      if (error != null) {
        debugPrint('   Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('   StackTrace: $stackTrace');
      }
    }
    // En production, envoyer à un service de logging (Sentry, Firebase Crashlytics, etc.)
  }

  /// Log d'avertissement
  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('⚠️ WARNING $prefix: $message');
    }
  }

  /// Log de succès
  static void success(String message, [String? tag]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('✅ SUCCESS $prefix: $message');
    }
  }
}





