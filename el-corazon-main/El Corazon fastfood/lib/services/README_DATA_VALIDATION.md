# ✅ Guide de Validation des Données Avant Envoi

## Vue d'ensemble

L'amélioration #6 implémente un système de validation des données métier avant l'envoi au serveur, permettant de :
- Détecter les erreurs côté client avant l'envoi
- Fournir un feedback immédiat à l'utilisateur
- Réduire les erreurs serveur et améliorer l'expérience utilisateur

## Utilisation

### 1. Validation des Commandes

#### Validation complète d'une commande
```dart
import 'package:fastfoodgo/services/data_validator_service.dart';

final validator = DataValidatorService();

final result = validator.validateOrder(
  items: cartItems,
  deliveryAddress: selectedAddress,
  paymentMethod: 'card',
  total: orderTotal,
);

if (!result.isValid) {
  // Afficher les erreurs
  for (final error in result.errors) {
    showError(error);
  }
  
  // Ou afficher les erreurs par champ
  result.fieldErrors.forEach((field, error) {
    showFieldError(field, error);
  });
} else {
  // La commande est valide, procéder à l'envoi
  await placeOrder();
}
```

#### Validation d'un item avant ajout au panier
```dart
final result = validator.validateMenuItemForCart(
  item: menuItem,
  quantity: 2,
);

if (!result.isValid) {
  // Afficher les erreurs
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result.errors.first),
      backgroundColor: Colors.red,
    ),
  );
} else {
  // Ajouter au panier
  cartService.addItem(menuItem, quantity: 2);
}
```

### 2. Validation des Adresses

```dart
final result = validator.validateAddressData(
  name: 'Maison',
  address: '123 Rue de la Paix',
  city: 'Paris',
  postalCode: '75001',
  type: AddressType.home,
  latitude: 48.8566,
  longitude: 2.3522,
);

if (!result.isValid) {
  // Afficher les erreurs
  result.fieldErrors.forEach((field, error) {
    // Mettre à jour l'UI pour afficher l'erreur sur le champ
    updateFieldError(field, error);
  });
} else {
  // Sauvegarder l'adresse
  await saveAddress(addressData);
}
```

### 3. Validation des Paiements

```dart
// Paiement par carte
final result = validator.validatePayment(
  paymentMethod: 'card',
  amount: orderTotal,
  paymentData: {
    'cardNumber': '1234 5678 9012 3456',
    'expiryDate': '12/25',
    'cvv': '123',
  },
);

if (!result.isValid) {
  // Afficher les erreurs
  showPaymentErrors(result.errors);
} else {
  // Procéder au paiement
  await processPayment();
}

// Paiement mobile money
final mobileResult = validator.validatePayment(
  paymentMethod: 'mobile_money',
  amount: orderTotal,
  paymentData: {
    'phoneNumber': '+33612345678',
  },
);
```

### 4. Validation des Codes Promo

```dart
final result = validator.validatePromoCode(
  promoCode: 'PROMO2024',
  orderTotal: 50.0,
  orderDate: DateTime.now(),
);

if (!result.isValid) {
  showError(result.errors.first);
} else {
  // Valider avec le serveur
  await validatePromoCodeWithServer('PROMO2024');
}
```

### 5. Validation Générique

```dart
// Validation d'une valeur avec règles personnalisées
final result = validator.validateValue(
  value: email,
  fieldName: 'email',
  required: true,
  minLength: 5,
  maxLength: 100,
  pattern: r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  customMessage: 'Veuillez entrer un email valide',
);

if (!result.isValid) {
  // Afficher l'erreur
  showFieldError('email', result.fieldErrors['email']!);
}
```

## Exemples Complets

### Exemple 1 : Validation avant création de commande
```dart
class CheckoutScreen extends StatefulWidget {
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _validator = DataValidatorService();
  final _cartService = CartService();
  final _appService = AppService();

  Future<void> _placeOrder() async {
    // Récupérer les données
    final cartItems = _cartService.items;
    final selectedAddress = _appService.selectedAddress;
    final paymentMethod = _selectedPaymentMethod;
    final total = _cartService.total;

    // Valider avant l'envoi
    final validationResult = _validator.validateOrder(
      items: cartItems,
      deliveryAddress: selectedAddress,
      paymentMethod: paymentMethod,
      total: total,
    );

    if (!validationResult.isValid) {
      // Afficher les erreurs
      _showValidationErrors(validationResult);
      return;
    }

    // La validation est passée, procéder à la commande
    setState(() => _isLoading = true);

    try {
      final orderId = await _appService.placeOrder(
        cartItems: cartItems,
        deliveryAddress: selectedAddress!,
        paymentMethod: paymentMethod!,
      );

      // Naviguer vers l'écran de confirmation
      Navigator.pushNamed(
        context,
        '/order-confirmation',
        arguments: orderId,
      );
    } catch (e) {
      // Gérer les erreurs serveur
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showValidationErrors(ValidationResult result) {
    // Afficher toutes les erreurs
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreurs de validation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: result.errors.map((error) => Text('• $error')).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

### Exemple 2 : Validation en temps réel dans un formulaire
```dart
class AddressForm extends StatefulWidget {
  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  final _validator = DataValidatorService();
  final _formKey = GlobalKey<FormState>();
  
