import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// La charge utile diffusée par `AssignmentService.offer` sur `ws/couriers/me/`
/// (`delivery.offered`), telle que le backend l'écrit.
Map<String, dynamic> _offerPayload() => {
  'assignment': 'assign-1',
  'order': 'order-1',
  'reference': 'EC000001',
  'restaurant': 'El Corazón',
  'delivery_address_line': 'Rue des Cocotiers',
};

void main() {
  group('AssignmentOffer — file des courses du livreur', () {
    test('lit la charge utile de `delivery.offered`', () {
      final offer = AssignmentOffer.fromPayload(_offerPayload());

      expect(offer.assignmentId, 'assign-1');
      expect(offer.orderId, 'order-1');
      expect(offer.reference, 'EC000001');
      expect(offer.restaurant, 'El Corazón');
      expect(offer.deliveryAddressLine, 'Rue des Cocotiers');
    });

    test('une trame partielle ne fait pas tomber la file', () {
      // Rater une proposition coûte un repas froid (ADR-008) : un champ
      // manquant doit dégrader l'alerte, jamais la supprimer.
      final offer = AssignmentOffer.fromPayload({
        'assignment': 'assign-1',
        'order': 'order-1',
      });

      expect(offer.assignmentId, 'assign-1');
      expect(offer.orderId, 'order-1');
      expect(offer.reference, isEmpty);
      expect(offer.restaurant, isEmpty);
      expect(offer.deliveryAddressLine, isEmpty);
    });

    test(
      "n'invente rien : les identifiants viennent du message, pas d'un défaut",
      () {
        // Le message sert à alerter, pas à décider — mais l'identifiant
        // d'affectation qu'il porte est celui qu'on rechargera. S'il était
        // fabriqué, le rechargement viserait une course inexistante.
        final offer = AssignmentOffer.fromPayload({
          ..._offerPayload(),
          'assignment': 'assign-42',
        });

        expect(offer.assignmentId, 'assign-42');
      },
    );
  });
}
