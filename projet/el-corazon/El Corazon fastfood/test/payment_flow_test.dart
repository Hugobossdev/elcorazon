import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/payment_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parcours de paiement, côté client.
///
/// Ces tests gardent une propriété de sécurité, pas un affichage : **le client
/// ne décide jamais qu'un paiement a abouti**. Jusqu'au 2 août 2026,
/// l'application détenait les clés marchandes et appelait le prestataire
/// elle-même ; c'est ce chemin qui a été retiré, et ce sont ces tests qui
/// signaleraient sa réapparition.
void main() {
  group('États de paiement', () {
    test('l’état par défaut n’est jamais « réglé »', () {
      // Une commande à payer à la livraison démarre à `none`, pas à
      // `completed` : c'est le serveur qui dit ce qui est encaissé.
      expect(PaymentStatus.values.first, PaymentStatus.none);
    });

    test('les six états couvrent le cycle de vie complet', () {
      // Si le serveur gagne un état, cette liste doit bouger avec lui — sans
      // quoi l'écran retomberait silencieusement sur un cas par défaut.
      expect(PaymentStatus.values, hasLength(6));
      expect(
        PaymentStatus.values,
        containsAll([
          PaymentStatus.none,
          PaymentStatus.pending,
          PaymentStatus.completed,
          PaymentStatus.cancelled,
          PaymentStatus.error,
          PaymentStatus.refunded,
        ]),
      );
    });
  });

  group('Moyens de paiement', () {
    test('« espèces » est le seul mode qui n’ouvre pas de règlement en ligne', () {
      // L'écran s'en sert pour ne pas appeler `/payments/{id}/initiate/` :
      // une commande réglée à la livraison n'a pas de transaction à ouvrir.
      expect(PaymentMethod.values, contains(PaymentMethod.cash));
      expect(PaymentMethod.cash.toString(), contains('cash'));
    });

    test('carte de crédit et de débit sont deux valeurs locales distinctes', () {
      // Le serveur n'en connaît qu'une (`card`) ; la distinction est
      // d'affichage. Les confondre ici casserait la traduction inverse.
      expect(PaymentMethod.creditCard, isNot(PaymentMethod.debitCard));
    });
  });

  group('Statuts de commande — contrat avec le serveur', () {
    test('chaque statut local porte la valeur attendue par l’API', () {
      // `dbValue` est ce qui part et revient dans le JSON. Une faute ici fait
      // retomber toutes les commandes sur « en attente » sans erreur visible.
      expect(OrderStatus.pending.dbValue, 'pending');
      expect(OrderStatus.confirmed.dbValue, 'confirmed');
      expect(OrderStatus.preparing.dbValue, 'preparing');
      expect(OrderStatus.ready.dbValue, 'ready');
      expect(OrderStatus.pickedUp.dbValue, 'picked_up');
      expect(OrderStatus.onTheWay.dbValue, 'on_the_way');
      expect(OrderStatus.delivered.dbValue, 'delivered');
      expect(OrderStatus.cancelled.dbValue, 'cancelled');
    });

    test('les valeurs en serpent ne sont pas rendues en camel', () {
      // Erreur classique : `pickedUp` envoyé tel quel. Le serveur refuse la
      // transition et l'écran affiche « impossible » sans expliquer pourquoi.
      expect(OrderStatus.pickedUp.dbValue, isNot('pickedUp'));
      expect(OrderStatus.onTheWay.dbValue, isNot('onTheWay'));
    });

    test('deux statuts n’ont pas de contrepartie côté serveur', () {
      // Le remboursement est un mouvement de paiement, pas un statut de
      // commande ; ce qui n'aboutit pas est **annulé**, avec un motif.
      expect(OrderStatus.values, contains(OrderStatus.refunded));
      expect(OrderStatus.values, contains(OrderStatus.failed));
    });
  });
}
