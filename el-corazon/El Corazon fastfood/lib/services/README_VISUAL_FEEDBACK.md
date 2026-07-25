# 🎨 Guide du Feedback Visuel Amélioré

## Vue d'ensemble

L'amélioration #8 implémente un système de feedback visuel amélioré avec :
- Animations fluides pour les messages
- Indicateurs de chargement contextuels
- Messages de succès/erreur avec actions
- Interface plus moderne et engageante

## Utilisation

### 1. Messages de Succès

#### Méthode de base
```dart
import 'package:fastfoodgo/services/visual_feedback_service.dart';

// Message simple
VisualFeedbackService.showSuccessMessage(
  context,
  'Commande passée avec succès !',
);

// Avec action
VisualFeedbackService.showSuccessMessage(
  context,
  'Article ajouté au panier',
  onAction: () {
    Navigator.pushNamed(context, '/cart');
  },
  actionLabel: 'Voir le panier',
);
```

#### Via extension (recommandé)
```dart
import 'package:fastfoodgo/services/visual_feedback_service.dart';

// Plus simple avec l'extension
context.showSuccess('Commande passée avec succès !');

// Avec action
context.showSuccess(
  'Article ajouté au panier',
  onAction: () => Navigator.pushNamed(context, '/cart'),
  actionLabel: 'Voir le panier',
);
```

### 2. Messages d'Erreur

```dart
// Message d'erreur simple
context.showError('Une erreur est survenue');

// Avec action de retry
context.showError(
  'Erreur de connexion',
  onAction: () => _retryOperation(),
  actionLabel: 'Réessayer',
);
```

### 3. Messages d'Avertissement et d'Information

```dart
// Avertissement
context.showWarning('Attention : Stock limité');

// Information
context.showInfo('Nouvelle fonctionnalité disponible !');
```

### 4. Feedback d'Actions Spécifiques

#### Ajout au panier
```dart
// Feedback automatique pour l'ajout au panier
context.showAddToCartFeedback(
  'Burger Classic',
  onViewCart: () => Navigator.pushNamed(context, '/cart'),
);
```

#### Commande passée
```dart
VisualFeedbackService.showOrderPlacedFeedback(
  context,
  orderId,
  onViewOrder: () => Navigator.pushNamed(context, '/order/$orderId'),
);
```

#### Action personnalisée
```dart
VisualFeedbackService.showActionFeedback(
  context,
  'Favori ajouté',
  icon: Icons.favorite,
  color: Colors.red,
  onView: () => Navigator.pushNamed(context, '/favorites'),
);
```

### 5. Indicateurs de Chargement

#### Chargement simple
```dart
// Afficher l'indicateur
final overlayEntry = context.showLoading();

// Effectuer l'opération
await performOperation();

// Masquer l'indicateur
VisualFeedbackService.hideLoadingIndicator(overlayEntry);
```

#### Chargement avec message
```dart
// Afficher avec message
final overlayEntry = context.showLoading(message: 'Chargement des données...');

try {
  await loadData();
} finally {
  // Toujours masquer, même en cas d'erreur
  VisualFeedbackService.hideLoadingIndicator(overlayEntry);
}
```

#### Méthode complète
```dart
VisualFeedbackService.showLoadingWithMessage(
  context,
  'Traitement en cours...',
);
```

### 6. Dialogues Améliorés

#### Dialogue de succès
```dart
await VisualFeedbackService.showSuccessDialog(
  context,
  title: 'Succès',
  message: 'Votre commande a été passée avec succès !',
  onPressed: () {
    Navigator.pushNamed(context, '/orders');
  },
);
```

#### Dialogue d'erreur
```dart
await VisualFeedbackService.showErrorDialog(
  context,
  title: 'Erreur',
  message: 'Impossible de passer la commande. Veuillez réessayer.',
  onPressed: () {
    // Action après fermeture
  },
);
```

### 7. Toasts

#### Toast simple
```dart
context.showToast('Opération réussie');
```

#### Toast avec durée personnalisée
```dart
context.showToast(
  'Message temporaire',
  duration: Duration(seconds: 5),
);
```

#### Feedback de copie
```dart
VisualFeedbackService.showCopyFeedback(context, 'Code promo');
// Affiche : "Code promo copié !"
```

## Exemples Complets

### Exemple 1 : Ajout au panier avec feedback
```dart
void _addToCart(MenuItem item) async {
  setState(() => _isAdding = true);
  
  try {
    await cartService.addItem(item);
    
    // Afficher le feedback avec animation
    context.showAddToCartFeedback(
      item.name,
      onViewCart: () {
        Navigator.pushNamed(context, '/cart');
      },
    );
  } catch (e) {
    // Afficher l'erreur avec action de retry
    context.showError(
      'Impossible d\'ajouter au panier',
      onAction: () => _addToCart(item),
      actionLabel: 'Réessayer',
    );
  } finally {
    setState(() => _isAdding = false);
  }
}
```

### Exemple 2 : Passer une commande avec indicateur de chargement
```dart
Future<void> _placeOrder() async {
  // Afficher l'indicateur de chargement
  final overlayEntry = context.showLoading(
    message: 'Traitement de votre commande...',
  );

  try {
    final orderId = await appService.placeOrder(
      address: _selectedAddress,
      paymentMethod: _paymentMethod,
    );

    // Masquer l'indicateur
    VisualFeedbackService.hideLoadingIndicator(overlayEntry);

    // Afficher le message de succès avec action
    VisualFeedbackService.showOrderPlacedFeedback(
      context,
      orderId,
      onViewOrder: () {
        Navigator.pushNamed(context, '/order/$orderId');
      },
    );
  } catch (e) {
    // Masquer l'indicateur en cas d'erreur
    VisualFeedbackService.hideLoadingIndicator(overlayEntry);

    // Afficher l'erreur avec retry
    context.showError(
      'Erreur lors du passage de commande',
      onAction: () => _placeOrder(),
      actionLabel: 'Réessayer',
    );
  }
}
```

