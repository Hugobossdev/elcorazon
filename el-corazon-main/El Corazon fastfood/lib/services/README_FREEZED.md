# 🧊 Guide de Freezed pour les Modèles

## Vue d'ensemble

L'amélioration #11 implémente Freezed pour réduire le code boilerplate dans les modèles. Freezed génère automatiquement :
- Classes immutables
- Méthodes `copyWith`
- Méthodes `toString`, `==` et `hashCode`
- Support JSON (avec json_serializable)
- Pattern matching

## Avantages

- ✅ **Code plus concis** : Moins de code boilerplate
- ✅ **Immutabilité garantie** : Les objets ne peuvent pas être modifiés après création
- ✅ **Meilleure performance** : Comparaisons et copies optimisées
- ✅ **Type safety** : Compile-time checks
- ✅ **Pattern matching** : Support pour when() et maybeWhen()

## Installation

Les dépendances ont déjà été ajoutées à `pubspec.yaml` :

```yaml
dependencies:
  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.4.11
  freezed: ^2.5.2
  json_serializable: ^6.8.0
```

## Utilisation

### 1. Générer le code

Avant d'utiliser les modèles Freezed, vous devez générer le code :

```bash
# Générer le code une fois
flutter pub run build_runner build

# Ou en mode watch (régénère automatiquement lors des changements)
flutter pub run build_runner watch

# Si vous avez des conflits, supprimez les fichiers générés
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Créer un modèle avec Freezed

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'my_model.freezed.dart';
part 'my_model.g.dart';

@freezed
class MyModel with _$MyModel {
  const factory MyModel({
    required String id,
    required String name,
    String? description,
    @Default(0) int count,
    @Default([]) List<String> tags,
  }) = _MyModel;

  factory MyModel.fromJson(Map<String, dynamic> json) =>
      _$MyModelFromJson(json);
}
```

### 3. Utilisation du modèle

```dart
// Création
final item = MyModel(
  id: '1',
  name: 'Test',
  description: 'Description',
  count: 5,
);

// Immutabilité garantie
// item.name = 'New Name'; // ❌ Erreur de compilation

// copyWith (généré automatiquement)
final updated = item.copyWith(
  name: 'New Name',
  count: item.count + 1,
);

// JSON
final json = item.toJson();
final fromJson = MyModel.fromJson(json);

// Comparaison (générée automatiquement)
final item2 = MyModel(id: '1', name: 'Test');
print(item == item2); // true si tous les champs sont égaux
```

## Exemples Complets

### Exemple 1 : MenuItem avec Freezed

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'menu_category.dart';

part 'freezed_menu_item.freezed.dart';
part 'freezed_menu_item.g.dart';

@freezed
class FreezedMenuItem with _$FreezedMenuItem {
  const factory FreezedMenuItem({
    required String id,
    required String name,
    required String description,
    required double price,
    required String categoryId,
    MenuCategory? category,
    String? imageUrl,
    @Default(false) bool isPopular,
    @Default(false) bool isVegetarian,
    @Default(false) bool isVegan,
    @Default(true) bool isAvailable,
    @Default(100) int availableQuantity,
    @Default([]) List<String> ingredients,
    @Default(0) int calories,
    @Default(15) int preparationTime,
    @Default(0.0) double rating,
    @Default(0) int reviewCount,
  }) = _FreezedMenuItem;

  factory FreezedMenuItem.fromJson(Map<String, dynamic> json) =>
      _$FreezedMenuItemFromJson(json);
}
```

### Exemple 2 : Utilisation avancée avec Unions

Freezed supporte les unions pour gérer différents états :

```dart
@freezed
class ApiResult<T> with _$ApiResult<T> {
  const factory ApiResult.loading() = Loading<T>;
  const factory ApiResult.success(T data) = Success<T>;
  const factory ApiResult.error(String message) = Error<T>;
}

// Utilisation
final result = ApiResult<String>.loading();

