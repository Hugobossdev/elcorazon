import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/customization_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Ce qui manquait au parcours de personnalisation, et que ces tests tiennent.
///
/// Trois trous, tous invisibles à l'analyse statique :
///
/// * les options **indisponibles** étaient écartées à la lecture du catalogue.
///   Un groupe dont toutes les options étaient épuisées disparaissait donc de
///   l'écran — y compris un groupe obligatoire — et la ligne partait sans le
///   choix que `validate_selection` exige, pour être refusée en 409 ;
/// * `CartService.updateItemCustomizations` n'avait **aucun appelant**, et
///   n'écrivait que les libellés d'affichage : les identifiants d'options et le
///   supplément restaient ceux de l'ancien choix ;
/// * rien ne rejouait une personnalisation existante, si bien que rouvrir une
///   ligne aurait rendu un écran vierge.
void main() {
  late CustomizationService service;

  /// Un burger tel que le détail de l'article le rend, avec un supplément
  /// épuisé — le cas que l'écran doit montrer sans le laisser cocher.
  List<CustomizationOption> optionsDuBurger() {
    return [
      CustomizationOption(
        id: 'cuisson-saignant',
        name: 'Saignant',
        category: 'Cuisson',
        isRequired: true,
        minSelections: 1,
        isRemote: true,
      ),
      CustomizationOption(
        id: 'cuisson-bien-cuit',
        name: 'Bien cuit',
        category: 'Cuisson',
        isRequired: true,
        minSelections: 1,
        isRemote: true,
      ),
      CustomizationOption(
        id: 'supp-fromage',
        name: 'Fromage',
        category: 'Suppléments',
        priceModifier: 500,
        maxQuantity: 3,
        isRemote: true,
      ),
      CustomizationOption(
        id: 'supp-bacon',
        name: 'Bacon',
        category: 'Suppléments',
        priceModifier: 1000,
        maxQuantity: 3,
        isRemote: true,
      ),
      CustomizationOption(
        id: 'supp-oeuf',
        name: 'Œuf',
        category: 'Suppléments',
        priceModifier: 500,
        maxQuantity: 3,
        isRemote: true,
        isAvailable: false,
      ),
    ];
  }

  eccore.MenuItem burgerDuCatalogue() {
    return const eccore.MenuItem(
      id: 'burger',
      restaurantSlug: 'el-corazon',
      categorySlug: 'burgers',
      categoryName: 'Burgers',
      name: 'Burger Poulet',
      slug: 'burger-poulet',
      description: '',
      image: null,
      price: eccore.Money(amountMinor: 4000, currency: 'XOF'),
      preparationMinutes: 10,
      allergens: [],
      dietaryTags: [],
      isAvailable: true,
      isPopular: false,
      vipExclusive: false,
      ratingAverage: 0,
      ratingCount: 0,
      sortOrder: 0,
    );
  }

  setUp(() async {
    service = CustomizationService();
    service.resetForTest();
    await service.initialize();
    service.seedOptionsForTest('burger', optionsDuBurger());
  });

  group('Une option indisponible est montrée, jamais retenue', () {
    test('elle reste dans la liste du groupe', () {
      final supplements =
          service.getOptionsByCategory('burger')['Suppléments']!;

      // Les écarter faisait disparaître un groupe entier dès que toutes ses
      // options l'étaient — un groupe obligatoire compris.
      expect(supplements.map((option) => option.name), contains('Œuf'));
      expect(
        supplements.firstWhere((option) => option.name == 'Œuf').isAvailable,
        isFalse,
      );
    });

    test('la cocher ne la retient pas', () async {
      await service.startCustomization('s', 'burger', 'Burger Poulet');

      service.updateSelection('s', 'Suppléments', 'supp-oeuf', true);

      expect(service.selectedOptionIds('s'), isEmpty);
      expect(service.calculatePriceModifier('s'), 0);
    });

    test('une option disponible du même groupe se coche normalement',
        () async {
      await service.startCustomization('s', 'burger', 'Burger Poulet');

      service.updateSelection('s', 'Suppléments', 'supp-fromage', true);

      expect(service.selectedOptionIds('s'), ['supp-fromage']);
      expect(service.calculatePriceModifier('s'), 500);
    });

    test('une option épuisée marquée par défaut n’est pas présélectionnée',
        () async {
      service.seedOptionsForTest('plat', [
        CustomizationOption(
          id: 'sauce-epuisee',
          name: 'Algérienne',
          category: 'Sauce',
          isDefault: true,
          priceModifier: 300,
          isRemote: true,
          isAvailable: false,
        ),
      ]);

      await service.startCustomization('d', 'plat', 'Plat');

      // Composer d'emblée une ligne que le serveur refuse ferait porter au
      // client une faute qu'il n'a pas commise.
      expect(service.selectedOptionIds('d'), isEmpty);
    });
  });

  group('L’ordre du catalogue est celui de l’écran', () {
    test('les groupes gardent l’ordre dans lequel le serveur les publie', () {
      // Le serveur trie par `sort_order` puis par nom
      // (`MenuItemViewSet.get_queryset`), et l'écran ne retrie jamais : il
      // parcourt les groupes dans l'ordre où la fiche les a donnés. Trier ici
      // par nom ou par identifiant remonterait « Suppléments » au-dessus de
      // « Cuisson » sur la moitié de la carte.
      expect(
        service.getOptionsByCategory('burger').keys,
        ['Cuisson', 'Suppléments'],
      );
    });

    test('les options gardent l’ordre de leur groupe', () {
      expect(
        service
            .getOptionsByCategory('burger')['Suppléments']!
            .map((option) => option.name),
        ['Fromage', 'Bacon', 'Œuf'],
      );
    });
  });

  group('Rouvrir une personnalisation la rejoue', () {
    test('les options de la ligne sont retenues à l’ouverture', () async {
      await service.startCustomization(
        's',
        'burger',
        'Burger Poulet',
        optionsInitiales: const ['cuisson-bien-cuit', 'supp-fromage'],
      );

      expect(
        service.selectedOptionIds('s'),
        ['cuisson-bien-cuit', 'supp-fromage'],
      );
      expect(service.calculatePriceModifier('s'), 500);
    });

    test('chaque option retrouve son groupe', () async {
      await service.startCustomization(
        's',
        'burger',
        'Burger Poulet',
        optionsInitiales: const ['cuisson-bien-cuit', 'supp-bacon'],
      );

      expect(service.libellesRetenus('s'), {
        'Cuisson': 'Bien cuit',
        'Suppléments': 'Bacon',
      });
    });

    test('une option devenue indisponible est écartée du rejeu', () async {
      await service.startCustomization(
        's',
        'burger',
        'Burger Poulet',
        optionsInitiales: const ['cuisson-saignant', 'supp-oeuf'],
      );

      // La garder ferait échouer l'enregistrement sur un choix que le client
      // n'a pas refait — et qu'il ne peut plus refaire.
      expect(service.selectedOptionIds('s'), ['cuisson-saignant']);
    });

    test('une option disparue du catalogue est écartée du rejeu', () async {
      await service.startCustomization(
        's',
        'burger',
        'Burger Poulet',
        optionsInitiales: const ['cuisson-saignant', 'option-supprimee'],
      );

      expect(service.selectedOptionIds('s'), ['cuisson-saignant']);
    });

    test('le rejeu remplace les choix par défaut du catalogue', () async {
      service.seedOptionsForTest('plat', [
        CustomizationOption(
          id: 'taille-standard',
          name: 'Standard',
          category: 'Taille',
          isDefault: true,
          isRequired: true,
          minSelections: 1,
          isRemote: true,
        ),
        CustomizationOption(
          id: 'taille-xl',
          name: 'XL',
          category: 'Taille',
          priceModifier: 1000,
          isRequired: true,
          minSelections: 1,
          isRemote: true,
        ),
      ]);

      await service.startCustomization(
        'r',
        'plat',
        'Plat',
        optionsInitiales: const ['taille-xl'],
      );

      // Superposer la présélection du catalogue rendrait deux choix dans un
      // groupe qui n'en accepte qu'un — refusé par le serveur.
      expect(service.selectedOptionIds('r'), ['taille-xl']);
      expect(service.calculatePriceModifier('r'), 1000);
    });
  });

  group('Enregistrer une personnalisation modifiée', () {
    late CartService panier;

    setUp(() {
      panier = CartService();
      panier.clear();
    });

    test('les identifiants, le supplément et la quantité partent ensemble', () {
      panier.addItem(
        burgerDuCatalogue(),
        customizations: {'Suppléments': 'Fromage'},
        optionIds: const ['supp-fromage'],
        optionsSupplement: 500,
      );

      panier.updateItemCustomizations(
        0,
        customizations: {'Suppléments': 'Bacon'},
        optionIds: const ['supp-bacon'],
        optionsSupplement: 1000,
        quantity: 2,
      );

      final ligne = panier.items.single;
      // Les trois faces de la ligne racontaient trois choses différentes : la
      // méthode n'écrivait que les libellés.
      expect(ligne.customizations, {'Suppléments': 'Bacon'});
      expect(ligne.selectedOptionIds, ['supp-bacon']);
      expect(ligne.supplementOptions, 1000);
      expect(ligne.quantity, 2);
      expect(ligne.prixUnitaire, 5000);
      expect(ligne.totalPrice, 10000);
    });

    test('ce qui n’est pas transmis reste en place', () {
      panier.addItem(
        burgerDuCatalogue(),
        customizations: {'Suppléments': 'Fromage'},
        optionIds: const ['supp-fromage'],
        optionsSupplement: 500,
        quantity: 3,
      );

      panier.updateItemCustomizations(0, quantity: 1);

      expect(panier.items.single.selectedOptionIds, ['supp-fromage']);
      expect(panier.items.single.supplementOptions, 500);
      expect(panier.items.single.quantity, 1);
    });

    test('deux lignes devenues identiques fusionnent', () {
      panier
        ..addItem(
          burgerDuCatalogue(),
          customizations: {'Suppléments': 'Fromage'},
          optionIds: const ['supp-fromage'],
          optionsSupplement: 500,
        )
        ..addItem(
          burgerDuCatalogue(),
          customizations: {'Suppléments': 'Bacon'},
          optionIds: const ['supp-bacon'],
          optionsSupplement: 1000,
        );
      expect(panier.items.length, 2);

      panier.updateItemCustomizations(
        1,
        customizations: {'Suppléments': 'Fromage'},
        optionIds: const ['supp-fromage'],
        optionsSupplement: 500,
      );

      expect(panier.items.length, 1);
      expect(panier.items.single.quantity, 2);
      expect(panier.items.single.selectedOptionIds, ['supp-fromage']);
    });

    test('deux personnalisations différentes restent deux lignes', () {
      panier
        ..addItem(
          burgerDuCatalogue(),
          customizations: {'Suppléments': 'Fromage'},
          optionIds: const ['supp-fromage'],
          optionsSupplement: 500,
        )
        ..addItem(
          burgerDuCatalogue(),
          customizations: {'Suppléments': 'Bacon'},
          optionIds: const ['supp-bacon'],
          optionsSupplement: 1000,
        );

      panier.updateItemCustomizations(
        1,
        customizations: {'Suppléments': 'Bacon, Œuf'},
        optionIds: const ['supp-bacon', 'supp-oeuf'],
        optionsSupplement: 1500,
      );

      expect(panier.items.length, 2);
      expect(panier.items[0].totalPrice, 4500);
      expect(panier.items[1].totalPrice, 5500);
    });

    test('réenregistrer sans rien changer ne double pas la quantité', () {
      panier.addItem(
        burgerDuCatalogue(),
        customizations: {'Suppléments': 'Fromage'},
        optionIds: const ['supp-fromage'],
        optionsSupplement: 500,
      );

      panier.updateItemCustomizations(
        0,
        customizations: {'Suppléments': 'Fromage'},
        optionIds: const ['supp-fromage'],
        optionsSupplement: 500,
      );

      expect(panier.items.length, 1);
      expect(panier.items.single.quantity, 1);
    });

    test('un index hors du panier ne modifie rien', () {
      panier.addItem(burgerDuCatalogue());

      panier.updateItemCustomizations(7, optionIds: const ['supp-bacon']);

      expect(panier.items.single.selectedOptionIds, isEmpty);
    });

    test('la ligne se retrouve par son identifiant, pas par sa position', () {
      panier
        ..addItem(burgerDuCatalogue(), optionIds: const ['supp-fromage'])
        ..addItem(burgerDuCatalogue(), optionIds: const ['supp-bacon']);

      final seconde = panier.items[1];

      // L'écran de personnalisation se superpose au panier : entre son
      // ouverture et son enregistrement, une synchronisation a pu réordonner
      // les lignes, et l'index relevé à l'ouverture désignerait la voisine.
      expect(panier.indexOfCartItem(seconde.id), 1);
      expect(panier.indexOfCartItem('ligne-inconnue'), -1);
    });
  });

  group('Quelles lignes le panier propose de modifier', () {
    test('une ligne du catalogue est modifiable, même sans option retenue', () {
      final ligne = CartItem(
        id: 'l1',
        menuItemId: 'burger',
        name: 'Burger Poulet',
        price: 4000,
        quantity: 1,
      );

      // C'est précisément par là qu'on ajoute le fromage oublié à l'ajout.
      expect(ligne.personnalisable, isTrue);
    });

    test('une composition libre ne l’est pas', () {
      final gateau = CartItem(
        id: 'l2',
        menuItemId: 'gateau',
        name: 'Gâteau',
        price: 15000,
        quantity: 1,
        customizations: const {'Livraison': 'Samedi à 14h', 'Type': 'Prêt'},
        compositionLibre: true,
      );

      // Le configurateur générique recompose les libellés à partir des seuls
      // groupes du catalogue : il effacerait le créneau en enregistrant.
      expect(gateau.personnalisable, isFalse);
    });

    test('le drapeau survit à un aller-retour de stockage', () {
      final gateau = CartItem(
        id: 'l3',
        menuItemId: 'gateau',
        name: 'Gâteau',
        price: 15000,
        quantity: 1,
        compositionLibre: true,
      );

      expect(CartItem.fromMap(gateau.toMap()).compositionLibre, isTrue);
    });

    test('un panier écrit avant le drapeau se relit comme modifiable', () {
      final ancien = {
        'id': 'l4',
        'menu_item_id': 'burger',
        'name': 'Burger',
        'price': 4000,
        'quantity': 1,
      };

      expect(CartItem.fromMap(ancien).compositionLibre, isFalse);
    });
  });
}
