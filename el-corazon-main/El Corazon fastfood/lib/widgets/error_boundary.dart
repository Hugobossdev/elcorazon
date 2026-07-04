import 'package:flutter/material.dart';

/// Widget qui capture et gère les erreurs de rendu
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? fallback;
  final Function(Object error, StackTrace stackTrace)? onError;

  const ErrorBoundary({
    required this.child, super.key,
    this.fallback,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Écouter les erreurs de rendu
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('RenderFlex overflowed')) {
        setState(() {
          _hasError = true;
        });
        widget.onError?.call(details.exception, details.stack!);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallback ?? _buildDefaultFallback();
    }
    return widget.child;
  }

  Widget _buildDefaultFallback() {
    return Material(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning,
              size: 48,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Erreur d\'affichage détectée',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'L\'interface s\'adapte automatiquement',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                });
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mixin pour gérer les erreurs de débordement dans les StatefulWidget
mixin OverflowErrorMixin<T extends StatefulWidget> on State<T> {
  bool _hasOverflowError = false;

  void handleOverflowError() {
    if (!_hasOverflowError) {
      setState(() {
        _hasOverflowError = true;
      });
    }
  }

  void clearOverflowError() {
    if (_hasOverflowError) {
      setState(() {
        _hasOverflowError = false;
      });
    }
  }

  Widget buildWithOverflowHandling(Widget child) {
    return _hasOverflowError ? SingleChildScrollView(child: child) : child;
  }
}

/// Widget qui enveloppe automatiquement le contenu dans un ScrollView si nécessaire
class AutoScrollWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  const AutoScrollWrapper({
    required this.child, super.key,
    this.padding,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
          physics: physics,
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
