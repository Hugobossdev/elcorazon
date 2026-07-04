import 'package:flutter/material.dart';
import '../constants/admin_constants.dart';

/// Widget de base pour tous les widgets interactifs admin
/// Garantit que tous les widgets ont des contraintes de taille pour éviter les erreurs de hit testing
class AdminInteractiveWidget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final BorderRadius? borderRadius;

  const AdminInteractiveWidget({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.constraints,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget widget = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AdminConstants.cardPadding),
      constraints: constraints ??
          const BoxConstraints(
            minHeight: 50,
          ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(AdminConstants.borderRadiusMD),
          child: widget,
        ),
      );
    }

    return widget;
  }
}

/// Card admin avec garantie de taille
class AdminSafeCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? elevation;
  final Color? color;
  final BorderRadius? borderRadius;

  const AdminSafeCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding,
    this.elevation,
    this.color,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AdminConstants.cardPadding),
      constraints: const BoxConstraints(
        minHeight: 100,
      ),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardColor,
        borderRadius: borderRadius ?? BorderRadius.circular(AdminConstants.borderRadiusMD),
      ),
      child: child,
    );

    if (onTap != null) {
      return Card(
        margin: margin ?? EdgeInsets.zero,
        elevation: elevation ?? AdminConstants.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(AdminConstants.borderRadiusMD),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius ?? BorderRadius.circular(AdminConstants.borderRadiusMD),
            child: cardContent,
          ),
        ),
      );
    }

    return Card(
      margin: margin ?? EdgeInsets.zero,
      elevation: elevation ?? AdminConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(AdminConstants.borderRadiusMD),
      ),
      child: cardContent,
    );
  }
}

/// Button admin avec garantie de taille
class AdminSafeButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final double? height;
  final bool isOutlined;

  const AdminSafeButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.textColor,
    this.height,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonHeight = height ?? 48.0;
    
    if (isOutlined) {
      return Container(
        constraints: BoxConstraints(
          minHeight: buttonHeight,
          minWidth: 100,
        ),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: color ?? Theme.of(context).colorScheme.primary,
            minimumSize: Size(0, buttonHeight),
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        minHeight: buttonHeight,
        minWidth: 100,
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Theme.of(context).colorScheme.primary,
          foregroundColor: textColor ?? Colors.white,
          minimumSize: Size(0, buttonHeight),
        ),
      ),
    );
  }
}

/// ListTile admin avec garantie de taille
class AdminSafeListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;

  const AdminSafeListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 56,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, color: color),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(
        minHeight: 56,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, color: color),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}


















