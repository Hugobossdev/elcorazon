# Guide d'utilisation du service d'alertes

## 📋 Vue d'ensemble

Le service d'alertes (`AlertService`) permet de gérer tous les messages d'alerte de l'application de manière centralisée et cohérente.

## 🚀 Utilisation rapide

### 1. Via les extensions (recommandé)

```dart
import 'package:fastfoodgo/utils/alert_extensions.dart';

// Dans votre widget
context.showSuccessMessage('Opération réussie !');
context.showErrorMessage('Une erreur est survenue');
context.showWarningMessage('Attention !');
context.showInfoMessage('Information importante');

// Confirmation
final confirmed = await context.showConfirmation(
  message: 'Êtes-vous sûr de vouloir continuer ?',
  title: 'Confirmation',
);
```

### 2. Via le service directement

```dart
import 'package:fastfoodgo/services/alert_service.dart';

// SnackBars
AlertService().showSuccessSnackBar(context, 'Succès !');
AlertService().showErrorSnackBar(context, 'Erreur !');
AlertService().showWarningSnackBar(context, 'Avertissement !');
AlertService().showInfoSnackBar(context, 'Information !');

// Alertes avec actions
final result = await AlertService().showActionAlert(
  context,
  message: 'Choisissez une action',
  title: 'Action requise',
  actions: [
    AlertAction(id: 'save', label: 'Enregistrer'),
    AlertAction(id: 'cancel', label: 'Annuler'),
  ],
);
```

### 3. Widgets d'affichage

```dart
import 'package:fastfoodgo/widgets/alert_banner.dart';

// Afficher une bannière d'alerte en haut de l'écran
AlertBanner(
  dismissible: true,
  margin: EdgeInsets.all(16),
)

// Afficher une liste d'alertes
AlertList(
  dismissible: true,
  margin: EdgeInsets.all(16),
)
```

## 📝 Types d'alertes

- **Success** : Messages de succès (vert)
- **Error** : Messages d'erreur (rouge)
- **Warning** : Messages d'avertissement (orange)
- **Info** : Messages d'information (bleu)

## 🎨 Personnalisation

### Durée d'affichage

```dart
context.showSuccessMessage(
  'Message',
  duration: Duration(seconds: 5),
);
```

### Titre personnalisé

```dart
AlertService().showError(
  'Message d\'erreur',
  title: 'Erreur critique',
);
```

### Confirmation personnalisée

```dart
final confirmed = await context.showConfirmation(
  message: 'Voulez-vous supprimer cet élément ?',
  title: 'Suppression',
  confirmText: 'Supprimer',
  cancelText: 'Annuler',
  confirmColor: Colors.red,
);
```

## 🔧 Intégration dans les écrans

```dart
import 'package:fastfoodgo/utils/alert_extensions.dart';
import 'package:fastfoodgo/widgets/alert_banner.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Bannière d'alerte en haut
          AlertBanner(),
          
          // Contenu de l'écran
          Expanded(
            child: YourContent(),
          ),
        ],
      ),
    );
  }
  
  void _handleAction(BuildContext context) {
    try {
      // Votre logique
      context.showSuccessMessage('Action réussie !');
    } catch (e) {
      context.showErrorMessage('Erreur: $e');
    }
  }
}
```

## ✅ Bonnes pratiques

1. **Utilisez les extensions** pour la simplicité
2. **Personnalisez la durée** selon l'importance du message
3. **Utilisez les widgets** pour les alertes persistantes
4. **Gérez les erreurs** avec des messages clairs
5. **Confirmez les actions critiques** avec `showConfirmation`

## 📚 Exemples complets

Voir les fichiers suivants pour des exemples :
- `lib/screens/client/cart_screen.dart`
- `lib/screens/client/menu_screen.dart`
- `lib/screens/client/client_home_screen.dart`

