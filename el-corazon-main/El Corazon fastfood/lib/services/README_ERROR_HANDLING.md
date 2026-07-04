# 🛡️ Guide de Gestion d'Erreurs Centralisée

## Vue d'ensemble

L'amélioration #5 implémente un système de gestion d'erreurs centralisé avec :
- Retry automatique avec backoff exponentiel
- Traduction des erreurs techniques en messages compréhensibles
- Gestion centralisée de tous les types d'erreurs

## Utilisation

### 1. Retry Automatique

#### Méthode de base
```dart
import 'package:fastfoodgo/services/error_handler_service.dart';

// Exécuter une opération avec retry automatique
final result = await ErrorHandlerService.handleWithRetry(
  operation: () async {
    // Votre opération qui peut échouer
    return await databaseService.getMenuItems();
  },
  maxRetries: 3,  // 3 tentatives maximum
  delay: Duration(seconds: 1),  // Délai initial de 1 seconde
  exponentialBackoff: true,  // Backoff exponentiel activé
);
```

#### Avec retry conditionnel
```dart
final result = await ErrorHandlerService.handleWithRetry(
  operation: () => fetchData(),
  maxRetries: 5,
  retryOn: (error) {
    // Retry seulement sur les erreurs réseau
    return ErrorHandlerService.isRetryableError(error);
  },
);
```

### 2. Traduction des Erreurs

#### Traduire une erreur
```dart
try {
  await someOperation();
} catch (e) {
  final userMessage = ErrorHandlerService.translateError(e);
  // Afficher le message à l'utilisateur
  showSnackBar(userMessage);
}
```

#### Messages traduits automatiquement

**Erreurs réseau :**
- `SocketException` → "Vérifiez votre connexion internet et réessayez."
- `TimeoutException` → "Le serveur met trop de temps à répondre. Veuillez réessayer."
- `HttpException` → "Erreur de communication avec le serveur. Veuillez réessayer."

**Erreurs Supabase :**
- `PostgrestException` avec code `PGRST116` → "Aucun résultat trouvé."
- `PostgrestException` avec code `42501` → "Vous n'avez pas la permission d'effectuer cette action."
- `PostgrestException` avec code `23505` → "Cette information existe déjà."

**Erreurs d'authentification :**
- `AuthException` avec "invalid credentials" → "Email ou mot de passe incorrect."
- `AuthException` avec "email not confirmed" → "Veuillez confirmer votre email avant de continuer."
- `AuthException` avec "token expired" → "Votre session a expiré. Veuillez vous reconnecter."

### 3. Exécution avec Gestion d'Erreurs

#### Méthode complète avec UI
```dart
final result = await ErrorHandlerService.handleOperation(
  context: context,
  operation: () async {
    return await databaseService.createOrder(orderData);
  },
  successMessage: 'Commande créée avec succès !',
  showErrorSnackBar: true,
  maxRetries: 3,
);

if (result != null) {
  // Opération réussie
  print('Order ID: ${result.id}');
}
```

#### Avec résultat structuré
```dart
final result = await ErrorHandlerService.executeWithResult(
  operation: () => fetchUserData(),
  maxRetries: 3,
);

if (result.isSuccess) {
  // Utiliser result.data
  final userData = result.data!;
} else {
  // Afficher result.errorMessage
  showError(result.errorMessage!);
}
```

### 4. Logging des Erreurs

```dart
final errorHandler = ErrorHandlerService();

// Logger une erreur
errorHandler.logError(
  'Erreur lors du chargement du menu',
  code: 'MENU_LOAD_ERROR',
  details: exception,
  stackTrace: stackTrace,
);

// Logger une erreur réseau
errorHandler.logNetworkError('fetchMenuItems', exception);

// Logger une erreur d'authentification
errorHandler.logAuthError('signIn', exception);

// Logger une erreur de base de données
errorHandler.logDatabaseError('getMenuItems', exception);

// Logger une erreur de paiement
errorHandler.logPaymentError('processPayment', exception);
```

### 5. Affichage des Erreurs

```dart
final errorHandler = ErrorHandlerService();

// Afficher un SnackBar d'erreur
errorHandler.showErrorSnackBar(
  context,
  'Une erreur est survenue',
  duration: Duration(seconds: 5),
);

// Afficher une boîte de dialogue d'erreur
errorHandler.showErrorDialog(
  context,
  'Erreur',
  'Une erreur est survenue lors du chargement.',
);
```

## Exemples Complets

