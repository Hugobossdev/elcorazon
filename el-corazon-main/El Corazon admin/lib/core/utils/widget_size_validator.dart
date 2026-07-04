import 'package:flutter/material.dart';

/// Validateur pour s'assurer que tous les widgets interactifs ont des contraintes de taille
class WidgetSizeValidator {
  WidgetSizeValidator._();

  /// Vérifie et corrige un Container pour qu'il ait des contraintes de taille
  static BoxConstraints ensureConstraints(BoxConstraints? existing) {
    if (existing != null) {
      // Si des contraintes existent déjà, s'assurer qu'elles ont au moins minHeight
      return BoxConstraints(
        minWidth: existing.minWidth > 0 ? existing.minWidth : 48,
        minHeight: existing.minHeight > 0 ? existing.minHeight : 48,
        maxWidth: existing.maxWidth,
        maxHeight: existing.maxHeight,
      );
    }
    // Contraintes par défaut
    return const BoxConstraints(
      minWidth: 48,
      minHeight: 48,
    );
  }

  /// Crée un Container sécurisé avec contraintes garanties
  static Widget safeContainer({
    required Widget child,
    BoxConstraints? constraints,
    EdgeInsetsGeometry? padding,
    Color? color,
    Decoration? decoration,
    double? width,
    double? height,
  }) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      constraints: ensureConstraints(constraints),
      padding: padding,
      color: color,
      decoration: decoration,
      child: child,
    );
  }

  /// Crée un InkWell sécurisé avec Material et contraintes garanties
  static Widget safeInkWell({
    required VoidCallback? onTap,
    required Widget child,
    BorderRadius? borderRadius,
    BoxConstraints? constraints,
    EdgeInsetsGeometry? padding,
    Color? materialColor,
  }) {
    if (onTap == null) return child;

    Widget content = child;
    
    // Ajouter padding si nécessaire
    if (padding != null) {
      content = Padding(padding: padding, child: content);
    }

    // Envelopper dans un Container avec contraintes
    content = safeContainer(
      constraints: constraints,
      child: content,
    );

    return Material(
      color: materialColor ?? Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: content,
      ),
    );
  }

  /// Crée un Row sécurisé avec mainAxisSize.min
  static Widget safeRow({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.center,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.min,
  }) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children,
    );
  }

  /// Crée un Column sécurisé avec mainAxisSize.min
  static Widget safeColumn({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.min,
  }) {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children,
    );
  }
}




