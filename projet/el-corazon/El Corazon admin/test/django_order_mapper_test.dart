import 'package:admin/models/order.dart';
import 'package:admin/repositories/django_order_mapper.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Traduction d'une commande du contrat vers ce que le back-office affiche.
///
/// Ces tests sont écrits **avant** de démonter l'adaptateur (lot 3) : ce
/// qu'ils épinglent n'est pas `DjangoOrderMapper` mais ce que l'opérateur voit.
/// Quand les écrans liront `eccore.Order` directement, ces attentes devront
/// tenir à l'identique — c'est tout leur objet.
///
/// Il n'y a pas de test de fumée sur `AdminApp` : la construction de
/// l'application démarre encore des services qui ouvrent des connexions
/// (socket, minuteurs de rafraîchissement), et un test qui les laisserait
/// tourner s'adresserait au réseau. Il reviendra quand ces services seront
/// injectés plutôt que construits sur place.
Map<String, dynamic> _montant(int mineur) =>
    {'amount': '$mineur', 'currency': 'XOF'};

eccore.Order _commande({
  String statut = 'preparing',
  String moyenPaiement = 'cash',
  String repere = '',
  String consignes = '',
  List<dynamic>? lignes,
}) {
  return eccore.Order.fromJson({
    'id': 'commande-1',
    'reference': 'CMD-0001',
    'restaurant': 'el-corazon-lome',
    'restaurant_name': 'El Corazón Lomé',
    'status': statut,
    'allowed_transitions': const <String>[],
    'subtotal': _montant(9000),
    'delivery_fee': _montant(1000),
    'discount': _montant(500),
    'total': _montant(9500),
    'payment_method': moyenPaiement,
    'delivery_address_line': 'Rue du Commerce',
    'delivery_landmark': repere,
    'delivery_location': {'lat': 6.14, 'lon': 1.23},
    'recipient_name': 'Awa',
    'recipient_phone': '+22890000000',
    'placed_at': '2026-08-08T09:58:00Z',
    'estimated_delivery_at': '2026-08-08T10:45:00Z',
    'delivery_instructions': consignes,
    'lines': lignes ??
        [
          {
            'id': 'ligne-1',
            'menu_item': 'article-1',
            'item_name': 'Poulet braisé',
            'item_image': 'https://exemple.test/poulet.jpg',
            'unit_price': _montant(4500),
            'quantity': 2,
            'line_total': _montant(9000),
            'notes': 'Bien épicé',
          },
        ],
    'created_at': '2026-08-08T09:58:00Z',
    'updated_at': '2026-08-08T10:00:00Z',
  });
}

void main() {
  group('Ce que l’écran montre d’une commande', () {
    test('les montants passent en unité majeure', () {
      final locale = DjangoOrderMapper.toLocal(_commande());

      expect(locale.subtotal, 9000);
      expect(locale.deliveryFee, 1000);
      expect(locale.discount, 500);
      expect(locale.total, 9500);
    });

    test('les lignes sont reprises une à une', () {
      final article = DjangoOrderMapper.toLocal(_commande()).items.single;

      expect(article.menuItemId, 'article-1');
      expect(article.menuItemName, 'Poulet braisé');
      expect(article.quantity, 2);
      expect(article.unitPrice, 4500);
      expect(article.totalPrice, 9000);
      expect(article.notes, 'Bien épicé');
    });

    test('le destinataire est celui de la commande', () {
      final locale = DjangoOrderMapper.toLocal(_commande());

      expect(locale.recipientName, 'Awa');
      expect(locale.recipientPhone, '+22890000000');
    });

    test('le client n’est pas exposé sur la liste', () {
      // L'écran affiche une commande, pas un dossier client.
      expect(DjangoOrderMapper.toLocal(_commande()).userId, isEmpty);
    });

    test('le repère complète l’adresse quand il existe', () {
      expect(
        DjangoOrderMapper.toLocal(_commande()).deliveryAddress,
        'Rue du Commerce',
      );
      expect(
        DjangoOrderMapper.toLocal(_commande(repere: 'face à la pharmacie'))
            .deliveryAddress,
        'Rue du Commerce (face à la pharmacie)',
      );
    });

    test('des consignes vides ne deviennent pas une note vide', () {
      final sans = DjangoOrderMapper.toLocal(_commande());
      expect(sans.deliveryNotes, isNull);
      expect(sans.specialInstructions, isNull);

      final avec = DjangoOrderMapper.toLocal(
        _commande(consignes: 'Sonner deux fois'),
      );
      expect(avec.deliveryNotes, 'Sonner deux fois');
    });

    test('une commande sans ligne reste lisible', () {
      final locale = DjangoOrderMapper.toLocal(_commande(lignes: const []));
      expect(locale.items, isEmpty);
      expect(locale.total, 9500);
    });
  });

  group('Statuts', () {
    OrderStatus lu(String serveur) =>
        DjangoOrderMapper.toLocal(_commande(statut: serveur)).status;

    test('chaque statut du contrat a sa contrepartie', () {
      expect(lu('confirmed'), OrderStatus.confirmed);
      expect(lu('preparing'), OrderStatus.preparing);
      expect(lu('ready'), OrderStatus.ready);
      expect(lu('picked_up'), OrderStatus.pickedUp);
      expect(lu('on_the_way'), OrderStatus.onTheWay);
      expect(lu('delivered'), OrderStatus.delivered);
      expect(lu('cancelled'), OrderStatus.cancelled);
    });

    test('un statut inconnu retombe sur « en attente »', () {
      expect(lu('quelque_chose_de_neuf'), OrderStatus.pending);
    });

    test('l’aller-retour rend le statut de départ', () {
      for (final serveur in [
        'confirmed',
        'preparing',
        'ready',
        'picked_up',
        'on_the_way',
        'delivered',
        'cancelled',
        'pending',
      ]) {
        expect(
          DjangoOrderMapper.toRemoteStatus(lu(serveur)),
          serveur,
          reason: 'le statut « $serveur » doit revenir tel quel',
        );
      }
    });

    test('ce qui n’aboutit pas est annulé, pas « échoué »', () {
      // Le serveur ne connaît ni `refunded` ni `failed` : le remboursement est
      // un mouvement de paiement, et ce qui n'aboutit pas est annulé avec un
      // motif.
      expect(DjangoOrderMapper.toRemoteStatus(OrderStatus.refunded), 'cancelled');
      expect(DjangoOrderMapper.toRemoteStatus(OrderStatus.failed), 'cancelled');
    });
  });

  group('Moyen de paiement', () {
    PaymentMethod lu(String serveur) =>
        DjangoOrderMapper.toLocal(_commande(moyenPaiement: serveur)).paymentMethod;

    test('chaque moyen connu est traduit', () {
      expect(lu('cash'), PaymentMethod.cash);
      expect(lu('card'), PaymentMethod.creditCard);
      expect(lu('wallet'), PaymentMethod.wallet);
    });

    test('un moyen inconnu passe pour du mobile money', () {
      expect(lu('crypto-monnaie'), PaymentMethod.mobileMoney);
    });
  });

  group('Horodatage', () {
    test('la date affichée est celle de la commande, pas de sa création', () {
      final locale = DjangoOrderMapper.toLocal(_commande());

      expect(locale.orderTime, DateTime.parse('2026-08-08T09:58:00Z'));
      expect(
        locale.estimatedDeliveryTime,
        DateTime.parse('2026-08-08T10:45:00Z'),
      );
    });
  });
}
