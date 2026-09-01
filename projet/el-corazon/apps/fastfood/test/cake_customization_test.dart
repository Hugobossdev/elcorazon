import 'package:elcora_fast/services/customization_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gâteau sur mesure — ce que l'application a le droit d'envoyer au serveur.
///
/// La composition d'un gâteau est la personnalisation la plus lourde du
/// catalogue : une dizaine de groupes, dont plusieurs obligatoires. Deux
/// règles la tiennent, et ce sont elles que ces tests protègent.
///
/// 1. **Seuls des identifiants du catalogue partent au panier.** Les options
///    de démonstration (`cake-shape-round`) n'existent pas côté serveur ;
///    `POST /carts/{slug}/lines/` les refuse, et le refus emportait la ligne.
/// 2. **La règle de choix vient du groupe**, pas d'une table locale : c'est
///    `OptionGroup.min_select`/`max_select` que `validate_selection` revalide
///    côté Django. La table locale était indexée par des étiquettes (`shape`)
///    que le serveur n'emploie pas — plus rien n'y était requis ni plafonné.
void main() {
  late CustomizationService service;

  /// Options telles que le détail d'un article les rend : identifiants réels,
  /// catégorie = nom du groupe, bornes portées par le groupe.
  List<CustomizationOption> optionsDuCatalogue() {
    return [
      CustomizationOption(
        id: '11111111-1111-1111-1111-111111111111',
        name: 'Rond',
        category: 'Forme',
        isDefault: true,
        isRequired: true,
        minSelections: 1,
        isRemote: true,
      ),
      CustomizationOption(
        id: '22222222-2222-2222-2222-222222222222',
        name: 'Cœur',
        category: 'Forme',
        priceModifier: 3500,
        isRequired: true,
        minSelections: 1,
        isRemote: true,
      ),
      CustomizationOption(
        id: '33333333-3333-3333-3333-333333333333',
        name: 'Fruits frais',
        category: 'Décoration',
        priceModifier: 2000,
        maxQuantity: 2,
        isRemote: true,
      ),
      CustomizationOption(
        id: '44444444-4444-4444-4444-444444444444',
        name: 'Macarons',
        category: 'Décoration',
        priceModifier: 3000,
        maxQuantity: 2,
        isRemote: true,
      ),
    ];
  }

  setUp(() async {
    service = CustomizationService();
    service.resetForTest();
    await service.initialize();
  });

  group('Options du catalogue', () {
    setUp(() {
      service.seedOptionsForTest('gateau-distant', optionsDuCatalogue());
    });

    test('la contrainte vient du groupe, pas de la table locale', () {
      final forme = service.constraintFor('gateau-distant', 'Forme');

      // « Forme » n'existe pas dans la table locale, indexée par `shape` :
      // sans lecture du groupe, la catégorie ressortait libre et sans plafond.
      expect(forme.isRequired, isTrue);
      expect(forme.isSingleChoice, isTrue);
      expect(forme.minSelections, 1);
    });

    test('un groupe à deux choix reste un choix multiple plafonné', () {
      final deco = service.constraintFor('gateau-distant', 'Décoration');

      expect(deco.isSingleChoice, isFalse);
      expect(deco.maxSelections, 2);
    });

    test('les identifiants retenus sont ceux du catalogue', () async {
      await service.startCustomization('session-1', 'gateau-distant', 'Gâteau personnalisé');
      service.updateSelection(
        'session-1',
        'Décoration',
        '33333333-3333-3333-3333-333333333333',
        true,
      );

      // Le rond est sélectionné par défaut, les fruits frais viennent d'être
      // ajoutés — triés, pour que deux compositions équivalentes produisent
      // la même ligne (`CartService._identical_line` côté serveur).
      expect(service.selectedOptionIds('session-1'), [
        '11111111-1111-1111-1111-111111111111',
        '33333333-3333-3333-3333-333333333333',
      ]);
    });

    test('un groupe obligatoire vide est refusé avant le panier', () async {
      await service.startCustomization('session-2', 'gateau-distant', 'Gâteau personnalisé');
      service.updateSelection(
        'session-2',
        'Forme',
        '11111111-1111-1111-1111-111111111111',
        false,
      );

      final validation = service.validateCustomization('session-2');

      expect(validation['isValid'], isFalse);
      expect((validation['errors'] as List).join(), contains('Forme'));
    });

    test('dépasser le plafond d’un groupe est refusé avant le panier', () async {
      await service.startCustomization('session-3', 'gateau-distant', 'Gâteau personnalisé');
      for (final id in [
        '33333333-3333-3333-3333-333333333333',
        '44444444-4444-4444-4444-444444444444',
      ]) {
        service.updateSelection('session-3', 'Décoration', id, true);
      }
      // Une troisième décoration : le groupe n'en accepte que deux.
      service.updateSelection('session-3', 'Décoration', 'de-trop', true);

      final validation = service.validateCustomization('session-3');

      expect(validation['isValid'], isFalse);
    });
  });

  group('Aucune option n’est fabriquée', () {
    /// C'est la garantie que ce nettoyage installe, et l'ancienne version
    /// faisait exactement l'inverse.
    ///
    /// Une table de démonstration de cinq cents lignes vivait dans
    /// `customization_service.dart` : des burgers, des pizzas et un gâteau,
    /// appariés à un article **par son nom** — nom exact, puis `contains` dans
    /// les deux sens. Un article du catalogue nommé « Burger Classique », ou
    /// seulement « Burger », héritait donc de « Fromage supplémentaire
    /// +1.5 » : des euros, affichés en francs CFA par un formateur qui n'avait
    /// aucun moyen de savoir. Et aucun de ces identifiants n'existant côté
    /// serveur, la ligne partait ensuite sans la moindre option.
    test('un article inconnu n’a aucune option', () {
      expect(service.getOptionsForMenuItem('article-jamais-lu'), isEmpty);
      expect(service.getOptionsByCategory('article-jamais-lu'), isEmpty);
      expect(service.hasRemoteOptions('article-jamais-lu'), isFalse);
    });

    test('un nom qui évoque la démonstration n’en réveille aucune', () {
      // Les noms qui déclenchaient l'appariement, un par un.
      for (final nom in [
        'Burger Classique',
        'burger',
        'Pizza Pepperoni',
        'Gâteau personnalisé',
      ]) {
        expect(
          service.getOptionsForMenuItem(nom),
          isEmpty,
          reason: '« $nom » ne doit plus réveiller d’options fictives',
        );
      }
    });

    test('aucune sélection par défaut n’apparaît sur un article inconnu',
        () async {
      // La maquette se pré-sélectionnait toute seule : l'écran s'ouvrait sur
      // une composition déjà faite, dont le client héritait sans l'avoir
      // choisie.
      await service.startCustomization(
        'session-inconnue',
        'article-jamais-lu',
        'Burger Classique',
      );

      expect(
        service.getCurrentCustomization('session-inconnue')!.selections,
        isEmpty,
      );
      expect(service.selectedOptionIds('session-inconnue'), isEmpty);
      expect(service.calculatePriceModifier('session-inconnue'), 0);
    });

    test('un article inconnu n’impose aucune contrainte inventée', () {
      // La table locale répondait « requis, choix unique » pour `shape` ou
      // `size` sur n'importe quel article, y compris ceux du catalogue.
      for (final categorie in ['shape', 'size', 'cooking', 'sauce']) {
        final contrainte = service.constraintFor('article-jamais-lu', categorie);
        expect(contrainte.isRequired, isFalse, reason: categorie);
        expect(contrainte.minSelections, 0, reason: categorie);
      }
    });

    test('le raccourci d’ajout ne se déclenche pas sur un article inconnu',
        () async {
      // `exigeUnChoix` détournait vers l'écran de personnalisation les
      // articles que la maquette prétendait obligatoires.
      expect(await service.exigeUnChoix('article-jamais-lu'), isFalse);
    });
  });

  group('États de lecture', () {
    test('un article jamais lu est à demander, pas vide', () {
      expect(
        service.etatDesOptions('article-jamais-lu'),
        EtatDesOptions.aDemander,
      );
      expect(service.erreurDesOptions('article-jamais-lu'), isNull);
    });

    test('un article lu avec options le dit', () {
      service.seedOptionsForTest('gateau-distant', optionsDuCatalogue());

      expect(
        service.etatDesOptions('gateau-distant'),
        EtatDesOptions.avecOptions,
      );
    });

    test('un article lu sans option le dit aussi', () {
      // Le serveur a répondu : cet article n'a rien à personnaliser. C'est une
      // réponse, et elle ne doit pas se confondre avec « pas encore lu ».
      service.seedOptionsForTest('plat-nu', const []);

      expect(service.etatDesOptions('plat-nu'), EtatDesOptions.sansOption);
      expect(service.getOptionsForMenuItem('plat-nu'), isEmpty);
    });
  });
}
