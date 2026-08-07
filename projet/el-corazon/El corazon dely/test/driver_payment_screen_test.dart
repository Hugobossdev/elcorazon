import 'package:elcora_dely/models/order.dart';
import 'package:elcora_dely/screens/payments/driver_payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Écran d'encaissement du livreur.
///
/// Le groupe `Aucune saisie de paiement` garde le constat critique de l'audit
/// du 2 août : cet écran faisait saisir au livreur le **numéro de carte** et le
/// **CVV** du client, puis appelait PayDunya depuis l'appareil avec les clés
/// marchandes. Si l'un de ces champs réapparaît, ces tests échouent.
void main() {
  Order commande({
    PaymentMethod moyen = PaymentMethod.cash,
    double total = 4500,
  }) {
    return Order(
      id: 'a1b2c3d4-0000-0000-0000-000000000001',
      userId: 'client-1',
      items: const [],
      subtotal: total - 500,
      deliveryFee: 500,
      total: total,
      status: OrderStatus.onTheWay,
      deliveryAddress: 'Rue du Commerce, Lomé',
      paymentMethod: moyen,
      orderTime: DateTime(2026, 8, 2, 12),
      createdAt: DateTime(2026, 8, 2, 12),
    );
  }

  Future<void> afficher(WidgetTester tester, Order o) async {
    await tester.pumpWidget(
      MaterialApp(home: DriverPaymentScreen(order: o, amount: o.total)),
    );
  }

  group('Commande réglée en espèces', () {
    testWidgets('annonce le montant à encaisser', (tester) async {
      await afficher(tester, commande());

      expect(find.text('À encaisser'), findsOneWidget);
      // Deux fois : en tête, et sur la ligne « Total » du récapitulatif.
      expect(find.text('4500 FCFA'), findsNWidgets(2));
    });

    testWidgets('explique la marche à suivre', (tester) async {
      await afficher(tester, commande());

      expect(
        find.textContaining('Encaissez le montant à la remise'),
        findsOneWidget,
      );
    });
  });

  group('Commande déjà réglée', () {
    testWidgets('ne demande aucun encaissement', (tester) async {
      await afficher(tester, commande(moyen: PaymentMethod.mobileMoney));

      expect(find.text('Déjà réglée'), findsOneWidget);
      expect(find.text('À encaisser'), findsNothing);
    });

    testWidgets('le dit explicitement au livreur', (tester) async {
      await afficher(tester, commande(moyen: PaymentMethod.creditCard));

      expect(
        find.textContaining("Vous n'avez rien à encaisser"),
        findsOneWidget,
      );
    });
  });

  group('Aucune saisie de paiement', () {
    testWidgets('aucun champ de texte sur l’écran', (tester) async {
      await afficher(tester, commande());

      // L'écran est en consultation. Un `TextField` ici signifierait qu'on a
      // remis de la saisie de paiement dans l'application du livreur.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(Form), findsNothing);
    });

    testWidgets('aucun libellé de données bancaires', (tester) async {
      await afficher(tester, commande());

      for (final interdit in [
        'CVV',
        'Numéro de carte',
        'Card',
        'Expiration',
        'Titulaire',
      ]) {
        expect(
          find.textContaining(interdit),
          findsNothing,
          reason: 'Le livreur ne saisit aucune donnée bancaire : « $interdit » '
              'ne doit pas apparaître.',
        );
      }
    });

    testWidgets('aucun bouton qui déclencherait un paiement', (tester) async {
      await afficher(tester, commande());

      // Le règlement s'ouvre depuis l'application du client
      // (`POST /payments/{commande}/initiate/`), jamais d'ici.
      expect(find.widgetWithText(ElevatedButton, 'Payer'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Payer'), findsNothing);
      expect(find.textContaining('Valider le paiement'), findsNothing);
    });
  });

  group('Informations de la course', () {
    testWidgets('affiche l’adresse et le total', (tester) async {
      await afficher(tester, commande(total: 7000));

      expect(find.text('Rue du Commerce, Lomé'), findsOneWidget);
      expect(find.text('7000 FCFA'), findsWidgets);
    });

    testWidgets('la référence est courte et lisible', (tester) async {
      await afficher(tester, commande());

      // Huit caractères en majuscules : ce qu'on lit à voix haute au
      // téléphone, pas un UUID complet.
      expect(find.text('#A1B2C3D4'), findsOneWidget);
    });
  });
}
