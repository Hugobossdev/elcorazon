import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/form_validation_service.dart';
import 'package:elcora_fast/theme.dart';
// import 'enhanced_button.dart'; // Supprimé

/// Champ de texte avec validation intégrée
class ValidatedTextField extends StatefulWidget {
  final String fieldName;
  final String formName;
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

  const ValidatedTextField({
    required this.fieldName, required this.formName, super.key,
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
  });

  @override
  State<ValidatedTextField> createState() => _ValidatedTextFieldState();
}

class _ValidatedTextFieldState extends State<ValidatedTextField>
    with TickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _errorAnimation;

  bool _isFocused = false;
  String? _errorMessage;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();

    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _errorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ),);

    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _onTextChange() {
    widget.onChanged?.call(_controller.text);
    _validateField();
  }

  Future<void> _validateField() async {
    final validationService =
        Provider.of<FormValidationService>(context, listen: false);
    final result = validationService.validateField(
      widget.formName,
      widget.fieldName,
      _controller.text,
    );

    setState(() {
      _hasError = !result.isValid;
      _errorMessage = result.errorMessage;
    });

    if (_hasError) {
      unawaited(_animationController.forward());
    } else {
      unawaited(_animationController.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        AnimatedBuilder(
          animation: _errorAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _hasError
                        ? Colors.red.withValues(alpha: 0.1)
                        : (_isFocused
                            ? const Color(0xFFE53E3E).withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05)),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: widget.keyboardType,
                obscureText: widget.obscureText,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                enabled: widget.enabled,
                onSubmitted: widget.onSubmitted,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: widget.prefixIcon,
                  suffixIcon: widget.suffixIcon,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _hasError
                          ? Colors.red
                          : (_isFocused
                              ? const Color(0xFFE53E3E)
                              : Colors.grey[300]!),
                      width: _isFocused ? 2 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE53E3E),
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 2,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: widget.enabled ? Colors.white : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            );
          },
        ),
        if (_hasError && _errorMessage != null)
          AnimatedBuilder(
            animation: _errorAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _errorAnimation.value,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Formulaire avec validation intégrée
class ValidatedForm extends StatefulWidget {
  final String formName;
  final Map<String, dynamic> initialValues;
  final Map<String, TextEditingController>? controllers;
  final Widget Function(BuildContext context, Map<String, dynamic> values,
      Map<String, String> errors,) builder;
  final Function(Map<String, dynamic> values)? onSubmit;
  final Function(Map<String, dynamic> values)? onChanged;
  final bool autoValidate;
  final bool enabled;

  const ValidatedForm({
    required this.formName, required this.builder, super.key,
    this.initialValues = const {},
    this.controllers,
    this.onSubmit,
    this.onChanged,
    this.autoValidate = false,
    this.enabled = true,
  });

  @override
  State<ValidatedForm> createState() => _ValidatedFormState();
}

class _ValidatedFormState extends State<ValidatedForm> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _values = {};
  final Map<String, String> _errors = {};
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isValidating = false;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    // Dispose controllers that we created
    for (final controller in _controllers.values) {
      if (widget.controllers == null ||
          !widget.controllers!.values.contains(controller)) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _initializeForm() {
    // Initialize values
    _values.addAll(widget.initialValues);

    // Initialize controllers
    if (widget.controllers != null) {
      _controllers.addAll(widget.controllers!);
    }

    // Create controllers for fields that don't have them
    final validationService =
        Provider.of<FormValidationService>(context, listen: false);
    final config = validationService.getValidationConfig(widget.formName);

    if (config != null) {
      for (final field in config.fields) {
        if (!_controllers.containsKey(field.fieldName)) {
          _controllers[field.fieldName] = TextEditingController(
            text: _values[field.fieldName]?.toString() ?? '',
          );
        }
      }
    }
  }

  Future<void> _validateForm() async {
    if (!mounted) return;

    setState(() {
      _isValidating = true;
    });

    try {
      final validationService =
          Provider.of<FormValidationService>(context, listen: false);
      final result =
          await validationService.validateForm(widget.formName, _values);

      if (mounted) {
        setState(() {
          _errors.clear();
          _errors.addAll(result.fieldErrors);
          _isValid = result.isValid;
          _isValidating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  Future<bool> _submitForm() async {
    if (!widget.enabled) return false;

    // Validate form
    await _validateForm();

    if (!_isValid) {
      return false;
    }

    // Submit form
    widget.onSubmit?.call(_values);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          widget.builder(context, _values, _errors),
          if (_isValidating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  /// Valider le formulaire
  Future<bool> validate() async {
    await _validateForm();
    return _isValid;
  }

  /// Soumettre le formulaire
  Future<bool> submit() async {
    return await _submitForm();
  }

  /// Obtenir les valeurs du formulaire
  Map<String, dynamic> get values => Map.from(_values);

  /// Obtenir les erreurs du formulaire
  Map<String, String> get errors => Map.from(_errors);

  /// Obtenir le contrôleur d'un champ
  TextEditingController? getController(String fieldName) {
    return _controllers[fieldName];
  }

  /// Définir la valeur d'un champ
  void setValue(String fieldName, dynamic value) {
    setState(() {
      _values[fieldName] = value;
      _controllers[fieldName]?.text = value?.toString() ?? '';
    });
  }

  /// Effacer le formulaire
  void clear() {
    setState(() {
      _values.clear();
      _errors.clear();
      for (final controller in _controllers.values) {
        controller.clear();
      }
    });
  }
}

/// Widget de formulaire d'authentification avec validation
class AuthForm extends StatelessWidget {
  final bool isLogin;
  final Function(Map<String, dynamic> values)? onSubmit;
  final Function(bool isLogin)? onModeChanged;

  const AuthForm({
    required this.isLogin, super.key,
    this.onSubmit,
    this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValidatedForm(
      formName: 'auth',
      builder: (context, values, errors) {
        return Column(
          children: [
            // Sélecteur de mode
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onModeChanged?.call(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isLogin
                              ? const Color(0xFFE53E3E)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Connexion',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isLogin ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onModeChanged?.call(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !isLogin
                              ? const Color(0xFFE53E3E)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Inscription',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: !isLogin ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Champs du formulaire
            if (!isLogin) ...[
              ValidatedTextField(
                fieldName: 'name',
                formName: 'auth',
                label: 'Nom complet',
                hint: 'Entrez votre nom complet',
                prefixIcon: const Icon(Icons.person),
                onChanged: (value) {
                  // La validation se fait automatiquement
                },
              ),
              const SizedBox(height: 16),
              ValidatedTextField(
                fieldName: 'phone',
                formName: 'auth',
                label: 'Téléphone',
                hint: 'Entrez votre numéro de téléphone',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone),
                onChanged: (value) {
                  // La validation se fait automatiquement
                },
              ),
              const SizedBox(height: 16),
            ],

            ValidatedTextField(
              fieldName: 'email',
              formName: 'auth',
              label: 'Email',
              hint: 'Entrez votre email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.email),
              onChanged: (value) {
                // La validation se fait automatiquement
              },
            ),
            const SizedBox(height: 16),

            ValidatedTextField(
              fieldName: 'password',
              formName: 'auth',
              label: 'Mot de passe',
              hint: 'Entrez votre mot de passe',
              obscureText: true,
              prefixIcon: const Icon(Icons.lock),
              onChanged: (value) {
                // La validation se fait automatiquement
              },
            ),
            const SizedBox(height: 24),

            // Bouton de soumission
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onSubmit?.call(values);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isLogin ? 'Se connecter' : 'S\'inscrire'),
              ),
            ),
          ],
        );
      },
      onSubmit: onSubmit,
      autoValidate: true,
    );
  }
}

/// Widget de formulaire d'adresse avec validation
class AddressForm extends StatelessWidget {
  final Function(Map<String, dynamic> values)? onSubmit;
  final Map<String, dynamic>? initialValues;

  const AddressForm({
    super.key,
    this.onSubmit,
    this.initialValues,
  });

  @override
  Widget build(BuildContext context) {
    return ValidatedForm(
      formName: 'address',
      initialValues: initialValues ?? {},
      builder: (context, values, errors) {
        return Column(
          children: [
            const ValidatedTextField(
              fieldName: 'name',
              formName: 'address',
              label: 'Nom de l\'adresse',
              hint: 'Ex: Maison, Travail, etc.',
              prefixIcon: Icon(Icons.home),
            ),
            const SizedBox(height: 16),
            const ValidatedTextField(
              fieldName: 'street',
              formName: 'address',
              label: 'Adresse',
              hint: 'Rue, numéro, quartier',
              prefixIcon: Icon(Icons.location_on),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(
                  child: ValidatedTextField(
                    fieldName: 'city',
                    formName: 'address',
                    label: 'Ville',
                    hint: 'Abidjan',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ValidatedTextField(
                    fieldName: 'postalCode',
                    formName: 'address',
                    label: 'Code postal',
                    hint: '00225',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icon(Icons.pin_drop),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onSubmit?.call(values);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Enregistrer l\'adresse'),
              ),
            ),
          ],
        );
      },
      onSubmit: onSubmit,
      autoValidate: true,
    );
  }
}
