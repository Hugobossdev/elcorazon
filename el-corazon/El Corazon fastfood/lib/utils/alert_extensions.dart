import 'package:flutter/material.dart';
import 'package:elcora_fast/services/alert_service.dart';

/// Extensions pour faciliter l'affichage des messages d'alerte
extension AlertExtensions on BuildContext {
  /// Affiche un message de succès
  void showSuccessMessage(String message, {String? title, Duration? duration}) {
    AlertService().showSuccessSnackBar(this, message, duration: duration);
  }

  /// Affiche un message d'erreur
  void showErrorMessage(String message, {String? title, Duration? duration}) {
    AlertService().showErrorSnackBar(this, message, duration: duration);
  }

  /// Affiche un message d'avertissement
  void showWarningMessage(String message, {String? title, Duration? duration}) {
    AlertService().showWarningSnackBar(this, message, duration: duration);
  }

  /// Affiche un message d'information
  void showInfoMessage(String message, {String? title, Duration? duration}) {
    AlertService().showInfoSnackBar(this, message, duration: duration);
  }

  /// Affiche une confirmation
  Future<bool> showConfirmation({
    required String message,
    String? title,
    String confirmText = 'Confirmer',
    String cancelText = 'Annuler',
    Color? confirmColor,
  }) async {
    return await AlertService().showConfirmation(
      this,
      message: message,
      title: title,
      confirmText: confirmText,
      cancelText: cancelText,
      confirmColor: confirmColor,
    );
  }

  /// Affiche une alerte avec actions
  Future<String?> showActionAlert({
    required String message,
    required List<AlertAction> actions, String? title,
  }) async {
    return await AlertService().showActionAlert(
      this,
      message: message,
      title: title,
      actions: actions,
    );
  }
}
