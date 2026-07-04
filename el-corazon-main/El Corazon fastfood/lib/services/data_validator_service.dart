import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/models/address.dart';

/// Résultat de validation avec détails
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final Map<String, String> fieldErrors;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.fieldErrors = const {},
  });

  ValidationResult copyWith({
    bool? isValid,
    List<String>? errors,
    Map<String, String>? fieldErrors,
  }) {
    return ValidationResult(
      isValid: isValid ?? this.isValid,
      errors: errors ?? this.errors,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }

  /// Créer un résultat valide
  factory ValidationResult.valid() {
    return const ValidationResult(isValid: true);
  }

  /// Créer un résultat invalide avec erreurs
  factory ValidationResult.invalid(List<String> errors,
      {Map<String, String>? fieldErrors,}) {
    return ValidationResult(
      isValid: false,
      errors: errors,
      fieldErrors: fieldErrors ?? {},
    );
  }
}

/// Service de validation des données métier avant envoi
class DataValidatorService {
  static final DataValidatorService _instance =
      DataValidatorService._internal();
  factory DataValidatorService() => _instance;
  DataValidatorService._internal();

  // =====================================================
  // VALIDATION DES COMMANDES
  // =====================================================

  /// Valide les données d'une commande avant l'envoi
  ValidationResult validateOrder({
    required List<CartItem> items,
    Address? deliveryAddress,
    String? paymentMethod,
    double? total,
    Map<String, dynamic>? additionalData,
  }) {
    final errors = <String>[];
    final fieldErrors = <String, String>{};

    // Valider les items
    if (items.isEmpty) {
      errors.add('Le panier est vide');
      fieldErrors['items'] = 'Le panier est vide';
    } else {
      // Valider chaque item
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final itemErrors = _validateCartItem(item, index: i);
        if (itemErrors.isNotEmpty) {
          errors.addAll(itemErrors);
          fieldErrors['items[$i]'] = itemErrors.join(', ');
        }
      }
    }

    // Valider l'adresse de livraison
    if (deliveryAddress == null) {
      errors.add('L\'adresse de livraison est requise');
      fieldErrors['deliveryAddress'] = 'L\'adresse de livraison est requise';
    } else {
      final addressErrors = _validateAddress(deliveryAddress);
      if (addressErrors.isNotEmpty) {
        errors.addAll(addressErrors);
        fieldErrors['deliveryAddress'] = addressErrors.join(', ');
      }
    }

    // Valider le mode de paiement
    if (paymentMethod == null || paymentMethod.isEmpty) {
      errors.add('Veuillez sélectionner un mode de paiement');
      fieldErrors['paymentMethod'] =
          'Veuillez sélectionner un mode de paiement';
    } else {
      final validPaymentMethods = ['cash', 'card', 'mobile_money', 'wallet'];
      if (!validPaymentMethods.contains(paymentMethod.toLowerCase())) {
        errors.add('Mode de paiement invalide');
        fieldErrors['paymentMethod'] = 'Mode de paiement invalide';
      }
    }

    // Valider le total
    if (total != null) {
      if (total <= 0) {
        errors.add('Le montant total doit être supérieur à 0');
        fieldErrors['total'] = 'Le montant total doit être supérieur à 0';
      } else {
        // Vérifier la cohérence du total avec les items
        // Le total doit inclure : subtotal + deliveryFee - discount
        // On calcule seulement le subtotal depuis les items
        final calculatedSubtotal = items.fold<double>(
          0.0,
          (sum, item) =>
              sum +
              (item
                  .totalPrice), // Utiliser totalPrice qui inclut déjà la quantité
        );

        // Le total passé doit être cohérent avec le subtotal calculé
        // Le total peut inclure des frais de livraison et remises qui ne sont pas dans les items
        // On vérifie seulement que le total est raisonnable (>= subtotal - une tolérance pour les remises)
        // On accepte une tolérance de 50% du subtotal pour les remises importantes
        final minTotal =
            calculatedSubtotal * 0.5; // Permettre jusqu'à 50% de remise
        final maxTotal = calculatedSubtotal *
            2.0; // Permettre jusqu'à 100% de frais supplémentaires

        if (total < minTotal || total > maxTotal) {
          // Si le total est en dehors de la plage raisonnable, vérifier plus précisément
          // Le total devrait être proche de subtotal (avec frais de livraison et remises)
          // On accepte une tolérance de 0.01 pour les arrondis
          if (total < calculatedSubtotal - 0.01) {
            errors.add(
                'Le montant total ne correspond pas aux articles du panier',);
            fieldErrors['total'] = 'Incohérence dans le calcul du total';
          }
        }
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      fieldErrors: fieldErrors,
    );
  }

