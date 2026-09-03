import 'package:admin/services/order_management_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aide_commande.dart';

/// Ce que la section « Performance » a le droit d'afficher.
///
/// Ces cas existent parce que les trois chiffres qu'elle montrait étaient faux,
/// chacun d'une façon différente :
///
/// * le **temps moyen de livraison** valait `estimated_delivery_at −
///   placed_at`, c'est-à-dire le délai *promis*. Il vient du barème de la zone
///   et ne bouge pas quand les livraisons prennent une heure de plus ;
/// * le **taux de livraison à l'heure** comptait les commandes dont cette même
///   promesse tenait dans les soixante minutes. Aucune horloge n'y entrait ;
/// * la **satisfaction client**, affichée sur cinq sous une étoile, était
///   `(1 − taux d'annulation) × 0,7 + ponctualité × 0,3`. Aucun client n'avait
///   rien noté.
///
/// Un test de moyenne ne suffisait pas à les attraper : ils *calculaient*
/// quelque chose, et rendaient un nombre plausible. Ce qui les distingue de la
/// version correcte, c'est **sur quoi** ils portent — d'où des cas construits
/// pour que la promesse et le réel diffèrent.
void main() {
  final passeeLe = DateTime(2026, 8, 8, 12);

  group('Le temps de livraison', () {
    test('se mesure entre la commande et la livraison, pas sur la promesse', () {
      // Promise en 30 minutes, livrée en 75. La version précédente rendait 30.
      final service = OrderManagementService.pourTests([
        commandeDeTest(
          statut: 'delivered',
          passeeLe: passeeLe,
          livraisonPrevueLe: passeeLe.add(const Duration(minutes: 30)),
          livreeLe: passeeLe.add(const Duration(minutes: 75)),
        ),
      ]);

      expect(service.getDeliveryStats()['average_delivery_time'], 75.0);
    });

    test('ignore une livraison sans horodatage plutôt que de lui prêter une durée', () {
      final service = OrderManagementService.pourTests([
        commandeDeTest(
          id: 'mesurable',
          statut: 'delivered',
          passeeLe: passeeLe,
          livreeLe: passeeLe.add(const Duration(minutes: 40)),
        ),
        commandeDeTest(id: 'sans-horodatage', statut: 'delivered', passeeLe: passeeLe),
      ]);

      final stats = service.getDeliveryStats();
      expect(stats['measured_orders'], 1);
      expect(stats['average_delivery_time'], 40.0);
    });

    test('rend le plus rapide et le plus lent des trajets', () {
      final service = OrderManagementService.pourTests([
        commandeDeTest(
          id: 'rapide',
          statut: 'delivered',
          passeeLe: passeeLe,
          livreeLe: passeeLe.add(const Duration(minutes: 18)),
        ),
        commandeDeTest(
          id: 'lente',
          statut: 'delivered',
          passeeLe: passeeLe,
          livreeLe: passeeLe.add(const Duration(minutes: 92)),
        ),
      ]);

      final stats = service.getDeliveryStats();
      expect(stats['fastest_delivery'], 18.0);
      expect(stats['slowest_delivery'], 92.0);
      expect(stats['average_delivery_time'], 55.0);
    });

    test('sans aucune livraison, tout est à zéro et rien n’est inventé', () {
      final service = OrderManagementService.pourTests([
        commandeDeTest(passeeLe: passeeLe),
      ]);

      final stats = service.getDeliveryStats();
      expect(stats['measured_orders'], 0);
      expect(stats['average_delivery_time'], 0.0);
      expect(stats['on_time_rate'], 0.0);
    });
  });

  group('La ponctualité', () {
    test('compare l’heure de livraison à l’heure annoncée', () {
      final service = OrderManagementService.pourTests([
        // Dans les temps : annoncée 13 h, livrée 12 h 50.
        commandeDeTest(
          id: 'a-lheure',
          statut: 'delivered',
          passeeLe: passeeLe,
          livraisonPrevueLe: passeeLe.add(const Duration(minutes: 60)),
          livreeLe: passeeLe.add(const Duration(minutes: 50)),
        ),
        // En retard : annoncée 13 h, livrée 13 h 20.
        commandeDeTest(
          id: 'en-retard',
          statut: 'delivered',
          passeeLe: passeeLe,
          livraisonPrevueLe: passeeLe.add(const Duration(minutes: 60)),
          livreeLe: passeeLe.add(const Duration(minutes: 80)),
        ),
      ]);

      expect(service.getDeliveryStats()['on_time_rate'], 50.0);
    });

    test('une livraison pile à l’heure annoncée est à l’heure', () {
      // La borne compte : `isAfter` et non `!isBefore`. Arriver à la minute
      // promise, c'est tenir la promesse.
      final service = OrderManagementService.pourTests([
        commandeDeTest(
          statut: 'delivered',
          passeeLe: passeeLe,
          livraisonPrevueLe: passeeLe.add(const Duration(minutes: 45)),
          livreeLe: passeeLe.add(const Duration(minutes: 45)),
        ),
      ]);

      expect(service.getDeliveryStats()['on_time_rate'], 100.0);
    });

    test('ne se juge que sur les commandes qui portaient une promesse', () {
      // Sans heure annoncée, il n'y a rien à tenir — et rien à manquer. La
      // compter comme un échec noircirait le taux ; la compter comme un succès
      // le flatterait.
      final service = OrderManagementService.pourTests([
        commandeDeTest(
          id: 'annoncee',
          statut: 'delivered',
          passeeLe: passeeLe,
          livraisonPrevueLe: passeeLe.add(const Duration(minutes: 60)),
          livreeLe: passeeLe.add(const Duration(minutes: 50)),
        ),
        commandeDeTest(
          id: 'sans-promesse',
          statut: 'delivered',
          passeeLe: passeeLe,
          livreeLe: passeeLe.add(const Duration(minutes: 200)),
        ),
      ]);

      final stats = service.getDeliveryStats();
      expect(stats['on_time_measured'], 1);
      expect(stats['on_time_rate'], 100.0);
      // Elle compte en revanche dans la durée moyenne : elle a bien eu lieu.
      expect(stats['measured_orders'], 2);
    });
  });

  group('Les chiffres de la section Performance', () {
    test('n’annoncent plus de satisfaction client', () {
      final service = OrderManagementService.pourTests([
        commandeDeTest(statut: 'delivered', passeeLe: passeeLe),
      ]);

      expect(service.getPerformanceStats().containsKey('customer_satisfaction'), isFalse);
    });

    test('rendent le taux d’annulation, qui lui se lit dans les commandes', () {
      final service = OrderManagementService.pourTests([
        commandeDeTest(id: 'a', statut: 'delivered', passeeLe: passeeLe),
        commandeDeTest(id: 'b', statut: 'cancelled', passeeLe: passeeLe),
        commandeDeTest(id: 'c', passeeLe: passeeLe),
        commandeDeTest(id: 'd', passeeLe: passeeLe),
      ]);

      expect(service.getPerformanceStats()['cancellation_rate'], 25.0);
    });

    test('annoncent combien de livraisons ont servi à la mesure', () {
      // Sans ce compte, « 34 min » sur deux livraisons et « 34 min » sur six
      // cents s'affichent à l'identique.
      final service = OrderManagementService.pourTests([
        commandeDeTest(
          id: 'a',
          statut: 'delivered',
          passeeLe: passeeLe,
          livreeLe: passeeLe.add(const Duration(minutes: 34)),
        ),
        commandeDeTest(id: 'b', passeeLe: passeeLe),
      ]);

      expect(service.getPerformanceStats()['measured_orders'], 1);
    });
  });
}
