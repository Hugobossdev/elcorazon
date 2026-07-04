import 'package:flutter/material.dart';

/// Helper pour créer des widgets interactifs sécurisés avec garantie de taille
class SafeWidgetHelper {
  SafeWidgetHelper._();

  /// Crée un InkWell sécurisé avec garantie de taille
  static Widget safeInkWell({
    required VoidCallback? onTap,
    required Widget child,
    BorderRadius? borderRadius,
    BoxConstraints? constraints,
    EdgeInsetsGeometry? padding,
  }) {
    if (onTap == null) return child;

    Widget content = child;
    
    // Ajouter padding si nécessaire
    if (padding != null) {
      content = Padding(padding: padding, child: content);
    }

    // Ajouter contraintes si nécessaire
    if (constraints != null || padding == null) {
      content = Container(
        width: double.infinity,
        constraints: constraints ?? const BoxConstraints(minHeight: 48),
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: content,
      ),
    );
  }

  /// Crée un Container sécurisé pour Row/Column avec mainAxisSize.min
  static Widget safeContainerForMinSize({
    required Widget child,
    BoxConstraints? constraints,
    EdgeInsetsGeometry? padding,
    Color? color,
    Decoration? decoration,
  }) {
    return Container(
      width: double.infinity,
      constraints: constraints ?? const BoxConstraints(minHeight: 48),
      padding: padding,
      color: color,
      decoration: decoration,
      child: child,
    );
  }
}


