### Exemple 1 : Chargement de données avec retry
```dart
class MenuScreen extends StatefulWidget {
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<MenuItem> _items = [];
  bool _isLoading = false;

  Future<void> _loadMenuItems() async {
    setState(() => _isLoading = true);

    try {
      final items = await ErrorHandlerService.handleWithRetry(
        operation: () => databaseService.getMenuItems(),
        maxRetries: 3,
        delay: Duration(seconds: 1),
      );

      setState(() {
        _items = items.map((d) => MenuItem.fromMap(d)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      
      final errorHandler = ErrorHandlerService();
      final userMessage = ErrorHandlerService.translateError(e);
      errorHandler.showErrorSnackBar(context, userMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

### Exemple 2 : Création de commande avec gestion d'erreurs
```dart
Future<void> _placeOrder() async {
  final result = await ErrorHandlerService.handleOperation(
    context: context,
    operation: () async {
      return await databaseService.createOrder(orderData);
    },
    successMessage: 'Commande passée avec succès !',
    showErrorSnackBar: true,
    maxRetries: 2,
  );

  if (result != null) {
    // Naviguer vers l'écran de confirmation
    Navigator.pushNamed(context, '/order-confirmation', arguments: result);
  }
}
```

### Exemple 3 : Upload d'image avec retry
```dart
Future<String?> _uploadImage(File imageFile) async {
  final result = await ErrorHandlerService.executeWithResult<String>(
    operation: () async {
      return await storageService.uploadImage(imageFile);
    },
    maxRetries: 3,
    delay: Duration(seconds: 2),
  );

  if (result.isSuccess) {
    return result.data;
  } else {
    // Afficher l'erreur
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.errorMessage!)),
    );
    return null;
  }
}
```

## Backoff Exponentiel

Le backoff exponentiel augmente progressivement le délai entre les tentatives :

- **Tentative 1** : Délai = `delay * 1` (1 seconde)
- **Tentative 2** : Délai = `delay * 2` (2 secondes)
- **Tentative 3** : Délai = `delay * 4` (4 secondes)
- **Tentative 4** : Délai = `delay * 8` (8 secondes)

Cela évite de surcharger le serveur avec des requêtes trop rapides.

## Types d'Erreurs Retryables

Par défaut, les erreurs suivantes sont considérées comme retryables :
- `SocketException` (pas de connexion réseau)
- `TimeoutException` (timeout)
- `HttpException` (erreurs HTTP)
- `PostgrestException` avec code 5xx (erreurs serveur)

Les erreurs d'authentification (`AuthException`) ne sont **pas** retryables par défaut.

## Bonnes Pratiques

### 1. Utiliser le retry pour les opérations réseau
```dart
// ✅ Bon
final data = await ErrorHandlerService.handleWithRetry(
  operation: () => fetchDataFromServer(),
  maxRetries: 3,
);

// ❌ Éviter (pas de retry)
final data = await fetchDataFromServer();
```

### 2. Toujours traduire les erreurs pour l'utilisateur
```dart
// ✅ Bon
try {
  await operation();
} catch (e) {
  final message = ErrorHandlerService.translateError(e);
  showError(message);
}

// ❌ Éviter
try {
  await operation();
} catch (e) {
  showError(e.toString()); // Message technique
}
```

### 3. Logger les erreurs pour le debugging
```dart
// ✅ Bon
try {
  await operation();
} catch (e) {
  ErrorHandlerService().logError(
    'Erreur lors de l\'opération',
    code: 'OPERATION_ERROR',
    details: e,
  );
  final message = ErrorHandlerService.translateError(e);
  showError(message);
}
```

### 4. Utiliser handleOperation pour les opérations simples
```dart
// ✅ Bon - Simple et efficace
await ErrorHandlerService.handleOperation(
  context: context,
  operation: () => createOrder(),
  successMessage: 'Commande créée !',
);

// ❌ Plus verbeux
try {
  await createOrder();
  showSuccess('Commande créée !');
} catch (e) {
  final message = ErrorHandlerService.translateError(e);
  showError(message);
}
```

## Migration depuis l'Ancien Code

### Avant
```dart
try {
  final items = await databaseService.getMenuItems();
  setState(() => _items = items);
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Erreur: ${e.toString()}')),
  );
}
```

### Après
```dart
final result = await ErrorHandlerService.handleOperation(
  context: context,
  operation: () => databaseService.getMenuItems(),
  maxRetries: 3,
);

if (result != null) {
  setState(() => _items = result);
}
```

## Bénéfices

- ✅ **Expérience utilisateur améliorée** : Messages d'erreur compréhensibles
- ✅ **Résilience** : Retry automatique sur les erreurs temporaires
- ✅ **Cohérence** : Gestion d'erreurs uniforme dans toute l'application
- ✅ **Maintenabilité** : Code centralisé et réutilisable
- ✅ **Debugging** : Logging structuré de toutes les erreurs

