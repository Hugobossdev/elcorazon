import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les options retenues sur une ligne de commande.
///
/// Le serveur les fige au passage de commande et les rend sur chaque ligne.
/// Le socle ne les lisait pas : le back-office affichait donc des articles
/// sans savoir ce que le client avait demandé, et la cuisine préparait à
/// l'aveugle un « sans oignon » qu'elle ne voyait nulle part.
Map<String, dynamic> _ligne({List<dynamic>? options}) => {
      'id': 'ligne-1',
      'menu_item': 'article-1',
      'item_name': 'Poulet braisé',
      'item_image': null,
      'unit_price': {'amount': '4500', 'currency': 'XOF'},
      'quantity': 2,
      'line_total': {'amount': '9000', 'currency': 'XOF'},
      'notes': '',
      if (options != null) 'options': options,
    };

void main() {
  group('Une ligne sans option', () {
    test('rend une liste vide, pas un nul', () {
      expect(OrderLine.fromJson(_ligne()).options, isEmpty);
    });
  });

  group('Une ligne avec options', () {
    final ligne = OrderLine.fromJson(
      _ligne(
        options: [
          {
            'group': 'Cuisson',
            'option': 'À point',
            'delta': 0,
            'currency': 'XOF',
          },
          {
            'group': 'Suppléments',
            'option': 'Double fromage',
            'delta': 500,
            'currency': 'XOF',
          },
        ],
      ),
    );

    test('chaque choix est repris avec son groupe', () {
      expect(ligne.options, hasLength(2));
      expect(ligne.options.first.groupName, 'Cuisson');
      expect(ligne.options.first.optionName, 'À point');
      expect(ligne.options.last.groupName, 'Suppléments');
    });

    test('le supplément de prix arrive en unité mineure', () {
      expect(ligne.options.first.priceDelta.amountMinor, 0);
      expect(ligne.options.last.priceDelta.amountMinor, 500);
      expect(ligne.options.last.priceDelta.currency, 'XOF');
    });
  });

  group('Un JSON incomplet', () {
    test('ne fait pas tomber la lecture d’une commande', () {
      // Une commande ancienne peut porter des options écrites autrement. Mieux
      // vaut une option au libellé vide qu'un écran de supervision qui refuse
      // d'afficher la commande.
      final ligne = OrderLine.fromJson(_ligne(options: [const <String, dynamic>{}]));

      expect(ligne.options.single.groupName, isEmpty);
      expect(ligne.options.single.optionName, isEmpty);
      expect(ligne.options.single.priceDelta.amountMinor, 0);
      expect(ligne.options.single.priceDelta.currency, 'XOF');
    });
  });
}
