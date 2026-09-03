import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/moyen_paiement.dart';
import 'package:admin/presentation/statut_commande.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aide_commande.dart';

/// Ce que le back-office lit d'une commande.
///
/// Ces cas remplacent `django_order_mapper_test.dart`, supprimé avec
/// l'adaptateur. Ils épinglent les **mêmes** attentes : ce que voit
/// l'opérateur ne devait pas changer parce qu'un modèle local disparaît.
///
/// S'y ajoute ce que la traduction perdait en route et qui arrive maintenant
/// jusqu'à l'écran : la référence lisible, les options choisies, l'annulation.
void main() {
  group('Les montants', () {
    test('passent en unité majeure pour l’affichage', () {
      final commande = commandeDeTest(totalCfa: 9500);

      expect(commande.totalAffiche, 9500);
      expect(commande.sousTotalAffiche, 9500);
      expect(commande.fraisLivraisonAffiches, 0);
      expect(commande.remiseAffichee, 0);
    });

    test('une ligne rend son prix unitaire et son total', () {
      final ligne = commandeDeTest(
        lignes: [ligneJson(prixUnitaireCfa: 4500)],
      ).lines.single;

      expect(ligne.prixUnitaireAffiche, 4500);
      expect(ligne.prixTotalAffiche, 9000);
      expect(ligne.quantity, 2);
    });
  });

  group('L’adresse', () {
    test('est rendue seule quand il n’y a pas de repère', () {
      expect(commandeDeTest().adresseComplete, 'Rue du Commerce');
    });

    test('reçoit le repère entre parenthèses', () {
      expect(
        commandeDeTest(repere: 'face à la pharmacie').adresseComplete,
        'Rue du Commerce (face à la pharmacie)',
      );
    });
  });

  group('Les consignes', () {
    test('vides ne deviennent pas une note vide', () {
      // Une chaîne vide sous un intitulé « Note » laisse croire qu'une note
      // existe et qu'elle ne dit rien.
      expect(commandeDeTest().consignes, isNull);
    });

    test('sont rendues telles quelles quand elles existent', () {
      expect(
        commandeDeTest(consignes: 'Sonner deux fois').consignes,
        'Sonner deux fois',
      );
    });
  });

  group('Le statut', () {
    test('chaque valeur du serveur a sa contrepartie', () {
      expect(
        commandeDeTest(statut: 'confirmed').statut,
        StatutCommande.confirmee,
      );
      expect(
        commandeDeTest(statut: 'picked_up').statut,
        StatutCommande.recuperee,
      );
      expect(
        commandeDeTest(statut: 'on_the_way').statut,
        StatutCommande.enRoute,
      );
      expect(
        commandeDeTest(statut: 'cancelled').statut,
        StatutCommande.annulee,
      );
    });

    test('une valeur inconnue retombe sur « en attente »', () {
      expect(
        commandeDeTest(statut: 'quelque_chose_de_neuf').statut,
        StatutCommande.enAttente,
      );
    });
  });

  group('Le moyen de paiement', () {
    test('chaque moyen connu est traduit', () {
      expect(
        commandeDeTest(moyenPaiement: 'cash').moyenPaiement,
        MoyenPaiement.especes,
      );
      expect(
        commandeDeTest(moyenPaiement: 'card').moyenPaiement,
        MoyenPaiement.carte,
      );
      expect(
        commandeDeTest(moyenPaiement: 'wallet').moyenPaiement,
        MoyenPaiement.portefeuille,
      );
    });

    test('un moyen inconnu passe pour du mobile money', () {
      expect(
        commandeDeTest(moyenPaiement: 'crypto-monnaie').moyenPaiement,
        MoyenPaiement.mobileMoney,
      );
    });

    test('seules les espèces ne sont pas déjà encaissées', () {
      expect(MoyenPaiement.especes.estPrepaye, isFalse);
      expect(MoyenPaiement.carte.estPrepaye, isTrue);
    });
  });

  group('Ce que la traduction locale perdait', () {
    test('la référence lisible arrive jusqu’à l’écran', () {
      // Le serveur rend `CMD-0001`, séquentielle et citable au téléphone.
      // `DjangoOrderMapper` la jetait, et 32 endroits fabriquaient un
      // identifiant en découpant l'UUID.
      expect(commandeDeTest(reference: 'CMD-0042').reference, 'CMD-0042');
    });

    test('les options choisies par le client sont lisibles', () {
      final ligne = commandeDeTest(
        lignes: [
          ligneJson(
            options: [
              {
                'group': 'Cuisson',
                'option': 'À point',
                'delta': 0,
                'currency': 'XOF',
              },
              {
                'group': 'extras',
                'option': 'Double fromage',
                'delta': 500,
                'currency': 'XOF',
              },
            ],
          ),
        ],
      ).lines.single;

      expect(ligne.personnalisations, [
        'Cuisson: À point',
        // Les identifiants techniques hérités gardent leur libellé français.
        'Suppléments: Double fromage',
      ]);
    });

    test('une ligne sans option ne montre rien', () {
      expect(
        commandeDeTest(lignes: [ligneJson()]).lines.single.personnalisations,
        isEmpty,
      );
    });

    test('la note d’un article distingue le vide de l’absence', () {
      expect(commandeDeTest(lignes: [ligneJson()]).lines.single.note, isNull);
      expect(
        commandeDeTest(lignes: [ligneJson(note: 'Bien épicé')]).lines.single.note,
        'Bien épicé',
      );
    });
  });

  group('Le livreur affecté', () {
    test('ne se lit pas sur la commande', () {
      // Ce groupe vérifiait que `commande.livreurAffecte` rendait `null`, en
      // annonçant qu'il tomberait « le jour où le serveur l'expose ». Le
      // serveur l'expose — non pas sur la commande, mais sur la course
      // (`/delivery/manage/assignments/`), parce qu'`apps.orders` ne dépend pas
      // d'`apps.delivery` (ADR-002).
      //
      // Le getter a donc été retiré plutôt que rempli : le laisser aurait
      // suggéré que la réponse est ici. Ce que ce test garde, c'est
      // l'affirmation utile — **rien dans le JSON d'une commande ne nomme un
      // livreur** — pour qu'un futur champ ajouté au sérialiseur de supervision
      // soit une décision et non une découverte.
      //
      // Le rapprochement commande → livreur est couvert par
      // `packages/elcorazon_core/test/managed_assignment_repository_test.dart`.
      final json = commandeJson();
      expect(
        json.keys.where(
          (cle) => cle.contains('courier') || cle.contains('delivery_person'),
        ),
        isEmpty,
      );
    });
  });

  group('La date affichée', () {
    test('est celle du passage de commande', () {
      final quand = DateTime(2026, 8, 8, 9, 58);
      expect(commandeDeTest(passeeLe: quand).passeeLe, quand);
    });
  });
}
