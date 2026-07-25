import 'package:flutter/material.dart';
import 'dart:async';

/// Service pour le feedback visuel amélioré avec animations
class VisualFeedbackService {
  static final VisualFeedbackService _instance =
      VisualFeedbackService._internal();
  factory VisualFeedbackService() => _instance;
  VisualFeedbackService._internal();

  // =====================================================
  // MESSAGES DE SUCCÈS
  // =====================================================

  /// Affiche un message de succès avec animation et action optionnelle
  static void showSuccessMessage(
    BuildContext context,
    String message, {
    VoidCallback? onAction,
    String? actionLabel,
    Duration duration = const Duration(seconds: 3),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    // Vérifier que le contexte est monté
    if (!context.mounted) {
      debugPrint(
          '⚠️ VisualFeedbackService: Contexte non monté, impossible d\'afficher le message: $message',);
      return;
    }

    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(20 * (1 - value), 0),
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: behavior,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: behavior == SnackBarBehavior.floating
              ? const EdgeInsets.all(16)
              : null,
          elevation: 6,
          action: onAction != null
              ? SnackBarAction(
                  label: actionLabel ?? 'Voir',
                  textColor: Colors.white,
                  onPressed: onAction,
                )
              : null,
        ),
      );
    } catch (e) {
      debugPrint(
          '❌ VisualFeedbackService: Erreur lors de l\'affichage du message de succès: $e',);
    }
  }

  // =====================================================
  // MESSAGES D'ERREUR
  // =====================================================

  /// Affiche un message d'erreur avec animation et action optionnelle
  static void showErrorMessage(
    BuildContext context,
    String message, {
    VoidCallback? onAction,
    String? actionLabel,
    Duration duration = const Duration(seconds: 4),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    // Vérifier que le contexte est monté
    if (!context.mounted) {
      debugPrint(
          '⚠️ VisualFeedbackService: Contexte non monté, impossible d\'afficher l\'erreur: $message',);
      return;
    }

    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: const Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 24,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(20 * (1 - value), 0),
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: behavior,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: behavior == SnackBarBehavior.floating
              ? const EdgeInsets.all(16)
              : null,
          elevation: 6,
          action: onAction != null
              ? SnackBarAction(
                  label: actionLabel ?? 'Réessayer',
                  textColor: Colors.white,
                  onPressed: onAction,
                )
              : SnackBarAction(
                  label: 'Fermer',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
        ),
      );
    } catch (e) {
      debugPrint(
          '❌ VisualFeedbackService: Erreur lors de l\'affichage du message d\'erreur: $e',);
    }
  }

  // =====================================================
  // MESSAGES D'AVERTISSEMENT
  // =====================================================

  /// Affiche un message d'avertissement avec animation
  static void showWarningMessage(
    BuildContext context,
    String message, {
    VoidCallback? onAction,
    String? actionLabel,
    Duration duration = const Duration(seconds: 3),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: behavior,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: behavior == SnackBarBehavior.floating
            ? const EdgeInsets.all(16)
            : null,
        elevation: 6,
        action: onAction != null
            ? SnackBarAction(
                label: actionLabel ?? 'Action',
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  // =====================================================
  // MESSAGES D'INFORMATION
  // =====================================================

  /// Affiche un message d'information avec animation
  static void showInfoMessage(
    BuildContext context,
    String message, {
    VoidCallback? onAction,
    String? actionLabel,
    Duration duration = const Duration(seconds: 3),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    // Vérifier que le contexte est monté
    if (!context.mounted) {
      debugPrint(
          '⚠️ VisualFeedbackService: Contexte non monté, impossible d\'afficher l\'info: $message',);
      return;
    }

    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue.shade700,
          behavior: behavior,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: behavior == SnackBarBehavior.floating
              ? const EdgeInsets.all(16)
              : null,
          elevation: 6,
          action: onAction != null
              ? SnackBarAction(
                  label: actionLabel ?? 'Voir',
                  textColor: Colors.white,
                  onPressed: onAction,
                )
              : null,
        ),
      );
    } catch (e) {
      debugPrint(
          '❌ VisualFeedbackService: Erreur lors de l\'affichage du message d\'info: $e',);
    }
  }

  // =====================================================
  // INDICATEURS DE CHARGEMENT CONTEXTUELS
  // =====================================================

  /// Affiche un indicateur de chargement contextuel
  static OverlayEntry? showLoadingIndicator(
    BuildContext context, {
    String? message,
    bool isDismissible = false,
  }) {
    final overlay = Overlay.of(context);
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Retourner l'overlay entry pour pouvoir le supprimer plus tard
    return overlayEntry;
  }

  /// Affiche un indicateur de chargement avec message personnalisé
  static OverlayEntry? showLoadingWithMessage(
    BuildContext context,
    String message, {
    bool isDismissible = false,
  }) {
    return showLoadingIndicator(
      context,
      message: message,
      isDismissible: isDismissible,
    );
  }

  /// Masque l'indicateur de chargement
  static void hideLoadingIndicator(OverlayEntry? overlayEntry) {
    overlayEntry?.remove();
  }

  // =====================================================
  // FEEDBACK D'ACTION
  // =====================================================

  /// Affiche un feedback lors d'une action (ex: ajout au panier)
  static void showActionFeedback(
    BuildContext context,
    String action, {
    IconData? icon,
    Color? color,
    VoidCallback? onView,
  }) {
    final iconData = icon ?? Icons.shopping_cart;
    final iconColor = color ?? Colors.green.shade700;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Icon(
                    iconData,
                    color: Colors.white,
                    size: 24,
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                action,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: iconColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 6,
        action: onView != null
            ? SnackBarAction(
                label: 'Voir',
                textColor: Colors.white,
                onPressed: onView,
              )
            : null,
      ),
    );
  }

  /// Affiche un feedback d'ajout au panier
  static void showAddToCartFeedback(
    BuildContext context,
    String itemName, {
    VoidCallback? onViewCart,
  }) {
    showActionFeedback(
      context,
      '$itemName ajouté au panier',
      icon: Icons.shopping_cart,
      color: Colors.green.shade700,
      onView: onViewCart,
    );
  }

  /// Affiche un feedback de commande passée
  static void showOrderPlacedFeedback(
    BuildContext context,
    String orderId, {
    VoidCallback? onViewOrder,
  }) {
    showSuccessMessage(
      context,
      'Commande passée avec succès !',
      onAction: onViewOrder,
      actionLabel: 'Voir la commande',
      duration: const Duration(seconds: 4),
    );
  }

  // =====================================================
  // DIALOGUES AVEC ANIMATIONS
  // =====================================================

  /// Affiche un dialogue de succès avec animation
  static Future<void> showSuccessDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title),
                    ),
                  ],
                ),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onPressed?.call();
                    },
                    child: Text(buttonText),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Affiche un dialogue d'erreur avec animation
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: Colors.red.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title),
                    ),
                  ],
                ),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onPressed?.call();
                    },
                    child: Text(buttonText),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =====================================================
  // UTILITAIRES
  // =====================================================

  /// Affiche un toast (message temporaire sans action)
  static void showToast(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: backgroundColor ?? Colors.grey.shade800,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        elevation: 4,
      ),
    );
  }

  /// Affiche un feedback de copie (ex: code promo copié)
  static void showCopyFeedback(BuildContext context, String item) {
    showToast(
      context,
      '$item copié !',
      duration: const Duration(seconds: 1),
      backgroundColor: Colors.green.shade700,
    );
  }
}

