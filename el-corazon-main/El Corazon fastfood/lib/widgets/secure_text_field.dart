import 'package:flutter/material.dart';
import 'package:elcora_fast/utils/input_sanitizer.dart';
import 'package:elcora_fast/theme.dart';

/// 🛡️ Champ de texte sécurisé avec protection contre les injections SQL et XSS
class SecureTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final FocusNode? focusNode;
  final String? initialValue;
  final bool required;
  final String? Function(String?)? customValidator;
  final bool strictValidation; // Mode strict (bloque plus de choses)
  final String? fieldName; // Nom du champ pour les messages d'erreur

  const SecureTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.initialValue,
    this.required = false,
    this.customValidator,
    this.strictValidation = true,
    this.fieldName,
  });

  @override
  State<SecureTextField> createState() => _SecureTextFieldState();
}

class _SecureTextFieldState extends State<SecureTextField> {
  late TextEditingController _controller;
  String? _errorMessage;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  String? _validate(String? value) {
    // Validation requise
    if (widget.required && (value == null || value.trim().isEmpty)) {
      return 'Ce champ est requis';
    }

    if (value == null || value.isEmpty) {
      return null; // Champ vide et non requis = OK
    }

    // 🛡️ Protection contre les injections SQL et XSS
    final sanitizeResult = InputSanitizer.validateAndSanitize(
      value,
      fieldName: widget.fieldName ?? widget.label ?? 'Ce champ',
      strict: widget.strictValidation,
    );

    if (!sanitizeResult.isValid) {
      return sanitizeResult.errorMessage;
    }

    // Validation personnalisée
    if (widget.customValidator != null) {
      return widget.customValidator!(value);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.suffixIcon,
        errorText: _hasError ? _errorMessage : null,
        errorMaxLines: 3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: widget.enabled
            ? AppColors.surfaceElevated
            : AppColors.surfaceVariant,
      ),
      validator: _validate,
      onChanged: (value) {
        // Réinitialiser l'erreur lors de la modification
        if (_hasError) {
          setState(() {
            _hasError = false;
            _errorMessage = null;
          });
        }

        // Sanitizer automatiquement la valeur
        final sanitizeResult = InputSanitizer.validateAndSanitize(
          value,
          fieldName: widget.fieldName ?? widget.label ?? 'Ce champ',
          strict: widget.strictValidation,
        );

        if (sanitizeResult.isValid && sanitizeResult.sanitizedValue != null) {
          // Mettre à jour la valeur sanitizée si différente
          if (sanitizeResult.sanitizedValue != value) {
            final cursorPosition = _controller.selection.start;
            _controller.value = TextEditingValue(
              text: sanitizeResult.sanitizedValue!,
              selection: TextSelection.collapsed(
                offset: cursorPosition > sanitizeResult.sanitizedValue!.length
                    ? sanitizeResult.sanitizedValue!.length
                    : cursorPosition,
              ),
            );
          }
        } else {
          // Afficher l'erreur
          setState(() {
            _hasError = true;
            _errorMessage = sanitizeResult.errorMessage;
          });
        }

        widget.onChanged?.call(_controller.text);
      },
      onFieldSubmitted: widget.onSubmitted,
    );
  }
}











