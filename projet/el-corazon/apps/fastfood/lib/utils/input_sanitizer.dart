/// 🛡️ Utilitaire de sanitization des entrées utilisateur
/// Protège contre les injections SQL, XSS et autres attaques
class InputSanitizer {
  /// Liste des mots-clés SQL dangereux
  static const List<String> _sqlDangerousKeywords = [
    'SELECT',
    'INSERT',
    'UPDATE',
    'DELETE',
    'DROP',
    'CREATE',
    'ALTER',
    'EXEC',
    'EXECUTE',
    'UNION',
    'SCRIPT',
    'OR 1=1',
    'AND 1=1',
  ];

  /// Liste des patterns XSS dangereux
  static const List<String> _xssPatterns = [
    '<script',
    '</script>',
    '<iframe',
    '</iframe>',
    'javascript:',
    'onclick=',
    'onload=',
    'onerror=',
    '<img',
    '<svg',
    '<body',
    '<input',
    '<form',
    '<object',
    '<embed',
  ];

  /// 🛡️ Sanitizer une chaîne de caractères
  /// Retourne la chaîne sanitizée ou null si dangereuse
  static String? sanitize(
    String input, {
    bool strict = true,
    bool isAddressField = false,
  }) {
    if (input.isEmpty) return input;

    // Vérifier les injections SQL (plus permissif pour les adresses)
    if (isAddressField) {
      if (_containsSqlInjectionStrict(input)) {
        return null;
      }
    } else {
      if (_containsSqlInjection(input)) {
        return null;
      }
    }

    // Vérifier les attaques XSS
    if (strict && _containsXss(input)) {
      return null;
    }

    // Nettoyer la chaîne
    String cleaned = input;

    // Supprimer les caractères de contrôle
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // Échapper les apostrophes simples (pour SQL)
    // Pour les adresses, on échappe toujours pour la sécurité SQL
    cleaned = cleaned.replaceAll("'", "''");

    // Supprimer les commentaires SQL
    cleaned = cleaned.replaceAll(RegExp(r'--.*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

    // Supprimer les balises HTML si strict
    if (strict) {
      cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>'), '');
    }

    // Limiter la longueur
    if (cleaned.length > 10000) {
      cleaned = cleaned.substring(0, 10000);
    }

    return cleaned.trim();
  }

  /// 🛡️ Vérifier si une chaîne contient des tentatives d'injection SQL
  static bool _containsSqlInjection(String input) {
    final upperInput = input.toUpperCase();

    // Vérifier les mots-clés SQL dangereux
    for (final keyword in _sqlDangerousKeywords) {
      if (upperInput.contains(keyword.toUpperCase())) {
        // Vérifier le contexte (ne pas bloquer "SELECT" dans "SELECTION")
        final regex = RegExp(r'\b' + keyword.toUpperCase() + r'\b');
        if (regex.hasMatch(upperInput)) {
          return true;
        }
      }
    }

    // Vérifier les patterns SQL dangereux
    // ⚠️ On ne bloque PAS les apostrophes simples seules : elles sont légitimes
    // dans les noms propres africains/français (ex : N'Guessan, D'Almeida).
    // On bloque uniquement les combinaisons SQL réellement dangereuses.
    final sqlPatterns = [
      r'(\bOR\b\s+\d+\s*=\s*\d+)', // OR 1=1
      r'(\bAND\b\s+\d+\s*=\s*\d+)', // AND 1=1
      r'(\bUNION\b.*\bSELECT\b)', // UNION SELECT
      r"('\s*\bOR\b\s+')", // ' OR '
      r"('\s*\bAND\b\s+')", // ' AND '
      r"('\s*;\s*--)", // '; --
      r"('\s*;\s*\bDROP\b)", // '; DROP
      r"('\s*;\s*\bDELETE\b)", // '; DELETE
      r"('\s*;\s*\bINSERT\b)", // '; INSERT
      r"('\s*;\s*\bUPDATE\b)", // '; UPDATE
    ];

    for (final pattern in sqlPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(input)) {
        return true;
      }
    }

    return false;
  }

  /// 🛡️ Vérifier si une chaîne contient des tentatives d'injection SQL (version stricte pour adresses)
  /// Plus permissive : autorise les caractères de ponctuation standards dans les adresses
  static bool _containsSqlInjectionStrict(String input) {
    final upperInput = input.toUpperCase();

    // Vérifier les mots-clés SQL dangereux
    for (final keyword in _sqlDangerousKeywords) {
      if (upperInput.contains(keyword.toUpperCase())) {
        // Vérifier le contexte (ne pas bloquer "SELECT" dans "SELECTION")
        final regex = RegExp(r'\b' + keyword.toUpperCase() + r'\b');
        if (regex.hasMatch(upperInput)) {
          return true;
        }
      }
    }

    // Vérifier uniquement les patterns SQL vraiment dangereux (sans bloquer la ponctuation)
    final sqlPatterns = [
      r'(\bOR\b\s+\d+\s*=\s*\d+)', // OR 1=1
      r'(\bAND\b\s+\d+\s*=\s*\d+)', // AND 1=1
      r'(\bUNION\b.*\bSELECT\b)',
      // Ne pas bloquer les apostrophes simples, points-virgules, pipes et esperluettes
      // car ils peuvent être légitimes dans les adresses
      // Mais bloquer les patterns SQL dangereux avec apostrophes
      r"('.*\bOR\b.*')", // ' OR ...
      r"('.*\bAND\b.*')", // ' AND ...
      r"('.*\bUNION\b.*')", // ' UNION ...
    ];

    for (final pattern in sqlPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(input)) {
        return true;
      }
    }

    return false;
  }

