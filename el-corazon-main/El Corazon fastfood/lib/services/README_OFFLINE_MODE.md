# 📡 Guide du Mode Offline Amélioré

## Vue d'ensemble

L'amélioration #9 implémente un mode offline amélioré avec :
- Indicateur visuel du statut de connexion
- Synchronisation transparente des données
- Fonctionnalités améliorées en mode offline
- Détection intelligente de la connectivité

## Architecture

### 1. ConnectivityService

Service centralisé pour gérer la connectivité réseau avec :
- Détection automatique des changements de connectivité
- Vérification de l'accès Internet réel (pas seulement la présence d'un réseau)
- Stream pour les changements de connectivité
- Vérification périodique (toutes les 30 secondes)

### 2. OfflineIndicator

Widget pour afficher le statut de connexion :
- `OfflineIndicator` : Indicateur en haut de l'écran
- `OfflineBanner` : Bannière en bas de l'écran
- `ConnectivityStatusIcon` : Icône dans l'AppBar

### 3. OfflineSyncService

Service existant amélioré pour :
- Sauvegarder les données en local
- Synchroniser automatiquement quand la connexion est rétablie
- Gérer les queues d'opérations en attente

## Utilisation

### 1. Intégration dans main.dart

Le `ConnectivityService` est déjà intégré dans `main.dart` :

```dart
ChangeNotifierProvider(
  create: (_) => ConnectivityService()..initialize(),
),
```

### 2. Ajouter l'indicateur offline

#### Dans un Scaffold

```dart
import '../widgets/offline_indicator.dart';

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Mon Écran'),
      actions: [
        ConnectivityStatusIcon(), // Icône de statut
      ],
    ),
    body: Column(
      children: [
        OfflineIndicator(), // Indicateur en haut
        Expanded(
          child: YourContent(),
        ),
      ],
    ),
  );
}
```

#### Avec Stack pour une bannière

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      children: [
        YourContent(),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: OfflineBanner(),
        ),
      ],
    ),
  );
}
```

### 3. Utiliser ConnectivityService dans le code

#### Vérifier le statut de connexion

```dart
import '../services/connectivity_service.dart';

// Via Provider
final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
if (connectivityService.isOnline) {
  // Exécuter l'opération en ligne
  await performOnlineOperation();
} else {
  // Sauvegarder pour synchronisation ultérieure
  await saveOffline();
}
```

#### Écouter les changements de connectivité

```dart
final connectivityService = Provider.of<ConnectivityService>(context, listen: false);

connectivityService.onConnectivityChanged.listen((isOnline) {
  if (isOnline) {
    // Connexion rétablie - synchroniser
    await syncPendingData();
  } else {
    // Mode offline - afficher un message
    showOfflineMessage();
  }
});
```

#### Force une vérification

```dart
final isOnline = await connectivityService.forceCheck();
if (isOnline) {
  // Effectuer une opération
}
```

### 4. Intégrer avec OfflineSyncService

```dart
import '../services/offline_sync_service.dart';
import '../services/connectivity_service.dart';

final offlineSync = Provider.of<OfflineSyncService>(context, listen: false);
final connectivity = Provider.of<ConnectivityService>(context, listen: false);

