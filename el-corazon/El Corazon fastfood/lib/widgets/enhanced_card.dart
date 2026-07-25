import 'package:flutter/material.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/theme.dart';

/// Carte améliorée avec animations et feedback visuel
class EnhancedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final bool showShadow;
  final bool enableAnimation;

  const EnhancedCard({
    required this.child,
    super.key,
    this.onTap,
    this.margin,
    this.padding,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.showShadow = true,
    this.enableAnimation = true,
  });

  @override
  State<EnhancedCard> createState() => _EnhancedCardState();
}

class _EnhancedCardState extends State<EnhancedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.enableAnimation) {
      _animationController = AnimationController(
        vsync: this,
        duration: DesignConstants.animationFast,
      );
      _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: DesignConstants.curveStandard,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (widget.enableAnimation) {
      _animationController.dispose();
    }
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null && widget.enableAnimation) {
      setState(() => _isPressed = true);
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed && widget.enableAnimation) {
      setState(() => _isPressed = false);
      _animationController.reverse();
      widget.onTap?.call();
    } else if (widget.onTap != null) {
      widget.onTap?.call();
    }
  }

  void _handleTapCancel() {
    if (_isPressed && widget.enableAnimation) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveElevation = _isPressed
        ? (widget.elevation ?? DesignConstants.elevationLow) * 0.5
        : (widget.elevation ?? DesignConstants.elevationLow);

    final Widget card = Container(
      margin: widget.margin ??
          const EdgeInsets.symmetric(
            horizontal: DesignConstants.spacingM,
            vertical: DesignConstants.spacingS,
          ),
      decoration: BoxDecoration(
        color: widget.backgroundColor ??
            theme.cardTheme.color ??
            AppColors.surfaceElevated,
        borderRadius: widget.borderRadius ?? DesignConstants.borderRadiusLarge,
        boxShadow: widget.showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: effectiveElevation * 2,
                  offset: Offset(0, effectiveElevation),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius:
              widget.borderRadius ?? DesignConstants.borderRadiusLarge,
          child: Padding(
            padding: widget.padding ?? DesignConstants.cardPadding,
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.enableAnimation && widget.onTap != null) {
      return GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: card,
        ),
      );
    }

    return card;
  }
}

/// Carte avec gradient
class GradientCard extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final VoidCallback? onTap;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;

  const GradientCard({
    required this.child,
    required this.gradientColors,
    super.key,
    this.onTap,
    this.margin,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ??
          const EdgeInsets.symmetric(
            horizontal: DesignConstants.spacingM,
            vertical: DesignConstants.spacingS,
          ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius ?? DesignConstants.borderRadiusLarge,
        boxShadow: DesignConstants.shadowMedium,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? DesignConstants.borderRadiusLarge,
          child: Padding(
            padding: padding ?? DesignConstants.cardPadding,
            child: child,
          ),
        ),
      ),
    );
  }
}