  String _name = '';
  String _address = '';
  String _city = '';
  String _postalCode = '';
  
  Map<String, String> _fieldErrors = {};

  void _validateField(String fieldName, String value) {
    ValidationResult result;
    
    switch (fieldName) {
      case 'name':
        result = _validator.validateValue(
          value: value,
          fieldName: 'name',
          required: true,
          minLength: 3,
        );
        break;
      case 'postalCode':
        result = _validator.validateValue(
          value: value,
          fieldName: 'postalCode',
          required: true,
          pattern: r'^\d{5}$',
        );
        break;
      // ... autres champs
      default:
        return;
    }

    setState(() {
      if (result.isValid) {
        _fieldErrors.remove(fieldName);
      } else {
        _fieldErrors[fieldName] = result.fieldErrors[fieldName] ?? '';
      }
    });
  }

  Future<void> _saveAddress() async {
    // Validation complète avant sauvegarde
    final result = _validator.validateAddressData(
      name: _name,
      address: _address,
      city: _city,
      postalCode: _postalCode,
    );

    if (!result.isValid) {
      setState(() => _fieldErrors = result.fieldErrors);
      return;
    }

    // Sauvegarder
    await saveAddress();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Nom',
              errorText: _fieldErrors['name'],
            ),
            onChanged: (value) {
              _name = value;
              _validateField('name', value);
            },
          ),
          // ... autres champs
        ],
      ),
    );
  }
}
```

### Exemple 3 : Validation avant ajout au panier
```dart
void _addToCart(MenuItem item) {
  // Valider avant d'ajouter
  final result = _validator.validateMenuItemForCart(
    item: item,
    quantity: _selectedQuantity,
  );

  if (!result.isValid) {
    // Afficher l'erreur
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.errors.first),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    return;
  }

  // Ajouter au panier
  cartService.addItem(item, quantity: _selectedQuantity);
  
  // Afficher un message de succès
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${item.name} ajouté au panier'),
      backgroundColor: Colors.green,
    ),
  );
}
```

## Types de Validation

### Validation de Commande
- ✅ Vérifie que le panier n'est pas vide
- ✅ Valide chaque item (disponibilité, quantité, prix)
- ✅ Vérifie l'adresse de livraison
- ✅ Valide le mode de paiement
- ✅ Vérifie la cohérence du total

### Validation d'Adresse
- ✅ Nom requis (minimum 3 caractères)
- ✅ Adresse requise (minimum 5 caractères)
- ✅ Ville requise
- ✅ Code postal valide (format français)
- ✅ Coordonnées GPS valides si présentes

### Validation de Paiement
- ✅ Mode de paiement valide
- ✅ Montant supérieur à 0
- ✅ Montant raisonnable (max 1,000,000)
- ✅ Données spécifiques selon le mode (carte, mobile money)

### Validation de Menu Item
- ✅ Item disponible
- ✅ Quantité valide (supérieure à 0)
- ✅ Quantité disponible en stock
- ✅ Prix valide

## Bonnes Pratiques

### 1. Valider avant l'envoi
```dart
// ✅ Bon
final result = validator.validateOrder(...);
if (!result.isValid) {
  showErrors(result.errors);
  return;
}
await placeOrder();

// ❌ Éviter
await placeOrder(); // Peut échouer côté serveur
```

### 2. Afficher les erreurs de manière claire
```dart
// ✅ Bon
if (!result.isValid) {
  result.fieldErrors.forEach((field, error) {
    // Afficher l'erreur sur le champ correspondant
    _updateFieldError(field, error);
  });
}

// ❌ Éviter
if (!result.isValid) {
  print(result.errors); // Pas visible pour l'utilisateur
}
```

### 3. Valider en temps réel pour une meilleure UX
```dart
// ✅ Bon
TextFormField(
  onChanged: (value) {
    final result = validator.validateValue(
      value: value,
      fieldName: 'email',
      required: true,
      pattern: emailPattern,
    );
    setState(() => _emailError = result.fieldErrors['email']);
  },
)

// ❌ Éviter
// Valider seulement à la soumission
```

### 4. Combiner avec la validation serveur
```dart
// ✅ Bon
// Validation côté client d'abord
final clientResult = validator.validateOrder(...);
if (!clientResult.isValid) {
  showErrors(clientResult.errors);
  return;
}

// Puis validation serveur
try {
  await placeOrder();
} catch (e) {
  // Gérer les erreurs serveur
  handleServerError(e);
}
```

## Bénéfices

- ✅ **Moins d'erreurs serveur** : Détection précoce des problèmes
- ✅ **Feedback immédiat** : L'utilisateur voit les erreurs tout de suite
- ✅ **Meilleure UX** : Validation en temps réel
- ✅ **Performance** : Moins de requêtes serveur inutiles
- ✅ **Cohérence** : Validation uniforme dans toute l'application

## Migration

### Avant
```dart
// Pas de validation avant l'envoi
await placeOrder();
```

### Après
```dart
// Validation avant l'envoi
final result = validator.validateOrder(...);
if (!result.isValid) {
  showErrors(result.errors);
  return;
}
await placeOrder();
```

