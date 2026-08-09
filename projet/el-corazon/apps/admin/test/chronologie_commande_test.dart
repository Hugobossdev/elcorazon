import 'package:admin/presentation/chronologie_commande.dart';
import 'package:admin/presentation/statut_commande.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aide_commande.dart';

/// L'« Historique de la commande » du back-office.
///
/// Ces cas remplacent ceux qui épinglaient un historique **fabriqué** —
/// l'heure de commande plus 5, 10, 25, 30 puis 45 minutes. Le socle lit
/// désormais le journal des transitions du serveur, et ce qui est affiché
/// vient de là ou n'est pas affiché.
void main() {
  final passeeLe = DateTime(2026, 8, 8, 12);

  group('Les étapes du service', () {
    test('il y en a sept, dans l’ordre du cycle de vie', () {
      expect(
        chronologieDe(commandeDeTest()).map((e) => e.libelle).toList(),
        [
          'En attente',
          'Confirmée',
          'En préparation',
          'Prête',
          'Récupérée',
          'En route',
          'Livrée',
        ],
      );
    });

    test('l’annulation n’en fait pas partie', () {
      // Elle interrompt la suite, elle ne la prolonge pas.
      expect(
        chronologieDe(commandeDeTest(statut: 'cancelled'))
            .map((e) => e.statut),
        isNot(contains(StatutCommande.annulee)),
      );
    });
  });

  group('Ce qui est franchi', () {
    List<bool> franchies(String statut) =>
        chronologieDe(commandeDeTest(statut: statut))
            .map((e) => e.franchie)
            .toList();

    test('une commande en attente n’a franchi que la première étape', () {
      expect(franchies('pending'),
          [true, false, false, false, false, false, false],);
    });

    test('une commande en préparation en a franchi trois', () {
      expect(franchies('preparing'),
          [true, true, true, false, false, false, false],);
    });

    test('seule une commande livrée franchit la dernière étape', () {
      expect(franchies('delivered').last, isTrue);
      expect(franchies('on_the_way').last, isFalse);
    });

    test('une commande annulée n’a franchi aucune étape du service', () {
      // Le rang se lisait sur `status.index`, et `cancelled` était déclaré
      // après `delivered` : une commande annulée paraissait avoir été mise en
      // livraison. `StatutCommande.rang` rend `null` pour une annulation.
      expect(franchies('cancelled'), everyElement(isFalse));
    });
  });

  group('Les heures viennent du journal du serveur', () {
    test('chaque transition donne l’heure de son étape', () {
      final commande = commandeDeTest(
        statut: 'ready',
        passeeLe: passeeLe,
        transitions: [
          transitionJson('confirmed', DateTime(2026, 8, 8, 12, 3)),
          transitionJson('preparing', DateTime(2026, 8, 8, 12, 11)),
          transitionJson('ready', DateTime(2026, 8, 8, 12, 34)),
        ],
      );

      final quand = {
        for (final etape in chronologieDe(commande)) etape.libelle: etape.quand,
      };

      expect(quand['Confirmée'], DateTime(2026, 8, 8, 12, 3));
      expect(quand['En préparation'], DateTime(2026, 8, 8, 12, 11));
      expect(quand['Prête'], DateTime(2026, 8, 8, 12, 34));
    });

    test('« en attente » retombe sur l’heure de commande', () {
      // Une commande naît en attente, sans venir d'ailleurs : le journal n'a
      // pas toujours de transition pour cette première étape.
      expect(
        chronologieDe(commandeDeTest(passeeLe: passeeLe)).first.quand,
        passeeLe,
      );
    });

    test('une étape sans transition n’a pas d’heure', () {
      // Sur la forme liste, le serveur ne rend pas le journal. L'écran affiche
      // alors l'étape sans heure — il n'en invente plus.
      final etapes = chronologieDe(commandeDeTest(statut: 'delivered'));

      expect(etapes.first.quand, isNotNull);
      expect(etapes.skip(1).map((e) => e.quand), everyElement(isNull));
    });

    test('deux commandes de statuts différents n’ont plus la même heure', () {
      // La preuve que rien n'est déduit : autrefois, une commande en attente
      // affichait la même heure de « livrée » qu'une commande livrée.
      final livree = commandeDeTest(
        statut: 'delivered',
        passeeLe: passeeLe,
        transitions: [transitionJson('delivered', DateTime(2026, 8, 8, 12, 52))],
      );
      final enAttente = commandeDeTest(passeeLe: passeeLe);

      expect(chronologieDe(livree).last.quand, DateTime(2026, 8, 8, 12, 52));
      expect(chronologieDe(enAttente).last.quand, isNull);
    });
  });

  group('L’annulation', () {
    test('n’est rendue que pour une commande annulée', () {
      expect(annulationDe(commandeDeTest()), isNull);
      expect(annulationDe(commandeDeTest(statut: 'cancelled')), isNotNull);
    });

    test('porte l’heure de sa transition', () {
      final annulee = commandeDeTest(
        statut: 'cancelled',
        transitions: [transitionJson('cancelled', DateTime(2026, 8, 8, 12, 8))],
      );

      expect(annulationDe(annulee)!.quand, DateTime(2026, 8, 8, 12, 8));
    });
  });
}
