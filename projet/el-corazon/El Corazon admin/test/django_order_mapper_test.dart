import 'package:admin/models/order.dart';
import 'package:admin/repositories/django_order_mapper.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Traduction du contrat serveur vers le modèle local des écrans.
///
/// C'est le seul endroit du back-office où une commande change de forme. Le
/// tester ici plutôt qu'à travers un écran isole ce qui se casse vraiment quand
/// le contrat bouge : un statut ajouté côté serveur, un montant qui change
/// d'unité.
///
/// Il n'y a pas de test de fumée sur `AdminApp` : la construction de
/// l'application démarre encore des services qui ouvrent des connexions
/// (socket, minuteurs de rafraîchissement), et un test qui les laisserait
/// tourner s'adresserait au réseau. Il reviendra quand ces services seront
/// injectés plutôt que construits sur place.
void main() {
  eccore.Order commande({
    String status = 'preparing',
    String paymentMethod = 'mobile_money',
    String landmark = '',
    List<eccore.OrderLine> lines = const [],
  }) {
    return eccore.Order(
      id: 'order-1',
      reference: 'EC000042',
      restaurantSlug: 'el-corazon-lome',
      restaurantName: 'El Corazón Lomé',
      status: status,
      allowedTransitions: const ['ready'],
      subtotal: const eccore.Money(amountMinor: 3500, currency: 'XOF'),
      deliveryFee: const eccore.Money(amountMinor: 500, currency: 'XOF'),
      discount: const eccore.Money(amountMinor: 0, currency: 'XOF'),
      total: const eccore.Money(amountMinor: 4000, currency: 'XOF'),
      paymentMethod: paymentMethod,
      deliveryAddressLine: 'Rue du Commerce',
      deliveryLandmark: landmark,
      deliveryLatitude: 6.1319,
      deliveryLongitude: 1.2255,
      recipientName: 'Awa K.',
      recipientPhone: '+22890111111',
      placedAt: DateTime.utc(2026, 7, 31, 12),
      createdAt: DateTime.utc(2026, 7, 31, 12),
      updatedAt: DateTime.utc(2026, 7, 31, 12),
      lines: lines,
    );
  }

  group('DjangoOrderMapper.toLocal', () {
    test('rend les montants en unité majeure', () {
      final locale = DjangoOrderMapper.toLocal(commande());

      expect(locale.subtotal, 3500);
      expect(locale.deliveryFee, 500);
      expect(locale.total, 4000);
    });

    test('accole le point de repère à l’adresse quand il existe', () {
      final sans = DjangoOrderMapper.toLocal(commande());
      final avec = DjangoOrderMapper.toLocal(
        commande(landmark: 'face à la pharmacie'),
      );

      expect(sans.deliveryAddress, 'Rue du Commerce');
      expect(avec.deliveryAddress, 'Rue du Commerce (face à la pharmacie)');
    });

    test('traduit les statuts en serpent vers l’énumération locale', () {
      expect(
        DjangoOrderMapper.toLocal(commande(status: 'picked_up')).status,
        OrderStatus.pickedUp,
      );
      expect(
        DjangoOrderMapper.toLocal(commande(status: 'on_the_way')).status,
        OrderStatus.onTheWay,
      );
    });

    test('un statut inconnu retombe sur « en attente », sans planter', () {
      // Le serveur peut gagner un statut avant que le back-office ne soit
      // redéployé ; l'écran doit rester lisible.
      expect(
        DjangoOrderMapper.toLocal(commande(status: 'scheduled')).status,
        OrderStatus.pending,
      );
    });

    test('le mobile money est le mode par défaut', () {
      expect(
        DjangoOrderMapper.toLocal(commande(paymentMethod: 'card')).paymentMethod,
        PaymentMethod.creditCard,
      );
      expect(
        DjangoOrderMapper.toLocal(
          commande(paymentMethod: 'inconnu'),
        ).paymentMethod,
        PaymentMethod.mobileMoney,
      );
    });
  });

  group('DjangoOrderMapper.toRemoteStatus', () {
    test('les statuts locaux repartent en serpent', () {
      expect(DjangoOrderMapper.toRemoteStatus(OrderStatus.pickedUp), 'picked_up');
      expect(DjangoOrderMapper.toRemoteStatus(OrderStatus.onTheWay), 'on_the_way');
    });

    test('« remboursée » et « échouée » repartent en annulation', () {
      // Le serveur n'a pas ces deux statuts : le remboursement est un mouvement
      // de paiement, et ce qui n'aboutit pas est annulé, avec un motif.
      expect(DjangoOrderMapper.toRemoteStatus(OrderStatus.refunded), 'cancelled');
      expect(DjangoOrderMapper.toRemoteStatus(OrderStatus.failed), 'cancelled');
    });
  });
}
