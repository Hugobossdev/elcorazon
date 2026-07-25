import 'package:flutter/material.dart';
import 'package:elcora_fast/utils/design_constants.dart';

/// Champ de texte personnalisé avec animations et feedback visuel améliorés
class CustomTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;
  final int maxLines;
  final bool showLabel;

  const CustomTextField({
    required this.label,
    required this.controller,
    super.key,
    this.hint,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.showLabel = true,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField>
    with SingleTickerProviderStateMixin {
  bool _obscureText = true;
  bool _isFocused = false;
  late AnimationController _focusAnimationController;
  late Animation<double> _focusAnimation;

  @override
  void initState() {
    super.initState();
    _focusAnimationController = AnimationController(
      vsync: this,
      duration: DesignConstants.animationNormal,
    );
    _focusAnimation = CurvedAnimation(
      parent: _focusAnimationController,
      curve: DesignConstants.curveStandard,
    );
  }

  @override
  void dispose() {
    _focusAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel)
          AnimatedDefaultTextStyle(
            duration: DesignConstants.animationFast,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: _isFocused ? FontWeight.w600 : FontWeight.w500,
              color: _isFocused
                  ? theme.primaryColor
                  : theme.colorScheme.onSurface,
            ) ?? const TextStyle(),
            child: Text(widget.label),
          ),
        if (widget.showLabel) const SizedBox(height: DesignConstants.spacingS),
        Focus(
          onFocusChange: (hasFocus) {
            setState(() => _isFocused = hasFocus);
            if (hasFocus) {
              _focusAnimationController.forward();
            } else {
              _focusAnimationController.reverse();
            }
          },
          child: AnimatedBuilder(
            animation: _focusAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: DesignConstants.borderRadiusMedium,
                  boxShadow: _isFocused
                      ? [
                          BoxShadow(
                            color: theme.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: TextFormField(
                  controller: widget.controller,
                  obscureText: widget.isPassword ? _obscureText : false,
                  keyboardType: widget.keyboardType,
                  validator: widget.validator,
                  onChanged: widget.onChanged,
                  enabled: widget.enabled,
                  maxLines: widget.maxLines,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    prefixIcon: widget.prefixIcon != null
                        ? Icon(
                            widget.prefixIcon,
                            color: _isFocused
                                ? theme.primaryColor
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                          )
                        : null,
                    suffixIcon: widget.isPassword
                        ? IconButton(
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          )
                        : widget.suffixIcon != null
                            ? IconButton(
                                onPressed: widget.onSuffixTap,
                                icon: Icon(
                                  widget.suffixIcon,
                                  color: theme.primaryColor,
                                ),
                              )
                            : null,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DesignConstants.spacingM,
                      vertical: DesignConstants.spacingM,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: DesignConstants.borderRadiusMedium,
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: DesignConstants.borderRadiusMedium,
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: DesignConstants.borderRadiusMedium,
                      borderSide: BorderSide(
                        color: theme.primaryColor,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: DesignConstants.borderRadiusMedium,
                      borderSide: BorderSide(
                        color: theme.colorScheme.error,
                        width: 1.5,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: DesignConstants.borderRadiusMedium,
                      borderSide: BorderSide(
                        color: theme.colorScheme.error,
                        width: 2,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: DesignConstants.borderRadiusMedium,
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Champ de recherche personnalisé avec animations améliorées
class SearchTextField extends StatefulWidget {
  final String hint;
  final TextEditingController controller;
  final void Function(String)? onChanged;
  final VoidCallback? onClear;

  const SearchTextField({
    required this.hint,
    required this.controller,
    super.key,
    this.onChanged,
    this.onClear,
  });

  @override
  State<SearchTextField> createState() => _SearchTextFieldState();
}

class _SearchTextFieldState extends State<SearchTextField>
    with SingleTickerProviderStateMixin {
  bool _isFocused = false;
  late AnimationController _focusAnimationController;
  late Animation<double> _focusAnimation;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusAnimationController = AnimationController(
      vsync: this,
      duration: DesignConstants.animationNormal,
    );
    _focusAnimation = CurvedAnimation(
      parent: _focusAnimationController,
      curve: DesignConstants.curveStandard,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusAnimationController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = widget.controller.text.isNotEmpty;

    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
        if (hasFocus) {
          _focusAnimationController.forward();
        } else {
          _focusAnimationController.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _focusAnimation,
        builder: (context, child) {
          return Container(
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              borderRadius: DesignConstants.borderRadiusXLarge,
              border: Border.all(
                color: _isFocused
                    ? theme.primaryColor
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
                width: _isFocused ? 2 : 1,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: TextField(
              controller: widget.controller,
              onChanged: widget.onChanged,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: _isFocused
                      ? theme.primaryColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                suffixIcon: hasText
                    ? IconButton(
                        onPressed: widget.onClear ??
                            () {
                              widget.controller.clear();
                              widget.onChanged?.call('');
                            },
                        icon: Icon(
                          Icons.clear_rounded,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        tooltip: 'Effacer',
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DesignConstants.spacingM,
                  vertical: DesignConstants.spacingS,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
