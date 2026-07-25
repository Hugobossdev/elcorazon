import 'package:flutter/material.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';

/// Bouton personnalisé avec animations et feedback visuel améliorés
class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double? width;
  final double? height;
  final double? fontSize;
  final BorderRadius? borderRadius;
  final bool outlined;
  final bool isFullWidth;

  const CustomButton({
    required this.text,
    required this.onPressed,
    super.key,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.width,
    this.height,
    this.fontSize,
    this.borderRadius,
    this.outlined = false,
    this.isFullWidth = true,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: DesignConstants.animationFast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: DesignConstants.curveStandard,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveWidth =
        widget.isFullWidth ? (widget.width ?? double.infinity) : widget.width;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: SizedBox(
          width: effectiveWidth,
          height: widget.height ?? DesignConstants.buttonHeight,
          child: widget.outlined
              ? OutlinedButton.icon(
                  onPressed: widget.isLoading ? null : widget.onPressed,
                  icon: widget.isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.textColor ?? theme.primaryColor,
                            ),
                          ),
                        )
                      : (widget.icon != null
                          ? Icon(
                              widget.icon,
                              color: widget.textColor ?? theme.primaryColor,
                              size: 20,
                            )
                          : const SizedBox.shrink()),
                  label: widget.isLoading
                      ? Text(
                          'Chargement...',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: widget.textColor ?? theme.primaryColor,
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Text(
                          widget.text,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: widget.textColor ?? theme.primaryColor,
                            fontSize: widget.fontSize ?? 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: widget.backgroundColor ?? AppColors.primary,
                      width: 2,
                    ),
                    foregroundColor: widget.textColor ?? AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: widget.borderRadius ??
                          DesignConstants.borderRadiusMedium,
                    ),
                    minimumSize: Size(
                      effectiveWidth ?? double.infinity,
                      DesignConstants.buttonHeight,
                    ),
                    padding: DesignConstants.buttonPadding,
                    elevation: 0,
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: widget.isLoading ? null : widget.onPressed,
                  icon: widget.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : (widget.icon != null
                          ? Icon(
                              widget.icon,
                              color: widget.textColor ?? Colors.white,
                              size: 20,
                            )
                          : const SizedBox.shrink()),
                  label: widget.isLoading
                      ? Text(
                          'Chargement...',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: widget.textColor ?? Colors.white,
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Text(
                          widget.text,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: widget.textColor ?? Colors.white,
                            fontSize: widget.fontSize ?? 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        widget.backgroundColor ?? AppColors.primary,
                    foregroundColor: widget.textColor ?? Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: widget.borderRadius ??
                          DesignConstants.borderRadiusMedium,
                    ),
                    elevation: _isPressed
                        ? DesignConstants.elevationLow
                        : DesignConstants.elevationMedium,
                    shadowColor: (widget.backgroundColor ?? AppColors.primary)
                        .withValues(alpha: 0.3),
                    minimumSize: Size(
                      effectiveWidth ?? double.infinity,
                      DesignConstants.buttonHeight,
                    ),
                    padding: DesignConstants.buttonPadding,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Bouton d'icône personnalisé avec animations améliorées
class CustomIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final String? tooltip;
  final bool showShadow;

  const CustomIconButton({
    required this.icon,
    required this.onPressed,
    super.key,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
    this.tooltip,
    this.showShadow = true,
  });

  @override
  State<CustomIconButton> createState() => _CustomIconButtonState();
}

class _CustomIconButtonState extends State<CustomIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: DesignConstants.animationFast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: DesignConstants.curveStandard,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _handleTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip ?? '',
      waitDuration: const Duration(milliseconds: 500),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? AppColors.primary,
              borderRadius: DesignConstants.borderRadiusMedium,
              boxShadow: widget.showShadow ? DesignConstants.shadowLow : null,
            ),
            child: IconButton(
              onPressed: widget.onPressed,
              icon: Icon(
                widget.icon,
                color: widget.iconColor ?? Colors.white,
                size: widget.size * 0.5,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}
