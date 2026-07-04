import 'package:flutter/material.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget button = outlined
          ? OutlinedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textColor ?? theme.primaryColor,
                      ),
                    )
                  : (icon != null
                      ? Icon(icon, color: textColor ?? theme.primaryColor)
                      : const SizedBox.shrink()),
              label: isLoading
                  ? Text('Chargement...')
                  : Text(
                      text,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: textColor ?? theme.primaryColor,
                        fontSize: fontSize,
                      ),
                    ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: backgroundColor ?? theme.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: borderRadius ?? BorderRadius.circular(12),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textColor ?? Colors.white,
                      ),
                    )
                  : (icon != null
                      ? Icon(icon, color: textColor ?? Colors.white)
                      : const SizedBox.shrink()),
              label: isLoading
                  ? Text('Chargement...')
                  : Text(
                      text,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: textColor ?? Colors.white,
                        fontSize: fontSize,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor ?? theme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: borderRadius ?? BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            );

    // Wrap in SizedBox only if width or height is specified
    // Otherwise, let the button size itself naturally
    if (width != null || height != null) {
      return SizedBox(
        width: width,
        height: height ?? 50,
        child: button,
      );
    }
    
    // If no width constraint, use minimum height
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: height ?? 50,
      ),
      child: button,
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
          color: backgroundColor ?? theme.primaryColor,
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
