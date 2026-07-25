import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Types de validation
enum ValidationType {
  required,
  email,
  phone,
  password,
  minLength,
  maxLength,
  numeric,
  alphanumeric,
  custom,
  sqlInjection, // 🛡️ Nouveau : Protection contre les injections SQL
  xss, // 🛡️ Nouveau : Protection contre les attaques XSS
  sanitize, // 🛡️ Nouveau : Sanitization des données
}

/// Règle de validation
class ValidationRule {
  final ValidationType type;
  final dynamic value;
  final String? message;
  final Function(String)? customValidator;

  const ValidationRule({
    required this.type,
    this.value,
    this.message,
    this.customValidator,
  });
}

/// Résultat de validation
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Map<String, String> fieldErrors;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.fieldErrors = const {},
  });

  ValidationResult copyWith({
    bool? isValid,
    String? errorMessage,
    Map<String, String>? fieldErrors,
  }) {
    return ValidationResult(
      isValid: isValid ?? this.isValid,
      errorMessage: errorMessage ?? this.errorMessage,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}

/// Configuration de validation pour un champ
class FieldValidationConfig {
  final String fieldName;
  final List<ValidationRule> rules;
  final String? label;

  const FieldValidationConfig({
    required this.fieldName,
    required this.rules,
    this.label,
  });
}

/// Configuration de validation pour un formulaire
class FormValidationConfig {
  final String formName;
  final List<FieldValidationConfig> fields;
  final Map<String, dynamic>? defaultValues;

  const FormValidationConfig({
    required this.formName,
    required this.fields,
    this.defaultValues,
  });
}

/// Service de validation des formulaires avec base de données
class FormValidationService extends ChangeNotifier {
  static final FormValidationService _instance =
      FormValidationService._internal();
  factory FormValidationService() => _instance;
  FormValidationService._internal();

  SupabaseClient? _supabase;

  // Cache des configurations de validation
  final Map<String, FormValidationConfig> _validationConfigs = {};

  // Cache des résultats de validation
  final Map<String, ValidationResult> _validationResults = {};

  // Historique des validations
  final List<Map<String, dynamic>> _validationHistory = [];

  /// Initialiser le service
  Future<void> initialize() async {
    try {
      _supabase = Supabase.instance.client;
      await _loadValidationConfigs();
      debugPrint('FormValidationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing FormValidationService: $e');
    }
  }

  /// Charger les configurations de validation depuis la base de données
  Future<void> _loadValidationConfigs() async {
    try {
      // Configuration pour le formulaire d'authentification
      _validationConfigs['auth'] = const FormValidationConfig(
        formName: 'auth',
        fields: [
          FieldValidationConfig(
            fieldName: 'name',
            label: 'Nom complet',
            rules: [
              ValidationRule(
                  type: ValidationType.required, message: 'Le nom est requis',),
              ValidationRule(
                  type: ValidationType.minLength,
                  value: 2,
                  message: 'Le nom doit contenir au moins 2 caractères',),
              ValidationRule(
                  type: ValidationType.maxLength,
                  value: 50,
                  message: 'Le nom ne peut pas dépasser 50 caractères',),
              ValidationRule(
                  type: ValidationType.sqlInjection,
                  message: '⚠️ Le nom contient des caractères non autorisés. Utilisez uniquement des lettres, espaces et tirets.',),
              ValidationRule(
                  type: ValidationType.xss,
                  message: '⚠️ Le nom contient du contenu non autorisé.',),
              ValidationRule(
                  type: ValidationType.sanitize,),
            ],
          ),
          FieldValidationConfig(
            fieldName: 'email',
            label: 'Email',
            rules: [
              ValidationRule(
                  type: ValidationType.required,
                  message: 'L\'email est requis',),
              ValidationRule(
                  type: ValidationType.email,
                  message: 'Veuillez entrer un email valide',),
              ValidationRule(
                  type: ValidationType.sqlInjection,
                  message: '⚠️ L\'email contient des caractères non autorisés.',),
              ValidationRule(
                  type: ValidationType.xss,
                  message: '⚠️ L\'email contient du contenu non autorisé.',),
              ValidationRule(
                  type: ValidationType.sanitize,),
            ],
          ),
          FieldValidationConfig(
            fieldName: 'phone',
            label: 'Téléphone',
            rules: [
              ValidationRule(
                  type: ValidationType.required,
                  message: 'Le téléphone est requis',),
              ValidationRule(
                  type: ValidationType.phone,
                  message: 'Veuillez entrer un numéro de téléphone valide',),
            ],
          ),
          FieldValidationConfig(
            fieldName: 'password',
            label: 'Mot de passe',
            rules: [
              ValidationRule(
                  type: ValidationType.required,
                  message: 'Le mot de passe est requis',),
              ValidationRule(
                  type: ValidationType.minLength,
                  value: 6,
                  message:
                      'Le mot de passe doit contenir au moins 6 caractères',),
              ValidationRule(
                  type: ValidationType.password,
                  message:
                      'Le mot de passe doit contenir au moins une majuscule, une minuscule et un chiffre',),
              ValidationRule(
                  type: ValidationType.sqlInjection,
                  message: '⚠️ Le mot de passe contient des caractères non autorisés.',),
              ValidationRule(
                  type: ValidationType.maxLength,
                  value: 128,
                  message: 'Le mot de passe ne peut pas dépasser 128 caractères',),
            ],
          ),
        ],
      );

      // Configuration pour le formulaire d'adresse
      _validationConfigs['address'] = const FormValidationConfig(
        formName: 'address',
        fields: [
          FieldValidationConfig(
            fieldName: 'name',
            label: 'Nom de l\'adresse',
            rules: [
              ValidationRule(
                  type: ValidationType.required,
                  message: 'Le nom de l\'adresse est requis',),
              ValidationRule(
                  type: ValidationType.minLength,
                  value: 2,
                  message: 'Le nom doit contenir au moins 2 caractères',),
            ],
          ),
          FieldValidationConfig(
            fieldName: 'street',
            label: 'Adresse',
            rules: [
              ValidationRule(
                  type: ValidationType.required,
                  message: 'L\'adresse est requise',),
              ValidationRule(
                  type: ValidationType.minLength,
                  value: 5,
                  message: 'L\'adresse doit contenir au moins 5 caractères',),
            ],
          ),
          FieldValidationConfig(
            fieldName: 'city',
            label: 'Ville',
            rules: [
              ValidationRule(
                  type: ValidationType.required,
                  message: 'La ville est requise',),
              ValidationRule(
                  type: ValidationType.minLength,
                  value: 2,
                  message: 'La ville doit contenir au moins 2 caractères',),
            ],
          ),
          FieldValidationConfig(
            fieldName: 'postalCode',
            label: 'Code postal',
            rules: [
              ValidationRule(
                  type: ValidationType.required,
                  message: 'Le code postal est requis',),
              ValidationRule(
                  type: ValidationType.numeric,
                  message:
                      'Le code postal doit contenir uniquement des chiffres',),
              ValidationRule(
                  type: ValidationType.minLength,
                  value: 4,
                  message: 'Le code postal doit contenir au moins 4 chiffres',),
            ],
          ),
        ],
      );

      // Configuration pour le formulaire de paiement
      _validationConfigs['payment'] = const FormValidationConfig(
        formName: 'payment',
        fields: [
          FieldValidationConfig(
            fieldName: 'cardNumber',
            label: 'Numéro de carte',
            rules: [
              ValidationRule(
                  type: ValidationType.required,
                  message: 'Le numéro de carte est requis',),
              ValidationRule(
                  type: ValidationType.numeric,
                  message:
                      'Le numéro de carte doit contenir uniquement des chiffres',),
              ValidationRule(
                  type: ValidationType.minLength,
                  value: 16,
                  message: 'Le numéro de carte doit contenir 16 chiffres',),
            ],
          ),
          FieldValidationConfig(
            fieldName: 'expiryDate',
            label: 'Date d\'expiration',
            rules: [
              ValidationRule(
                  type: ValidationType.required,
                  message: 'La date d\'expiration est requise',),
            ],
          ),
          FieldValidationConfig(
            fieldName: 'cvv',
            label: 'CVV',
            rules: [
              ValidationRule(
                  type: ValidationType.required, message: 'Le CVV est requis',),
              ValidationRule(
                  type: ValidationType.numeric,
                  message: 'Le CVV doit contenir uniquement des chiffres',),
              ValidationRule(
                  type: ValidationType.minLength,
                  value: 3,
                  message: 'Le CVV doit contenir 3 chiffres',),
            ],
          ),
        ],
      );

      debugPrint('Validation configurations loaded successfully');
    } catch (e) {
      debugPrint('Error loading validation configurations: $e');
    }
  }

  /// Valider un champ individuel
  ValidationResult validateField(
      String formName, String fieldName, String value,) {
    final config = _validationConfigs[formName];
    if (config == null) {
      return const ValidationResult(
        isValid: false,
        errorMessage: 'Configuration de validation non trouvée',
      );
    }

    final fieldConfig = config.fields.firstWhere(
      (field) => field.fieldName == fieldName,
      orElse: () =>
          throw Exception('Champ $fieldName non trouvé dans la configuration'),
    );

    for (final rule in fieldConfig.rules) {
      final result = _validateRule(rule, value);
      if (!result.isValid) {
        return result;
      }
    }

    return const ValidationResult(isValid: true);
  }

  /// Valider un formulaire complet
  Future<ValidationResult> validateForm(
      String formName, Map<String, dynamic> formData,) async {
    try {
      final config = _validationConfigs[formName];
      if (config == null) {
        return const ValidationResult(
          isValid: false,
          errorMessage: 'Configuration de validation non trouvée',
        );
      }

      final Map<String, String> fieldErrors = {};
      bool isValid = true;

      // Valider chaque champ
      for (final fieldConfig in config.fields) {
        final value = formData[fieldConfig.fieldName]?.toString() ?? '';
        final result = validateField(formName, fieldConfig.fieldName, value);

        if (!result.isValid) {
          isValid = false;
          fieldErrors[fieldConfig.fieldName] =
              result.errorMessage ?? 'Erreur de validation';
        }
      }

      // Valider les contraintes de base de données
      if (isValid) {
        final dbValidationResult =
            await _validateWithDatabase(formName, formData);
        if (!dbValidationResult.isValid) {
          isValid = false;
          fieldErrors.addAll(dbValidationResult.fieldErrors);
        }
      }

      final result = ValidationResult(
        isValid: isValid,
        fieldErrors: fieldErrors,
      );

      // Sauvegarder le résultat
      _validationResults[formName] = result;

      // Ajouter à l'historique
      _validationHistory.add({
        'formName': formName,
        'timestamp': DateTime.now().toIso8601String(),
        'isValid': isValid,
        'fieldErrors': fieldErrors,
      });

      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error validating form $formName: $e');
      return ValidationResult(
        isValid: false,
        errorMessage: 'Erreur lors de la validation: $e',
      );
    }
  }

  /// Valider avec la base de données
  Future<ValidationResult> _validateWithDatabase(
      String formName, Map<String, dynamic> formData,) async {
    try {
      if (_supabase == null) {
        debugPrint('Supabase not initialized, skipping database validation');
        return const ValidationResult(isValid: true);
      }

      switch (formName) {
        case 'auth':
          return await _validateAuthWithDatabase(formData);
        case 'address':
          return await _validateAddressWithDatabase(formData);
        case 'payment':
          return await _validatePaymentWithDatabase(formData);
        default:
          return const ValidationResult(isValid: true);
      }
    } catch (e) {
      debugPrint('Error validating with database: $e');
      return ValidationResult(
        isValid: false,
        errorMessage: 'Erreur de validation avec la base de données: $e',
      );
    }
  }

  /// Valider l'authentification avec la base de données
  Future<ValidationResult> _validateAuthWithDatabase(
      Map<String, dynamic> formData,) async {
    final Map<String, String> errors = {};

    if (_supabase == null) {
      return const ValidationResult(isValid: true);
    }

    // Vérifier si l'email existe déjà
    if (formData.containsKey('email')) {
      try {
        final response = await _supabase!
            .from('users')
            .select('id')
            .eq('email', formData['email'])
            .maybeSingle();

        if (response != null) {
          errors['email'] = 'Cet email est déjà utilisé';
        }
      } catch (e) {
        debugPrint('Error checking email uniqueness: $e');
      }
    }

    // Vérifier si le téléphone existe déjà
    if (formData.containsKey('phone')) {
      try {
        final response = await _supabase!
            .from('users')
            .select('id')
            .eq('phone', formData['phone'])
            .maybeSingle();

        if (response != null) {
          errors['phone'] = 'Ce numéro de téléphone est déjà utilisé';
        }
      } catch (e) {
        debugPrint('Error checking phone uniqueness: $e');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      fieldErrors: errors,
    );
  }

  /// Valider l'adresse avec la base de données
  Future<ValidationResult> _validateAddressWithDatabase(
      Map<String, dynamic> formData,) async {
    final Map<String, String> errors = {};

    // Vérifier si l'adresse existe déjà pour cet utilisateur
    if (formData.containsKey('street') && formData.containsKey('city')) {
      try {
        if (_supabase != null) {
          final userId = _supabase!.auth.currentUser?.id;
          if (userId != null) {
            final response = await _supabase!
                .from('user_addresses')
                .select('id')
                .eq('user_id', userId)
                .eq('street', formData['street'])
                .eq('city', formData['city'])
                .maybeSingle();

            if (response != null) {
              errors['street'] = 'Cette adresse existe déjà';
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking address uniqueness: $e');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      fieldErrors: errors,
    );
  }

  /// Valider le paiement avec la base de données
  Future<ValidationResult> _validatePaymentWithDatabase(
      Map<String, dynamic> formData,) async {
    final Map<String, String> errors = {};

    // Vérifier si la carte existe déjà
    if (formData.containsKey('cardNumber')) {
      try {
        if (_supabase != null) {
          final userId = _supabase!.auth.currentUser?.id;
          if (userId != null) {
            final response = await _supabase!
                .from('user_payment_methods')
                .select('id')
                .eq('user_id', userId)
                .eq('card_number', formData['cardNumber'])
                .maybeSingle();

            if (response != null) {
              errors['cardNumber'] = 'Cette carte est déjà enregistrée';
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking card uniqueness: $e');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      fieldErrors: errors,
    );
  }

  /// Valider une règle spécifique
  ValidationResult _validateRule(ValidationRule rule, String value) {
    switch (rule.type) {
      case ValidationType.required:
        if (value.trim().isEmpty) {
          return ValidationResult(
            isValid: false,
            errorMessage: rule.message ?? 'Ce champ est requis',
          );
        }
        break;

      case ValidationType.email:
        if (!_isValidEmail(value)) {
          return ValidationResult(
            isValid: false,
            errorMessage: rule.message ?? 'Veuillez entrer un email valide',
          );
        }
        break;

      case ValidationType.phone:
        if (!_isValidPhone(value)) {
          return ValidationResult(
            isValid: false,
            errorMessage:
                rule.message ?? 'Veuillez entrer un numéro de téléphone valide',
          );
        }
        break;

      case ValidationType.password:
        if (!_isValidPassword(value)) {
          return ValidationResult(
            isValid: false,
            errorMessage: rule.message ??
                'Le mot de passe doit contenir au moins une majuscule, une minuscule et un chiffre',
          );
        }
        break;

      case ValidationType.minLength:
        if (value.length < (rule.value as int)) {
          return ValidationResult(
            isValid: false,
            errorMessage: rule.message ??
                'Ce champ doit contenir au moins ${rule.value} caractères',
          );
        }
        break;

      case ValidationType.maxLength:
        if (value.length > (rule.value as int)) {
          return ValidationResult(
            isValid: false,
            errorMessage: rule.message ??
                'Ce champ ne peut pas dépasser ${rule.value} caractères',
          );
        }
        break;

      case ValidationType.numeric:
        if (!_isNumeric(value)) {
          return ValidationResult(
            isValid: false,
            errorMessage: rule.message ??
                'Ce champ doit contenir uniquement des chiffres',
          );
        }
        break;

      case ValidationType.alphanumeric:
        if (!_isAlphanumeric(value)) {
          return ValidationResult(
            isValid: false,
            errorMessage: rule.message ??
                'Ce champ doit contenir uniquement des lettres et des chiffres',
          );
        }
        break;

      case ValidationType.custom:
        if (rule.customValidator != null) {
          final result = rule.customValidator!(value);
          if (result != null) {
            return ValidationResult(
              isValid: false,
              errorMessage: result,
            );
          }
        }
        break;

      // 🛡️ Protection contre les injections SQL
      case ValidationType.sqlInjection:
        if (_containsSqlInjection(value)) {
          return ValidationResult(
            isValid: false,
            errorMessage: rule.message ?? 
                '⚠️ Caractères non autorisés détectés. Veuillez utiliser uniquement des lettres, chiffres et caractères de ponctuation standards.',
          );
        }
        break;

      // 🛡️ Protection contre les attaques XSS
      case ValidationType.xss:
        if (_containsXss(value)) {
          return ValidationResult(
            isValid: false,
            errorMessage: rule.message ?? 
                '⚠️ Contenu non autorisé détecté. Les balises HTML et scripts ne sont pas autorisés.',
          );
        }
        break;

      // 🛡️ Sanitization automatique
      case ValidationType.sanitize:
        final sanitized = validateAndSanitize(value);
        if (sanitized == null) {
          return ValidationResult(
            isValid: false,
            errorMessage: rule.message ?? 
                '⚠️ Le contenu contient des caractères non autorisés. Veuillez corriger votre saisie.',
          );
        }
        break;
    }

    return const ValidationResult(isValid: true);
  }

  /// Vérifier si l'email est valide
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  /// Vérifier si le téléphone est valide
  bool _isValidPhone(String phone) {
    // Format français : +33 ou 0 suivi de 9 chiffres
    return RegExp(r'^(\+33|0)[1-9](\d{8})$')
        .hasMatch(phone.replaceAll(' ', ''));
  }

  /// Vérifier si le mot de passe est valide
  bool _isValidPassword(String password) {
    // Au moins 6 caractères, une majuscule, une minuscule et un chiffre
    return password.length >= 6 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  /// Vérifier si la valeur est numérique
  bool _isNumeric(String value) {
    return RegExp(r'^[0-9]+$').hasMatch(value);
  }

  /// Vérifier si la valeur est alphanumérique
  bool _isAlphanumeric(String value) {
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value);
  }

  /// 🛡️ Détecter les tentatives d'injection SQL
  bool _containsSqlInjection(String value) {
    if (value.isEmpty) return false;
    
    // Liste des patterns SQL dangereux
    final sqlPatterns = [
      r'(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE|UNION|SCRIPT)\b)',
      r'(--|#|\/\*|\*\/)', // Commentaires SQL
      r'(\bOR\b.*=.*=)', // OR 1=1
      r'(\bAND\b.*=.*=)', // AND 1=1
      r"('|(\\')|(;)|(\|)|(&))", // Caractères spéciaux SQL
      r'(\bUNION\b.*\bSELECT\b)',
      r'(\bEXEC\b|\bEXECUTE\b)',
      r'(xp_|sp_)', // Procédures stockées
      r'(\bCHAR\b|\bVARCHAR\b|\bNVARCHAR\b)',
      r'(\bCONCAT\b|\bCAST\b|\bCONVERT\b)',
    ];
    
    final upperValue = value.toUpperCase();
    for (final pattern in sqlPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(upperValue)) {
        return true;
      }
    }
    
    return false;
  }

  /// 🛡️ Détecter les tentatives d'attaque XSS
  bool _containsXss(String value) {
    if (value.isEmpty) return false;
    
    // Liste des patterns XSS dangereux
    final xssPatterns = [
      r'<script[^>]*>.*?</script>',
      r'<iframe[^>]*>.*?</iframe>',
      r'javascript:',
      r'on\w+\s*=', // onclick=, onload=, etc.
      r'<img[^>]*src[^>]*=.*javascript:',
      r'<svg[^>]*on\w+',
      r'<body[^>]*on\w+',
      r'<input[^>]*on\w+',
      r'<form[^>]*>',
      r'<object[^>]*>',
      r'<embed[^>]*>',
      r'<link[^>]*>',
      r'<meta[^>]*>',
    ];
    
    for (final pattern in xssPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(value)) {
        return true;
      }
    }
    
    return false;
  }

  /// 🛡️ Sanitizer les données pour éviter les injections
  String _sanitizeInput(String value) {
    if (value.isEmpty) return value;
    
    // Supprimer les caractères dangereux
    String sanitized = value;
    
    // Supprimer les caractères de contrôle
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    
    // Échapper les caractères spéciaux SQL
    sanitized = sanitized
        .replaceAll("'", "''") // Échapper les apostrophes
        .replaceAll(';', '') // Supprimer les points-virgules
        .replaceAll('--', '') // Supprimer les commentaires SQL
        .replaceAll('/*', '') // Supprimer les commentaires SQL
        .replaceAll('*/', ''); // Supprimer les commentaires SQL
    
    // Supprimer les balises HTML dangereuses
    sanitized = sanitized.replaceAll(RegExp(r'<[^>]+>'), '');
    
    // Limiter la longueur pour éviter les buffer overflows
    if (sanitized.length > 10000) {
      sanitized = sanitized.substring(0, 10000);
    }
    
    return sanitized.trim();
  }

  /// 🛡️ Valider et sanitizer une valeur
  String? validateAndSanitize(String value, {bool allowHtml = false}) {
    if (value.isEmpty) return value;
    
    // Détecter les injections SQL
    if (_containsSqlInjection(value)) {
      return null; // Retourner null pour indiquer une erreur
    }
    
    // Détecter les attaques XSS
    if (!allowHtml && _containsXss(value)) {
      return null; // Retourner null pour indiquer une erreur
    }
    
    // Sanitizer la valeur
    return _sanitizeInput(value);
  }

  /// Obtenir la configuration de validation pour un formulaire
  FormValidationConfig? getValidationConfig(String formName) {
    return _validationConfigs[formName];
  }

  /// Obtenir le résultat de validation pour un formulaire
  ValidationResult? getValidationResult(String formName) {
    return _validationResults[formName];
  }

  /// Obtenir l'historique des validations
  List<Map<String, dynamic>> getValidationHistory() {
    return List.from(_validationHistory);
  }

  /// Effacer les résultats de validation
  void clearValidationResults() {
    _validationResults.clear();
    notifyListeners();
  }

  /// Effacer l'historique des validations
  void clearValidationHistory() {
    _validationHistory.clear();
    notifyListeners();
  }

  /// Ajouter une configuration de validation personnalisée
  void addValidationConfig(String formName, FormValidationConfig config) {
    _validationConfigs[formName] = config;
    notifyListeners();
  }

  /// Supprimer une configuration de validation
  void removeValidationConfig(String formName) {
    _validationConfigs.remove(formName);
    _validationResults.remove(formName);
    notifyListeners();
  }
}
