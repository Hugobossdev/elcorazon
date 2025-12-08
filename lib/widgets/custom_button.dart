import 'package:flutter/material.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';

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
    required this.text, required this.onPressed, super.key,
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

    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 50,
      child: outlined
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
                  ? const Text('Chargement...')
                  : Text(
                      text,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: textColor ?? theme.primaryColor,
                        fontSize: fontSize,
                      ),
                    ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: backgroundColor ?? AppColors.primary, width: 2,),
                foregroundColor: textColor ?? AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      borderRadius ?? DesignConstants.borderRadiusMedium,
                ),
                minimumSize: Size(
                    width ?? double.infinity, DesignConstants.buttonHeight,),
                padding: DesignConstants.buttonPadding,
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
                  ? const Text('Chargement...')
                  : Text(
                      text,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: textColor ?? Colors.white,
                        fontSize: fontSize,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor ?? AppColors.primary,
                foregroundColor: textColor ?? Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      borderRadius ?? DesignConstants.borderRadiusMedium,
                ),
                elevation: DesignConstants.elevationLow,
                minimumSize: Size(
                    width ?? double.infinity, DesignConstants.buttonHeight,),
                padding: DesignConstants.buttonPadding,
              ),
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
    required this.icon, required this.onPressed, super.key,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.primary,
          borderRadius: DesignConstants.borderRadiusMedium,
          boxShadow: DesignConstants.shadowLow,
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
