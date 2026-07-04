# 👨‍💻 Guide Développeur - El Corazon Fastfood

Guide pour les développeurs travaillant sur le projet.

## 🎯 Standards de code

### Conventions de nommage

```dart
// Classes et types: PascalCase
class UserProfile { }
enum OrderStatus { }

// Variables et fonctions: camelCase
String userName = '';
void fetchUserData() { }

// Constantes: SCREAMING_SNAKE_CASE ou camelCase pour classes
const int MAX_RETRIES = 3;
static const primaryColor = Color(0xFFE53935);

// Fichiers: snake_case
user_profile_screen.dart
database_service.dart
```

### Organisation des imports

```dart
// 1. Dart SDK
import 'dart:async';
import 'dart:convert';

// 2. Flutter SDK
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. Packages externes
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// 4. Imports locaux (package relatif)
import 'package:elcora_fast/models/user.dart';
import 'package:elcora_fast/services/app_service.dart';
```

### Structure d'un Widget

```dart
class MyWidget extends StatefulWidget {
  // 1. Paramètres du constructeur
  final String title;
  final VoidCallback? onTap;
  
  const MyWidget({
    super.key,
    required this.title,
    this.onTap,
  });

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  // 2. Variables d'état
  bool _isLoading = false;
  String? _errorMessage;
  
  // 3. Lifecycle methods
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    // Nettoyer les ressources
    super.dispose();
  }
  
  // 4. Méthodes privées
  Future<void> _loadData() async {
    // ...
  }
  
  // 5. Build methods
  @override
  Widget build(BuildContext context) {
    return Container();
  }
  
  // 6. Widget builders (privés)
  Widget _buildHeader() {
    return Text(widget.title);
  }
}
```

## 🔧 Commandes utiles

### Développement

```bash
# Lancer en mode debug
flutter run

# Lancer sur un device spécifique
flutter run -d <device-id>

# Hot reload (pendant que l'app tourne)
# Appuyer sur 'r' dans le terminal

# Hot restart
# Appuyer sur 'R' dans le terminal

# Voir les logs
flutter logs

# Formatter le code
dart format lib

# Analyser le code
flutter analyze

# Fix automatique des problèmes
dart fix --apply
```

### Build et Release

```bash
# Nettoyer le projet
flutter clean

# Récupérer les dépendances
flutter pub get

# Build APK de debug
flutter build apk --debug

# Build APK de release
flutter build apk --release

# Build App Bundle (Play Store)
flutter build appbundle --release

# Build iOS
flutter build ios --release
```

### Tests

```bash
# Lancer tous les tests
flutter test

# Lancer des tests spécifiques
flutter test test/services/cart_service_test.dart

# Tests avec couverture
flutter test --coverage

# Voir la couverture
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 🐛 Debugging

### Logs structurés

Utiliser des emojis pour identifier rapidement les logs :

```dart
debugPrint('✅ Success: Data loaded');
debugPrint('⚠️ Warning: Slow connection detected');
debugPrint('❌ Error: $error');
debugPrint('🔄 Loading: Fetching user data...');
debugPrint('📍 Location: ${location.latitude}, ${location.longitude}');
debugPrint('💰 Payment: Transaction completed');
```

### DevTools

```bash
# Lancer DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Performance profiling
# Dans DevTools → Performance tab
# Enregistrer et analyser les frames
```

### Breakpoints et inspection

```dart
// Breakpoint conditionnel
debugger(when: userId == 'specific-id');

// Inspection de variables
print('Current state: ${json.encode(state.toJson())}');

// Assert en mode debug
assert(user != null, 'User should not be null here');
```

## 📦 Gestion des dépendances

### Ajouter une dépendance

```bash
# Package pub.dev
flutter pub add package_name

# Version spécifique
flutter pub add package_name:^1.2.3

# Dev dependency
flutter pub add --dev package_name
```

### Mettre à jour les dépendances

```bash
# Voir les packages obsolètes
flutter pub outdated

# Mettre à jour tous les packages
flutter pub upgrade

# Mettre à jour un packa ge spécifique
flutter pub upgrade package_name
```

## 🎨 Theming et Styles

### Utiliser le thème

```dart
// Accéder au thème
final theme = Theme.of(context);

// Couleurs du thème
theme.colorScheme.primary
theme.colorScheme.secondary
theme.colorScheme.error

// Textes du thème
theme.textTheme.headlineLarge
theme.textTheme.bodyMedium

// Couleurs personnalisées
AppColors.primary
AppColors.secondary
```

### Responsive Design

```dart
// Obtenir la taille de l'écran
final size = MediaQuery.of(context).size;
final width = size.width;
final height = size.height;

// Breakpoints
if (width > 600) {
  // Tablet ou desktop
} else {
  // Mobile
}

// LayoutBuilder pour adaptive UI
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 600) {
      return TabletLayout();
    }
    return MobileLayout();
  },
)
```

## 🔐 Bonnes pratiques de sécurité

### Ne jamais

```dart
❌ const apiKey = 'hardcoded-api-key';
❌ print('Password: $password');
❌ await http.get('http://unsafe-url'); // Toujours HTTPS
```

### Toujours

```dart
✅ final apiKey = dotenv.env['API_KEY'];
✅ debugPrint('User authenticated: ${user.id}'); // Pas de données sensibles
✅ await http.get('https://secure-api.com');
```

### Validation des entrées

```dart
// Toujours valider les entrées utilisateur
if (email.isEmpty || !email.contains('@')) {
  return 'Email invalide';
}

// Sanitiser les données
final cleanName = name.trim();
```

## 🔄 State Management avec Provider

### Créer un service

```dart
class MyService extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  Future<void> doSomething() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Logic here
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

### Utiliser un service

```dart
// Dans build()
final myService = Provider.of<MyService>(context);

// Ou avec Consumer
Consumer<MyService>(
  builder: (context, service, child) {
    return Text(service.someValue);
  },
)

// Sans rebuild (listen: false)
final service = Provider.of<MyService>(context, listen: false);
service.doSomething();
```

## 📝 Documentation du code

```dart
/// Récupère les données utilisateur depuis Supabase.
///
/// Retourne un [User] si trouvé, sinon `null`.
/// Lance une [DatabaseException] en cas d'erreur réseau.
///
/// Exemple:
/// ```dart
/// final user = await getUserById('user-123');
/// ```
Future<User?> getUserById(String userId) async {
  // Implementation
}
```

## 🚨 Gestion des erreurs

```dart
try {
  final result = await riskyOperation();
} on NetworkException catch (e) {
  // Erreur réseau spécifique
  debugPrint('❌ Network error: $e');
  showErrorSnackBar(context, 'Problème de connexion');
} catch (e, stackTrace) {
  // Erreur générique
  debugPrint('❌ Error: $e\n$stackTrace');
  showErrorSnackBar(context, 'Une erreur est survenue');
}
```

## 📞 Support

- **Questions techniques**: Ouvrir une issue GitHub
- **Discussions**: Slack / Discord du projet
- **Documentation**: Relireces fichiers dans `/docs`

---

**Bon développement! 🚀**
