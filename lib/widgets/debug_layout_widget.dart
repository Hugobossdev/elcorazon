import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as rendering;

/// Widget de debug pour détecter les débordements et problèmes de layout
class DebugLayoutWidget extends StatelessWidget {
  final Widget child;
  final bool showLayoutBorders;
  final bool showSizeIndicators;
  final bool showConstraints;
  final bool enableOverflowDetection;

  const DebugLayoutWidget({
    required this.child, super.key,
    this.showLayoutBorders = false,
    this.showSizeIndicators = false,
    this.showConstraints = false,
    this.enableOverflowDetection = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableOverflowDetection && 
        !showLayoutBorders && 
        !showSizeIndicators && 
        !showConstraints) {
      return child;
    }

    return Builder(
      builder: (context) {
        // Activer les indicateurs de debug Flutter si demandé
        if (showLayoutBorders || showSizeIndicators) {
          rendering.debugPaintSizeEnabled = true;
        }

        return OverflowDetector(
          showConstraints: showConstraints,
          child: child,
        );
      },
    );
  }
}

/// Widget qui détecte les débordements et les affiche visuellement
class OverflowDetector extends StatelessWidget {
  final Widget child;
  final bool showConstraints;

  const OverflowDetector({
    required this.child, super.key,
    this.showConstraints = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: showConstraints 
              ? ConstraintsDebugPainter(constraints: constraints)
              : null,
          child: child,
        );
      },
    );
  }
}

/// Painter pour afficher les contraintes de layout
class ConstraintsDebugPainter extends CustomPainter {
  final BoxConstraints constraints;

  ConstraintsDebugPainter({required this.constraints});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Dessiner le rectangle des contraintes max
    canvas.drawRect(
      Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight),
      paint,
    );

    // Dessiner un rectangle pour la taille réelle
    final actualPaint = Paint()
      ..color = Colors.green.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      actualPaint,
    );

    // Dessiner un rectangle rouge si débordement
    if (size.width > constraints.maxWidth || 
        size.height > constraints.maxHeight) {
      final overflowPaint = Paint()
        ..color = Colors.red.withOpacity(0.5)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        overflowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(ConstraintsDebugPainter oldDelegate) {
    return oldDelegate.constraints != constraints;
  }
}

/// Widget qui enveloppe un widget et détecte les débordements
class SafeLayout extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool enableScrolling;
  final bool showDebugInfo;

  const SafeLayout({
    required this.child, super.key,
    this.padding,
    this.enableScrolling = true,
    this.showDebugInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widget = enableScrolling
            ? SingleChildScrollView(
                padding: padding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                    maxWidth: constraints.maxWidth,
                  ),
                  child: child,
                ),
              )
            : Padding(
                padding: padding ?? EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth,
                    maxHeight: constraints.maxHeight,
                  ),
                  child: child,
                ),
              );

        if (showDebugInfo) {
          return Stack(
            children: [
              widget,
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'W: ${constraints.maxWidth.toStringAsFixed(0)}\n'
                    'H: ${constraints.maxHeight.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return widget;
      },
    );
  }
}

/// Extension pour ajouter facilement la détection de débordement
extension DebugWidgetExtension on Widget {
  /// Enveloppe le widget dans un détecteur de débordement
  Widget withOverflowDetection({bool showDebugInfo = false}) {
    return SafeLayout(
      showDebugInfo: showDebugInfo,
      child: this,
    );
  }

  /// Enveloppe le widget avec des indicateurs de debug
  Widget withDebugLayout({
    bool showLayoutBorders = false,
    bool showSizeIndicators = false,
    bool showConstraints = false,
  }) {
    return DebugLayoutWidget(
      showLayoutBorders: showLayoutBorders,
      showSizeIndicators: showSizeIndicators,
      showConstraints: showConstraints,
      child: this,
    );
  }
}

/// Mixin pour capturer les erreurs de débordement
mixin OverflowErrorHandler<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final errorString = details.exception.toString();
      if (errorString.contains('overflow') ||
          errorString.contains('RenderFlex') ||
          errorString.contains('A RenderFlex overflowed')) {
        debugPrint('⚠️ OVERFLOW DÉTECTÉ: ${details.exception}');
        debugPrint('📍 Stack: ${details.stack}');
        
        // Log dans la console pour debug
        debugPrint('🔍 Vérifiez les widgets Row/Column dans: ${details.context}');
      }
      if (originalOnError != null) {
        originalOnError(details);
      } else {
        FlutterError.presentError(details);
      }
    };
  }
}

/// Widget qui enveloppe un Row avec protection contre débordement
class DebugRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final bool showDebugInfo;

  const DebugRow({
    required this.children, super.key,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.showDebugInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final row = Row(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          mainAxisSize: mainAxisSize,
          textDirection: textDirection,
          verticalDirection: verticalDirection,
          children: children,
        );

        if (showDebugInfo) {
          return Stack(
            children: [
              row,
              Positioned(
                top: -20,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Row - MaxW: ${constraints.maxWidth.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return row;
      },
    );
  }
}

/// Widget qui enveloppe un Column avec protection contre débordement
class DebugColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final bool showDebugInfo;

  const DebugColumn({
    required this.children, super.key,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.showDebugInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = Column(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          mainAxisSize: mainAxisSize,
          textDirection: textDirection,
          verticalDirection: verticalDirection,
          children: children,
        );

        if (showDebugInfo) {
          return Stack(
            children: [
              column,
              Positioned(
                top: -20,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Column - MaxH: ${constraints.maxHeight.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return column;
      },
    );
  }
}

/// Configuration globale du debug
class DebugConfig {
  static bool _isDebugMode = false;
  static bool _showLayoutBorders = false;
  static bool _showSizeIndicators = false;
  static bool _showConstraints = false;
  static bool _captureOverflowErrors = true;

  static bool get isDebugMode => _isDebugMode;
  static bool get showLayoutBorders => _showLayoutBorders;
  static bool get showSizeIndicators => _showSizeIndicators;
  static bool get showConstraints => _showConstraints;
  static bool get captureOverflowErrors => _captureOverflowErrors;

  /// Activer le mode debug complet
  static void enableDebugMode({
    bool showLayoutBorders = true,
    bool showSizeIndicators = true,
    bool showConstraints = false,
    bool captureOverflowErrors = true,
  }) {
    _isDebugMode = true;
    _showLayoutBorders = showLayoutBorders;
    _showSizeIndicators = showSizeIndicators;
    _showConstraints = showConstraints;
    _captureOverflowErrors = captureOverflowErrors;

    if (_showLayoutBorders || _showSizeIndicators) {
      rendering.debugPaintSizeEnabled = true;
    }

    if (_captureOverflowErrors) {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        final errorString = details.exception.toString();
        if (errorString.contains('overflow') ||
            errorString.contains('RenderFlex') ||
            errorString.contains('A RenderFlex overflowed')) {
          debugPrint('🚨 DÉBORDEMENT DÉTECTÉ:');
          debugPrint('   Type: ${details.exception.runtimeType}');
          debugPrint('   Message: ${details.exception}');
          debugPrint('   Contexte: ${details.context}');
          if (details.stack != null) {
            debugPrint('   Stack trace disponible');
          }
        }
        if (originalOnError != null) {
          originalOnError(details);
        } else {
          FlutterError.presentError(details);
        }
      };
    }
  }

  /// Désactiver le mode debug
  static void disableDebugMode() {
    _isDebugMode = false;
    _showLayoutBorders = false;
    _showSizeIndicators = false;
    _showConstraints = false;
    _captureOverflowErrors = false;
    rendering.debugPaintSizeEnabled = false;
  }
}