  /// Valide un item du panier
  List<String> _validateCartItem(CartItem item, {int? index}) {
    final errors = <String>[];
    final prefix = index != null ? 'Article ${index + 1}' : 'Article';

    // Valider que l'item a un ID et un nom
    if (item.id.isEmpty || item.name.isEmpty) {
      errors.add('$prefix : L\'article est invalide');
    }

    // Valider la quantité
    if (item.quantity <= 0) {
      errors.add('$prefix : La quantité doit être supérieure à 0');
    }

    // Valider le prix
    if (item.price <= 0) {
      errors.add('$prefix : Le prix doit être supérieur à 0');
    }

    // Note: La validation de disponibilité et de stock doit être faite
    // avec les données du menu item si disponible, mais CartItem
    // ne contient pas directement le MenuItem complet

    return errors;
  }

  /// Valide une adresse
  List<String> _validateAddress(Address address) {
    final errors = <String>[];

    if (address.name.isEmpty) {
      errors.add('Le nom de l\'adresse est requis');
    }

    if (address.address.isEmpty) {
      errors.add('L\'adresse est requise');
    }

    if (address.city.isEmpty) {
      errors.add('La ville est requise');
    }

    // Le code postal est optionnel pour certains pays, mais s'il est fourni, il doit être valide
    if (address.postalCode.isNotEmpty &&
        !_isValidPostalCode(address.postalCode)) {
      errors.add('Le code postal est invalide');
    }

    // Valider les coordonnées si présentes
    if (address.latitude == null || address.longitude == null) {
      errors.add('Veuillez sélectionner une position sur la carte (coordonnées manquantes)');
    } else {
      if (address.latitude! < -90 || address.latitude! > 90) {
        errors.add('La latitude est invalide');
      }
      if (address.longitude! < -180 || address.longitude! > 180) {
        errors.add('La longitude est invalide');
      }
    }

    return errors;
  }

  // =====================================================
  // VALIDATION DES ADRESSES
  // =====================================================

  /// Valide les données d'une adresse
  ValidationResult validateAddressData({
    required String name,
    required String address,
    required String city,
    required String postalCode,
    AddressType? type,
    double? latitude,
    double? longitude,
  }) {
    final errors = <String>[];
    final fieldErrors = <String, String>{};

    if (name.trim().isEmpty) {
      errors.add('Le nom de l\'adresse est requis');
      fieldErrors['name'] = 'Le nom de l\'adresse est requis';
    } else if (name.length < 3) {
      errors.add('Le nom de l\'adresse doit contenir au moins 3 caractères');
      fieldErrors['name'] = 'Le nom est trop court';
    }

    if (address.trim().isEmpty) {
      errors.add('L\'adresse est requise');
      fieldErrors['address'] = 'L\'adresse est requise';
    } else if (address.length < 5) {
      errors.add('L\'adresse doit contenir au moins 5 caractères');
      fieldErrors['address'] = 'L\'adresse est trop courte';
    }

    if (city.trim().isEmpty) {
      errors.add('La ville est requise');
      fieldErrors['city'] = 'La ville est requise';
    }

    // Le code postal est optionnel, mais s'il est fourni, il doit être valide
    if (postalCode.trim().isNotEmpty && !_isValidPostalCode(postalCode)) {
      errors.add('Le code postal est invalide');
      fieldErrors['postalCode'] = 'Format de code postal invalide';
    }

    if (latitude != null && (latitude < -90 || latitude > 90)) {
      errors.add('La latitude est invalide');
      fieldErrors['latitude'] = 'Latitude invalide';
    }

    if (longitude != null && (longitude < -180 || longitude > 180)) {
      errors.add('La longitude est invalide');
      fieldErrors['longitude'] = 'Longitude invalide';
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      fieldErrors: fieldErrors,
    );
  }

  // =====================================================
  // VALIDATION DES PAIEMENTS
  // =====================================================

