import 'package:admin/presentation/anciennete_commande.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'âge affiché d'une commande dans les listes du back-office.
///
/// Ces cas décrivent ce que l'écran montrait déjà ; ils sont écrits maintenant
/// parce que la règle vient seulement de devenir atteignable — elle lisait
/// l'horloge depuis le corps d'un widget.
void main() {
  final maintenant = DateTime(2026, 8, 8, 14, 30);

  String age(DateTime passeeLe) =>
      ancienneteCommande(passeeLe, maintenant: maintenant);

  group('Moins d’une heure : des minutes', () {
    test('à l’instant', () {
      expect(age(maintenant), '0min');
    });

    test('douze minutes', () {
      expect(age(maintenant.subtract(const Duration(minutes: 12))), '12min');
    });

    test('cinquante-neuf minutes restent des minutes', () {
      expect(age(maintenant.subtract(const Duration(minutes: 59))), '59min');
    });
  });

  group('Moins d’un jour : des heures', () {
    test('la soixantième minute bascule en heures', () {
      expect(age(maintenant.subtract(const Duration(minutes: 60))), '1h');
    });

    test('les heures sont tronquées, pas arrondies', () {
      // 2 h 59 reste « 2h » : l'écart affiché ne dépasse jamais le réel.
      expect(age(maintenant.subtract(const Duration(hours: 2, minutes: 59))),
          '2h',);
    });

    test('vingt-trois heures restent des heures', () {
      expect(age(maintenant.subtract(const Duration(hours: 23))), '23h');
    });
  });

  group('Au-delà : la date de la commande', () {
    test('la vingt-quatrième heure bascule en date', () {
      final passeeLe = maintenant.subtract(const Duration(hours: 24));
      expect(age(passeeLe), '7/8');
    });

    test('la date affichée est celle de la commande, pas l’écart', () {
      expect(age(DateTime(2026, 3, 4, 9)), '4/3');
    });

    test('les nombres ne sont pas complétés par un zéro', () {
      // `4/3` et non `04/03` : c'est ce que l'écran montre aujourd'hui.
      expect(age(DateTime(2026, 3, 4)), isNot(contains('0')));
    });
  });

  group('Une date à venir', () {
    test('donne un écart négatif plutôt qu’une erreur', () {
      // Le cas ne se produit pas sur une commande déjà passée, mais rien ne
      // l'interdit : autant savoir ce qui s'affiche.
      expect(age(maintenant.add(const Duration(minutes: 10))), '-10min');
    });
  });
}
