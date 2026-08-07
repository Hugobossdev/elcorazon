import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

/// Service centralisé pour la gestion des erreurs
class ErrorHandlerService extends ChangeNotifier {
  static final ErrorHandlerService _instance = ErrorHandlerService._internal();
  factory ErrorHandlerService() => _instance;
  ErrorHandlerService._internal();

  final List<AppError> _errors = [];
  bool _isInitialized = false;

  List<AppError> get errors => List.unmodifiable(_errors);
  bool get isInitialized => _isInitialized;
  bool get hasErrors => _errors.isNotEmpty;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Enregistre une erreur
  void logError(String message, {String? code, dynamic details, StackTrace? stackTrace}) {
    final error = AppError(
      message: message,
      code: code,
      details: details,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
    );

    _errors.add(error);
    
    // Log en mode debug
    if (kDebugMode) {
      Journal.trace('🚨 Error: $message');
      if (code != null) Journal.trace('   Code: $code');
      if (details != null) Journal.trace('   Details: $details');
      if (stackTrace != null) Journal.trace('   StackTrace: $stackTrace');
    }

    notifyListeners();
  }

  /// Enregistre une erreur de réseau
  void logNetworkError(String operation, dynamic error) {
    logError(
      'Network error during $operation',
      code: 'NETWORK_ERROR',
      details: error.toString(),
    );
  }

  /// Enregistre une erreur d'authentification
  void logAuthError(String operation, dynamic error) {
    logError(
      'Authentication error during $operation',
      code: 'AUTH_ERROR',
      details: error.toString(),
    );
  }

  /// Enregistre une erreur de base de données
  void logDatabaseError(String operation, dynamic error) {
    logError(
      'Database error during $operation',
      code: 'DATABASE_ERROR',
      details: error.toString(),
    );
  }

  /// Enregistre une erreur de paiement
  void logPaymentError(String operation, dynamic error) {
    logError(
      'Payment error during $operation',
      code: 'PAYMENT_ERROR',
      details: error.toString(),
    );
  }

  /// Efface toutes les erreurs
  void clearErrors() {
    _errors.clear();
    notifyListeners();
  }

  /// Efface une erreur spécifique
  void clearError(String errorId) {
    _errors.removeWhere((error) => error.id == errorId);
    notifyListeners();
  }

  /// Obtient les erreurs par type
  List<AppError> getErrorsByType(String type) {
    return _errors.where((error) => error.code == type).toList();
  }

  /// Obtient les erreurs récentes
  List<AppError> getRecentErrors({Duration? since}) {
    final cutoff = since != null ? DateTime.now().subtract(since) : DateTime.now().subtract(const Duration(hours: 24));
    return _errors.where((error) => error.timestamp.isAfter(cutoff)).toList();
  }

