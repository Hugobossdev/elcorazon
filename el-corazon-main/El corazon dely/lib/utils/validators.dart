class Validators {
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
  );

  static final RegExp _phoneRegex = RegExp(
    r'^\+?[\d\s-]{9,}$',
  );

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez entrer $fieldName';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez entrer votre email';
    }
    if (!_emailRegex.hasMatch(value)) {
      return 'Veuillez entrer une adresse email valide';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer un mot de passe';
    }
    if (value.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères';
    }
    // Optionnel : Ajouter plus de complexité si nécessaire
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez entrer votre numéro de téléphone';
    }
    // Nettoyer le numéro pour la vérification
    final cleanPhone = value.replaceAll(RegExp(r'[\s-]'), '');
    if (cleanPhone.length < 9) {
      return 'Numéro de téléphone invalide (trop court)';
    }
    if (!_phoneRegex.hasMatch(value)) {
       // On accepte les espaces et tirets grâce au regex, mais il faut que ça ressemble à un numéro
       return 'Format de téléphone invalide';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez entrer votre nom';
    }
    if (value.trim().length < 2) {
      return 'Le nom est trop court';
    }
    return null;
  }
}



