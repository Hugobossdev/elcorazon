import 'dart:convert';

import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'aller-retour JSON du catalogue.
///
/// `fromJson` existait seul. Une application hors ligne doit pouvoir ranger un
/// article et le relire à l'identique : `OfflineSyncService` de `fastfood` le
/// faisait au travers d'un modèle local, qui portait son propre couple
/// `toMap`/`fromMap`. Le modèle local retiré, l'aller-retour revient là où il
/// a un sens — sur l'entité.
Map<String, dynamic> _article({
  List<dynamic>? groupes,
  Object? calories,
}) =>
    {
      'id': 'article-1',
      'restaurant': 'el-corazon-lome',
      'category': 'burgers',
      'category_name': 'Burgers',
      'name': 'Poulet braisé',
      'slug': 'poulet-braise',
      'description': 'Braisé au feu de bois',
      'image': 'https://exemple.test/poulet.jpg',
      'price': {'amount': '450000', 'currency': 'XOF'},
      'preparation_minutes': 20,
      'allergens': ['arachide'],
      'dietary_tags': ['halal', 'sans_gluten'],
      'is_available': true,
      'is_popular': true,
      'vip_exclusive': false,
      'rating_average': '4.5',
      'rating_count': 12,
      'sort_order': 3,
      'ingredients': ['poulet', 'épices'],
      'calories': calories,
      if (groupes != null) 'option_groups': groupes,
    };

Map<String, dynamic> _categorie() => {
      'id': 'categorie-1',
      'restaurant': 'el-corazon-lome',
      'name': 'Burgers',
      'slug': 'burgers',
      'emoji': '🍔',
      'description': 'Nos burgers',
      'sort_order': 2,
    };

void main() {
  group('Un article', () {
    test('relu après écriture est le même', () {
      final origine = MenuItem.fromJson(_article(calories: 620));
      final relu = MenuItem.fromJson(
        json.decode(json.encode(origine.toJson())) as Map<String, dynamic>,
      );

      expect(relu.id, origine.id);
      expect(relu.restaurantSlug, origine.restaurantSlug);
      expect(relu.categorySlug, origine.categorySlug);
      expect(relu.categoryName, origine.categoryName);
      expect(relu.name, origine.name);
      expect(relu.slug, origine.slug);
      expect(relu.description, origine.description);
      expect(relu.image, origine.image);
      expect(relu.preparationMinutes, origine.preparationMinutes);
      expect(relu.allergens, origine.allergens);
      expect(relu.dietaryTags, origine.dietaryTags);
      expect(relu.isAvailable, origine.isAvailable);
      expect(relu.isPopular, origine.isPopular);
      expect(relu.vipExclusive, origine.vipExclusive);
      expect(relu.ratingAverage, origine.ratingAverage);
      expect(relu.ratingCount, origine.ratingCount);
      expect(relu.sortOrder, origine.sortOrder);
      expect(relu.ingredients, origine.ingredients);
      expect(relu.calories, origine.calories);
    });

    test('garde son prix au centime près', () {
      // Le montant voyage en unité mineure et en chaîne (ADR-007) : le relire
      // par un `double` le perdrait.
      final relu = MenuItem.fromJson(
        json.decode(json.encode(MenuItem.fromJson(_article()).toJson()))
            as Map<String, dynamic>,
      );

      expect(relu.price.amountMinor, 450000);
      expect(relu.price.currency, 'XOF');
    });

    test('sans calories, il n’en invente pas', () {
      final relu = MenuItem.fromJson(
        json.decode(json.encode(MenuItem.fromJson(_article()).toJson()))
            as Map<String, dynamic>,
      );

      expect(relu.calories, isNull);
    });

    test('ses groupes d’options survivent au voyage', () {
      final origine = MenuItem.fromJson(
        _article(
          groupes: [
            {
              'id': 'groupe-1',
              'name': 'Cuisson',
              'min_select': 1,
              'max_select': 1,
              'is_required': true,
              'sort_order': 0,
              'options': [
                {
                  'id': 'option-1',
                  'name': 'À point',
                  'price_delta': {'amount': '0', 'currency': 'XOF'},
                  'is_default': true,
                  'is_available': true,
                  'sort_order': 0,
                },
                {
                  'id': 'option-2',
                  'name': 'Bien cuit',
                  'price_delta': {'amount': '50000', 'currency': 'XOF'},
                  'is_default': false,
                  'is_available': true,
                  'sort_order': 1,
                },
              ],
            },
          ],
        ),
      );

      final relu = MenuItem.fromJson(
        json.decode(json.encode(origine.toJson())) as Map<String, dynamic>,
      );

      expect(relu.optionGroups, hasLength(1));
      final groupe = relu.optionGroups.single;
      expect(groupe.name, 'Cuisson');
      expect(groupe.isRequired, isTrue);
      expect(groupe.options, hasLength(2));
      expect(groupe.options.last.name, 'Bien cuit');
      expect(groupe.options.last.priceDelta.amountMinor, 50000);
      expect(groupe.options.first.isDefault, isTrue);
    });

    test('sans groupe d’options, la liste reste vide', () {
      final relu = MenuItem.fromJson(
        json.decode(json.encode(MenuItem.fromJson(_article()).toJson()))
            as Map<String, dynamic>,
      );

      expect(relu.optionGroups, isEmpty);
    });
  });

  group('Une catégorie', () {
    test('relue après écriture est la même', () {
      final origine = Category.fromJson(_categorie());
      final relu = Category.fromJson(
        json.decode(json.encode(origine.toJson())) as Map<String, dynamic>,
      );

      expect(relu.id, origine.id);
      expect(relu.restaurantSlug, origine.restaurantSlug);
      expect(relu.name, origine.name);
      expect(relu.slug, origine.slug);
      expect(relu.emoji, origine.emoji);
      expect(relu.description, origine.description);
      expect(relu.sortOrder, origine.sortOrder);
    });

    test('une pastille absente reste absente', () {
      // Elle ne devient pas la chaîne « null ».
      final sansEmoji = Map<String, dynamic>.of(_categorie())..remove('emoji');
      final relu = Category.fromJson(
        json.decode(json.encode(Category.fromJson(sansEmoji).toJson()))
            as Map<String, dynamic>,
      );

      expect(relu.emoji, isEmpty);
    });
  });
}
