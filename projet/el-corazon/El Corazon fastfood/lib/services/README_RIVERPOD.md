# 🚀 Guide de Riverpod pour la Gestion d'État

> ⚠️ **Document antérieur à la migration Django (1er août 2026).**
> Les exemples ci-dessous montrent des dépôts Supabase qui n'existent plus.
> L'accès aux données passe désormais par `packages/elcorazon_core`, dont les
> dépôts parlent à l'API Django `/api/v1/*`. Le **patron** décrit ici reste
> valable — c'est son implémentation qui a changé.
>
> Référence : [`docs/architecture/04-migration-flutter.md`](../../../docs/architecture/04-migration-flutter.md).

## Vue d'ensemble

L'amélioration #12 implémente Riverpod comme alternative (optionnelle) à Provider pour la gestion d'état. Riverpod offre :
- Code plus déclaratif
- Meilleure gestion des dépendances
- Plus facile à tester
- Type-safe à la compilation
- Gestion automatique des dépendances

## Installation

La dépendance a déjà été ajoutée à `pubspec.yaml` :

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
```

## Avantages de Riverpod vs Provider

| Aspect | Provider | Riverpod |
|--------|----------|----------|
| Type safety | Runtime | Compile-time |
| Dépendances | Manuelles | Automatiques |
| Testabilité | Moyenne | Excellente |
| Code | Verbeux | Déclaratif |
| Hot reload | Parfois problématique | Optimisé |

## Utilisation

### 1. Configuration de l'App

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    // Envelopper l'app avec ProviderScope
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### 2. Créer un Provider Simple

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider simple (équivalent à un ChangeNotifier)
final counterProvider = StateProvider<int>((ref) => 0);

// Utilisation
final counter = ref.watch(counterProvider); // Lire la valeur
ref.read(counterProvider.notifier).state++; // Modifier
```

### 3. Provider Asynchrone (Future)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/menu_repository.dart';

// Provider asynchrone
final menuItemsProvider = FutureProvider<List<MenuItem>>((ref) async {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.getMenuItems();
});

// Utilisation dans un widget
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuItemsAsync = ref.watch(menuItemsProvider);

    return menuItemsAsync.when(
      data: (items) => ListView.builder(...),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error),
    );
  }
}
```

### 4. Provider avec Paramètres (Family)

```dart
// Provider avec paramètres
final menuItemProvider = FutureProvider.family<MenuItem?, String>(
  (ref, itemId) async {
    final repository = ref.watch(menuRepositoryProvider);
    return repository.getMenuItemById(itemId);
  },
);

// Utilisation
final item = ref.watch(menuItemProvider('item-id-123'));
```

### 5. StateNotifier pour État Complexe

```dart
// Définir l'état
class CartState {
  final List<CartItem> items;
  final double total;

  CartState({required this.items, required this.total});
}

// Créer le notifier
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState(items: [], total: 0.0));

  void addItem(CartItem item) {
    state = CartState(
      items: [...state.items, item],
      total: state.total + item.price,
    );
  }
}

// Créer le provider
final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);

// Utilisation
final cartState = ref.watch(cartProvider);
ref.read(cartProvider.notifier).addItem(item);
```

## Exemples Complets

### Exemple 1 : Menu Items avec Riverpod

```dart
// lib/providers/menu_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item.dart';
import '../repositories/menu_repository.dart';

// Provider du repository
final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return CatalogRepository(apiClient: ref.watch(apiClientProvider));
});

// Provider pour charger les menu items
final menuItemsProvider = FutureProvider<List<MenuItem>>((ref) async {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.getMenuItems();
});

// Provider pour rechercher
final searchMenuItemsProvider = FutureProvider.family<List<MenuItem>, String>(
  (ref, query) async {
    final repository = ref.watch(menuRepositoryProvider);
    return repository.searchMenuItems(query);
  },
);
```

### Exemple 2 : Utilisation dans un Widget

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/menu_providers.dart';

class MenuScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuItemsAsync = ref.watch(menuItemsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Menu')),
      body: menuItemsAsync.when(
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            return MenuItemCard(item: items[index]);
          },
        ),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Erreur: $error'),
        ),
      ),
    );
  }
}
```

### Exemple 3 : Panier avec StateNotifier