// Vérifier la connectivité avant une opération
if (connectivity.isOnline) {
  // Opération en ligne
  await performOnlineOperation();
} else {
  // Sauvegarder en local pour synchronisation ultérieure
  await offlineSync.saveOrderOffline(orderData);
}
```

### 5. Consumer pour UI réactive

```dart
Consumer<ConnectivityService>(
  builder: (context, connectivityService, child) {
    final isOnline = connectivityService.isOnline;
    
    return Column(
      children: [
        if (!isOnline)
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.orange,
            child: Text('Mode offline'),
          ),
        // Votre contenu
        YourContent(),
      ],
    );
  },
)
```

## Composants

### OfflineIndicator

Indicateur principal affiché en haut de l'écran :

```dart
OfflineIndicator(
  showWhenOnline: false, // Afficher même quand en ligne (par défaut false)
  backgroundColor: Colors.orange, // Couleur personnalisée
  textColor: Colors.white, // Couleur du texte
  padding: EdgeInsets.all(16), // Padding personnalisé
  height: 48, // Hauteur personnalisée
)
```

**Propriétés :**
- `showWhenOnline` : Afficher l'indicateur même quand en ligne
- `backgroundColor` : Couleur de fond personnalisée
- `textColor` : Couleur du texte personnalisée
- `padding` : Padding personnalisé
- `height` : Hauteur personnalisée

### OfflineBanner

Bannière en bas de l'écran :

```dart
OfflineBanner(
  backgroundColor: Colors.orange,
  textColor: Colors.white,
  dismissible: true, // Peut être masquée
)
```

**Propriétés :**
- `backgroundColor` : Couleur de fond
- `textColor` : Couleur du texte
- `dismissible` : Peut être masquée par l'utilisateur

### ConnectivityStatusIcon

Icône dans l'AppBar :

```dart
ConnectivityStatusIcon(
  onlineColor: Colors.green,
  offlineColor: Colors.orange,
  size: 24,
)
```

**Propriétés :**
- `onlineColor` : Couleur quand en ligne
- `offlineColor` : Couleur quand hors ligne
- `size` : Taille de l'icône

## Exemples Complets

### Exemple 1 : Écran avec indicateur offline

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/offline_indicator.dart';
import '../services/connectivity_service.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mon Écran'),
        actions: [
          ConnectivityStatusIcon(),
        ],
      ),
      body: Column(
        children: [
          OfflineIndicator(),
          Expanded(
            child: Consumer<ConnectivityService>(
              builder: (context, connectivity, child) {
                if (!connectivity.isOnline) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Mode hors ligne',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Vos données seront synchronisées dès que la connexion sera rétablie.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                return YourOnlineContent();
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

### Exemple 2 : Opération avec gestion offline

```dart
Future<void> _placeOrder() async {
  final connectivity = Provider.of<ConnectivityService>(context, listen: false);
  final offlineSync = Provider.of<OfflineSyncService>(context, listen: false);
  
  // Afficher l'indicateur de chargement
  final overlayEntry = context.showLoading(
    message: 'Traitement de votre commande...',
  );

  try {
    if (connectivity.isOnline) {
      // Passer la commande en ligne
      final orderId = await appService.placeOrder(
        address: _selectedAddress,
        paymentMethod: _paymentMethod,
      );
      
      VisualFeedbackService.hideLoadingIndicator(overlayEntry);
      
      context.showSuccess(
        'Commande passée avec succès !',
        onAction: () => Navigator.pushNamed(context, '/order/$orderId'),
        actionLabel: 'Voir la commande',
      );
    } else {
      // Sauvegarder en local pour synchronisation ultérieure
      final orderData = {
        'items': _cartItems,
        'address': _selectedAddress.toMap(),
        'paymentMethod': _paymentMethod.toString(),
        'total': _total,
      };
      
      await offlineSync.saveOrderOffline(orderData);
      
      VisualFeedbackService.hideLoadingIndicator(overlayEntry);
      
      context.showInfo(
        'Commande sauvegardée - Elle sera synchronisée dès que la connexion sera rétablie.',
        duration: Duration(seconds: 5),
      );
    }
  } catch (e) {
    VisualFeedbackService.hideLoadingIndicator(overlayEntry);
    
    context.showError(
      'Erreur lors du passage de commande',
      onAction: () => _placeOrder(),
      actionLabel: 'Réessayer',
    );
  }
}
```

### Exemple 3 : Synchronisation automatique

```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    final connectivity = Provider.of<ConnectivityService>(context, listen: false);
    
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      (isOnline) async {
        if (isOnline) {
          // Connexion rétablie - synchroniser
          await _syncPendingData();
        }
      },
    );
  }

  Future<void> _syncPendingData() async {
    final offlineSync = Provider.of<OfflineSyncService>(context, listen: false);
    
    // Afficher un message
    context.showInfo('Synchronisation en cours...');
    
    try {
      // Synchroniser les données en attente
      await offlineSync.syncPendingData();
      
      context.showSuccess('Synchronisation terminée !');
    } catch (e) {
      context.showError('Erreur lors de la synchronisation');
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YourWidget();
  }
}
```

## Bonnes Pratiques

### 1. Toujours vérifier la connectivité avant les opérations critiques

```dart
// ✅ Bon
if (connectivityService.isOnline) {
  await performOnlineOperation();
} else {
  await saveOffline();
}

// ❌ Éviter - Ne pas gérer le mode offline
await performOnlineOperation(); // Peut échouer en mode offline
```

### 2. Informer l'utilisateur du statut de connexion

```dart
// ✅ Bon - Afficher un indicateur visuel
OfflineIndicator()

// ❌ Éviter - Laisser l'utilisateur dans l'ignorance
// Pas d'indication visuelle
```

### 3. Synchroniser automatiquement quand la connexion est rétablie

```dart
// ✅ Bon - Écouter les changements
connectivityService.onConnectivityChanged.listen((isOnline) {
  if (isOnline) {
    await syncPendingData();
  }
});

// ❌ Éviter - Ne pas synchroniser automatiquement
// L'utilisateur doit relancer l'app
```

### 4. Sauvegarder les données en local pour le mode offline

```dart
// ✅ Bon - Sauvegarder en local
if (!connectivity.isOnline) {
  await offlineSync.saveOrderOffline(orderData);
}

// ❌ Éviter - Perdre les données en mode offline
// Les données sont perdues si pas de connexion
```

## Bénéfices

- ✅ **Utilisateur informé** : Indicateur clair du statut de connexion
- ✅ **Fonctionnalité améliorée** : Possibilité d'utiliser l'app en mode offline
- ✅ **Synchronisation transparente** : Les données sont synchronisées automatiquement
- ✅ **Meilleure expérience** : Pas de frustration en cas de perte de connexion

## Détection de Connectivité

Le `ConnectivityService` effectue deux vérifications :

1. **Vérification du type de connexion** : Wi-Fi, mobile, etc.
2. **Vérification de l'accès Internet réel** : Test de connexion à un serveur DNS

Cela garantit qu'on détecte non seulement la présence d'un réseau, mais aussi l'accès réel à Internet.

