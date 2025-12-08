# 🏗️ Guide du Pattern Repository

## Vue d'ensemble

L'amélioration #10 implémente le pattern Repository pour séparer la logique métier de l'accès aux données. Cela permet :
- Code plus testable
- Meilleure maintenabilité
- Facilite les changements de backend
- Séparation claire des responsabilités

## Architecture

### Structure

```
lib/
├── repositories/          # Couche d'accès aux données
│   ├── menu_repository.dart          # Interface abstraite
│   ├── supabase_menu_repository.dart # Implémentation Supabase
│   ├── order_repository.dart
│   └── supabase_order_repository.dart
└── services/             # Couche de logique métier
    ├── menu_service.dart # Utilise MenuRepository
    └── ...
```

### Séparation des Responsabilités

1. **Repository** : Accès aux données uniquement
   - Pas de logique métier
   - Peut être remplacé facilement (Supabase, Firestore, REST API, etc.)
   - Facile à tester avec des mocks

2. **Service** : Logique métier
   - Utilise le repository pour accéder aux données
   - Gère l'état (ChangeNotifier)
   - Logique de validation, transformation, etc.

3. **UI** : Présentation
   - Utilise les services
   - Pas de logique métier ou d'accès direct aux données

## Utilisation

### 1. Créer un Repository

#### Interface abstraite

```dart
// lib/repositories/menu_repository.dart
abstract class MenuRepository {
  Future<List<MenuItem>> getMenuItems({String? categoryId});
  Future<MenuItem?> getMenuItemById(String id);
  Stream<List<MenuItem>> watchMenuItems({String? categoryId});
}
```

#### Implémentation

```dart
// lib/repositories/supabase_menu_repository.dart
class SupabaseMenuRepository implements MenuRepository {
  final SupabaseClient _supabase;

  SupabaseMenuRepository(this._supabase);

  @override
  Future<List<MenuItem>> getMenuItems({String? categoryId}) async {
    // Implémentation spécifique à Supabase
    final response = await _supabase
        .from('menu_items')
        .select('*')
        .eq('is_available', true);
    
    return response.map((data) => MenuItem.fromMap(data)).toList();
  }
}
```

### 2. Créer un Service

```dart
// lib/services/menu_service.dart
class MenuService extends ChangeNotifier {
  final MenuRepository _repository;

  List<MenuItem> _menuItems = [];
  bool _isLoading = false;

  MenuService(this._repository);

  Future<void> loadMenuItems({String? categoryId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _menuItems = await _repository.getMenuItems(categoryId: categoryId);
    } catch (e) {
      // Gérer l'erreur
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<MenuItem> get menuItems => List.unmodifiable(_menuItems);
  bool get isLoading => _isLoading;
}
```

### 3. Utiliser dans l'UI

```dart
// Dans main.dart
final menuRepository = SupabaseMenuRepository(SupabaseConfig.client);
final menuService = MenuService(menuRepository);

ChangeNotifierProvider(create: (_) => menuService),

// Dans un widget
Consumer<MenuService>(
  builder: (context, menuService, child) {
    if (menuService.isLoading) {
      return CircularProgressIndicator();
    }

    return ListView.builder(
      itemCount: menuService.menuItems.length,
      itemBuilder: (context, index) {
        final item = menuService.menuItems[index];
        return MenuItemCard(item: item);
      },
    );
  },
)
```

## Avantages

### 1. Testabilité

```dart
// Test avec un mock repository
class MockMenuRepository implements MenuRepository {
  @override
  Future<List<MenuItem>> getMenuItems({String? categoryId}) async {
    return [
      MenuItem(id: '1', name: 'Test Item', price: 10.0),
    ];
  }
}

void main() {
  test('MenuService loads menu items', () async {
    final mockRepo = MockMenuRepository();
    final service = MenuService(mockRepo);
    
    await service.loadMenuItems();
    
    expect(service.menuItems.length, 1);
    expect(service.menuItems.first.name, 'Test Item');
  });
}
```

### 2. Flexibilité

```dart
// Facile de changer de backend
final menuRepository = 
  // SupabaseMenuRepository(SupabaseConfig.client);
  // FirestoreMenuRepository(FirebaseFirestore.instance);
  // RestMenuRepository(apiClient);
  MockMenuRepository(); // Pour les tests

final menuService = MenuService(menuRepository);
```

### 3. Maintenabilité

- **Repository** : Change uniquement si le backend change
- **Service** : Change uniquement si la logique métier change
- **UI** : Change uniquement si l'interface change

## Exemples Complets

### Exemple 1 : MenuService avec Repository

```dart
// lib/services/menu_service.dart
import 'package:flutter/foundation.dart';
import '../models/menu_item.dart';
import '../repositories/menu_repository.dart';

class MenuService extends ChangeNotifier {
  final MenuRepository _repository;

  List<MenuItem> _menuItems = [];
  List<MenuCategory> _categories = [];
  bool _isLoading = false;

  MenuService(this._repository);

  List<MenuItem> get menuItems => List.unmodifiable(_menuItems);
  List<MenuCategory> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;

  Future<void> loadMenuItems({String? categoryId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _menuItems = await _repository.getMenuItems(categoryId: categoryId);
    } catch (e) {
      debugPrint('Error loading menu items: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    _categories = await _repository.getMenuCategories();
    notifyListeners();
  }
}
```

