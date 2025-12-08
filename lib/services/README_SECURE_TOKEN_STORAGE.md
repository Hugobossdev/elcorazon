# 🔐 Guide de Gestion Sécurisée des Tokens

## Vue d'ensemble

L'amélioration #14 implémente un service de gestion sécurisée des tokens d'authentification avec :
- Stockage sécurisé avec FlutterSecureStorage (chiffré au niveau système)
- Vérification automatique de l'expiration
- Rotation des tokens
- Migration depuis SharedPreferences
- Décodage et extraction des informations du token

## Installation

Les dépendances ont déjà été ajoutées à `pubspec.yaml` :

```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
  jwt_decoder: ^2.0.1
```

## Avantages vs SharedPreferences

| Aspect | SharedPreferences | FlutterSecureStorage |
|--------|-------------------|----------------------|
| Sécurité | Stockage en clair | Chiffré au niveau système |
| Protection | Accès direct au fichier | Sécurisé par le système |
| Conformité | Risque de sécurité | Meilleures pratiques |

## Utilisation

### 1. Sauvegarder un Token

```dart
import 'lib/services/secure_token_storage_service.dart';

// Après authentification
final authResponse = await supabase.auth.signInWithPassword(
  email: email,
  password: password,
);

if (authResponse.session != null) {
  final tokenStorage = SecureTokenStorageService();
  
  // Sauvegarder le token d'accès
  await tokenStorage.saveAccessToken(authResponse.session!.accessToken);
  
  // Sauvegarder le refresh token si disponible
  if (authResponse.session!.refreshToken != null) {
    await tokenStorage.saveRefreshToken(authResponse.session!.refreshToken!);
  }
  
  // Ou sauvegarder les deux en une fois
  await tokenStorage.saveTokens(
    accessToken: authResponse.session!.accessToken,
    refreshToken: authResponse.session!.refreshToken,
  );
}
```

### 2. Récupérer un Token

```dart
final tokenStorage = SecureTokenStorageService();

// Récupérer le token d'accès
final accessToken = await tokenStorage.getAccessToken();

if (accessToken != null) {
  // Utiliser le token pour les requêtes authentifiées
  // Supabase gère automatiquement les tokens, mais vous pouvez les utiliser manuellement
}
```

### 3. Vérifier si un Token est Valide

```dart
final tokenStorage = SecureTokenStorageService();

// Vérifier si le token d'accès est valide
final isValid = await tokenStorage.isAccessTokenValid();

if (!isValid) {
  // Token invalide ou expiré, demander une nouvelle authentification
  // Ou utiliser le refresh token pour obtenir un nouveau token
}
```

### 4. Vérifier l'Expiration

```dart
final tokenStorage = SecureTokenStorageService();
final token = await tokenStorage.getAccessToken();

if (token != null) {
  // Vérifier si le token est valide (non expiré)
  final isValid = SecureTokenStorageService.isTokenValid(token);
  
  // Obtenir la date d'expiration
  final expiryDate = SecureTokenStorageService.getTokenExpiry(token);
  
  // Obtenir le temps restant
  final timeUntilExpiry = SecureTokenStorageService.getTimeUntilExpiry(token);
  
  if (timeUntilExpiry != null) {
    print('Token expire dans: ${timeUntilExpiry.inMinutes} minutes');
  }
}
```

### 5. Rotation des Tokens

```dart
final tokenStorage = SecureTokenStorageService();

// Vérifier si le token doit être renouvelé
final shouldRotate = await tokenStorage.shouldRotateToken();

if (shouldRotate) {
  // Obtenir un nouveau token avec le refresh token
  final refreshToken = await tokenStorage.getRefreshToken();
  if (refreshToken != null) {
    // Appeler l'API pour obtenir un nouveau token
    // ...
  }
}
```

### 6. Supprimer les Tokens

```dart
final tokenStorage = SecureTokenStorageService();

// Supprimer tous les tokens (lors de la déconnexion)
await tokenStorage.clearTokens();

// Ou supprimer uniquement le token d'accès
await tokenStorage.clearAccessToken();

// Ou supprimer uniquement le refresh token
await tokenStorage.clearRefreshToken();
```

### 7. Décoder un Token

```dart
final tokenStorage = SecureTokenStorageService();
final token = await tokenStorage.getAccessToken();

if (token != null) {
  // Décoder le payload du token
  final payload = SecureTokenStorageService.decodeToken(token);
  
  // Obtenir l'ID utilisateur
  final userId = SecureTokenStorageService.getUserIdFromToken(token);
  
  // Obtenir l'email
  final email = SecureTokenStorageService.getEmailFromToken(token);
  
  // Obtenir les permissions
  final permissions = SecureTokenStorageService.getPermissionsFromToken(token);
}
```

### 8. Migration depuis SharedPreferences

```dart
final tokenStorage = SecureTokenStorageService();

// Migrer les tokens existants vers le stockage sécurisé
await tokenStorage.migrateFromSharedPreferences();
```

## Exemples Complets

### Exemple 1 : Authentification avec Stockage Sécurisé

```dart
class AuthService {
  final SecureTokenStorageService _tokenStorage = SecureTokenStorageService();
  
  Future<bool> signIn(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.session != null) {
        // Sauvegarder les tokens de manière sécurisée
        await _tokenStorage.saveTokens(
          accessToken: response.session!.accessToken,
          refreshToken: response.session!.refreshToken,
        );
        
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Erreur de connexion: $e');
      return false;
    }
  }
  
  Future<bool> isAuthenticated() async {
    return await _tokenStorage.isAccessTokenValid();
  }
  
  Future<void> signOut() async {
    // Supprimer les tokens
    await _tokenStorage.clearTokens();
    
    // Déconnexion Supabase
    await supabase.auth.signOut();
  }
}
```

