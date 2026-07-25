import 'package:flutter/material.dart';

/// Bouton moderne avec différentes variantes
class ModernButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ModernButtonVariant variant;
  final ModernButtonSize size;
  final bool isLoading;
  final bool isFullWidth;

  const ModernButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = ModernButtonVariant.primary,
    this.size = ModernButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonStyle = _getButtonStyle(context);

    Widget button;
    
    switch (variant) {
      case ModernButtonVariant.primary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: _buildChild(theme),
        );
        break;
      case ModernButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: _buildChild(theme),
        );
        break;
      case ModernButtonVariant.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: _buildChild(theme),
        );
        break;
      case ModernButtonVariant.danger:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle?.copyWith(
            backgroundColor: WidgetStateProperty.all(
              const Color(0xFFEF4444), // Error color
            ),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
          child: _buildChild(theme),
        );
        break;
    }

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }

  ButtonStyle? _getButtonStyle(BuildContext context) {
    final padding = _getPadding();
    
    return ButtonStyle(
      padding: WidgetStateProperty.all(padding),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevation: WidgetStateProperty.all(0),
    );
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case ModernButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
      case ModernButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
      case ModernButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 18);
    }
  }

  Widget _buildChild(ThemeData theme) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == ModernButtonVariant.primary ||
                    variant == ModernButtonVariant.danger
                ? Colors.white
                : theme.colorScheme.primary,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: _getIconSize()),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge,
          ),
        ],
      );
    }

    return Text(
      label,
      style: theme.textTheme.labelLarge,
    );
  }

  double _getIconSize() {
    switch (size) {
      case ModernButtonSize.small:
        return 16;
      case ModernButtonSize.medium:
        return 20;
      case ModernButtonSize.large:
        return 24;
    }
  }
}

enum ModernButtonVariant {
  primary,
  secondary,
  text,
  danger,
}

enum ModernButtonSize {
  small,
  medium,
  large,
}

