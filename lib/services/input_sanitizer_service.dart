
/// Service de sanitization et validation des entrées utilisateur
/// Protège contre les injections XSS, SQL injection, et autres attaques
class InputSanitizerService {
  static final InputSanitizerService _instance = InputSanitizerService._internal();
  factory InputSanitizerService() => _instance;
  InputSanitizerService._internal();

  // =====================================================
  // SANITIZATION DES CHAÎNES DE CARACTÈRES
  // =====================================================

  /// Sanitize une chaîne de caractères en supprimant les caractères dangereux
  /// 
  /// Supprime :
  /// - Les balises HTML/XML (<, >)
  /// - Les guillemets (", ')
  /// - Les caractères de contrôle
  /// - Limite la longueur
  static String sanitizeString(
    String input, {
    int maxLength = 500,
    bool allowHtml = false,
    bool trimWhitespace = true,
  }) {
    if (input.isEmpty) return input;

    String sanitized = input;

    // Supprimer les caractères de contrôle (sauf les espaces)
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '');

    if (!allowHtml) {
      // Supprimer les balises HTML/XML
      sanitized = sanitized.replaceAll(RegExp(r'<[^>]*>'), '');
      // Supprimer les caractères dangereux (<, >, ", ')
      sanitized = sanitized.replaceAll(RegExp(r'[<>"' r"'" r']'), '');
      // Supprimer les scripts potentiels
      sanitized = sanitized.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
      sanitized = sanitized.replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');
    }

    // Nettoyer les espaces multiples
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

    // Trim
    if (trimWhitespace) {
      sanitized = sanitized.trim();
    }