result.when(
  loading: () => print('Loading...'),
  success: (data) => print('Data: $data'),
  error: (message) => print('Error: $message'),
);
```

### Exemple 3 : Modèles imbriqués

```dart
@freezed
class OrderItem with _$OrderItem {
  const factory OrderItem({
    required String menuItemId,
    required String menuItemName,
    required int quantity,
    required double unitPrice,
    required double totalPrice,
    @Default({}) Map<String, dynamic> customizations,
  }) = _OrderItem;

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
}

@freezed
class Order with _$Order {
  const factory Order({
    required String id,
    required String userId,
    required List<OrderItem> items, // Modèle imbriqué
    required double total,
    required OrderStatus status,
  }) = _Order;

  factory Order.fromJson(Map<String, dynamic> json) =>
      _$OrderFromJson(json);
}
```

## Migration depuis l'Ancien Code

### Avant (Code boilerplate)

```dart
class MenuItem {
  final String id;
  final String name;
  final double price;
  
  MenuItem({
    required this.id,
    required this.name,
    required this.price,
  });
  
  MenuItem copyWith({
    String? id,
    String? name,
    double? price,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
    };
  }
  
  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['id'],
      name: map['name'],
      price: map['price'],
    );
  }
  
  @override
  bool operator ==(Object other) {
    // ... code de comparaison
  }
  
  @override
  int get hashCode {
    // ... code de hash
  }
  
  @override
  String toString() {
    // ... code toString
  }
}
```

### Après (Avec Freezed)

```dart
@freezed
class MenuItem with _$MenuItem {
  const factory MenuItem({
    required String id,
    required String name,
    required double price,
  }) = _MenuItem;

  factory MenuItem.fromJson(Map<String, dynamic> json) =>
      _$MenuItemFromJson(json);
}
```

**Réduction du code : ~80 lignes → ~10 lignes !**

## Fonctionnalités Avancées

### 1. Custom JSON Serialization

```dart
@freezed
class MenuItem with _$MenuItem {
  const factory MenuItem({
    required String id,
    @JsonKey(name: 'item_name') required String name,
    @JsonKey(name: 'item_price') required double price,
    @JsonKey(fromJson: _dateTimeFromJson) required DateTime createdAt,
  }) = _MenuItem;

  factory MenuItem.fromJson(Map<String, dynamic> json) =>
      _$MenuItemFromJson(json);
}

// Fonction helper pour la conversion
DateTime _dateTimeFromJson(dynamic value) {
  if (value is String) {
    return DateTime.parse(value);
  } else if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.now();
}
```

### 2. Pattern Matching

```dart
@freezed
class OrderStatus with _$OrderStatus {
  const factory OrderStatus.pending() = Pending;
  const factory OrderStatus.confirmed() = Confirmed;
  const factory OrderStatus.preparing() = Preparing;
  const factory OrderStatus.ready() = Ready;
  const factory OrderStatus.delivered() = Delivered;
  const factory OrderStatus.cancelled() = Cancelled;
}

// Utilisation
final status = OrderStatus.confirmed();

status.when(
  pending: () => print('En attente'),
  confirmed: () => print('Confirmée'),
  preparing: () => print('En préparation'),
  ready: () => print('Prête'),
  delivered: () => print('Livrée'),
  cancelled: () => print('Annulée'),
);

// Ou avec maybeWhen pour gérer seulement certains cas
status.maybeWhen(
  confirmed: () => print('Confirmée'),
  orElse: () => print('Autre statut'),
);
```

### 3. Méthodes et Getters Personnalisés

```dart
@freezed
class MenuItem with _$MenuItem {
  const factory MenuItem({
    required String id,
    required String name,
    required double price,
    @Default(0) int quantity,
  }) = _MenuItem;

  // Getter personnalisé
  double get totalPrice => price * quantity;
  
  // Méthode personnalisée
  bool isAvailable() => quantity > 0;
  
  factory MenuItem.fromJson(Map<String, dynamic> json) =>
      _$MenuItemFromJson(json);
}
```

## Bonnes Pratiques

### 1. Utiliser des valeurs par défaut

```dart
// ✅ Bon - Valeurs par défaut
@freezed
class MenuItem with _$MenuItem {
  const factory MenuItem({
    required String id,
    @Default(false) bool isPopular,
    @Default([]) List<String> ingredients,
  }) = _MenuItem;
}