### Exemple 2 : Vérification Automatique de l'Expiration

```dart
class TokenRefreshService {
  final SecureTokenStorageService _tokenStorage = SecureTokenStorageService();
  Timer? _refreshTimer;
  
  void startTokenRefreshMonitoring() {
    // Vérifier toutes les minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final shouldRotate = await _tokenStorage.shouldRotateToken();
      
      if (shouldRotate) {
        await _refreshToken();
      }
    });
  }
  
  Future<void> _refreshToken() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) return;
      
      // Appeler l'API pour obtenir un nouveau token
      final response = await supabase.auth.refreshSession();
      
      if (response.session != null) {
        await _tokenStorage.saveTokens(
          accessToken: response.session!.accessToken,
          refreshToken: response.session!.refreshToken,
        );
      }
    } catch (e) {
      debugPrint('Erreur lors du rafraîchissement du token: $e');
    }
  }
  
  void stopTokenRefreshMonitoring() {
    _refreshTimer?.cancel();
  }
}
```

### Exemple 3 : Intercepteur pour Vérifier les Tokens

```dart
class SecureHttpInterceptor {
  final SecureTokenStorageService _tokenStorage = SecureTokenStorageService();
  
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await _tokenStorage.getAccessToken();
    
    if (token == null) {
      return {};
    }
    
    // Vérifier si le token est valide
    if (!SecureTokenStorageService.isTokenValid(token)) {
      // Essayer de rafraîchir le token
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken != null) {
        // Rafraîchir le token
        // ...
      } else {
        // Rediriger vers la connexion
        return {};
      }
    }
    
    return {
      'Authorization': 'Bearer $token',
    };
  }
}
```

## Intégration avec Supabase

Supabase gère automatiquement les tokens, mais vous pouvez les intégrer :

```dart
class SupabaseAuthService {
  final SecureTokenStorageService _tokenStorage = SecureTokenStorageService();
  
  Future<void> initialize() async {
    // Écouter les changements de session
    supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      
      if (session != null) {
        // Sauvegarder les nouveaux tokens
        _tokenStorage.saveTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        );
      } else {
        // Supprimer les tokens lors de la déconnexion
        _tokenStorage.clearTokens();
      }
    });
  }
}
```

## Bonnes Pratiques

### 1. Toujours Vérifier la Validité avant Utilisation

```dart
// ✅ Bon
final token = await tokenStorage.getAccessToken();
if (token != null && SecureTokenStorageService.isTokenValid(token)) {
  // Utiliser le token
}

// ❌ Éviter - Ne pas vérifier la validité
final token = await tokenStorage.getAccessToken();
// Utiliser directement sans vérification
```

### 2. Gérer la Rotation des Tokens

```dart
// ✅ Bon - Vérifier et rafraîchir automatiquement
if (await tokenStorage.shouldRotateToken()) {
  await refreshToken();
}

// ❌ Éviter - Ne pas gérer la rotation
// Le token peut expirer sans prévention
```

### 3. Supprimer les Tokens lors de la Déconnexion

```dart
// ✅ Bon - Supprimer tous les tokens
Future<void> signOut() async {
  await tokenStorage.clearTokens();
  await supabase.auth.signOut();
}

// ❌ Éviter - Ne pas supprimer les tokens
await supabase.auth.signOut();
// Les tokens restent dans le stockage sécurisé
```

### 4. Migrer les Anciens Tokens

```dart
// ✅ Bon - Migrer lors de l'initialisation
Future<void> initialize() async {
  await tokenStorage.migrateFromSharedPreferences();
}

// ❌ Éviter - Garder les anciens tokens dans SharedPreferences
// Risque de sécurité
```

## Sécurité

### Protection Fournie

- ✅ **Stockage chiffré** : Tokens stockés de manière sécurisée par le système
- ✅ **Vérification d'expiration** : Vérification automatique de l'expiration
- ✅ **Rotation** : Support pour la rotation des tokens
- ✅ **Décodage sécurisé** : Extraction sécurisée des informations du token

### Bonnes Pratiques de Sécurité

1. **Ne jamais stocker les tokens en clair** : Utiliser FlutterSecureStorage
2. **Vérifier l'expiration** : Toujours vérifier avant utilisation
3. **Gérer la rotation** : Renouveler les tokens avant expiration
4. **Supprimer lors de la déconnexion** : Nettoyer tous les tokens

## Migration depuis SharedPreferences

Si vous utilisez actuellement SharedPreferences pour les tokens :

```dart
// Avant (Non sécurisé)
final prefs = await SharedPreferences.getInstance();
await prefs.setString('auth_token', token);

// Après (Sécurisé)
final tokenStorage = SecureTokenStorageService();
await tokenStorage.saveAccessToken(token);

// Migration automatique
await tokenStorage.migrateFromSharedPreferences();
```

## Bénéfices

- ✅ **Sécurité renforcée** : Stockage chiffré au niveau système
- ✅ **Protection contre les attaques** : Tokens non accessibles en clair
- ✅ **Conformité** : Meilleures pratiques de sécurité
- ✅ **Gestion automatique** : Vérification et rotation automatiques
- ✅ **Migration facile** : Migration depuis SharedPreferences