  /// Valide les données de paiement
  ValidationResult validatePayment({
    required String paymentMethod,
    required double amount,
    Map<String, dynamic>? paymentData,
  }) {
    final errors = <String>[];
    final fieldErrors = <String, String>{};

    // Valider le mode de paiement
    final validPaymentMethods = ['cash', 'card', 'mobile_money', 'wallet'];
    if (!validPaymentMethods.contains(paymentMethod.toLowerCase())) {
      errors.add('Mode de paiement invalide');
      fieldErrors['paymentMethod'] = 'Mode de paiement invalide';
    }

    // Valider le montant
    if (amount <= 0) {
      errors.add('Le montant doit être supérieur à 0');
      fieldErrors['amount'] = 'Montant invalide';
    }

    if (amount > 1000000) {
      errors.add('Le montant est trop élevé');
      fieldErrors['amount'] = 'Montant trop élevé';
    }

    // Valider les données spécifiques selon le mode de paiement
    if (paymentMethod.toLowerCase() == 'card' && paymentData != null) {
      final cardErrors = _validateCardPayment(paymentData);
      if (cardErrors.isNotEmpty) {
        errors.addAll(cardErrors);
        fieldErrors['card'] = cardErrors.join(', ');
      }
    }

    if (paymentMethod.toLowerCase() == 'mobile_money' && paymentData != null) {
      final mobileErrors = _validateMobileMoneyPayment(paymentData);
      if (mobileErrors.isNotEmpty) {
        errors.addAll(mobileErrors);
        fieldErrors['mobileMoney'] = mobileErrors.join(', ');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      fieldErrors: fieldErrors,
    );
  }

  /// Valide les données de paiement par carte
  List<String> _validateCardPayment(Map<String, dynamic> paymentData) {
    final errors = <String>[];

    final cardNumber = paymentData['cardNumber']?.toString() ?? '';
    if (cardNumber.isEmpty) {
      errors.add('Le numéro de carte est requis');
    } else if (!_isValidCardNumber(cardNumber)) {
      errors.add('Le numéro de carte est invalide');
    }

    final expiryDate = paymentData['expiryDate']?.toString() ?? '';
    if (expiryDate.isEmpty) {
      errors.add('La date d\'expiration est requise');
    } else if (!_isValidExpiryDate(expiryDate)) {
      errors.add('La date d\'expiration est invalide');
    }

    final cvv = paymentData['cvv']?.toString() ?? '';
    if (cvv.isEmpty) {
      errors.add('Le CVV est requis');
    } else if (cvv.length != 3 && cvv.length != 4) {
      errors.add('Le CVV doit contenir 3 ou 4 chiffres');
    }

    return errors;
  }

  /// Valide les données de paiement mobile money
  List<String> _validateMobileMoneyPayment(Map<String, dynamic> paymentData) {
    final errors = <String>[];

    final phoneNumber = paymentData['phoneNumber']?.toString() ?? '';
    if (phoneNumber.isEmpty) {
      errors.add('Le numéro de téléphone est requis');
    } else if (!_isValidPhoneNumber(phoneNumber)) {
      errors.add('Le numéro de téléphone est invalide');
    }

    return errors;
  }

  // =====================================================
  // VALIDATION DES PROMO CODES
  // =====================================================

  /// Valide un code promo avant application
  ValidationResult validatePromoCode({
    required String promoCode,
    required double orderTotal,
    DateTime? orderDate,
  }) {
    final errors = <String>[];
    final fieldErrors = <String, String>{};

    if (promoCode.trim().isEmpty) {
      errors.add('Le code promo est requis');
      fieldErrors['promoCode'] = 'Le code promo est requis';
    } else if (promoCode.length < 3) {
      errors.add('Le code promo doit contenir au moins 3 caractères');
      fieldErrors['promoCode'] = 'Code promo trop court';
    }

    // Note: La validation de l'existence et de la validité du code promo
    // doit être faite côté serveur. Cette validation vérifie seulement
    // le format et les prérequis.

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      fieldErrors: fieldErrors,
    );
  }

  // =====================================================
  // VALIDATION DES MENU ITEMS
  // =====================================================

  /// Valide un menu item avant ajout au panier
  ValidationResult validateMenuItemForCart({
    required MenuItem item,
    required int quantity,
  }) {
    final errors = <String>[];
    final fieldErrors = <String, String>{};

    if (!item.isAvailable) {
      errors.add('${item.name} n\'est plus disponible');
      fieldErrors['available'] = 'Article non disponible';
    }

    if (quantity <= 0) {
      errors.add('La quantité doit être supérieure à 0');
      fieldErrors['quantity'] = 'Quantité invalide';
    }

    if (quantity > item.availableQuantity) {
      errors.add(
        'La quantité demandée ($quantity) dépasse la quantité disponible (${item.availableQuantity})',
      );
      fieldErrors['quantity'] = 'Quantité insuffisante en stock';
    }

    if (item.price <= 0) {
      errors.add('Le prix de l\'article est invalide');
      fieldErrors['price'] = 'Prix invalide';
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      fieldErrors: fieldErrors,
    );
  }

  // =====================================================
  // MÉTHODES UTILITAIRES DE VALIDATION
  // =====================================================

