import 'package:admin/presentation/statut_commande.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le vocabulaire des statuts de commande du back-office.
///
/// Ces cas gardent la traduction entre ce que rend le serveur et ce que lit
/// l'opérateur. Ils sont écrits **avant** de retirer `models/order.dart` : ce
/// qu'ils épinglent devra tenir à l'identique après.
void main() {
  group('Les huit statuts du serveur', () {
    test('chacun a sa contrepartie, et l’aller-retour est fidèle', () {
      for (final valeur in [
        'pending',
        'confirmed',
        'preparing',
        'ready',
        'picked_up',
        'on_the_way',
        'delivered',
        'cancelled',
      ]) {
        expect(
          StatutCommande.depuisServeur(valeur).versServeur,
          valeur,
          reason: 'le statut « $valeur » doit revenir tel quel',
        );
      }
    });

    test('il y en a huit, pas dix', () {
      // `models/order.dart` en déclarait dix : `refunded` et `failed`
      // n'existent pas côté serveur et étaient tous deux renvoyés en
      // `cancelled`.
      expect(StatutCommande.values, hasLength(8));
      expect(
        StatutCommande.values.map((s) => s.versServeur),
        isNot(anyElement(anyOf('refunded', 'failed'))),
      );
    });

    test('un statut inconnu retombe sur « en attente »', () {
      // Plutôt que de faire disparaître la commande d'un écran de supervision.
      expect(
        StatutCommande.depuisServeur('quelque_chose_de_neuf'),
        StatutCommande.enAttente,
      );
    });
  });

  group('Les libellés', () {
    test('sont ceux que l’opérateur lisait déjà', () {
      expect(StatutCommande.enAttente.libelle, 'En attente');
      expect(StatutCommande.enPreparation.libelle, 'En préparation');
      expect(StatutCommande.recuperee.libelle, 'Récupérée');
      expect(StatutCommande.enRoute.libelle, 'En route');
      expect(StatutCommande.annulee.libelle, 'Annulée');
    });

    test('chaque statut a une illustration distincte', () {
      // Deux étapes qui partageraient la même illustration seraient
      // indiscernables dans la liste de supervision, où l'opérateur balaie
      // les vignettes avant de lire les libellés.
      //
      // La pastille Unicode que ce cas éprouvait est devenue un token du pack
      // partagé (`elcorazon_core`) : le back-office, le client et le livreur
      // montrent désormais la même image pour la même étape.
      final illustrations =
          StatutCommande.values.map((s) => s.illustration).toSet();
      expect(illustrations, hasLength(StatutCommande.values.length));
    });
  });

  group('Ce que l’écran demande d’un statut', () {
    test('une commande est en cours jusqu’à sa livraison ou son annulation', () {
      expect(StatutCommande.enRoute.estEnCours, isTrue);
      expect(StatutCommande.livree.estEnCours, isFalse);
      expect(StatutCommande.annulee.estEnCours, isFalse);
    });

    test('terminée est l’exact contraire d’en cours', () {
      for (final statut in StatutCommande.values) {
        expect(statut.estTerminee, isNot(statut.estEnCours));
      }
    });

    test('seuls trois états se laissent encore modifier', () {
      final modifiables = StatutCommande.values
          .where((s) => s.peutEtreModifiee)
          .map((s) => s.versServeur)
          .toList();

      expect(modifiables, ['pending', 'confirmed', 'preparing']);
    });
  });

  group('Le rang dans le cycle de vie', () {
    test('suit l’ordre du service', () {
      expect(StatutCommande.enAttente.rang, lessThan(StatutCommande.prete.rang!));
      expect(StatutCommande.prete.rang, lessThan(StatutCommande.livree.rang!));
    });

    test('une annulation n’a pas de rang', () {
      // L'ancienne énumération la classait après `delivered`, ce qui faisait
      // passer une commande annulée pour une commande partie en livraison.
      expect(StatutCommande.annulee.rang, isNull);
    });
  });
}