### Exemple 3 : Opération asynchrone avec feedback
```dart
Future<void> _loadData() async {
  final overlayEntry = context.showLoading(
    message: 'Chargement des données...',
  );

  try {
    final data = await fetchData();
    
    // Masquer le chargement
    VisualFeedbackService.hideLoadingIndicator(overlayEntry);

    // Afficher le succès
    context.showSuccess(
      '${data.length} éléments chargés',
    );
  } catch (e) {
    // Masquer le chargement
    VisualFeedbackService.hideLoadingIndicator(overlayEntry);

    // Afficher l'erreur
    context.showError(
      'Erreur de chargement',
      onAction: () => _loadData(),
      actionLabel: 'Réessayer',
    );
  }
}
```

### Exemple 4 : Validation avec feedback visuel
```dart
Future<void> _validateAndSubmit() async {
  // Valider
  final result = validator.validateForm(_formData);
  
  if (!result.isValid) {
    // Afficher les erreurs
    context.showError(
      result.errors.join('\n'),
      duration: Duration(seconds: 5),
    );
    return;
  }

  // Afficher le chargement
  final overlayEntry = context.showLoading(
    message: 'Envoi en cours...',
  );

  try {
    await submitForm(_formData);
    
    // Masquer le chargement
    VisualFeedbackService.hideLoadingIndicator(overlayEntry);

    // Afficher le succès avec dialogue
    await VisualFeedbackService.showSuccessDialog(
      context,
      title: 'Succès',
      message: 'Formulaire envoyé avec succès !',
    );
  } catch (e) {
    // Masquer le chargement
    VisualFeedbackService.hideLoadingIndicator(overlayEntry);

    // Afficher l'erreur
    context.showError('Erreur lors de l\'envoi');
  }
}
```

## Animations

### Messages de Succès
- Icône avec animation d'échelle (scale)
- Texte avec fade-in et slide

### Messages d'Erreur
- Icône avec animation élastique (elastic)
- Texte avec fade-in et slide

### Dialogues
- Animation d'échelle (scale) et fade-in
- Transition fluide

## Personnalisation

### Durée d'affichage
```dart
VisualFeedbackService.showSuccessMessage(
  context,
  'Message',
  duration: Duration(seconds: 5), // Personnaliser la durée
);
```

### Comportement
```dart
VisualFeedbackService.showSuccessMessage(
  context,
  'Message',
  behavior: SnackBarBehavior.fixed, // Ou .floating (défaut)
);
```

### Couleurs personnalisées
```dart
VisualFeedbackService.showActionFeedback(
  context,
  'Action personnalisée',
  icon: Icons.star,
  color: Colors.amber, // Couleur personnalisée
);
```

## Bonnes Pratiques

### 1. Masquer les messages précédents
Les méthodes masquent automatiquement les messages précédents, mais vous pouvez aussi le faire manuellement :
```dart
ScaffoldMessenger.of(context).hideCurrentSnackBar();
context.showSuccess('Nouveau message');
```

### 2. Toujours masquer les indicateurs de chargement
```dart
// ✅ Bon
final overlayEntry = context.showLoading();
try {
  await operation();
} finally {
  VisualFeedbackService.hideLoadingIndicator(overlayEntry);
}

// ❌ Éviter (si l'opération échoue, l'indicateur reste visible)
final overlayEntry = context.showLoading();
await operation(); // Peut échouer
VisualFeedbackService.hideLoadingIndicator(overlayEntry); // Pas exécuté si erreur
```

### 3. Utiliser les actions pour améliorer l'UX
```dart
// ✅ Bon - Avec action
context.showSuccess(
  'Article ajouté au panier',
  onAction: () => Navigator.pushNamed(context, '/cart'),
  actionLabel: 'Voir le panier',
);

// ❌ Moins bon - Sans action
context.showSuccess('Article ajouté au panier');
```

### 4. Messages clairs et concis
```dart
// ✅ Bon
context.showError('Connexion internet requise');

// ❌ Éviter
context.showError('Erreur 500: Internal Server Error');
```

## Bénéfices

- ✅ **Meilleure communication** : Messages clairs avec animations
- ✅ **Actions rapides** : Boutons d'action dans les messages
- ✅ **Interface moderne** : Animations fluides et design épuré
- ✅ **Feedback contextuel** : Indicateurs de chargement adaptés
- ✅ **Cohérence** : Système uniforme dans toute l'application

## Migration depuis l'Ancien Code

### Avant
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Article ajouté au panier'),
    backgroundColor: Colors.green,
  ),
);
```

### Après
```dart
// Avec animation et action
context.showAddToCartFeedback(
  'Article',
  onViewCart: () => Navigator.pushNamed(context, '/cart'),
);
```

## Types de Feedback

1. **Messages de succès** : Vert, avec icône check_circle
2. **Messages d'erreur** : Rouge, avec icône error, action de retry par défaut
3. **Messages d'avertissement** : Orange, avec icône warning_amber
4. **Messages d'information** : Bleu, avec icône info_outline
5. **Indicateurs de chargement** : Overlay avec spinner et message
6. **Toasts** : Messages temporaires sans action
7. **Dialogues** : Boîtes de dialogue avec animations