// ❌ Éviter - Pas de valeurs par défaut
@freezed
class MenuItem with _$MenuItem {
  const factory MenuItem({
    required String id,
    required bool isPopular, // Toujours requis
    required List<String> ingredients, // Toujours requis
  }) = _MenuItem;
}
```

### 2. Utiliser des types optionnels pour les champs nullable

```dart
// ✅ Bon - Type optionnel explicite
@freezed
class MenuItem with _$MenuItem {
  const factory MenuItem({
    required String id,
    String? imageUrl, // Optionnel
    String? description, // Optionnel
  }) = _MenuItem;
}
```

### 3. Grouper les données liées

```dart
// ✅ Bon - Grouper les données liées
@freezed
class Address with _$Address {
  const factory Address({
    required String street,
    required String city,
    required String postalCode,
    required String country,
  }) = _Address;
  
  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);
}

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    required Address address, // Utiliser le modèle imbriqué
  }) = _User;
}
```

## Comparaison Avant/Après

### Code Boilerplate Réduit

| Aspect | Avant | Après |
|--------|-------|-------|
| Lignes de code | ~100 lignes | ~15 lignes |
| copyWith | Manuel | Automatique |
| == et hashCode | Manuel | Automatique |
| toString | Manuel | Automatique |
| JSON | Manuel | Automatique |
| Immutabilité | Manuelle | Garantie |

### Performance

- **Comparaisons** : Plus rapides avec hashCode optimisé
- **Copies** : Plus efficaces avec copyWith optimisé
- **Mémoire** : Meilleure utilisation avec immutabilité

## Workflow de Développement

1. **Créer le modèle** : Écrire la classe avec `@freezed`
2. **Générer le code** : Exécuter `build_runner`
3. **Utiliser le modèle** : Le code généré est prêt à l'emploi
4. **Modifier le modèle** : Ajouter/supprimer des champs
5. **Régénérer** : Le code est automatiquement mis à jour

## Commandes Utiles

```bash
# Générer le code
flutter pub run build_runner build

# Mode watch (régénère automatiquement)
flutter pub run build_runner watch

# Supprimer les fichiers générés et régénérer
flutter pub run build_runner build --delete-conflicting-outputs

# Nettoyer les fichiers générés
flutter pub run build_runner clean
```

## Bénéfices

- ✅ **Réduction du code** : Moins de code à maintenir
- ✅ **Moins d'erreurs** : Code généré = moins de bugs
- ✅ **Meilleure performance** : Optimisations automatiques
- ✅ **Type safety** : Vérifications à la compilation
- ✅ **Maintenabilité** : Code plus clair et concis

## Notes Importantes

1. **Fichiers générés** : Les fichiers `.freezed.dart` et `.g.dart` ne doivent **jamais** être modifiés manuellement
2. **Version control** : Ajoutez les fichiers générés au git, ils sont nécessaires pour la compilation
3. **Hot reload** : Les modifications des modèles Freezed nécessitent un hot restart (pas juste hot reload)
4. **Compatibilité** : Freezed fonctionne avec tous les types Dart, y compris les enums, les unions, etc.

## Migration Progressive

Vous pouvez migrer progressivement :

1. Créer de nouveaux modèles avec Freezed
2. Migrer les modèles existants un par un
3. Garder les anciens modèles pour la compatibilité
4. Utiliser des factory methods `fromMap()` pour la compatibilité

Exemple de compatibilité :

```dart
@freezed
class FreezedMenuItem with _$FreezedMenuItem {
  // ... définition Freezed
  
  // Factory pour compatibilité avec l'ancien code
  factory FreezedMenuItem.fromMap(Map<String, dynamic> map) {
    return FreezedMenuItem(
      id: map['id'],
      name: map['name'],
      // ...
    );
  }
  
  // Méthode pour compatibilité
  Map<String, dynamic> toMap() {
    return toJson();
  }
}
```