    // Limiter la longueur
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized;
  }

  /// Sanitize un texte multi-lignes (description, commentaire, etc.)
  static String sanitizeMultilineText(
    String input, {
    int maxLength = 2000,
    bool allowLineBreaks = true,
  }) {
    if (input.isEmpty) return input;

    String sanitized = input;

    // Supprimer les caractères de contrôle
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '');

    // Supprimer les balises HTML
    sanitized = sanitized.replaceAll(RegExp(r'<[^>]*>'), '');

    // Supprimer les caractères dangereux (<, >, ", ')
    sanitized = sanitized.replaceAll(RegExp(r'[<>"' r"'" r']'), '');

    // Gérer les retours à la ligne
    if (!allowLineBreaks) {
      sanitized = sanitized.replaceAll(RegExp(r'[\r\n]+'), ' ');
    } else {
      // Normaliser les retours à la ligne
      sanitized = sanitized.replaceAll(RegExp(r'\r\n'), '\n');
      sanitized = sanitized.replaceAll(RegExp(r'\r'), '\n');
    }

    // Nettoyer les espaces
    sanitized = sanitized.replaceAll(RegExp(r'[ \t]+'), ' ');

    // Limiter la longueur
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized.trim();
  }

  /// Sanitize un nom (personne, produit, etc.)
  static String sanitizeName(String input, {int maxLength = 100}) {
    if (input.isEmpty) return input;

    String sanitized = input.trim();

    // Supprimer les caractères non alphanumériques et espaces
    // Autoriser les accents et caractères spéciaux courants
    sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-ZÀ-ÿ0-9\s\-' r"'" r'\.]'), '');

    // Nettoyer les espaces multiples
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

    // Limiter la longueur
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized.trim();
  }

  /// Sanitize une URL
  static String sanitizeUrl(String input) {
    if (input.isEmpty) return input;

    String sanitized = input.trim();

    // Valider le format de base d'une URL
    if (!sanitized.startsWith('http://') && !sanitized.startsWith('https://')) {
      sanitized = 'https://$sanitized';
    }

    // Supprimer les caractères dangereux dans l'URL
    sanitized = sanitized.replaceAll(RegExp(r'[<>"' r"'" r']'), '');

    return sanitized;
  }

  // =====================================================
  // VALIDATION ET SANITIZATION DES EMAILS
  // =====================================================

  /// Valide si un email est valide
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;

    // Expression régulière pour valider un email
    final emailRegex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
      caseSensitive: false,
    );

    return emailRegex.hasMatch(email.trim());
  }

  /// Sanitize et valide un email
  static String? sanitizeEmail(String email) {
    if (email.isEmpty) return null;

    // Nettoyer l'email
    String sanitized = email.trim().toLowerCase();

    // Supprimer les espaces
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), '');

    // Supprimer les caractères dangereux (<, >, ", ')
    sanitized = sanitized.replaceAll(RegExp(r'[<>"' r"'" r']'), '');

    // Limiter la longueur (standard RFC 5321 : 64 caractères pour la partie locale, 255 pour le domaine)
    if (sanitized.length > 320) {
      sanitized = sanitized.substring(0, 320);
    }

    // Valider l'email
    if (!isValidEmail(sanitized)) {
      return null;
    }

    return sanitized;
  }

  // =====================================================
  // VALIDATION ET SANITIZATION DES TÉLÉPHONES
  // =====================================================

  /// Valide si un numéro de téléphone est valide
  static bool isValidPhone(String phone) {
    if (phone.isEmpty) return false;

    // Nettoyer le numéro
    final String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Format international : + suivi de 7 à 15 chiffres
    // Format local : 7 à 15 chiffres
    final phoneRegex = RegExp(r'^(\+?[0-9]{7,15})$');

    return phoneRegex.hasMatch(cleaned);
  }

  /// Sanitize et valide un numéro de téléphone
  static String? sanitizePhone(String phone) {
    if (phone.isEmpty) return null;

    // Nettoyer le numéro
    String sanitized = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    // Supprimer les caractères non numériques (sauf + au début)
    if (sanitized.startsWith('+')) {
      sanitized = '+${sanitized.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    } else {
      sanitized = sanitized.replaceAll(RegExp(r'[^0-9]'), '');
    }

    // Valider
    if (!isValidPhone(sanitized)) {
      return null;
    }

    return sanitized;
  }

  // =====================================================
  // VALIDATION ET SANITIZATION DES MOTS DE PASSE
  // =====================================================

  /// Valide si un mot de passe est sécurisé
  static bool isValidPassword(String password) {
    if (password.length < 8) return false;

    // Au moins une majuscule
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false;

    // Au moins une minuscule
    if (!RegExp(r'[a-z]').hasMatch(password)) return false;

    // Au moins un chiffre
    if (!RegExp(r'[0-9]').hasMatch(password)) return false;

    // Optionnel : au moins un caractère spécial
    // if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) return false;

    return true;
  }

  /// Sanitize un mot de passe (ne pas le modifier, juste valider)
  static String? sanitizePassword(String password) {
    if (password.isEmpty) return null;

    // Ne pas modifier le mot de passe, juste valider
    if (!isValidPassword(password)) {
      return null;
    }

    return password;
  }

  // =====================================================
  // VALIDATION ET SANITIZATION DES NUMÉRIQUES
  // =====================================================

  /// Sanitize un nombre entier
  static int? sanitizeInt(String input, {int? min, int? max}) {
    if (input.isEmpty) return null;

    // Nettoyer (supprimer les espaces et caractères non numériques)
    final String cleaned = input.replaceAll(RegExp(r'[^0-9\-]'), '');

    try {
      final int value = int.parse(cleaned);

      // Vérifier les limites
      if (min != null && value < min) return null;
      if (max != null && value > max) return null;

      return value;
    } catch (e) {
      return null;
    }
  }

  /// Sanitize un nombre décimal
  static double? sanitizeDouble(String input, {double? min, double? max}) {
    if (input.isEmpty) return null;

    // Nettoyer (autoriser les points et virgules pour les décimales)
    String cleaned = input.replaceAll(RegExp(r'[^\d.,\-]'), '');
    cleaned = cleaned.replaceAll(',', '.');

    try {
      final double value = double.parse(cleaned);

      // Vérifier les limites
      if (min != null && value < min) return null;
      if (max != null && value > max) return null;

      return value;
    } catch (e) {
      return null;
    }
  }

  // =====================================================
  // SANITIZATION DES OBJETS ET MAPS
  // =====================================================

  /// Sanitize un Map de données
  static Map<String, dynamic> sanitizeMap(
    Map<String, dynamic> data, {
    Map<String, Function(String)>? fieldSanitizers,
  }) {
    final sanitized = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      // Sanitizer personnalisé pour ce champ
      if (fieldSanitizers != null && fieldSanitizers.containsKey(key)) {
        if (value is String) {
          sanitized[key] = fieldSanitizers[key]!(value);
        } else {
          sanitized[key] = value;
        }
      } else if (value is String) {
        // Sanitizer par défaut pour les chaînes
        sanitized[key] = sanitizeString(value);
      } else if (value is Map) {
        // Récursif pour les maps imbriquées
        sanitized[key] = sanitizeMap(value as Map<String, dynamic>);
      } else if (value is List) {
        // Sanitize les listes
        sanitized[key] = sanitizeList(value);
      } else {
        // Autres types (numériques, booléens, etc.) - pas de sanitization nécessaire
        sanitized[key] = value;
      }
    }

    return sanitized;
  }

  /// Sanitize une liste
  static List<dynamic> sanitizeList(List<dynamic> list) {
    return list.map((item) {
      if (item is String) {
        return sanitizeString(item);
      } else if (item is Map) {
        return sanitizeMap(item as Map<String, dynamic>);
      } else if (item is List) {
        return sanitizeList(item);
      } else {
        return item;
      }
    }).toList();
  }

  // =====================================================
  // VALIDATION DES CODES POSTAUX
  // =====================================================

  /// Valide un code postal (format français : 5 chiffres)
  static bool isValidPostalCode(String postalCode) {
    if (postalCode.isEmpty) return false;

    final String cleaned = postalCode.replaceAll(RegExp(r'[\s\-]'), '');

    return RegExp(r'^\d{5}$').hasMatch(cleaned);
  }

  /// Sanitize un code postal
  static String? sanitizePostalCode(String postalCode) {
    if (postalCode.isEmpty) return null;

    final String sanitized = postalCode.replaceAll(RegExp(r'[^0-9]'), '');

    if (sanitized.length != 5) return null;

    return sanitized;
  }

  // =====================================================
  // VALIDATION DES CARTES BANCAIRES
  // =====================================================

  /// Valide un numéro de carte bancaire (format basique)
  static bool isValidCreditCardNumber(String cardNumber) {
    if (cardNumber.isEmpty) return false;

    final String cleaned = cardNumber.replaceAll(RegExp(r'[\s\-]'), '');

    // Format basique : 13 à 19 chiffres
    if (!RegExp(r'^\d{13,19}$').hasMatch(cleaned)) return false;

    // Algorithme de Luhn (optionnel, à implémenter si nécessaire)
    // return _luhnCheck(cleaned);

    return true;
  }

  /// Sanitize un numéro de carte bancaire
  static String? sanitizeCreditCardNumber(String cardNumber) {
    if (cardNumber.isEmpty) return null;

    final String sanitized = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (!isValidCreditCardNumber(sanitized)) return null;

    return sanitized;
  }

  // =====================================================
  // UTILITAIRES
  // =====================================================

  /// Échapper les caractères spéciaux pour HTML (protection XSS)
  static String escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  /// Vérifier si une chaîne contient des caractères dangereux
  static bool containsDangerousCharacters(String input) {
    final dangerousPatterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'on\w+\s*=', caseSensitive: false),
      RegExp(r'<iframe', caseSensitive: false),
      RegExp(r'<object', caseSensitive: false),
      RegExp(r'<embed', caseSensitive: false),
    ];

    return dangerousPatterns.any((pattern) => pattern.hasMatch(input));
  }
}

