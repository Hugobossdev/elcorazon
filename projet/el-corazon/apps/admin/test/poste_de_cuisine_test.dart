// Chaque test de ce fichier range une commande dans une colonne du poste, et
// nomme donc son statut — `preparing` compris, même quand c'est la valeur par
// défaut de `commandeDeTest`. Le taire ferait lire « une commande » là où le test
// regarde « une commande en préparation ». Le décor étant partagé avec d'autres
// suites qui s'appuient sur ce défaut, c'est ici que la règle se lève, et non là.
// ignore_for_file: avoid_redundant_argument_values
import 'package:admin/presentation/poste_de_cuisine.dart';
import 'package:admin/presentation/statut_commande.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aide_commande.dart';

/// Le poste de cuisine — les trois règles qui décident de tout ce qu'il montre.
///
/// El Corazón est une cuisine en ligne, et la cuisine n'avait pas d'outil : le
/// personnel faisait avancer les commandes depuis l'écran d'administration, ses
/// filtres, ses exports et ses statistiques. On y pilote une flotte ; on n'y
/// tient pas un coup de feu.
///
/// Ces tests portent la logique, pas les pixels : dans quelle colonne tombe une
/// commande, laquelle passe avant, laquelle est en retard. Écrites dans un
/// `build`, ces règles ne se vérifieraient qu'en montant un widget et en lisant
/// des couleurs — c'est précisément pour cela que `ancienneteCommande` avait
/// déjà été extraite d'un écran.
void main() {
  final midi = DateTime(2026, 9, 10, 12);

  group('Répartition en colonnes', () {
    test('chaque statut de cuisine tombe dans sa colonne', () {
      expect(ColonneCuisine.pour(StatutCommande.confirmee), ColonneCuisine.confirmees);
      expect(ColonneCuisine.pour(StatutCommande.enPreparation), ColonneCuisine.preparation);
      expect(ColonneCuisine.pour(StatutCommande.prete), ColonneCuisine.pretes);
    });

    test('tout ce qui a quitté la cuisine se regroupe', () {
      // Ce que devient le repas après la remise regarde la livraison, pas le
      // cuisinier : trois colonnes de plus n'apprendraient rien au poste.
      for (final statut in [
        StatutCommande.recuperee,
        StatutCommande.enRoute,
        StatutCommande.livree,
      ]) {
        expect(ColonneCuisine.pour(statut), ColonneCuisine.remises);
      }
    });

    test('une commande non confirmée n\'entre pas au poste', () {
      // Le paiement n'est pas encaissé : la préparer serait travailler pour
      // rien.
      expect(ColonneCuisine.pour(StatutCommande.enAttente), isNull);
    });

    test('une commande annulée disparaît de l\'écran', () {
      // La laisser ferait préparer un repas que personne ne viendra chercher.
      expect(ColonneCuisine.pour(StatutCommande.annulee), isNull);

      final poste = composerLePoste(
        [commandeDeTest(statut: 'cancelled', passeeLe: midi)],
        minutesDePreparation: 20,
        maintenant: midi,
      );

      expect(poste.values.expand((f) => f), isEmpty);
    });
  });

  group('Tri par ancienneté', () {
    test('la plus ancienne passe en tête', () {
      // La seule priorité qui tienne en cuisine. Toute autre règle — les
      // grosses commandes d'abord, les proches d'abord — produit des commandes
      // oubliées au fond de la file.
      final poste = composerLePoste(
        [
          commandeDeTest(id: 'recente', statut: 'preparing', passeeLe: midi),
          commandeDeTest(
            id: 'ancienne',
            statut: 'preparing',
            passeeLe: midi.subtract(const Duration(minutes: 30)),
          ),
          commandeDeTest(
            id: 'moyenne',
            statut: 'preparing',
            passeeLe: midi.subtract(const Duration(minutes: 10)),
          ),
        ],
        minutesDePreparation: 60,
        maintenant: midi,
      );

      expect(
        poste[ColonneCuisine.preparation]!.map((c) => c.commande.id),
        ['ancienne', 'moyenne', 'recente'],
      );
    });

    test('le tri s\'applique colonne par colonne', () {
      final poste = composerLePoste(
        [
          commandeDeTest(id: 'p-recente', statut: 'preparing', passeeLe: midi),
          commandeDeTest(
            id: 'c-ancienne',
            statut: 'confirmed',
            passeeLe: midi.subtract(const Duration(hours: 2)),
          ),
        ],
        minutesDePreparation: 60,
        maintenant: midi,
      );

      expect(poste[ColonneCuisine.confirmees]!.single.commande.id, 'c-ancienne');
      expect(poste[ColonneCuisine.preparation]!.single.commande.id, 'p-recente');
    });
  });

  group('Retard', () {
    test('au-delà du délai déclaré, la commande est en retard', () {
      final poste = composerLePoste(
        [
          commandeDeTest(
            statut: 'preparing',
            passeeLe: midi.subtract(const Duration(minutes: 25)),
          ),
        ],
        minutesDePreparation: 20,
        maintenant: midi,
      );

      expect(poste[ColonneCuisine.preparation]!.single.enRetard, isTrue);
    });

    test('en deçà, elle ne l\'est pas', () {
      final poste = composerLePoste(
        [
          commandeDeTest(
            statut: 'preparing',
            passeeLe: midi.subtract(const Duration(minutes: 5)),
          ),
        ],
        minutesDePreparation: 20,
        maintenant: midi,
      );

      expect(poste[ColonneCuisine.preparation]!.single.enRetard, isFalse);
    });

    test('une commande remise n\'est plus en retard', () {
      // La cuisine a fini son travail. La peindre en rouge indéfiniment
      // noierait celles qui attendent encore quelque chose.
      final poste = composerLePoste(
        [
          commandeDeTest(
            statut: 'picked_up',
            passeeLe: midi.subtract(const Duration(hours: 3)),
          ),
        ],
        minutesDePreparation: 20,
        maintenant: midi,
      );

      expect(poste[ColonneCuisine.remises]!.single.enRetard, isFalse);
    });

    test('un établissement sans délai déclaré retombe sur un quart d\'heure', () {
      // Zéro minute rendrait toute commande en retard dès la seconde suivante,
      // et le signal ne voudrait plus rien dire.
      expect(delaiDePreparation(0), const Duration(minutes: 15));
      expect(delaiDePreparation(25), const Duration(minutes: 25));
    });
  });

  group('Étape suivante', () {
    test('elle vient du serveur, jamais d\'une table locale', () {
      // `allowed_transitions` est calculé par la machine à états côté serveur.
      // La recomposer ici est le défaut que `Course` a déjà corrigé dans Dely :
      // trois écrans, trois `switch`, trois trous différents.
      final poste = composerLePoste(
        [
          commandeDeTest(
            statut: 'confirmed',
            passeeLe: midi,
            transitionsAutorisees: const ['preparing', 'cancelled'],
          ),
        ],
        minutesDePreparation: 20,
        maintenant: midi,
      );

      expect(
        poste[ColonneCuisine.confirmees]!.single.etapeSuivante,
        StatutCommande.enPreparation,
      );
    });

    test('une transition illégale ne devient jamais un bouton', () {
      // Le serveur n'autorise que `cancelled` : proposer « Prête » ferait
      // presser un bouton qui ne peut que revenir en erreur.
      final poste = composerLePoste(
        [
          commandeDeTest(
            statut: 'confirmed',
            passeeLe: midi,
            transitionsAutorisees: const ['cancelled'],
          ),
        ],
        minutesDePreparation: 20,
        maintenant: midi,
      );

      expect(poste[ColonneCuisine.confirmees]!.single.etapeSuivante, isNull);
    });

    test('l\'annulation ne tombe jamais sous le bouton « suivant »', () {
      // Elle a son propre geste, avec sa confirmation et son motif. Sous un
      // bouton qu'on presse à la chaîne, elle finirait pressée par erreur.
      final poste = composerLePoste(
        [
          commandeDeTest(
            statut: 'preparing',
            passeeLe: midi,
            transitionsAutorisees: const ['cancelled', 'ready'],
          ),
        ],
        minutesDePreparation: 20,
        maintenant: midi,
      );

      expect(poste[ColonneCuisine.preparation]!.single.etapeSuivante, StatutCommande.prete);
    });

    test('une commande terminale ne propose rien', () {
      final poste = composerLePoste(
        [commandeDeTest(statut: 'delivered', passeeLe: midi)],
        minutesDePreparation: 20,
        maintenant: midi,
      );

      expect(poste[ColonneCuisine.remises]!.single.etapeSuivante, isNull);
    });
  });

  group('Le poste dans son ensemble', () {
    test('les quatre colonnes existent toujours, même vides', () {
      // Une colonne qui disparaît quand elle se vide fait sauter la mise en
      // page sous les yeux du cuisinier, en plein service.
      final poste = composerLePoste(const [], minutesDePreparation: 20, maintenant: midi);

      expect(poste.keys, ColonneCuisine.values);
      expect(poste.values.every((f) => f.isEmpty), isTrue);
    });

    test('une nouvelle commande apparaît dans sa colonne', () {
      final poste = composerLePoste(
        [commandeDeTest(id: 'neuve', statut: 'confirmed', passeeLe: midi)],
        minutesDePreparation: 20,
        maintenant: midi,
      );

      expect(poste[ColonneCuisine.confirmees]!.single.commande.id, 'neuve');
      expect(poste[ColonneCuisine.preparation], isEmpty);
    });
  });
}
