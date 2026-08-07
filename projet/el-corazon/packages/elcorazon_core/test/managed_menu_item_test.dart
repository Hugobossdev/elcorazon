import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Article du catalogue vu de l'exploitation.
///
/// Ce qui se teste ici, ce sont les quatre écarts avec la forme publique. Le
/// dépôt d'exploitation rendait des `MenuItem`, modelés sur le sérialiseur
/// public : la catégorie arrivait en UUID dans un champ nommé `categorySlug`,
/// `category_name` retombait sur la chaîne vide, et le stock — que le serveur
/// rend — n'était lu nulle part.
Map<String, dynamic> _json({
  bool tracksStock = false,
  int? stockQuantity,
  bool isDeleted = false,
  List<dynamic>? optionGroups,
}) {
  return {
    'id': 'item-1',
    'restaurant': 'el-corazon-lome',
    // Clé primaire, et non slug : c'est par elle qu'on réaffecte un article.
    'category': 'f7c1e0d2-0000-0000-0000-000000000001',
    'name': 'Burger Corazón',
    'slug': 'burger-corazon',
    'description': 'Le classique',
    'image': 'https://cdn.test/burger.jpg',
    'price': {'amount': '3500', 'currency': 'XOF'},
    'preparation_minutes': 15,
    'calories': 720,
    'ingredients': ['pain', 'boeuf'],
    'allergens': ['gluten'],
    'dietary_tags': <String>[],
    'is_available': true,
    'is_popular': true,
    'vip_exclusive': false,
    'tracks_stock': tracksStock,
    'stock_quantity': stockQuantity,
    'rating_average': '4.5',
    'rating_count': 12,
    'sort_order': 3,
    'is_deleted': isDeleted,
    if (optionGroups != null) 'option_groups': optionGroups,
  };
}

void main() {
  group('La catégorie est un identifiant', () {
    test('elle est lue telle quelle, sans être prise pour un slug', () {
      final article = ManagedMenuItem.fromJson(_json());
      expect(article.categoryId, 'f7c1e0d2-0000-0000-0000-000000000001');
    });
  });

  group('Stock', () {
    test('un article sans suivi n’est jamais en rupture', () {
      // C'est `isAvailable` qui décide alors de sa présence à la carte.
      final article = ManagedMenuItem.fromJson(_json());
      expect(article.tracksStock, isFalse);
      expect(article.estEnRupture, isFalse);
    });

    test('un article suivi et épuisé est en rupture', () {
      final article =
          ManagedMenuItem.fromJson(_json(tracksStock: true, stockQuantity: 0));
      expect(article.stockQuantity, 0);
      expect(article.estEnRupture, isTrue);
    });

    test('un article suivi et pourvu ne l’est pas', () {
      final article =
          ManagedMenuItem.fromJson(_json(tracksStock: true, stockQuantity: 7));
      expect(article.estEnRupture, isFalse);
    });

    test('un suivi sans quantité vaut rupture', () {
      // Le serveur ne devrait pas rendre cette combinaison ; s'il le fait,
      // annoncer « en stock » serait le pire des deux choix.
      final article = ManagedMenuItem.fromJson(_json(tracksStock: true));
      expect(article.estEnRupture, isTrue);
    });
  });

  group('Retrait de la carte', () {
    test('un article retiré reste lisible', () {
      // Il n'est pas effacé : les commandes passées le référencent.
      expect(ManagedMenuItem.fromJson(_json(isDeleted: true)).isDeleted, isTrue);
      expect(ManagedMenuItem.fromJson(_json()).isDeleted, isFalse);
    });
  });

  group('Groupes d’options', () {
    test('ils accompagnent la liste, contrairement à la forme publique', () {
      final article = ManagedMenuItem.fromJson(
        _json(
          optionGroups: [
            {
              'id': 'grp-1',
              'name': 'Suppléments',
              'min_select': 0,
              'max_select': 2,
              'is_required': false,
              'sort_order': 0,
              'options': [
                {
                  'id': 'opt-1',
                  'name': 'Extra fromage',
                  'price_delta': {'amount': '500', 'currency': 'XOF'},
                  'is_default': false,
                  'is_available': true,
                  'sort_order': 0,
                },
              ],
            },
          ],
        ),
      );

      expect(article.optionGroups.single.name, 'Suppléments');
      expect(article.optionGroups.single.options.single.priceDelta.amountMinor, 500);
    });

    test('leur absence n’est pas une erreur', () {
      expect(ManagedMenuItem.fromJson(_json()).optionGroups, isEmpty);
    });
  });

  group('Le reste du contrat', () {
    test('est lu sans perte', () {
      final article = ManagedMenuItem.fromJson(_json());

      expect(article.id, 'item-1');
      expect(article.restaurantSlug, 'el-corazon-lome');
      expect(article.name, 'Burger Corazón');
      expect(article.slug, 'burger-corazon');
      expect(article.price.amountMinor, 3500);
      expect(article.preparationMinutes, 15);
      expect(article.calories, 720);
      expect(article.ingredients, ['pain', 'boeuf']);
      expect(article.allergens, ['gluten']);
      expect(article.isAvailable, isTrue);
      expect(article.isPopular, isTrue);
      expect(article.vipExclusive, isFalse);
      expect(article.ratingAverage, 4.5);
      expect(article.ratingCount, 12);
      expect(article.sortOrder, 3);
    });
  });
}
