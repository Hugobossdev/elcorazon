import 'package:elcora_fast/presentation/preselection_gateau.dart';
import 'package:elcora_fast/services/customization_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// La pré-sélection d'options quand un client part d'un gâteau du catalogue
/// pour composer le sien.
///
/// La devinette vivait dans une méthode de `cake_order_screen.dart` qui, du
/// même geste, lisait le service, décidait, écrivait et affichait un bandeau.
CustomizationOption _option(String id, String nom, {String categorie = 'flavor'}) =>
    CustomizationOption(id: id, name: nom, category: categorie);

void main() {
  final parfums = [
    _option('cake-flavor-chocolate', 'Chocolat'),
    _option('cake-flavor-vanilla', 'Vanille'),
    _option('cake-flavor-strawberry', 'Fraise'),
  ];
  final formes = [
    _option('cake-shape-round', 'Rond', categorie: 'shape'),
    _option('cake-shape-heart', 'Cœur', categorie: 'shape'),
    _option('cake-shape-square', 'Carré', categorie: 'shape'),
  ];

  List<String> suggerees(String texte, List<CustomizationOption> options) =>
      optionsSuggereesPar(texte, options).map((o) => o.id).toList();

  group('Par le nom de l’option', () {
    test('« Gâteau chocolat » suggère le chocolat', () {
      expect(suggerees('Gâteau chocolat', parfums), ['cake-flavor-chocolate']);
    });

    test('la casse ne compte pas', () {
      expect(suggerees('GÂTEAU VANILLE', parfums), ['cake-flavor-vanilla']);
    });

    test('le nom peut être au milieu d’une phrase', () {
      expect(
        suggerees('Notre fraise du moment, génoise légère', parfums),
        ['cake-flavor-strawberry'],
      );
    });
  });

  group('Par mot-clé et identifiant', () {
    test('« cœur » et « coeur » désignent la même forme', () {
      expect(suggerees('Gâteau en forme de cœur', formes),
          ['cake-shape-heart'],);
      expect(suggerees('Gateau en forme de coeur', formes),
          ['cake-shape-heart'],);
    });

    test('le mot-clé seul ne suffit pas : l’identifiant doit suivre', () {
      // « rond » est un mot connu, mais aucune option de parfum ne porte
      // « round » dans son identifiant.
      expect(suggerees('Gâteau rond', parfums), isEmpty);
    });
  });

  group('Ce qui ne correspond à rien', () {
    test('un texte sans rapport ne suggère rien', () {
      expect(suggerees('Pièce montée traditionnelle', parfums), isEmpty);
    });

    test('une option sans nom ne coche pas tout', () {
      // Un nom vide est contenu dans n'importe quelle chaîne : sans garde, il
      // serait suggéré par tous les gâteaux.
      expect(suggerees('Pièce montée', [_option('cake-flavor-x', '')]), isEmpty);
    });

    test('une liste d’options vide rend une liste vide', () {
      expect(optionsSuggereesPar('Gâteau chocolat', const []), isEmpty);
    });
  });

  group('Plusieurs correspondances', () {
    test('un gâteau peut en suggérer plusieurs, dans l’ordre des options', () {
      expect(
        suggerees('Gâteau rond au chocolat', [...parfums, ...formes]),
        ['cake-flavor-chocolate', 'cake-shape-round'],
      );
    });

    test('« Fraisier » ne suggère pas « Fraise »', () {
      // La correspondance est une inclusion littérale : « fraisier » ne
      // contient pas « fraise ». Le nom de pâtisserie le plus courant en
      // français passe donc à côté de son propre parfum. C'est l'existant ;
      // le corriger demanderait une racinisation, donc une décision.
      expect(suggerees('Fraisier maison', parfums), isEmpty);
    });

    test('la description compte autant que le nom', () {
      // L'écran fournit « nom description » collés ; les deux sont fouillés.
      expect(
        suggerees('Le classique — un cœur de saison', formes),
        ['cake-shape-heart'],
      );
    });
  });
}
