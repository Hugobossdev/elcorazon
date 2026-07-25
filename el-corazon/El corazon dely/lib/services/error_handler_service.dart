import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  void logError(String message,
      {String? code, dynamic details, StackTrace? stackTrace}) {
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
      debugPrint('🚨 Error: $message');
      if (code != null) debugPrint('   Code: $code');
      if (details != null) debugPrint('   Details: $details');
      if (stackTrace != null) debugPrint('   StackTrace: $stackTrace');
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
    final cutoff = since != null
        ? DateTime.now().subtract(since)
        : DateTime.now().subtract(const Duration(hours: 24));
    return _errors.where((error) => error.timestamp.isAfter(cutoff)).toList();
  }

  /// Affiche un snackbar d'erreur
  void showErrorSnackBar(BuildContext context, String message,
      {Duration? duration}) {
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
    String? id,
    required this.message,
    this.code,
    this.details,
    required this.timestamp,
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





