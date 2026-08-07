import 'package:admin/models/order.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Alertes de la supervision des commandes.
///
/// Le bandeau « commandes urgentes / en retard » existait à l'écran mais était
/// alimenté par deux listes vides écrites en dur : il ne s'affichait jamais, et
/// une commande oubliée en cuisine ne se voyait qu'en parcourant les onglets un
/// par un.
///
/// Ces règles sont **temporelles**, ce qui est précisément ce qui se casse en
/// silence : une commande livrée reste « en retard » pour toujours si le statut
/// n'est pas regardé, et une commande sans heure annoncée déclenche une alerte
/// permanente si `null` est traité comme une date dépassée. L'heure est donc
/// injectée ici plutôt que lue à l'horloge.
void main() {
  final maintenant = DateTime(2026, 8, 6, 12);

  Order commande({
    required String id,
    required OrderStatus statut,
    Duration passeeIlYA = const Duration(minutes: 5),
    Duration? livraisonPrevueDans,
  }) {
    final passee = maintenant.subtract(passeeIlYA);
    return Order(
      id: id,
      userId: 'client-1',
      items: const [],
      subtotal: 5000,
      total: 5600,
      status: statut,
      deliveryAddress: 'Tokoin, Lomé',
      paymentMethod: PaymentMethod.cash,
      orderTime: passee,
      createdAt: passee,
      estimatedDeliveryTime:
          livraisonPrevueDans == null ? null : maintenant.add(livraisonPrevueDans),
    );
  }

  group('Commandes urgentes', () {
    test('une commande en attente depuis trop longtemps est signalée', () {
      final urgentes = OrderManagementService.urgentAmong(
        [
          commande(
            id: 'oubliee',
            statut: OrderStatus.pending,
            passeeIlYA: const Duration(minutes: 45),
          ),
        ],
        now: maintenant,
      );

      expect(urgentes.single.id, 'oubliee');
    });

    test('une commande récente ne l’est pas', () {
      final urgentes = OrderManagementService.urgentAmong(
        [
          commande(
            id: 'fraiche',
            statut: OrderStatus.pending,
            passeeIlYA: const Duration(minutes: 3),
          ),
        ],
        now: maintenant,
      );

      expect(urgentes, isEmpty);
    });

    test('une commande déjà en préparation n’est plus « en attente »', () {
      // L'alerte vise ce qui n'a pas démarré. Une commande en cuisine depuis
      // une heure est peut-être en retard — c'est l'autre alerte — mais elle
      // n'est pas oubliée.
      final urgentes = OrderManagementService.urgentAmong(
        [
          commande(
            id: 'en-cuisine',
            statut: OrderStatus.preparing,
            passeeIlYA: const Duration(hours: 1),
          ),
        ],
        now: maintenant,
      );

      expect(urgentes, isEmpty);
    });

    test('une commande annulée ne remonte jamais', () {
      final urgentes = OrderManagementService.urgentAmong(
        [
          commande(
            id: 'annulee',
            statut: OrderStatus.cancelled,
            passeeIlYA: const Duration(days: 3),
          ),
        ],
        now: maintenant,
      );

      expect(urgentes, isEmpty);
    });

    test('la plus ancienne passe en tête', () {
      final urgentes = OrderManagementService.urgentAmong(
        [
          commande(
            id: 'recente',
            statut: OrderStatus.pending,
            passeeIlYA: const Duration(minutes: 25),
          ),
          commande(
            id: 'ancienne',
            statut: OrderStatus.confirmed,
            passeeIlYA: const Duration(hours: 2),
          ),
        ],
        now: maintenant,
      );

      expect(urgentes.map((order) => order.id), ['ancienne', 'recente']);
    });
  });

  group('Commandes en retard', () {
    test('l’heure annoncée dépassée met la commande en retard', () {
      final retard = OrderManagementService.overdueAmong(
        [
          commande(
            id: 'en-retard',
            statut: OrderStatus.onTheWay,
            livraisonPrevueDans: const Duration(minutes: -15),
          ),
        ],
        now: maintenant,
      );

      expect(retard.single.id, 'en-retard');
    });

    test('une livraison encore dans les temps ne l’est pas', () {
      final retard = OrderManagementService.overdueAmong(
        [
          commande(
            id: 'dans-les-temps',
            statut: OrderStatus.onTheWay,
            livraisonPrevueDans: const Duration(minutes: 10),
          ),
        ],
        now: maintenant,
      );

      expect(retard, isEmpty);
    });

    test('sans heure annoncée, pas de retard', () {
      // Traiter l'absence de promesse comme une promesse rompue ferait sonner
      // l'alerte en permanence, jusqu'à ce que plus personne ne la regarde.
      final retard = OrderManagementService.overdueAmong(
        [commande(id: 'sans-promesse', statut: OrderStatus.preparing)],
        now: maintenant,
      );

      expect(retard, isEmpty);
    });

    test('une commande livrée n’est plus en retard', () {
      // Sans le filtre sur le statut, toute commande livrée avec ne serait-ce
      // qu'une minute de décalage resterait dans le bandeau pour toujours, et
      // la liste ne ferait que croître.
      final retard = OrderManagementService.overdueAmong(
        [
          commande(
            id: 'livree',
            statut: OrderStatus.delivered,
            livraisonPrevueDans: const Duration(hours: -5),
          ),
        ],
        now: maintenant,
      );

      expect(retard, isEmpty);
    });

    test('le retard le plus ancien passe en tête', () {
      final retard = OrderManagementService.overdueAmong(
        [
          commande(
            id: 'peu',
            statut: OrderStatus.onTheWay,
            livraisonPrevueDans: const Duration(minutes: -5),
          ),
          commande(
            id: 'beaucoup',
            statut: OrderStatus.ready,
            livraisonPrevueDans: const Duration(hours: -2),
          ),
        ],
        now: maintenant,
      );

      expect(retard.map((order) => order.id), ['beaucoup', 'peu']);
    });
  });
}