### Exemple 2 : Intégration dans main.dart

```dart
import 'package:provider/provider.dart';
import 'repositories/menu_repository.dart';
import 'repositories/supabase_menu_repository.dart';
import 'services/menu_service.dart';
import 'supabase/supabase_config.dart';

void main() {
  // Créer le repository
  final menuRepository = SupabaseMenuRepository(SupabaseConfig.client);
  
  // Créer le service avec le repository
  final menuService = MenuService(menuRepository);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => menuService),
        // Autres providers...
      ],
      child: MyApp(),
    ),
  );
}
```

### Exemple 3 : Utilisation dans un Widget

```dart
class MenuScreen extends StatefulWidget {
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  void initState() {
    super.initState();
    // Charger les données au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MenuService>(context, listen: false).loadMenuItems();
      Provider.of<MenuService>(context, listen: false).loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Menu')),
      body: Consumer<MenuService>(
        builder: (context, menuService, child) {
          if (menuService.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (menuService.menuItems.isEmpty) {
            return Center(child: Text('Aucun item disponible'));
          }

          return ListView.builder(
            itemCount: menuService.menuItems.length,
            itemBuilder: (context, index) {
              final item = menuService.menuItems[index];
              return MenuItemCard(item: item);
            },
          );
        },
      ),
    );
  }
}
```

## Bonnes Pratiques

### 1. Repository : Accès aux données uniquement

```dart
// ✅ Bon - Repository fait uniquement l'accès aux données
class SupabaseMenuRepository implements MenuRepository {
  @override
  Future<List<MenuItem>> getMenuItems({String? categoryId}) async {
    // Juste la récupération des données
    final response = await _supabase.from('menu_items').select('*');
    return response.map((data) => MenuItem.fromMap(data)).toList();
  }
}

// ❌ Éviter - Repository ne doit pas contenir de logique métier
class SupabaseMenuRepository implements MenuRepository {
  @override
  Future<List<MenuItem>> getMenuItems({String? categoryId}) async {
    // ❌ Logique métier dans le repository
    if (DateTime.now().hour < 12) {
      // Afficher seulement les items du petit déjeuner
    }
  }
}
```

### 2. Service : Logique métier uniquement

```dart
// ✅ Bon - Service gère la logique métier
class MenuService extends ChangeNotifier {
  Future<void> loadMenuItems({String? categoryId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Appel au repository
      _menuItems = await _repository.getMenuItems(categoryId: categoryId);
      
      // Logique métier
      _menuItems = _filterByTimeOfDay(_menuItems);
    } catch (e) {
      // Gestion d'erreur
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<MenuItem> _filterByTimeOfDay(List<MenuItem> items) {
    // Logique métier ici
    if (DateTime.now().hour < 12) {
      return items.where((item) => item.isBreakfast).toList();
    }
    return items;
  }
}
```

### 3. UI : Présentation uniquement

```dart
// ✅ Bon - UI utilise le service
Consumer<MenuService>(
  builder: (context, menuService, child) {
    return ListView.builder(
      itemCount: menuService.menuItems.length,
      itemBuilder: (context, index) {
        return MenuItemCard(item: menuService.menuItems[index]);
      },
    );
  },
)

// ❌ Éviter - UI ne doit pas accéder directement au repository
// ou à la base de données
FutureBuilder(
  future: _repository.getMenuItems(), // ❌ Accès direct au repository
  // ...
)
```

## Migration depuis l'Ancien Code

### Avant (Logique mélangée)

```dart
class AppService extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<MenuItem> _menuItems = [];

  Future<void> loadMenuItems() async {
    // Accès direct à la base de données dans le service
    final data = await _databaseService.getMenuItems();
    // Logique métier mélangée
    _menuItems = data.map((d) => MenuItem.fromMap(d)).toList();
    // Filtrage métier
    _menuItems = _menuItems.where((item) => item.isAvailable).toList();
    notifyListeners();
  }
}
```

### Après (Avec Repository)

```dart
// Repository : Accès aux données
class SupabaseMenuRepository implements MenuRepository {
  @override
  Future<List<MenuItem>> getMenuItems() async {
    final response = await _supabase.from('menu_items').select('*');
    return response.map((data) => MenuItem.fromMap(data)).toList();
  }
}

// Service : Logique métier
class MenuService extends ChangeNotifier {
  final MenuRepository _repository;
  List<MenuItem> _menuItems = [];

  MenuService(this._repository);

  Future<void> loadMenuItems() async {
    final items = await _repository.getMenuItems();
    // Logique métier dans le service
    _menuItems = items.where((item) => item.isAvailable).toList();
    notifyListeners();
  }
}
```

## Bénéfices

- ✅ **Code plus testable** : Facile de mocker les repositories
- ✅ **Meilleure maintenabilité** : Séparation claire des responsabilités
- ✅ **Flexibilité** : Facile de changer de backend
- ✅ **Réutilisabilité** : Services peuvent être réutilisés dans différents contextes
- ✅ **Évolutivité** : Facile d'ajouter de nouvelles fonctionnalités

