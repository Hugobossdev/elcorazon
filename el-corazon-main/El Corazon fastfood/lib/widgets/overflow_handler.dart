import 'package:flutter/material.dart';

/// Widget qui gère les erreurs de débordement de manière élégante
class OverflowHandler extends StatelessWidget {
  final Widget child;
  final String? errorMessage;
  final bool showErrorBanner;

  const OverflowHandler({
    required this.child, super.key,
    this.errorMessage,
    this.showErrorBanner = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Mixin pour gérer les débordements dans les StatefulWidget
mixin OverflowMixin<T extends StatefulWidget> on State<T> {
  bool _hasOverflow = false;
  String? _overflowMessage;

  void handleOverflow(String message) {
    if (!_hasOverflow) {
      setState(() {
        _hasOverflow = true;
        _overflowMessage = message;
      });
    }
  }

  void clearOverflow() {
    if (_hasOverflow) {
      setState(() {
        _hasOverflow = false;
        _overflowMessage = null;
      });
    }
  }

  Widget buildWithOverflowHandling(Widget child) {
    return Stack(
      children: [
        child,
        if (_hasOverflow && _overflowMessage != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.withValues(alpha: 0.8),
              child: Text(
                _overflowMessage!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Widget qui détecte et corrige automatiquement les débordements
class AutoOverflowFix extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AutoOverflowFix({
    required this.child, super.key,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// Extension pour faciliter l'utilisation des widgets sécurisés
extension SafeWidgetExtension on Widget {
  /// Enveloppe le widget dans un gestionnaire de débordement
  Widget safeColumn() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(),
        child: this,
      ),
    );
  }

  /// Enveloppe le widget dans un gestionnaire de débordement avec padding
  Widget safeColumnWithPadding(EdgeInsetsGeometry padding) {
    return SingleChildScrollView(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(),
        child: this,
      ),
    );
  }
}
