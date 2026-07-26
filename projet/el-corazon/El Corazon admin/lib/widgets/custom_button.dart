import 'package:flutter/material.dart';

enum ButtonVariant {
  filled,
  outlined,
  text,
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double? width;
  final double? height;
  final double? fontSize;
  final BorderRadius? borderRadius;
  final bool outlined;
  final ButtonVariant variant;
  final Color? color;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.width,
    this.height,
    this.fontSize,
    this.borderRadius,
    this.outlined = false,
    this.variant = ButtonVariant.filled,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? backgroundColor ?? theme.colorScheme.primary;
    final effectiveTextColor = textColor ??
        (variant == ButtonVariant.filled ? Colors.white : effectiveColor);

    Widget button;

    switch (variant) {
      case ButtonVariant.filled:
        if (icon == null && !isLoading) {
          button = ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: effectiveColor,
              shape: RoundedRectangleBorder(
                borderRadius: borderRadius ?? BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _buildLabel(effectiveTextColor),
          );
        } else {
          button = ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: _buildIcon(effectiveTextColor),
            label: _buildLabel(effectiveTextColor),
            style: ElevatedButton.styleFrom(
              backgroundColor: effectiveColor,
              shape: RoundedRectangleBorder(
                borderRadius: borderRadius ?? BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          );
        }
        break;
      case ButtonVariant.outlined:
        if (icon == null && !isLoading) {
          button = OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: effectiveColor),
              shape: RoundedRectangleBorder(
                borderRadius: borderRadius ?? BorderRadius.circular(12),
              ),
            ),
            child: _buildLabel(effectiveTextColor),
          );
        } else {
          button = OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: _buildIcon(effectiveTextColor),
            label: _buildLabel(effectiveTextColor),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: effectiveColor),
              shape: RoundedRectangleBorder(
                borderRadius: borderRadius ?? BorderRadius.circular(12),
              ),
            ),
          );
        }
        break;
      case ButtonVariant.text:
        if (icon == null && !isLoading) {
          button = TextButton(
            onPressed: isLoading ? null : onPressed,
            style: TextButton.styleFrom(
              foregroundColor: effectiveColor,
              shape: RoundedRectangleBorder(
                borderRadius: borderRadius ?? BorderRadius.circular(12),
              ),
            ),
            child: _buildLabel(effectiveTextColor),
          );
        } else {
          button = TextButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: _buildIcon(effectiveTextColor),
            label: _buildLabel(effectiveTextColor),
            style: TextButton.styleFrom(
              foregroundColor: effectiveColor,
              shape: RoundedRectangleBorder(
                borderRadius: borderRadius ?? BorderRadius.circular(12),
              ),
            ),
          );
        }
        break;
    }

    // IMPORTANT: Ne pas utiliser double.infinity si width n'est pas spécifié
    // car cela cause des problèmes dans les Row sans Expanded
    // Si width est null, laisser le parent (comme Expanded) gérer la largeur
    if (width != null) {
      return SizedBox(
        width: width,
        height: height ?? 50,
        child: button,
      );
    } else {
      return SizedBox(
        height: height ?? 50,
        child: button,
      );
    }
  }

  Widget _buildIcon(Color iconColor) {
    if (isLoading) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: iconColor,
        ),
      );
    }
    return icon != null
        ? Icon(icon, color: iconColor)
        : const SizedBox.shrink();
  }

  Widget _buildLabel(Color textColor) {
    return isLoading
        ? const Text('Chargement...')
        : Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
            ),
          );
  }
}

class CustomIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final String? tooltip;

  const CustomIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: iconColor ?? Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}
