import 'package:flutter/material.dart';

/// A safe wrapper for IconButton that ensures proper size constraints
/// to prevent "Cannot hit test a render box with no size" errors.
///
/// This widget automatically wraps IconButton in a Container with
/// minimum size constraints, ensuring the button is always hittable.
///
/// Usage:
/// ```dart
/// SafeIconButton(
///   icon: Icon(Icons.close),
///   onPressed: () {},
/// )
/// ```
class SafeIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final double? iconSize;
  final Color? color;
  final Color? disabledColor;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? highlightColor;
  final Color? splashColor;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;
  final double? minWidth;
  final double? minHeight;
  final BoxConstraints? constraints;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool enableFeedback;
  final VisualDensity? visualDensity;

  const SafeIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconSize,
    this.color,
    this.disabledColor,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.tooltip,
    this.padding,
    this.alignment,
    this.minWidth = 48.0,
    this.minHeight = 48.0,
    this.constraints,
    this.autofocus = false,
    this.focusNode,
    this.enableFeedback = true,
    this.visualDensity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          constraints ??
          BoxConstraints(minWidth: minWidth!, minHeight: minHeight!),
      child: IconButton(
        icon: icon,
        onPressed: onPressed,
        iconSize: iconSize,
        color: color,
        disabledColor: disabledColor,
        focusColor: focusColor,
        hoverColor: hoverColor,
        highlightColor: highlightColor,
        splashColor: splashColor,
        tooltip: tooltip,
        padding: padding ?? const EdgeInsets.all(8.0),
        alignment: alignment ?? Alignment.center,
        autofocus: autofocus,
        focusNode: focusNode,
        enableFeedback: enableFeedback,
        visualDensity: visualDensity,
      ),
    );
  }
}

/// A safe wrapper for InkWell that ensures proper size constraints
/// and Material ancestor to prevent hit test errors.
///
/// Usage:
/// ```dart
/// SafeInkWell(
///   onTap: () {},
///   width: 48,
///   height: 48,
///   child: Icon(Icons.add),
/// )
/// ```
class SafeInkWell extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final Color? highlightColor;
  final Color? hoverColor;

  const SafeInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.width,
    this.height,
    this.constraints,
    this.padding,
    this.borderRadius,
    this.splashColor,
    this.highlightColor,
    this.hoverColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      constraints:
          constraints ??
          (width != null || height != null
              ? null
              : const BoxConstraints(minWidth: 48.0, minHeight: 48.0)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          borderRadius: borderRadius,
          splashColor: splashColor,
          highlightColor: highlightColor,
          hoverColor: hoverColor,
          child: Container(
            padding: padding,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