  /// Vérifie si un code postal est valide
  /// Accepte les formats français (5 chiffres) et ivoiriens (plus flexibles)
  bool _isValidPostalCode(String postalCode) {
    final cleaned = postalCode.replaceAll(' ', '').replaceAll('-', '');
    // Format français : 5 chiffres
    // Format ivoirien : peut être vide ou avoir différents formats
    // On accepte : vide (optionnel), 5 chiffres, ou au moins 3 caractères alphanumériques
    if (cleaned.isEmpty) {
      return true; // Code postal optionnel pour certains pays
    }
    // Accepter 5 chiffres (format français) ou au moins 3 caractères alphanumériques
    return RegExp(r'^\d{5}$').hasMatch(cleaned) ||
        RegExp(r'^[A-Za-z0-9]{3,}$').hasMatch(cleaned);
  }

  /// Vérifie si un numéro de téléphone est valide
  bool _isValidPhoneNumber(String phone) {
    // Format français : +33 ou 0 suivi de 9 chiffres
    return RegExp(r'^(\+33|0)[1-9](\d{8})$')
        .hasMatch(phone.replaceAll(' ', '').replaceAll('-', ''));
  }

  /// Vérifie si un numéro de carte est valide (algorithme de Luhn)
  bool _isValidCardNumber(String cardNumber) {
    // Retirer les espaces
    final cleaned = cardNumber.replaceAll(' ', '').replaceAll('-', '');

    // Vérifier que c'est uniquement des chiffres
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return false;
    }

    // Vérifier la longueur (13-19 chiffres)
    if (cleaned.length < 13 || cleaned.length > 19) {
      return false;
    }

    // Algorithme de Luhn
    int sum = 0;
    bool alternate = false;

    for (int i = cleaned.length - 1; i >= 0; i--) {
      int digit = int.parse(cleaned[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit % 10) + 1;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  /// Vérifie si une date d'expiration de carte est valide
  bool _isValidExpiryDate(String expiryDate) {
    // Format MM/YY ou MM/YYYY
    final cleaned = expiryDate.replaceAll(' ', '').replaceAll('/', '');

    if (cleaned.length != 4 && cleaned.length != 6) {
      return false;
    }

    final month = int.tryParse(cleaned.substring(0, 2));
    final year = int.tryParse(cleaned.substring(2));

    if (month == null || year == null) {
      return false;
    }

    if (month < 1 || month > 12) {
      return false;
    }

    // Vérifier que la date n'est pas expirée
    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;

    if (year < currentYear || (year == currentYear && month < currentMonth)) {
      return false;
    }

    return true;
  }

  // =====================================================
  // VALIDATION GÉNÉRIQUE
  // =====================================================

  /// Valide une valeur selon un type
  ValidationResult validateValue({
    required dynamic value,
    required String fieldName,
    bool required = false,
    int? minLength,
    int? maxLength,
    double? minValue,
    double? maxValue,
    String? pattern,
    String? customMessage,
  }) {
    final errors = <String>[];
    final fieldErrors = <String, String>{};

    // Vérifier si requis
    if (required) {
      if (value == null || value.toString().trim().isEmpty) {
        errors.add('$fieldName est requis');
        fieldErrors[fieldName] = customMessage ?? 'Ce champ est requis';
        return ValidationResult(
          isValid: false,
          errors: errors,
          fieldErrors: fieldErrors,
        );
      }
    }

    // Si la valeur est null ou vide et non requise, c'est valide
    if (value == null || value.toString().trim().isEmpty) {
      return ValidationResult.valid();
    }

    final stringValue = value.toString();

    // Vérifier la longueur minimale
    if (minLength != null && stringValue.length < minLength) {
      errors.add('$fieldName doit contenir au moins $minLength caractères');
      fieldErrors[fieldName] = 'Minimum $minLength caractères';
    }

    // Vérifier la longueur maximale
    if (maxLength != null && stringValue.length > maxLength) {
      errors.add('$fieldName ne peut pas dépasser $maxLength caractères');
      fieldErrors[fieldName] = 'Maximum $maxLength caractères';
    }

    // Vérifier la valeur minimale (pour les nombres)
    final numValue = double.tryParse(stringValue);
    if (numValue != null && minValue != null && numValue < minValue) {
      errors.add('$fieldName doit être supérieur ou égal à $minValue');
      fieldErrors[fieldName] = 'Valeur minimale : $minValue';
    }

    // Vérifier la valeur maximale (pour les nombres)
    if (numValue != null && maxValue != null && numValue > maxValue) {
      errors.add('$fieldName doit être inférieur ou égal à $maxValue');
      fieldErrors[fieldName] = 'Valeur maximale : $maxValue';
    }

    // Vérifier le pattern (regex)
    if (pattern != null && !RegExp(pattern).hasMatch(stringValue)) {
      errors.add('$fieldName a un format invalide');
      fieldErrors[fieldName] = customMessage ?? 'Format invalide';
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      fieldErrors: fieldErrors,
    );
  }
}
