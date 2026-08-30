import 'package:elcora_fast/services/customization_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Personnalisation d'un plat de la carte — ce qui décide qu'un choix manque.
///
/// Presque toute la carte porte un groupe obligatoire : « Cuisson du steak »
/// sur les burgers de bœuf, « Taille » et « Base » sur les pizzas,
/// « Accompagnement » et « Niveau de piment » sur les grillades. Une ligne
/// composée sans ces options est refusée par `validate_selection` côté Django,
/// et `POST /carts/{slug}/lines/` répond 409 — après que la synchronisation a
/// vidé le panier serveur, si bien que l'écran montrait des articles que la
/// commande n'aurait pas portés.
///
/// Ces tests tiennent le seul point où l'application peut le savoir avant
/// l'appel : la borne basse du groupe, telle que le catalogue la publie.
void main() {
  late CustomizationService service;

  /// Un burger tel que le détail de l'article le rend : une cuisson à choisir,
  /// des suppléments facultatifs.
  List<CustomizationOption> optionsDuBurger() {
    return [
      CustomizationOption(
        id: 'aaaaaaaa-0000-0000-0000-000000000001',
        name: 'Saignant',
        category: 'Cuisson du steak',
        isRequired: true,
        minSelections: 1,
        isRemote: true,
      ),
      CustomizationOption(
        id: 'aaaaaaaa-0000-0000-0000-000000000002',
        name: 'Bien cuit',
        category: 'Cuisson du steak',
        isRequired: true,
        minSelections: 1,
        isRemote: true,
      ),
      CustomizationOption(
        id: 'bbbbbbbb-0000-0000-0000-000000000001',
        name: 'Bacon grillé',
        category: 'Suppléments',
        priceModifier: 500,
        maxQuantity: 4,
        isRemote: true,
      ),
    ];
  }

  /// Un dessert : des suppléments, et rien d'obligatoire.
  List<CustomizationOption> optionsDuDessert() {
    return [
      CustomizationOption(
        id: 'cccccccc-0000-0000-0000-000000000001',
        name: 'Chantilly',
        category: 'Suppléments',
        priceModifier: 200,
        maxQuantity: 2,
        isRemote: true,
      ),
    ];
  }

  /// Options de démonstration : elles se disent requises, mais leurs
  /// identifiants n'existent pas au catalogue.
  List<CustomizationOption> optionsDeDemonstration() {
    return [
      CustomizationOption(
        id: 'cake-shape-round',
        name: 'Rond',
        category: 'shape',
        isRequired: true,
        minSelections: 1,
      ),
    ];
  }

  setUp(() async {
    service = CustomizationService();
    service.clearAllCustomizations();
    await service.initialize();
  });

  group('Ce qui impose de passer par la personnalisation', () {
    test('un groupe du catalogue qui exige un choix l’impose', () async {
      service.seedOptionsForTest('burger', optionsDuBurger());

      expect(await service.exigeUnChoix('burger'), isTrue);
    });

    test('des groupes tous facultatifs laissent le raccourci', () async {
      service.seedOptionsForTest('dessert', optionsDuDessert());

      expect(await service.exigeUnChoix('dessert'), isFalse);
    });

    test('une option de démonstration n’impose rien : le serveur l’ignore',
        () async {
      service.seedOptionsForTest('maquette', optionsDeDemonstration());

      // Elle se dit requise, mais son identifiant n'existe pas côté serveur :
      // détourner le client vers un écran de choix ne lui ferait pas composer
      // une ligne acceptable pour autant.
      expect(await service.exigeUnChoix('maquette'), isFalse);
    });
  });

  group('Ce que la ligne emporte au panier', () {
    test('la cuisson choisie part avec son identifiant de catalogue',
        () async {
      service.seedOptionsForTest('burger', optionsDuBurger());
      await service.startCustomization('s1', 'burger', 'Burger BBQ');

      service.updateSelection(
        's1',
        'Cuisson du steak',
        'aaaaaaaa-0000-0000-0000-000000000002',
        true,
      );
      service.updateSelection(
        's1',
        'Suppléments',
        'bbbbbbbb-0000-0000-0000-000000000001',
        true,
      );

      expect(service.selectedOptionIds('s1'), [
        'aaaaaaaa-0000-0000-0000-000000000002',
        'bbbbbbbb-0000-0000-0000-000000000001',
      ]);
    });

    test('aucune cuisson retenue : rien ne part, et le manque est visible',
        () async {
      service.seedOptionsForTest('burger', optionsDuBurger());
      await service.startCustomization('s2', 'burger', 'Burger BBQ');

      // Aucune option du catalogue n'est marquée par défaut : le groupe
      // obligatoire s'ouvre vide, et c'est au client de trancher.
      expect(service.selectedOptionIds('s2'), isEmpty);
      expect(
        service.constraintFor('burger', 'Cuisson du steak').minSelections,
        1,
      );
    });
  });
}
