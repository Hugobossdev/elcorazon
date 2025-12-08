import 'package:flutter/material.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/widgets/menu_item_card.dart';
import 'package:elcora_fast/widgets/cart_item_card.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/cart_item.dart' as cart_item;

/// Service pour intégrer facilement les améliorations de design
class DesignEnhancementService {
  /// Créer un bouton amélioré avec animations
  static Widget createEnhancedButton({
    required String text,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    bool isLoading = false,
    bool isFullWidth = false,
    Duration animationDelay = Duration.zero,
  }) {
    final Widget button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor, // Let Theme handle default
        foregroundColor: textColor, // Let Theme handle default
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(text),
              ],
            ),
    );
    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  /// Créer une carte de catégorie améliorée
  static Widget createEnhancedCategoryCard({
    required String title,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    Duration animationDelay = Duration.zero,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  // Color handled by Theme
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    // Color handled by Theme (or use opacity/secondary style)
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Créer une carte de produit améliorée
  static Widget createEnhancedMenuItemCard({
    required String name,
    required String description,
    required double price,
    String? id,
    String? imageUrl,
    bool isPopular = false,
    bool isVegetarian = false,
    bool isVegan = false,
    VoidCallback? onTap,
    VoidCallback? onAddToCart,
    VoidCallback? onFavoriteTap,
    bool isFavorite = false,
    Duration animationDelay = Duration.zero,
    int quantity = 0,
  }) {
    return MenuItemCard(
      item: MenuItem(
        id: id ?? '',
        name: name,
        description: description,
        price: price,
        categoryId: 'burgers', // Placeholder category ID
        imageUrl: imageUrl,
        isPopular: isPopular,
        isVegetarian: isVegetarian,
        isVegan: isVegan,
      ),
      onTap: onTap ?? () {},
      onAddToCart: onAddToCart ?? () {},
      onFavoriteTap: onFavoriteTap,
      isFavorite: isFavorite,
      isGridView: true,
    );
  }

  /// Créer une carte de panier améliorée
  static Widget createEnhancedCartItemCard({
    required String name,
    required String description,
    required double price,
    required int quantity,
    String? imageUrl,
    VoidCallback? onIncrement,
    VoidCallback? onDecrement,
    VoidCallback? onRemove,
    Duration animationDelay = Duration.zero,
  }) {
    return CartItemCard(
      item: cart_item.CartItem(
        id: '',
        menuItemId: '',
        name: name,
        price: price,
        quantity: quantity,
        imageUrl: imageUrl,
        customizations: {},
      ),
      onRemove: onRemove ?? () {},
      onQuantityChanged: (newQuantity) {
        if (newQuantity > quantity && onIncrement != null) {
          onIncrement();
        } else if (newQuantity < quantity && onDecrement != null) {
          onDecrement();
        }
      },
    );
  }

  /// Créer une carte améliorée générique
  static Widget createEnhancedCard({
    required Widget child,
    VoidCallback? onTap,
    Color? backgroundColor,
    EdgeInsetsGeometry? padding,
    Duration animationDelay = Duration.zero,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: backgroundColor, // Let Theme handle the default color
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  /// Créer un indicateur de chargement amélioré
  static Widget createEnhancedLoadingIndicator({
    String? message,
    Duration animationDelay = Duration.zero,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Créer un message de succès avec animation
  static void showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Créer un message d'erreur avec animation
  static void showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Créer un dialogue amélioré
  static void showEnhancedDialog({
    required BuildContext context,
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        // Utiliser Dialog avec une animation personnalisée
        // pour éviter les problèmes de taille 0
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (cancelText != null)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onCancel?.call();
                        },
                        child: Text(
                          cancelText,
                          // style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    if (confirmText != null) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onConfirm?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDestructive
                              ? AppColors.error
                              : AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(confirmText),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Obtenir le thème amélioré
  static ThemeData getEnhancedTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primary.withOpacity(0.1),
        onPrimaryContainer: AppColors.textPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textPrimary,
        tertiary: AppColors.tertiary,
        onTertiary: Colors.white,
        error: AppColors.error,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceVariant,
        onSurfaceVariant: AppColors.textSecondary,
      ),
      brightness: Brightness.light,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: AppColors.surface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

/// Extension pour faciliter l'utilisation des améliorations
extension DesignEnhancementExtension on BuildContext {
  /// Naviguer vers la démonstration de design
  void navigateToDesignDemo() {
    Navigator.pushNamed(this, '/design-demo');
  }

  /// Afficher un message de succès
  void showSuccessMessage(String message) {
    DesignEnhancementService.showSuccessMessage(this, message);
  }

  /// Afficher un message d'erreur
  void showErrorMessage(String message) {
    DesignEnhancementService.showErrorMessage(this, message);
  }

  /// Afficher un dialogue amélioré
  void showEnhancedDialog({
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
  }) {
    DesignEnhancementService.showEnhancedDialog(
      context: this,
      title: title,
      content: content,
      confirmText: confirmText,
      cancelText: cancelText,
      onConfirm: onConfirm,
      onCancel: onCancel,
      isDestructive: isDestructive,
    );
  }
}
