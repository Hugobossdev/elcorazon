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

  // ------------------------------------------------- création de compte
  //
  // Les trois validateurs ci-dessous doublent une règle que le serveur applique
  // de toute façon — c'est lui qui décide, et ces contrôles ne le remplacent
  // pas. Ils existent pour que le refus arrive **avant** l'aller-retour : sur
  // un réseau lent, découvrir au bout de huit secondes qu'il manquait un « + »
  // au numéro fait abandonner le formulaire.

  /// Le format E.164 exigé par le serveur (`phone_validator`).
  ///
  /// `+22890123456` : un « + », un premier chiffre non nul, et de huit à
  /// quinze chiffres en tout. Le numéro local togolais seul — `90123456` — est
  /// refusé, ici comme là-bas : sans indicatif, deux pays ont le même numéro.
  static final RegExp _e164Regex = RegExp(r'^\+[1-9]\d{7,14}$');

  static String? validatePhoneE164(String? value) {
    final numero = value?.replaceAll(RegExp(r'[\s-]'), '') ?? '';
    if (numero.isEmpty) {
      return 'Veuillez entrer votre numéro de téléphone';
    }
    if (!numero.startsWith('+')) {
      return 'Ajoutez l\'indicatif du pays, par exemple +228';
    }
    if (!_e164Regex.hasMatch(numero)) {
      return 'Numéro invalide. Format attendu : +22890123456';
    }
    return null;
  }

  /// Ce que Django refuse à coup sûr — longueur, et mot de passe tout en
  /// chiffres.
  ///
  /// Volontairement en deçà de ses validateurs : la liste des mots de passe
  /// courants et la comparaison au nom du compte vivent côté serveur, et les
  /// recopier ici produirait deux jeux de règles qui divergeraient. Ce qui est
  /// vérifié ici est ce qui se vérifie sans rien connaître d'autre.
  static String? validateStrongPassword(String? value) {
    final motDePasse = value ?? '';
    if (motDePasse.isEmpty) {
      return 'Veuillez choisir un mot de passe';
    }
    if (motDePasse.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    if (RegExp(r'^\d+$').hasMatch(motDePasse)) {
      return 'Un mot de passe uniquement composé de chiffres est trop facile à deviner';
    }
    return null;
  }

  static String? validatePasswordConfirmation(String? value, String motDePasse) {
    if (value == null || value.isEmpty) {
      return 'Confirmez votre mot de passe';
    }
    if (value != motDePasse) {
      return 'Les deux mots de passe ne correspondent pas';
    }
    return null;
  }
}