  /// Affiche un snackbar d'erreur
  void showErrorSnackBar(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: duration ?? const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Fermer',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Affiche une boîte de dialogue d'erreur
  void showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // RETRY AUTOMATIQUE AVEC BACKOFF EXPONENTIEL
  // =====================================================

  /// Exécute une opération avec retry automatique en cas d'erreur
  /// 
  /// [operation] : L'opération à exécuter
  /// [maxRetries] : Nombre maximum de tentatives (défaut: 3)
  /// [delay] : Délai initial entre les tentatives (défaut: 1 seconde)
  /// [exponentialBackoff] : Utiliser un backoff exponentiel (défaut: true)
  /// [retryOn] : Fonction pour déterminer si on doit retry (défaut: retry sur erreurs réseau)
  /// 
  /// Retourne le résultat de l'opération ou lance une exception traduite
  static Future<T> handleWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
    bool exponentialBackoff = true,
    bool Function(dynamic error)? retryOn,
  }) async {
    int attempts = 0;
    Exception? lastError;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        lastError = e is Exception ? e : Exception(e.toString());

        // Vérifier si on doit retry cette erreur
        if (retryOn != null && !retryOn(e)) {
          throw _translateError(e);
        }

        // Si c'est la dernière tentative, lancer l'erreur traduite
        if (attempts >= maxRetries) {
          throw _translateError(e);
        }

        // Calculer le délai avec backoff exponentiel si activé
        final waitTime = exponentialBackoff
            ? delay * (1 << (attempts - 1)) // 2^(attempts-1) * delay
            : delay;

        if (kDebugMode) {
          Journal.trace('⚠️ Tentative $attempts/$maxRetries échouée. Nouvelle tentative dans ${waitTime.inSeconds}s...');
        }

        await Future.delayed(waitTime);
      }
    }

    // Ne devrait jamais arriver ici, mais au cas où
    throw lastError ?? Exception('Opération échouée après $maxRetries tentatives');
  }

  /// Détermine si une erreur est retryable (erreurs réseau temporaires)
  static bool isRetryableError(dynamic error) {
    // Erreurs réseau
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is HttpException) return true;
    
    // Erreurs d'API : seules les pannes de transport et les 5xx méritent une
    // nouvelle tentative. Un 4xx est un refus argumenté du serveur — le
    // rejouer à l'identique donnera le même refus.
    if (error is ApiException) {
      return error.status == 0 || error.status >= 500;
    }

    // Session expirée : il faut se reconnecter, pas réessayer.
    if (error is SessionExpiredException) return false;

    // Par défaut, ne pas retry
    return false;
  }

  // =====================================================
  // TRADUCTION DES ERREURS
  // =====================================================

  /// Traduit une erreur technique en message compréhensible pour l'utilisateur
  static String translateError(dynamic error) {
    return _translateError(error);
  }

  static String _translateError(dynamic error) {
    // Erreurs réseau
    if (error is SocketException) {
      return 'Vérifiez votre connexion internet et réessayez.';
    }
    
    if (error is TimeoutException) {
      return 'Le serveur met trop de temps à répondre. Veuillez réessayer.';
    }
    
    if (error is HttpException) {
      return 'Erreur de communication avec le serveur. Veuillez réessayer.';
    }

    // Erreurs de l'API Django (RFC 9457)
    if (error is ApiException) {
      return _translateApiError(error);
    }

    if (error is SessionExpiredException) {
      return 'Votre session a expiré. Veuillez vous reconnecter.';
    }

    if (error is WrongAccountTypeException) {
      return 'Ce compte n\'est pas un compte client.';
    }

    // Erreurs de format
    if (error is FormatException) {
      return 'Les données reçues sont invalides. Veuillez réessayer.';
    }

    // Erreurs de type
    if (error is TypeError) {
      return 'Une erreur de traitement est survenue. Veuillez réessayer.';
    }

    // Erreurs génériques
    if (error is Exception) {
      final message = error.toString().toLowerCase();
      
      // Messages spécifiques basés sur le contenu
      if (message.contains('network') || message.contains('connection')) {
        return 'Problème de connexion. Vérifiez votre internet.';
      }
      
      if (message.contains('timeout')) {
        return 'Temps d\'attente dépassé. Veuillez réessayer.';
      }
      
      if (message.contains('permission') || message.contains('unauthorized')) {
        return 'Vous n\'avez pas la permission d\'effectuer cette action.';
      }
      
      if (message.contains('not found') || message.contains('404')) {
        return 'La ressource demandée est introuvable.';
      }
      
      if (message.contains('server') || message.contains('500')) {
        return 'Erreur serveur. Veuillez réessayer plus tard.';
      }
    }

    // Message par défaut
    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  /// Traduit une erreur `application/problem+json` du backend.
  ///
  /// `detail` est déjà un message destiné à l'utilisateur, rédigé côté serveur
  /// (`common/exceptions.py`) : on l'affiche tel quel plutôt que de le
  /// réécrire ici, où il divergerait à la première évolution du backend. Les
  /// cas traités à part sont ceux où le serveur ne peut pas savoir quoi dire —
  /// panne de transport — ou dont la formulation appartient à l'app.
  static String _translateApiError(ApiException error) {
    if (error.status == 0) {
      return 'Problème de connexion. Vérifiez votre internet.';
    }
    if (error.isThrottled) {
      return 'Trop de tentatives. Patientez un instant avant de réessayer.';
    }
    if (error.isUnauthorized) {
      return 'Votre session a expiré. Veuillez vous reconnecter.';
    }
    if (error.status >= 500) {
      return 'Erreur serveur. Veuillez réessayer plus tard.';
    }

    return error.detail;
  }

  // =====================================================
  // MÉTHODES UTILITAIRES
  // =====================================================

  /// Exécute une opération et affiche un message d'erreur traduit en cas d'échec
  static Future<T?> handleOperation<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    String? successMessage,
    bool showErrorSnackBar = true,
    int maxRetries = 0, // Par défaut, pas de retry
  }) async {
    try {
      final result = maxRetries > 0
          ? await handleWithRetry(
              operation: operation,
              maxRetries: maxRetries,
            )
          : await operation();

      if (successMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      return result;
    } catch (e) {
      final translatedError = translateError(e);
      
      if (showErrorSnackBar && context.mounted) {
        final errorHandler = ErrorHandlerService();
        errorHandler.showErrorSnackBar(context, translatedError);
      }

      // Logger l'erreur
      ErrorHandlerService().logError(
        translatedError,
        code: 'OPERATION_ERROR',
        details: e,
      );

      return null;
    }
  }

  /// Exécute une opération avec retry et retourne un résultat avec statut
  static Future<OperationResult<T>> executeWithResult<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    try {
      final result = await handleWithRetry(
        operation: operation,
        maxRetries: maxRetries,
        delay: delay,
      );
      return OperationResult<T>.success(result);
    } catch (e) {
      return OperationResult<T>.failure(
        translateError(e),
        originalError: e,
      );
    }
  }
}

/// Résultat d'une opération avec statut
class OperationResult<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final dynamic originalError;

  OperationResult._({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    this.originalError,
  });

  factory OperationResult.success(T data) {
    return OperationResult._(
      isSuccess: true,
      data: data,
    );
  }

  factory OperationResult.failure(
    String errorMessage, {
    dynamic originalError,
  }) {
    return OperationResult._(
      isSuccess: false,
      errorMessage: errorMessage,
      originalError: originalError,
    );
  }

  bool get isFailure => !isSuccess;
}

/// Classe représentant une erreur de l'application
class AppError {
  final String id;
  final String message;
  final String? code;
  final dynamic details;
  final DateTime timestamp;
  final StackTrace? stackTrace;

  AppError({
    required this.message, required this.timestamp, String? id,
    this.code,
    this.details,
    this.stackTrace,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  @override
  String toString() {
    return 'AppError(id: $id, message: $message, code: $code, timestamp: $timestamp)';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message': message,
      'code': code,
      'details': details?.toString(),
      'timestamp': timestamp.toIso8601String(),
      'stackTrace': stackTrace?.toString(),
    };
  }
}

