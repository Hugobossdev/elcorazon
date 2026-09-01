import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/presentation/tarification.dart';
import 'package:elcora_fast/services/customization_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le prix d'un plat personnalisé, de la fiche produit au panier.
///
/// Ces tests tiennent une seule promesse, mais elle est celle qui manquait :
/// **le montant annoncé sur la fiche est celui qui apparaît au panier**. Il ne
/// l'était pas — la fiche lisait un champ que rien ne renseignait, et la ligne
/// du panier ne portait que le tarif catalogue — si bien qu'un burger composé
/// à 6 200 s'affichait à 5 000 une fois ajouté, puis remontait à 6 200 quand le
/// serveur répondait.
///
/// Le montant qui **fait foi** reste celui du serveur (invariant C1, ADR-007) :
/// ce qui est vérifié ici, c'est que l'app montre le même, et non un troisième.
void main() {
  // ---------------------------------------------------------------- la règle

  group('La règle de prix', () {
    test('sans option, le prix unitaire est celui du catalogue', () {
      // Scénario 1 : plat 5 000, aucune option, quantité 1.
      expect(
        totalDeLigne(prixDeBase: 5000, supplementOptions: 0, quantite: 1),
        5000,
      );
    });

    test('une option payante s’ajoute au prix de base', () {
      // Scénario 2 : plat 5 000, option +500, quantité 1.
      expect(
        totalDeLigne(prixDeBase: 5000, supplementOptions: 500, quantite: 1),
        5500,
      );
    });

    test('les options sont multipliées avec le plat, pas ajoutées à côté', () {
      // Scénario 3 : plat 5 000, options +500 et +1 000, quantité 2.
      // (5 000 + 1 500) × 2 = 13 000, et non 5 000 × 2 + 1 500 = 11 500.
      expect(
        totalDeLigne(prixDeBase: 5000, supplementOptions: 1500, quantite: 2),
        13000,
      );
    });

    test('une option gratuite ne change rien', () {
      // Scénario 4 : une option à 0 est un choix, pas un supplément. Elle doit
      // être retenue — et facturée zéro.
      expect(
        totalDeLigne(prixDeBase: 5000, supplementOptions: 0, quantite: 1),
        5000,
      );
    });

    test('la pizza du cahier des charges', () {
      // 5 000 + 500 + 1 000 + 300 = 6 800 l'unité ; × 2 = 13 600.
      const supplements = 500.0 + 1000.0 + 300.0;
      expect(
        prixUnitairePersonnalise(
          prixDeBase: 5000,
          supplementOptions: supplements,
        ),
        6800,
      );
      expect(
        totalDeLigne(
          prixDeBase: 5000,
          supplementOptions: supplements,
          quantite: 2,
        ),
        13600,
      );
    });

    test('trois exemplaires d’un plat à option', () {
      // (5 000 + 1 000) × 3 = 18 000.
      expect(
        totalDeLigne(prixDeBase: 5000, supplementOptions: 1000, quantite: 3),
        18000,
      );
    });
  });

  // ------------------------------------------------------- la ligne au panier

  group('La ligne du panier applique la même règle', () {
    CartItem ligne({
      double prix = 5000,
      double supplement = 0,
      int quantite = 1,
      Map<String, dynamic> options = const {},
      List<String> identifiants = const [],
    }) {
      return CartItem(
        id: 'ligne-1',
        menuItemId: 'article-1',
        name: 'Pizza',
        price: prix,
        quantity: quantite,
        customizations: options,
        selectedOptionIds: identifiants,
        supplementOptions: supplement,
      );
    }

    test('le total de ligne reprend le montant de la fiche', () {
      final pizza = ligne(supplement: 1800, quantite: 2);

      expect(pizza.prixUnitaire, 6800);
      expect(pizza.totalPrice, 13600);
      expect(
        pizza.totalPrice,
        totalDeLigne(prixDeBase: 5000, supplementOptions: 1800, quantite: 2),
      );
    });

    test('une ligne rendue par le serveur n’est pas renchérie', () {
      // Scénario 5 : `unit_price` intègre déjà les options. La ligne
      // resynchronisée porte donc un supplément nul, et repasser par la règle
      // ne compte pas les options une seconde fois.
      final duServeur = ligne(prix: 6800);

      expect(duServeur.prixUnitaire, 6800);
      expect(duServeur.totalPrice, 6800);
    });

    test('le supplément survit à un aller-retour de stockage', () {
      // Le panier est relu du stockage au démarrage : perdre le supplément y
      // ferait réapparaître le prix nu du plat.
      final compose = ligne(
        supplement: 1800,
        quantite: 2,
        options: {'Garniture': 'Poulet, Fromage'},
        identifiants: const ['opt-poulet', 'opt-fromage'],
      );

      final relu = CartItem.fromMap(compose.toMap());

      expect(relu.supplementOptions, 1800);
      expect(relu.totalPrice, 13600);
      expect(relu, equals(compose));
    });

    test('un panier écrit avant les suppléments se relit sans supplément', () {
      // Compatibilité descendante : `options_supplement` est absent des paniers
      // sérialisés par les versions antérieures.
      final ancien = {
        'id': 'ligne-1',
        'menu_item_id': 'article-1',
        'name': 'Pizza',
        'price': 5000.0,
        'quantity': 1,
        'image_url': null,
        'customizations': <String, dynamic>{},
      };

      expect(CartItem.fromMap(ancien).supplementOptions, 0);
      expect(CartItem.fromMap(ancien).totalPrice, 5000);
    });

    test('le sous-total cumule les lignes personnalisées', () {
      final panier = [
        ligne(supplement: 1800, quantite: 2), // 13 600
        ligne(prix: 2000, quantite: 3), //        6 000
      ];

      expect(
        sousTotalDuPanier(panier.map((l) => l.totalPrice)),
        19600,
      );
    });
  });

  // ------------------------------------------------ le chiffrage des options

  group('Ce que le configurateur chiffre', () {
    late CustomizationService service;

    /// Une pizza telle que le détail de l'article la rend : une base à
    /// choisir, des garnitures facultatives.
    List<CustomizationOption> optionsDeLaPizza() {
      return [
        CustomizationOption(
          id: 'base-tomate',
          name: 'Sauce tomate',
          category: 'Base',
          isRequired: true,
          minSelections: 1,
          isRemote: true,
        ),
        CustomizationOption(
          id: 'base-creme',
          name: 'Crème fraîche',
          category: 'Base',
          priceModifier: 300,
          isRequired: true,
          minSelections: 1,
          isRemote: true,
        ),
        CustomizationOption(
          id: 'garn-fromage',
          name: 'Fromage',
          category: 'Garnitures',
          priceModifier: 500,
          maxQuantity: 3,
          isRemote: true,
        ),
        CustomizationOption(
          id: 'garn-poulet',
          name: 'Poulet',
          category: 'Garnitures',
          priceModifier: 1000,
          maxQuantity: 3,
          isRemote: true,
        ),
      ];
    }

    setUp(() async {
      service = CustomizationService();
      service.clearAllCustomizations();
      await service.initialize();
      service.seedOptionsForTest('pizza', optionsDeLaPizza());
    });

    test('le supplément suit les choix, pendant la composition', () async {
      await service.startCustomization('s1', 'pizza', 'Pizza');

      expect(service.calculatePriceModifier('s1'), 0);

      service.updateSelection('s1', 'Base', 'base-creme', true);
      service.updateSelection('s1', 'Garnitures', 'garn-fromage', true);
      service.updateSelection('s1', 'Garnitures', 'garn-poulet', true);

      // 300 + 500 + 1 000 = 1 800.
      expect(service.calculatePriceModifier('s1'), 1800);
    });

    test('le total de la session est tenu à jour, et non à la fermeture',
        () async {
      // C'est ce champ que la barre d'ajout lisait pour annoncer son total.
      // Seul `finishCustomization` le renseignait — après avoir refermé la
      // session — si bien qu'il valait zéro tant que l'écran était ouvert.
      await service.startCustomization('s2', 'pizza', 'Pizza');
      service.updateSelection('s2', 'Garnitures', 'garn-poulet', true);

      expect(service.getCurrentCustomization('s2')!.totalPriceModifier, 1000);
    });

    test('une option retenue deux fois n’est comptée qu’une', () async {
      // Scénario 5 : `updateSelection` ajoutait sans garde, et un double appel
      // — un rebond de la liste, une remise en état — doublait le supplément.
      await service.startCustomization('s3', 'pizza', 'Pizza');

      service.updateSelection('s3', 'Garnitures', 'garn-poulet', true);
      service.updateSelection('s3', 'Garnitures', 'garn-poulet', true);

      expect(service.calculatePriceModifier('s3'), 1000);
      expect(service.selectedOptionIds('s3'), ['garn-poulet']);
    });

    test('une option gratuite est retenue sans rien coûter', () async {
      await service.startCustomization('s4', 'pizza', 'Pizza');
      service.updateSelection('s4', 'Base', 'base-tomate', true);

      expect(service.selectedOptionIds('s4'), ['base-tomate']);
      expect(service.calculatePriceModifier('s4'), 0);
    });

    test('le supplément d’un autre article ne déteint pas sur celui-ci',
        () async {
      // Le service est un singleton et garde les options de tous les articles
      // ouverts. La recherche par identifiant balayait ce cache entier et
      // rendait la première correspondance : les options de démonstration
      // partagent leurs identifiants d'un article à l'autre sans partager
      // leurs prix.
      service.seedOptionsForTest('burger', [
        CustomizationOption(
          id: 'garn-fromage',
          name: 'Cheddar',
          category: 'Garnitures',
          priceModifier: 5000,
          isRemote: true,
        ),
      ]);

      await service.startCustomization('s5', 'pizza', 'Pizza');
      service.updateSelection('s5', 'Garnitures', 'garn-fromage', true);

      // Le fromage de la pizza vaut 500, pas les 5 000 du cheddar du burger.
      expect(service.calculatePriceModifier('s5'), 500);
    });

    test('les libellés retenus sont lisibles, pas des identifiants', () async {
      // Le panier affichait « Garnitures: [garn-poulet, garn-fromage] ».
      await service.startCustomization('s6', 'pizza', 'Pizza');
      service.updateSelection('s6', 'Base', 'base-creme', true);
      service.updateSelection('s6', 'Garnitures', 'garn-poulet', true);
      service.updateSelection('s6', 'Garnitures', 'garn-fromage', true);

      expect(service.libellesRetenus('s6'), {
        'Base': 'Crème fraîche',
        'Garnitures': 'Poulet, Fromage',
      });
    });

    test('un groupe obligatoire non satisfait est signalé', () async {
      // Scénario 8 : « Base » exige un choix, et rien n'est retenu par défaut.
      await service.startCustomization('s7', 'pizza', 'Pizza');

      final verdict = service.validateCustomization('s7');
      expect(verdict['isValid'], isFalse);
      expect(verdict['errors'], isNotEmpty);
      expect(service.constraintFor('pizza', 'Base').minSelections, 1);
    });

    test('le plafond d’un groupe est celui du catalogue', () async {
      // Scénario 9 : `max_select` vient du groupe serveur, et c'est lui que
      // `validate_selection` revalide.
      final garnitures = service.constraintFor('pizza', 'Garnitures');

      expect(garnitures.maxSelections, 3);
      expect(garnitures.isSingleChoice, isFalse);

      final base = service.constraintFor('pizza', 'Base');
      expect(base.isSingleChoice, isTrue);
      expect(base.isRequired, isTrue);
    });
  });

  // --------------------------------------------- deux configurations, deux lignes

  group('Deux personnalisations du même plat', () {
    CartItem avec(List<String> identifiants, double supplement) {
      return CartItem(
        id: 'l',
        menuItemId: 'pizza',
        name: 'Pizza',
        price: 5000,
        quantity: 1,
        selectedOptionIds: identifiants,
        supplementOptions: supplement,
      );
    }

    test('restent distinctes', () {
      // Scénario 6 : « Pizza + fromage » et « Pizza + poulet » ne se fusionnent
      // pas — la même règle que `CartService._identical_line` côté serveur.
      expect(
        avec(const ['garn-fromage'], 500),
        isNot(equals(avec(const ['garn-poulet'], 1000))),
      );
    });

    test('deux lignes strictement identiques sont égales', () {
      expect(
        avec(const ['garn-fromage'], 500),
        equals(avec(const ['garn-fromage'], 500)),
      );
    });
  });
}