/// Extension pour faciliter l'utilisation
extension VisualFeedbackExtension on BuildContext {
  /// Affiche un message de succès
  void showSuccess(String message,
      {VoidCallback? onAction, String? actionLabel,}) {
    VisualFeedbackService.showSuccessMessage(
      this,
      message,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Affiche un message d'erreur
  void showError(String message,
      {VoidCallback? onAction, String? actionLabel,}) {
    VisualFeedbackService.showErrorMessage(
      this,
      message,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Affiche un message d'avertissement
  void showWarning(String message,
      {VoidCallback? onAction, String? actionLabel,}) {
    VisualFeedbackService.showWarningMessage(
      this,
      message,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Affiche un message d'information
  void showInfo(String message, {VoidCallback? onAction, String? actionLabel}) {
    VisualFeedbackService.showInfoMessage(
      this,
      message,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Affiche un feedback d'ajout au panier
  void showAddToCartFeedback(String itemName, {VoidCallback? onViewCart}) {
    VisualFeedbackService.showAddToCartFeedback(
      this,
      itemName,
      onViewCart: onViewCart,
    );
  }

  /// Affiche un indicateur de chargement
  OverlayEntry? showLoading({String? message}) {
    return VisualFeedbackService.showLoadingIndicator(this, message: message);
  }

  /// Affiche un toast
  void showToast(String message, {Duration? duration, Color? backgroundColor}) {
    VisualFeedbackService.showToast(
      this,
      message,
      duration: duration ?? const Duration(seconds: 2),
      backgroundColor: backgroundColor,
    );
  }
}
