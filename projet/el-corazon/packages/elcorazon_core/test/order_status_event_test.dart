import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'historique des transitions d'une commande.
///
/// Le serveur l'écrit dans la même transaction que le changement de statut et
/// le rend sur la forme détail. Le socle l'annonçait dans son commentaire de
/// classe sans jamais le lire : les applications qui affichent un historique
/// l'inventaient donc, faute d'avoir la vraie source sous la main.
Map<String, dynamic> _montant(int mineur) =>
    {'amount': '$mineur', 'currency': 'XOF'};

Map<String, dynamic> _commande({List<dynamic>? evenements}) => {
      'id': 'commande-1',
      'reference': 'CMD-0001',
      'restaurant': 'el-corazon-lome',
      'restaurant_name': 'El Corazón Lomé',
      'status': 'delivered',
      'allowed_transitions': const <String>[],
      'subtotal': _montant(9000),
      'delivery_fee': _montant(1000),
      'discount': _montant(0),
      'total': _montant(10000),
      'payment_method': 'cash',
      'delivery_address_line': 'Rue du Commerce',
      'delivery_landmark': '',
      'delivery_location': {'lat': 6.14, 'lon': 1.23},
      'recipient_name': 'Awa',
      'recipient_phone': '+22890000000',
      'placed_at': '2026-08-08T09:58:00Z',
      'created_at': '2026-08-08T09:58:00Z',
      'updated_at': '2026-08-08T10:45:00Z',
      if (evenements != null) 'status_events': evenements,
    };

void main() {
  group('Sur la forme liste', () {
    test('l’historique est vide, il n’est pas absent', () {
      // `GET /orders/` ne rend pas `status_events` ; une liste vide se
      // parcourt, un `null` fait tomber l'écran.
      expect(Order.fromJson(_commande()).statusEvents, isEmpty);
    });
  });

  group('Sur la forme détail', () {
    final commande = Order.fromJson(
      _commande(
        evenements: [
          {
            'id': 'evenement-1',
            'from_status': '',
            'to_status': 'pending',
            'reason': '',
            'created_at': '2026-08-08T09:58:00Z',
          },
          {
            'id': 'evenement-2',
            'from_status': 'pending',
            'to_status': 'confirmed',
            'reason': 'Stock vérifié',
            'created_at': '2026-08-08T10:03:00Z',
          },
        ],
      ),
    );

    test('chaque transition est reprise', () {
      expect(commande.statusEvents, hasLength(2));
      expect(commande.statusEvents.last.fromStatus, 'pending');
      expect(commande.statusEvents.last.toStatus, 'confirmed');
    });

    test('l’heure est celle du serveur, pas une heure déduite', () {
      expect(
        commande.statusEvents.first.createdAt,
        DateTime.parse('2026-08-08T09:58:00Z'),
      );
      expect(
        commande.statusEvents.last.createdAt,
        DateTime.parse('2026-08-08T10:03:00Z'),
      );
    });

    test('la première transition n’a pas d’avant', () {
      expect(commande.statusEvents.first.fromStatus, isEmpty);
    });

    test('le motif est vide quand la transition vient du système', () {
      expect(commande.statusEvents.first.reason, isEmpty);
      expect(commande.statusEvents.last.reason, 'Stock vérifié');
    });

    test('un motif absent du JSON vaut une chaîne vide', () {
      final sansMotif = Order.fromJson(
        _commande(
          evenements: [
            {
              'id': 'evenement-1',
              'from_status': 'ready',
              'to_status': 'picked_up',
              'created_at': '2026-08-08T10:20:00Z',
            },
          ],
        ),
      );

      expect(sansMotif.statusEvents.single.reason, isEmpty);
    });
  });
}