```dart
// lib/providers/cart_providers.dart
class CartState {
  final List<CartItem> items;
  final double total;

  CartState({required this.items, required this.total});
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState(items: [], total: 0.0));

  void addItem(CartItem item) {
    final newItems = [...state.items, item];
    state = CartState(
      items: newItems,
      total: newItems.fold(0.0, (sum, item) => sum + item.price),
    );
  }

  void removeItem(String itemId) {
    final newItems = state.items.where((item) => item.id != itemId).toList();
    state = CartState(
      items: newItems,
      total: newItems.fold(0.0, (sum, item) => sum + item.price),
    );
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);
```

### Exemple 4 : Utilisation du Panier

```dart
class CartScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text('Panier')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: cartState.items.length,
              itemBuilder: (context, index) {
                final item = cartState.items[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text('${item.price} FCFA'),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () => cartNotifier.removeItem(item.id),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${cartState.total.toStringAsFixed(0)} FCFA',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: cartState.items.isEmpty ? null : () {
                    // Passer commande
                  },
                  child: Text('Commander'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## Migration depuis Provider

### Avant (Provider)

```dart
// Service
class MenuService extends ChangeNotifier {
  List<MenuItem> _items = [];
  List<MenuItem> get items => _items;

  Future<void> loadItems() async {
    _items = await repository.getMenuItems();
    notifyListeners();
  }
}

// main.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => MenuService()),
  ],
  child: MyApp(),
)

// Widget
Consumer<MenuService>(
  builder: (context, service, child) {
    return ListView.builder(...);
  },
)
```

### Après (Riverpod)

```dart
// Provider
final menuItemsProvider = FutureProvider<List<MenuItem>>((ref) async {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.getMenuItems();
});

// main.dart
ProviderScope(
  child: MyApp(),
)

// Widget
Consumer(
  builder: (context, ref, child) {
    final items = ref.watch(menuItemsProvider);
    return items.when(...);
  },
)
```

## Coexistence avec Provider

Riverpod peut coexister avec Provider :

```dart
// main.dart
MultiProvider(
  providers: [
    // Providers existants (Provider)
    ChangeNotifierProvider(create: (_) => AppService()),
    ChangeNotifierProvider(create: (_) => CartService()),
  ],
  child: ProviderScope( // Envelopper avec ProviderScope
    child: MyApp(),
  ),
)
```

## Bonnes Pratiques

### 1. Utiliser `ref.watch()` pour l'UI

```dart
// ✅ Bon - L'UI se met à jour automatiquement
final items = ref.watch(menuItemsProvider);

// ❌ Éviter - Ne se met pas à jour automatiquement
final items = ref.read(menuItemsProvider);
```

### 2. Utiliser `ref.read()` pour les actions

```dart
// ✅ Bon - Pour les actions (boutons, callbacks)
ref.read(cartProvider.notifier).addItem(item);

// ❌ Éviter - Dans le build pour lire une valeur
final cart = ref.read(cartProvider);
```

### 3. Invalider pour recharger

```dart
// Recharger les données
ref.invalidate(menuItemsProvider);

// Ou utiliser refresh
ref.refresh(menuItemsProvider);
```

### 4. Gérer les erreurs

```dart
final itemsAsync = ref.watch(menuItemsProvider);

itemsAsync.when(
  data: (items) => ListView(...),
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => ErrorWidget(error),
);
```

## Bénéfices

- ✅ **Code plus déclaratif** : Moins de boilerplate
- ✅ **Meilleure gestion des dépendances** : Automatique avec `ref.watch()`
- ✅ **Plus facile à tester** : Providers testables indépendamment
- ✅ **Type-safe** : Erreurs détectées à la compilation
- ✅ **Performance** : Optimisations automatiques
- ✅ **Hot reload** : Meilleur support du hot reload

## Migration Progressive

Vous pouvez migrer progressivement :

1. **Phase 1** : Utiliser Riverpod pour les nouvelles fonctionnalités
2. **Phase 2** : Migrer les fonctionnalités existantes une par une
3. **Phase 3** : Garder Provider pour la compatibilité si nécessaire

## Notes Importantes

1. **ProviderScope** : Nécessaire à la racine de l'app
2. **ConsumerWidget** : Utiliser `ConsumerWidget` au lieu de `StatelessWidget` pour accéder à `ref`
3. **ConsumerStatefulWidget** : Utiliser `ConsumerStatefulWidget` pour les widgets avec état
4. **Coexistence** : Riverpod peut coexister avec Provider sans problème

## Commandes Utiles

```bash
# Installer les dépendances
flutter pub get

# Lancer l'app avec Riverpod
flutter run
```

L'amélioration #12 est terminée. Riverpod offre une alternative moderne et puissante à Provider pour la gestion d'état, avec une meilleure gestion des dépendances et une meilleure testabilité.

