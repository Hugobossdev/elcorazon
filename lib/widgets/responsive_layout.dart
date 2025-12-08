import 'package:flutter/material.dart';

/// Widget qui gère automatiquement les débordements et s'adapte à la taille de l'écran
class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool enableScrolling;

  const ResponsiveLayout({
    required this.child, super.key,
    this.padding,
    this.enableScrolling = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return enableScrolling
            ? SingleChildScrollView(
                padding: padding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: child,
                ),
              )
            : Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              );
      },
    );
  }
}

/// Widget qui détecte et corrige automatiquement les débordements
class AutoOverflowFix extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxHeight;

  const AutoOverflowFix({
    required this.child, super.key,
    this.padding,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = maxHeight ?? constraints.maxHeight;

        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: availableHeight,
              maxHeight: availableHeight,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
