import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/presentation/suivi_commande.dart';
import 'package:flutter_test/flutter_test.dart';

/// La chronologie d'une commande — dix statuts repliés sur quatre jalons.
///
/// Ce repliement est la seule règle de l'écran de détail, et c'est la plus
/// facile à casser : ajouter un statut au serveur sans le classer laisserait
/// une commande sans jalon courant, donc une chronologie qui n'avance plus.
///
/// L'écran affichait par ailleurs un statut **figé** au chargement de la
/// liste : la commande arrivait en argument de route et n'était jamais relue.
/// Ces cas tiennent la règle ; la relecture, elle, est tenue par
/// `getOrderById` dans l'écran.
void main() {
  Order commande({
    OrderStatus statut = OrderStatus.pending,
    List<OrderStatusUpdate> evenements = const [],
    DateTime? deposee,
  }) {
    final maintenant = deposee ?? DateTime(2026, 8, 30, 12, 30);
    return Order(
      id: 'commande-1',
      userId: 'client-1',
      items: const [],
      subtotal: 6500,
      total: 7500,
      deliveryAddress: 'Cocody, Abidjan',
      paymentMethod: PaymentMethod.mobileMoney,
      orderTime: maintenant,
      createdAt: maintenant,
      status: statut,
      statusUpdates: evenements,
    );
  }

  group('Le rang d’un statut', () {
    test('les dix statuts sont classés, aucun n’est oublié', () {
      for (final statut in OrderStatus.values) {
        final rang = rangDuStatut(statut);
        expect(
          rang >= -1 && rang <= 3,
          isTrue,
          reason: '$statut tombe hors de la chronologie',
        );
      }
    });

    test('les statuts d’attente et de confirmation partagent le premier jalon',
        () {
      expect(rangDuStatut(OrderStatus.pending), 0);
      expect(rangDuStatut(OrderStatus.confirmed), 0);
    });

    test('« prête » reste dans la préparation, elle n’est pas partie', () {
      // La cuisine a fini, le livreur n'a rien pris : afficher « En route »
      // ferait guetter un livreur qui n'existe pas encore.
      expect(rangDuStatut(OrderStatus.ready), 1);
      expect(rangDuStatut(OrderStatus.pickedUp), 2);
    });

    test('ce qui sort du cycle n’a pas de rang', () {
      expect(rangDuStatut(OrderStatus.cancelled), -1);
      expect(rangDuStatut(OrderStatus.refunded), -1);
      expect(rangDuStatut(OrderStatus.failed), -1);
      expect(estSortieDuCycle(OrderStatus.cancelled), isTrue);
      expect(estSortieDuCycle(OrderStatus.delivered), isFalse);
    });
  });

  group('La chronologie', () {
    test('une commande neuve montre quatre jalons, un seul franchi', () {
      final etapes = etapesDeSuivi(commande());

      expect(etapes.length, 4);
      expect(etapes.where((e) => e.franchie).length, 1);
      expect(etapes.first.courante, isTrue);
      expect(etapes.first.jalon, JalonDeSuivi.confirmee);
    });

    test('une commande livrée a tous ses jalons franchis', () {
      final etapes = etapesDeSuivi(commande(statut: OrderStatus.delivered));

      expect(etapes.length, 4);
      expect(etapes.every((e) => e.franchie), isTrue);
      expect(etapes.last.courante, isTrue);
    });

    test('un seul jalon est courant à la fois', () {
      for (final statut in OrderStatus.values) {
        final etapes = etapesDeSuivi(commande(statut: statut));
        expect(
          etapes.where((e) => e.courante).length,
          1,
          reason: '$statut ne désigne pas exactement un jalon courant',
        );
      }
    });

    test('les jalons franchis précèdent toujours ceux qui restent', () {
      for (final statut in OrderStatus.values) {
        final etapes = etapesDeSuivi(commande(statut: statut));
        var vuNonFranchi = false;
        for (final etape in etapes) {
          if (!etape.franchie) vuNonFranchi = true;
          if (etape.franchie && vuNonFranchi) {
            fail('$statut : un jalon franchi suit un jalon qui ne l’est pas');
          }
        }
      }
    });
  });

  group('Une commande sortie du cycle', () {
    test('ne montre pas trois cases grises qui laisseraient espérer', () {
      // Annulée après la préparation : les deux premiers jalons ont bien eu
      // lieu, « En route » et « Livrée » n'arriveront jamais. Les afficher en
      // attente ferait guetter une livraison qui ne viendra pas.
      final etapes = etapesDeSuivi(
        commande(statut: OrderStatus.cancelled).copyWith(
          status: OrderStatus.cancelled,
          statusUpdates: [
            OrderStatusUpdate(
              status: OrderStatus.preparing,
              timestamp: DateTime(2026, 8, 30, 12, 40),
            ),
          ],
        ),
      );

      expect(etapes.last.annulation, isTrue);
      expect(etapes.any((e) => !e.franchie), isFalse);
    });

    test('chaque sortie porte son propre mot', () {
      expect(libelleDeSortie(OrderStatus.cancelled), 'Annulée');
      expect(libelleDeSortie(OrderStatus.refunded), 'Remboursée');
      expect(libelleDeSortie(OrderStatus.failed), 'Échouée');
    });
  });

  group('Les heures', () {
    test('le premier jalon retombe sur l’heure de dépôt', () {
      // Elle est toujours connue, et c'est la même chose : une commande
      // confirmée à l'instant où elle est passée.
      final depot = DateTime(2026, 8, 30, 12, 30);
      final etapes = etapesDeSuivi(commande(deposee: depot));

      expect(etapes.first.horodatage, depot);
    });

    test('un jalon franchi sans événement n’invente pas d’heure', () {
      // Le serveur n'a pas enregistré le passage : on sait que c'est arrivé,
      // pas quand. Une heure inventée serait pire qu'une heure absente.
      final etapes = etapesDeSuivi(commande(statut: OrderStatus.onTheWay));
      final enRoute =
          etapes.firstWhere((e) => e.jalon == JalonDeSuivi.enRoute);

      expect(enRoute.franchie, isTrue);
      expect(enRoute.horodatage, isNull);
    });

    test('l’heure vient de l’événement du serveur quand il existe', () {
      final priseEnCharge = DateTime(2026, 8, 30, 13, 5);
      final etapes = etapesDeSuivi(
        commande(
          statut: OrderStatus.onTheWay,
          evenements: [
            OrderStatusUpdate(
              status: OrderStatus.pickedUp,
              timestamp: priseEnCharge,
            ),
          ],
        ),
      );

      final enRoute =
          etapes.firstWhere((e) => e.jalon == JalonDeSuivi.enRoute);
      expect(enRoute.horodatage, priseEnCharge);
    });
  });
}
