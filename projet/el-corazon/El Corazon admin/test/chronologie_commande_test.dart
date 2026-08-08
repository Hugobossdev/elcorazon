import 'package:admin/models/order.dart';
import 'package:admin/presentation/chronologie_commande.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'« Historique de la commande » de `order_management_screen.dart`.
///
/// Ces tests ne valident pas que l'historique est juste — il ne l'est pas.
/// Ils épinglent ce qu'il affiche, y compris le fait que ses heures sont
/// fabriquées, pour que la correction se voie quand elle sera décidée.
Order _commande({
  OrderStatus statut = OrderStatus.pending,
  DateTime? passeeLe,
}) {
  final quand = passeeLe ?? DateTime(2026, 8, 8, 12);

  return Order(
    id: 'commande-1',
    userId: '',
    items: const [],
    subtotal: 4500,
    total: 4500,
    status: statut,
    deliveryAddress: 'Rue du Commerce',
    recipientName: 'Awa',
    paymentMethod: PaymentMethod.cash,
    orderTime: quand,
    createdAt: quand,
  );
}

void main() {
  group('Les étapes', () {
    test('il y en a six, dans l’ordre du cycle de vie', () {
      expect(
        chronologieDe(_commande()).map((e) => e.libelle).toList(),
        [
          'Commande passée',
          'Commande confirmée',
          'En préparation',
          'Prête',
          'En livraison',
          'Livrée',
        ],
      );
    });

    test('« passée » est toujours franchie', () {
      for (final statut in OrderStatus.values) {
        expect(chronologieDe(_commande(statut: statut)).first.franchie, isTrue);
      }
    });
  });

  group('Ce qui est franchi', () {
    List<bool> franchies(OrderStatus statut) =>
        chronologieDe(_commande(statut: statut)).map((e) => e.franchie).toList();

    test('une commande en attente n’a franchi que la première étape', () {
      expect(franchies(OrderStatus.pending),
          [true, false, false, false, false, false],);
    });

    test('une commande en préparation en a franchi trois', () {
      expect(franchies(OrderStatus.preparing),
          [true, true, true, false, false, false],);
    });

    test('seule une commande livrée franchit la dernière étape', () {
      expect(franchies(OrderStatus.delivered).last, isTrue);
      expect(franchies(OrderStatus.onTheWay).last, isFalse);
    });

    test('une commande annulée paraît tout avoir franchi sauf la livraison', () {
      // `cancelled` est déclaré après `delivered` : la comparaison par rang
      // coche « en livraison » sur une commande qui n'est jamais partie.
      expect(franchies(OrderStatus.cancelled),
          [true, true, true, true, true, false],);
    });
  });

  group('Les heures sont fabriquées', () {
    test('chaque étape est un décalage fixe depuis l’heure de commande', () {
      final passeeLe = DateTime(2026, 8, 8, 12);
      final etapes = chronologieDe(_commande(passeeLe: passeeLe));

      expect(etapes.map((e) => e.quand).toList(), [
        passeeLe,
        DateTime(2026, 8, 8, 12, 5),
        DateTime(2026, 8, 8, 12, 10),
        DateTime(2026, 8, 8, 12, 25),
        DateTime(2026, 8, 8, 12, 30),
        DateTime(2026, 8, 8, 12, 45),
      ]);
    });

    test('le statut réel ne change aucune heure', () {
      // Preuve que rien de mesuré n'y entre : une commande encore en attente
      // affiche la même heure de « livrée » qu'une commande livrée.
      final enAttente = chronologieDe(_commande());
      final livree = chronologieDe(_commande(statut: OrderStatus.delivered));

      expect(enAttente.last.quand, livree.last.quand);
    });
  });
}
