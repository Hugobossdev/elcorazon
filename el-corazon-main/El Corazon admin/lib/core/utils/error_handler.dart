import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/admin_constants.dart';

/// Type d'erreur possible dans l'application
enum ErrorType {
  network,
  authentication,
  authorization,
  validation,
  notFound,
  server,
  timeout,
  unknown,
}

/// Classe pour gérer les erreurs de manière centralisée
class ErrorHandler {
  ErrorHandler._(); // Constructeur privé

  /// Analyse une exception et retourne un type d'erreur
  static ErrorType getErrorType(dynamic error) {
    if (error is SocketException) {
      return ErrorType.network;
    }
    
    // Vérifier les erreurs HTTP client
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('socket') || 
        errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('failed to fetch')) {
      return ErrorType.network;
    }

    if (error is AuthException) {
      return ErrorType.authentication;
    }

    if (error is PostgrestException) {
      if (error.code == 'PGRST116') {
        return ErrorType.notFound;
      }
      if (error.code == '42501' || error.code == 'PGRST301') {
        return ErrorType.authorization;
      }
      return ErrorType.server;
    }

    if (error is TimeoutException) {
      return ErrorType.timeout;
    }

    if (error is FormatException || error is ArgumentError) {
      return ErrorType.validation;
    }

    return ErrorType.unknown;
  }

  /// Convertit une erreur en message utilisateur lisible
  static String getUserFriendlyMessage(dynamic error) {
    final errorType = getErrorType(error);

    switch (errorType) {
      case ErrorType.network:
        return AdminConstants.errorNetwork;
      case ErrorType.authentication:
        if (error is AuthException) {
          return _getAuthErrorMessage(error);
        }
        return 'Erreur d\'authentification';
      case ErrorType.authorization:
        return AdminConstants.errorUnauthorized;
      case ErrorType.validation:
        if (error is FormatException || error is ArgumentError) {
          return '${AdminConstants.errorValidation}: ${error.message}';
        }
        return AdminConstants.errorValidation;
      case ErrorType.notFound:
        return AdminConstants.errorNotFound;
      case ErrorType.server:
        if (error is PostgrestException) {
          return 'Erreur serveur: ${error.message}';
        }
        return 'Erreur serveur';
      case ErrorType.timeout:
        return AdminConstants.errorTimeout;
      case ErrorType.unknown:
        return AdminConstants.errorGeneric;
    }
  }

  /// Obtient un message d'erreur spécifique pour les erreurs d'authentification
  static String _getAuthErrorMessage(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid') || message.contains('credentials')) {
      return 'Email ou mot de passe incorrect';
    }
    if (message.contains('email not confirmed')) {
      return 'Veuillez confirmer votre email avant de vous connecter';
    }
    if (message.contains('user not found')) {
      return 'Aucun compte trouvé avec cet email';
    }
    if (message.contains('password')) {
      return 'Le mot de passe doit contenir au moins ${AdminConstants.minPasswordLength} caractères';
    }
    if (message.contains('too many')) {
      return 'Trop de tentatives. Veuillez réessayer plus tard';
    }
    if (message.contains('expired')) {
      return 'Votre session a expiré. Veuillez vous reconnecter';
    }

    return 'Erreur d\'authentification: ${error.message}';
  }

  /// Obtient un message d'erreur pour les erreurs de base de données
  static String getDatabaseErrorMessage(PostgrestException error) {
    final code = error.code;

    switch (code) {
      case '23505': // Unique constraint violation
        return 'Cette valeur existe déjà';
      case '23503': // Foreign key violation
        return 'Cette ressource est utilisée ailleurs';
      case '23502': // Not null violation
        return 'Certains champs obligatoires sont manquants';
      case 'PGRST116': // No rows returned
        return AdminConstants.errorNotFound;
      case '42501': // Insufficient privilege
      case 'PGRST301':
        return AdminConstants.errorUnauthorized;
      default:
        return 'Erreur base de données: ${error.message}';
    }
  }

  /// Log une erreur pour le debug
  static void logError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    final errorType = getErrorType(error);
    final message = getUserFriendlyMessage(error);

    debugPrint('═══════════════════════════════════════');
    debugPrint('ERROR [${errorType.name.toUpperCase()}]');
    if (context != null) {
      debugPrint('Context: $context');
    }
    debugPrint('Message: $message');
    debugPrint('Error: $error');
    if (additionalData != null && additionalData.isNotEmpty) {
      debugPrint('Additional Data: $additionalData');
    }
    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
    }
    debugPrint('═══════════════════════════════════════');
  }

  /// Gère une erreur et retourne un message utilisateur
  static String handleError(
    dynamic error, {
    String? context,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    logError(error, stackTrace, context: context, additionalData: additionalData);
    return getUserFriendlyMessage(error);
  }
}

/// Extension pour simplifier la gestion d'erreurs sur les Futures
extension FutureErrorHandling<T> on Future<T> {
  /// Exécute un Future et gère les erreurs automatiquement
  Future<T?> safeCall({
    Function(String)? onError,
    Function(T)? onSuccess,
  }) async {
    try {
      final result = await this;
      onSuccess?.call(result);
      return result;
    } catch (error, stackTrace) {
      final message = ErrorHandler.handleError(error, stackTrace: stackTrace);
      onError?.call(message);
      return null;
    }
  }
}
