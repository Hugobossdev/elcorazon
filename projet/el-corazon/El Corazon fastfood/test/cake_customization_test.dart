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
    service.clearAllCustomizations();
    // Charge les options de démonstration, celles que le configurateur montre
    // tant que l'établissement n'a pas publié son gâteau au catalogue.
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

      final validation = service.validateCustomization('session-2', 'Gâteau personnalisé');

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

      final validation = service.validateCustomization('session-3', 'Gâteau personnalisé');

      expect(validation['isValid'], isFalse);
    });
  });

  group('Options de démonstration', () {
    test('aucun identifiant n’est envoyé au serveur', () async {
      // L'établissement n'a pas publié l'article : le configurateur reste une
      // vitrine. Envoyer `cake-shape-round` produirait un 400, et l'ancienne
      // version y perdait la ligne — puis le panier distant tout entier.
      await service.startCustomization(
        'session-locale',
        'gateau-en-memoire',
        'Gâteau personnalisé',
      );

      // La maquette est bien peuplée — et sélectionnée : c'est justement ce
      // qui rendait le piège invisible.
      expect(
        service.getOptionsForMenuItem(
          'gateau-en-memoire',
          fallbackName: 'Gâteau personnalisé',
        ),
        isNotEmpty,
      );
      expect(
        service.getCurrentCustomization('session-locale')!.selections,
        isNotEmpty,
      );

      expect(service.hasRemoteOptions('gateau-en-memoire'), isFalse);
      expect(service.selectedOptionIds('session-locale'), isEmpty);
    });

    test('la table locale garde sa règle pour la maquette', () {
      final forme = service.constraintFor('gateau-en-memoire', 'shape');

      expect(forme.isRequired, isTrue);
      expect(forme.isSingleChoice, isTrue);
    });
  });
}
