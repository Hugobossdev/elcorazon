import 'package:flutter/material.dart';
import 'package:elcora_fast/utils/design_constants.dart';

/// Widget de carte avec le style d'auth_screen
/// Utilise borderRadius 24, ombres shadowHigh, et padding cohérent
class AuthStyleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final Border? border;

  const AuthStyleCard({
    required this.child,
    super.key,
    this.padding,
    this.backgroundColor,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignConstants.radiusXLarge),
        boxShadow: DesignConstants.shadowHigh,
        border: border,
      ),
      child: Padding(
        padding: padding ?? DesignConstants.paddingL,
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesignConstants.radiusXLarge),
          child: card,
        ),
      );
    }

    return card;
  }
}