  /// 🛡️ Vérifier si une chaîne contient des tentatives d'attaque XSS
  static bool _containsXss(String input) {
    final lowerInput = input.toLowerCase();

    for (final pattern in _xssPatterns) {
      if (lowerInput.contains(pattern.toLowerCase())) {
        return true;
      }
    }

    // Vérifier les événements JavaScript
    if (RegExp(r'on\w+\s*=', caseSensitive: false).hasMatch(input)) {
      return true;
    }

    return false;
  }

  /// 🛡️ Valider et sanitizer une valeur avec message d'erreur
  static SanitizeResult validateAndSanitize(
    String input, {
    bool strict = true,
    String? fieldName,
  }) {
    if (input.isEmpty) {
      return SanitizeResult(
        isValid: true,
        sanitizedValue: input,
      );
    }

    // Pour les champs d'adresse, utiliser une validation plus permissive
    final isAddressField = fieldName != null &&
        (fieldName.toLowerCase().contains('address') ||
            fieldName.toLowerCase().contains('adresse') ||
            fieldName == 'street' ||
            fieldName == 'city' ||
            fieldName == 'postal_code' ||
            fieldName == 'postalCode');

    // Vérifier les injections SQL (plus permissif pour les adresses)
    if (isAddressField) {
      if (_containsSqlInjectionStrict(input)) {
        return SanitizeResult(
          isValid: false,
          errorMessage:
              'Le champ "$fieldName" contient des caractères non autorisés. Veuillez utiliser uniquement des lettres, chiffres et caractères de ponctuation standards.',
        );
      }
    } else {
      if (_containsSqlInjection(input)) {
        return SanitizeResult(
          isValid: false,
          errorMessage: fieldName != null
              ? 'Le champ "$fieldName" contient des caractères non autorisés. Veuillez utiliser uniquement des lettres, chiffres et caractères de ponctuation standards.'
              : 'Caractères non autorisés détectés. Veuillez corriger votre saisie.',
        );
      }
    }

    // Vérifier les attaques XSS
    if (strict && _containsXss(input)) {
      return SanitizeResult(
        isValid: false,
        errorMessage: fieldName != null
            ? 'Le champ "$fieldName" contient du contenu non autorisé. Les balises HTML et scripts ne sont pas autorisés.'
            : 'Contenu non autorisé détecté. Les balises HTML et scripts ne sont pas autorisés.',
      );
    }

    // Sanitizer la valeur
    final sanitized =
        sanitize(input, strict: strict, isAddressField: isAddressField);
    if (sanitized == null) {
      return const SanitizeResult(
        isValid: false,
        errorMessage:
            'Impossible de traiter cette valeur. Veuillez corriger votre saisie.',
      );
    }

    return SanitizeResult(
      isValid: true,
      sanitizedValue: sanitized,
    );
  }

