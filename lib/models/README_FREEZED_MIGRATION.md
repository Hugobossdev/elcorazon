# 🔄 Guide de Migration vers Freezed

## Vue d'ensemble

Ce guide explique comment migrer progressivement les modèles existants vers Freezed.

## Stratégie de Migration

### Phase 1 : Préparation
1. Ajouter les dépendances (déjà fait)
2. Créer des modèles d'exemple (déjà fait)
3. Tester avec un modèle simple

### Phase 2 : Migration Progressive
1. Identifier les modèles les plus utilisés
2. Migrer un modèle à la fois
3. Tester après chaque migration
4. Maintenir la compatibilité avec l'ancien code

### Phase 3 : Finalisation
1. Migrer tous les modèles
2. Supprimer l'ancien code
3. Nettoyer les dépendances inutilisées

## Étapes de Migration pour un Modèle

### Étape 1 : Créer le nouveau modèle Freezed

```dart
// lib/models/freezed_menu_item.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'menu_category.dart';

part 'freezed_menu_item.freezed.dart';
part 'freezed_menu_item.g.dart';

@freezed
class FreezedMenuItem with _$FreezedMenuItem {
  const factory FreezedMenuItem({
    required String id,
    required String name,
    // ... autres champs
  }) = _FreezedMenuItem;

  factory FreezedMenuItem.fromJson(Map<String, dynamic> json) =>
      _$FreezedMenuItemFromJson(json);
}
```

### Étape 2 : Générer le code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Étape 3 : Ajouter les méthodes de compatibilité

```dart
@freezed
class FreezedMenuItem with _$FreezedMenuItem {
  // ... définition

  /// Factory pour compatibilité avec l'ancien code
  factory FreezedMenuItem.fromMap(Map<String, dynamic> map) {
    // Conversion depuis l'ancien format
    return FreezedMenuItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      // ...
    );
  }

  /// Méthode pour compatibilité
  Map<String, dynamic> toMap() {
    return toJson();
  }
}
```

### Étape 4 : Créer un adaptateur

```dart
// lib/adapters/menu_item_adapter.dart
class MenuItemAdapter {
  /// Convertir depuis l'ancien modèle
  static FreezedMenuItem fromOld(MenuItem oldItem) {
    return FreezedMenuItem(
      id: oldItem.id,
      name: oldItem.name,
      // ...
    );
  }

  /// Convertir vers l'ancien modèle (si nécessaire)
  static MenuItem toOld(FreezedMenuItem newItem) {
    return MenuItem(
      id: newItem.id,
      name: newItem.name,
      // ...
    );
  }
}
```

### Étape 5 : Mettre à jour le code progressivement

```dart
// Avant
final item = MenuItem.fromMap(data);

// Après (avec adaptateur)
final item = FreezedMenuItem.fromMap(data);

// Ou directement
final item = FreezedMenuItem.fromJson(data);
```

### Étape 6 : Tester

1. Tester toutes les fonctionnalités
2. Vérifier la compatibilité JSON
3. Vérifier les performances

## Modèles Prioritaires

Commencez par migrer les modèles les plus simples et les plus utilisés :

1. ✅ `MenuItem` (exemple créé)
2. ✅ `User` (exemple créé)
3. `OrderItem`
4. `Address`
5. `PromoCode`

## Checklist de Migration

Pour chaque modèle :

- [ ] Créer le modèle Freezed
- [ ] Générer le code avec build_runner
- [ ] Ajouter les méthodes de compatibilité (fromMap, toMap)
- [ ] Créer un adaptateur si nécessaire
- [ ] Mettre à jour les tests
- [ ] Mettre à jour les services/repositories
- [ ] Tester toutes les fonctionnalités
- [ ] Vérifier les performances
- [ ] Documenter les changements

## Exemple Complet : MenuItem

### Avant

```dart
class MenuItem {
  final String id;
  final String name;
  final double price;
  // ... 100+ lignes de code boilerplate
}
```

### Après

```dart
@freezed
class FreezedMenuItem with _$FreezedMenuItem {
  const factory FreezedMenuItem({
    required String id,
    required String name,
    required double price,
    @Default(false) bool isPopular,
  }) = _FreezedMenuItem;

  factory FreezedMenuItem.fromJson(Map<String, dynamic> json) =>
      _$FreezedMenuItemFromJson(json);
}
```

## Notes Importantes

1. **Compatibilité** : Gardez les anciens modèles pendant la migration
2. **Tests** : Testez chaque migration individuellement
3. **Performance** : Vérifiez que les performances ne se dégradent pas
4. **Documentation** : Documentez les changements dans votre équipe

## Support

Si vous rencontrez des problèmes :
1. Vérifiez que `build_runner` a bien généré le code
2. Vérifiez les imports (`part` directives)
3. Vérifiez que les dépendances sont à jour
4. Consultez la [documentation officielle de Freezed](https://pub.dev/packages/freezed)

