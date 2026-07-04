import 'package:flutter/material.dart';

/// Service centralisé pour la gestion des messages d'alerte
class AlertService extends ChangeNotifier {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  final List<AlertMessage> _alerts = [];
  bool _isInitialized = false;

  List<AlertMessage> get alerts => List.unmodifiable(_alerts);
  bool get isInitialized => _isInitialized;
  bool get hasAlerts => _alerts.isNotEmpty;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    notifyListeners();
  }

  /// Affiche un message de succès
  void showSuccess(String message, {String? title, Duration? duration}) {
    _addAlert(
      AlertMessage(
        type: AlertType.success,
        message: message,
        title: title ?? 'Succès',
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Affiche un message d'erreur
  void showError(String message, {String? title, Duration? duration}) {
    _addAlert(
      AlertMessage(
        type: AlertType.error,
        message: message,
        title: title ?? 'Erreur',
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  /// Affiche un message d'avertissement
  void showWarning(String message, {String? title, Duration? duration}) {
    _addAlert(
      AlertMessage(
        type: AlertType.warning,
        message: message,
        title: title ?? 'Avertissement',
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Affiche un message d'information
  void showInfo(String message, {String? title, Duration? duration}) {
    _addAlert(
      AlertMessage(
        type: AlertType.info,
        message: message,
        title: title ?? 'Information',
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Affiche une alerte de confirmation
  Future<bool> showConfirmation(
    BuildContext context, {
    required String message,
    String? title,
    String confirmText = 'Confirmer',
    String cancelText = 'Annuler',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'Confirmation'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  confirmColor ?? Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Affiche une alerte avec actions personnalisées
  Future<String?> showActionAlert(
    BuildContext context, {
    required String message,
    required List<AlertAction> actions, String? title,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: title != null ? Text(title) : null,
        content: Text(message),
        actions: actions.map((action) {
          return TextButton(
            onPressed: () => Navigator.of(context).pop(action.id),
            child: Text(action.label),
          );
        }).toList(),
      ),
    );
    return result;
  }

  /// Affiche un SnackBar personnalisé
  void showSnackBar(
    BuildContext context,
    String message, {
    AlertType type = AlertType.info,
    Duration? duration,
    SnackBarAction? action,
  }) {
    // Vérifier que le contexte est monté
    if (!context.mounted) {
      debugPrint(
          '⚠️ AlertService: Contexte non monté, impossible d\'afficher: $message',);
      return;
    }

    try {
      final colors = _getColorsForType(type);

      // Masquer la notification actuelle avant d'en afficher une nouvelle
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _getIconForType(type),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: colors['background'],
          duration: duration ?? const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          action: action,
        ),
      );
    } catch (e) {
      debugPrint('❌ AlertService: Erreur lors de l\'affichage du SnackBar: $e');
    }
  }

  /// Affiche un message de succès via SnackBar
  void showSuccessSnackBar(BuildContext context, String message,
      {Duration? duration,}) {
    showSnackBar(context, message, type: AlertType.success, duration: duration);
  }

  /// Affiche un message d'erreur via SnackBar
  void showErrorSnackBar(BuildContext context, String message,
      {Duration? duration,}) {
    showSnackBar(context, message, type: AlertType.error, duration: duration);
  }

  /// Affiche un message d'avertissement via SnackBar
  void showWarningSnackBar(BuildContext context, String message,
      {Duration? duration,}) {
    showSnackBar(context, message, type: AlertType.warning, duration: duration);
  }

  /// Affiche un message d'information via SnackBar
  void showInfoSnackBar(BuildContext context, String message,
      {Duration? duration,}) {
    showSnackBar(context, message, duration: duration);
  }

  /// Ajoute une alerte à la liste
  void _addAlert(AlertMessage alert) {
    _alerts.add(alert);
    notifyListeners();

    // Supprimer automatiquement après la durée spécifiée
    if (alert.duration != null) {
      Future.delayed(alert.duration!, () {
        removeAlert(alert.id);
      });
    }
  }

  /// Supprime une alerte
  void removeAlert(String id) {
    _alerts.removeWhere((alert) => alert.id == id);
    notifyListeners();
  }

  /// Supprime toutes les alertes
  void clearAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  /// Obtient les couleurs pour un type d'alerte
  Map<String, Color> _getColorsForType(AlertType type) {
    switch (type) {
      case AlertType.success:
        return {
          'background': Colors.green,
          'foreground': Colors.white,
          'icon': Colors.white,
        };
      case AlertType.error:
        return {
          'background': Colors.red,
          'foreground': Colors.white,
          'icon': Colors.white,
        };
      case AlertType.warning:
        return {
          'background': Colors.orange,
          'foreground': Colors.white,
          'icon': Colors.white,
        };
      case AlertType.info:
        return {
          'background': Colors.blue,
          'foreground': Colors.white,
          'icon': Colors.white,
        };
    }
  }

  /// Obtient l'icône pour un type d'alerte
  IconData _getIconForType(AlertType type) {
    switch (type) {
      case AlertType.success:
        return Icons.check_circle;
      case AlertType.error:
        return Icons.error;
      case AlertType.warning:
        return Icons.warning;
      case AlertType.info:
        return Icons.info;
    }
  }
}

/// Type d'alerte
enum AlertType {
  success,
  error,
  warning,
  info,
}

/// Message d'alerte
class AlertMessage {
  final String id;
  final AlertType type;
  final String message;
  final String title;
  final DateTime timestamp;
  final Duration? duration;

  AlertMessage({
    required this.type, required this.message, required this.title, String? id,
    this.duration,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = DateTime.now();

  Color get backgroundColor {
    switch (type) {
      case AlertType.success:
        return Colors.green;
      case AlertType.error:
        return Colors.red;
      case AlertType.warning:
        return Colors.orange;
      case AlertType.info:
        return Colors.blue;
    }
  }

  IconData get icon {
    switch (type) {
      case AlertType.success:
        return Icons.check_circle;
      case AlertType.error:
        return Icons.error;
      case AlertType.warning:
        return Icons.warning;
      case AlertType.info:
        return Icons.info;
    }
  }
}

/// Action d'alerte
class AlertAction {
  final String id;
  final String label;
  final VoidCallback? onPressed;

  AlertAction({
    required this.id,
    required this.label,
    this.onPressed,
  });
}