  /// 🛡️ Échapper les caractères spéciaux pour SQL
  static String escapeSql(String input) {
    return input
        .replaceAll("'", "''")
        .replaceAll(r'\', r'\\')
        .replaceAll(r'\n', r'\n')
        .replaceAll(r'\r', r'\r')
        .replaceAll(r'\t', r'\t');
  }

  /// 🛡️ Nettoyer les caractères de contrôle
  static String removeControlChars(String input) {
    return input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  /// 🛡️ Valider un email avec protection contre les injections
  static bool isValidEmailSafe(String email) {
    if (email.isEmpty) return false;

    // Vérifier d'abord les injections
    if (_containsSqlInjection(email) || _containsXss(email)) {
      return false;
    }

    // Puis valider le format email
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  /// 🛡️ Valider un numéro de téléphone avec protection
  static bool isValidPhoneSafe(String phone) {
    if (phone.isEmpty) return false;

    // Nettoyer le numéro (supprimer espaces, tirets, parenthèses, points)
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    // Vérifier les injections SQL sur le numéro nettoyé (plus permissif pour les numéros)
    // On vérifie seulement les patterns vraiment dangereux
    final upperCleaned = cleaned.toUpperCase();
    for (final keyword in _sqlDangerousKeywords) {
      final regex = RegExp(r'\b' + keyword.toUpperCase() + r'\b');
      if (regex.hasMatch(upperCleaned)) {
        return false;
      }
    }

    // Vérifier les patterns SQL vraiment dangereux (OR 1=1, UNION SELECT, etc.)
    final dangerousPatterns = [
      r'(\bOR\b\s+\d+\s*=\s*\d+)',
      r'(\bAND\b\s+\d+\s*=\s*\d+)',
      r'(\bUNION\b.*\bSELECT\b)',
    ];
    for (final pattern in dangerousPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(phone)) {
        return false;
      }
    }

    // Valider le format (français ou international)
    // Format français : +33 ou 0 suivi de 9 chiffres
    // Format international : + suivi de 7 à 15 chiffres
    final frenchPattern = RegExp(r'^(\+33|0)[1-9](\d{8})$');
    final internationalPattern = RegExp(r'^\+\d{7,15}$');
    final localPattern = RegExp(r'^\d{7,15}$');

    return frenchPattern.hasMatch(cleaned) ||
        internationalPattern.hasMatch(cleaned) ||
        localPattern.hasMatch(cleaned);
  }

  /// 🛡️ Sanitizer un numéro de téléphone (nettoie sans modifier le format de base)
  static String? sanitizePhone(String phone) {
    if (phone.isEmpty) return null;

    // Nettoyer le numéro (supprimer espaces, tirets, parenthèses, points)
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    // Supprimer les caractères non numériques (sauf + au début)
    if (cleaned.startsWith('+')) {
      cleaned = '+${cleaned.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    } else {
      cleaned = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    }

    // Valider le format
    if (!isValidPhoneSafe(cleaned)) {
      return null;
    }

    return cleaned;
  }
}

/// Résultat de la sanitization
class SanitizeResult {
  final bool isValid;
  final String? sanitizedValue;
  final String? errorMessage;

  const SanitizeResult({
    required this.isValid,
    this.sanitizedValue,
    this.errorMessage,
  });
}
