import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcora_dely/screens/payments/driver_payment_screen.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Écran d'encaissement du livreur.
///
/// Le groupe `Aucune saisie de paiement` garde le constat critique de l'audit
/// du 2 août : cet écran faisait saisir au livreur le **numéro de carte** et le
/// **CVV** du client, puis appelait PayDunya depuis l'appareil avec les clés
/// marchandes. Si l'un de ces champs réapparaît, ces tests échouent.
///
/// Depuis le lot 3, l'écran reçoit une `Course` — l'affectation du socle et le
/// détail de sa commande — et non plus une copie locale de commande. Les
/// montants sont des `Money` : ils s'affichent par leur propre règle, celle du
/// socle, au lieu d'un `toStringAsFixed(0)` suivi de « FCFA ».
void main() {
  // Espace insécable étroite (U+202F) — le séparateur de milliers du socle.
  const nbsp = ' ';

  eccore.Money montant(int mineur) =>
      eccore.Money(amountMinor: mineur, currency: 'XOF');

  /// La course telle que le serveur la rend depuis le lot 4 : elle porte le
  /// moyen de paiement, le total et le montant à encaisser, que l'écran lisait
  /// auparavant sur une commande relue.
  ///
  /// [ancienServeur] retire ces trois champs, pour vérifier que l'écran reste
  /// affichable devant un serveur qui ne les envoie pas encore.
  /// [aEncaisser] est ce que le serveur dit qu'il **reste** dû, en unité
  /// mineure ; `null` veut dire « plus rien à réclamer ». Il ne se déduit plus
  /// du moyen de paiement — c'était le défaut : « mobile money » valait « déjà
  /// réglée », y compris quand le règlement avait échoué.
  eccore.Assignment affectation({
    String moyen = 'cash',
    int total = 4500,
    int? aEncaisser = 4500,
    bool ancienServeur = false,
  }) {
    return eccore.Assignment.fromJson({
      'id': 'course-1',
      'order': 'a1b2c3d4-0000-0000-0000-000000000001',
      'order_reference': 'CMD-0001',
      'restaurant_name': 'El Corazón Lomé',
      'pickup_location': {'lat': 6.13, 'lon': 1.22},
      'delivery_address_line': 'Rue du Commerce, Lomé',
      'delivery_landmark': '',
      'delivery_location': {'lat': 6.14, 'lon': 1.23},
      'recipient_name': 'Awa',
      'recipient_phone': '+22890000000',
      'courier': {
        'id': 'livreur-7',
        'full_name': 'Kodjo',
        'vehicle_type': 'moto',
        'rating_average': '4.8',
        'rating_count': 12,
      },
      'status': eccore.DeliveryStatus.onTheWay,
      'allowed_transitions': const ['delivered'],
      'courier_fee': {'amount': '1000', 'currency': 'XOF'},
      'offered_at': '2026-08-02T12:00:00Z',
      'created_at': '2026-08-02T11:59:00Z',
      'updated_at': '2026-08-02T12:00:00Z',
      if (!ancienServeur) ...{
        'payment_method': moyen,
        'order_total': {'amount': '$total', 'currency': 'XOF'},
        'amount_to_collect': aEncaisser == null
            ? null
            : {'amount': '$aEncaisser', 'currency': 'XOF'},
      },
    });
  }

  Course course({String moyen = 'cash', int total = 4500, int? aEncaisser = 4500}) =>
      Course(
        assignment: affectation(moyen: moyen, total: total, aEncaisser: aEncaisser),
      );

  Future<void> afficher(WidgetTester tester, Course c) async {
    await tester.pumpWidget(
      MaterialApp(home: DriverPaymentScreen(order: c)),
    );
  }

  group('Commande réglée en espèces', () {
    testWidgets('annonce le montant à encaisser', (tester) async {
      await afficher(tester, course());

      expect(find.text('À encaisser'), findsOneWidget);
      // Deux fois : en tête, et sur la ligne « Total » du récapitulatif.
      expect(find.text('4${nbsp}500 CFA'), findsNWidgets(2));
    });

    testWidgets('explique la marche à suivre', (tester) async {
      await afficher(tester, course());

      expect(
        find.textContaining('Encaissez le montant à la remise'),
        findsOneWidget,
      );
    });
  });

  group('Commande déjà réglée', () {
    testWidgets('ne demande aucun encaissement', (tester) async {
      // « Déjà réglée » se lit sur `amount_to_collect`, et sur lui seul : c'est
      // le serveur qui connaît l'état du règlement, et il le rend sous forme de
      // ce qu'il **reste** dû.
      await afficher(tester, course(moyen: 'mobile_money', aEncaisser: null));

      expect(find.text('Déjà réglée'), findsOneWidget);
      expect(find.text('À encaisser'), findsNothing);
    });

    testWidgets('le dit explicitement au livreur', (tester) async {
      await afficher(tester, course(moyen: 'card', aEncaisser: null));

      expect(
        find.textContaining("Vous n'avez rien à encaisser"),
        findsOneWidget,
      );
    });
  });

  group('Le moyen de paiement ne décide de rien', () {
    testWidgets('un paiement en ligne qui n’a pas abouti reste à encaisser', (
      tester,
    ) async {
      // Le défaut, dans son cas exact : le prestataire refuse, ou le client
      // quitte l'écran de règlement, et quelqu'un confirme la commande depuis
      // le back-office. L'écran annonçait « Déjà réglée. Vous n'avez rien à
      // encaisser », et le livreur repartait sans son argent.
      await afficher(tester, course(moyen: 'mobile_money'));

      expect(find.text('À encaisser'), findsOneWidget);
      expect(find.text('Déjà réglée'), findsNothing);
      expect(find.text('4${nbsp}500 CFA'), findsNWidgets(2));
    });

    testWidgets('des espèces déjà encaissées ne sont pas réclamées deux fois', (
      tester,
    ) async {
      // La même erreur dans l'autre sens : « espèces donc à encaisser », y
      // compris quand le règlement avait finalement été enregistré.
      await afficher(tester, course(aEncaisser: null));

      expect(find.text('Déjà réglée'), findsOneWidget);
      expect(find.text('À encaisser'), findsNothing);
    });

    testWidgets('un règlement partiel n’annonce que le reste', (tester) async {
      // Le montant à réclamer et le total de la commande ne sont plus le même
      // nombre : c'est précisément ce que l'ancienne règle ne pouvait pas dire.
      await afficher(tester, course(aEncaisser: 2000));

      expect(find.text('À encaisser'), findsOneWidget);
      expect(find.text('2${nbsp}000 CFA'), findsOneWidget);
      expect(find.text('4${nbsp}500 CFA'), findsOneWidget);
    });
  });

  group('Aucune saisie de paiement', () {
    testWidgets('aucun champ de texte sur l’écran', (tester) async {
      await afficher(tester, course());

      // L'écran est en consultation. Un `TextField` ici signifierait qu'on a
      // remis de la saisie de paiement dans l'application du livreur.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(Form), findsNothing);
    });

    testWidgets('aucun libellé de données bancaires', (tester) async {
      await afficher(tester, course());

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
      await afficher(tester, course());

      // Le règlement s'ouvre depuis l'application du client
      // (`POST /payments/{commande}/initiate/`), jamais d'ici.
      expect(find.widgetWithText(ElevatedButton, 'Payer'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Payer'), findsNothing);
      expect(find.textContaining('Valider le paiement'), findsNothing);
    });
  });

  group('Informations de la course', () {
    testWidgets('affiche l’adresse et le total', (tester) async {
      await afficher(tester, course(total: 7000));

      expect(find.text('Rue du Commerce, Lomé'), findsOneWidget);
      expect(find.text('7${nbsp}000 CFA'), findsWidgets);
    });

    testWidgets('la référence est celle du serveur', (tester) async {
      await afficher(tester, course());

      // `order_reference`, et non les huit premiers caractères de l'UUID :
      // c'est la seule référence qu'un client sait lire à voix haute et que
      // le back-office sait retrouver. Le fragment d'UUID affiché jusqu'ici
      // (`#A1B2C3D4`) n'existait nulle part ailleurs que sur cet écran.
      expect(find.text('CMD-0001'), findsOneWidget);
      expect(find.text('#A1B2C3D4'), findsNothing);
    });

    testWidgets('une course sans montant reste affichable', (tester) async {
      // Servie par un serveur antérieur au lot 4, la course n'a ni total ni
      // montant à encaisser : l'écran doit rester lisible plutôt que casser.
      await afficher(tester, Course(assignment: affectation(ancienServeur: true)));

      expect(find.text('Rue du Commerce, Lomé'), findsOneWidget);
      expect(find.text('CMD-0001'), findsOneWidget);
    });
  });

  group('Le montant vient du socle', () {
    testWidgets('il s’affiche selon la règle unique, pas la sienne', (tester) async {
      // « 12 500 CFA » avec une espace insécable étroite, et non
      // « 12500 FCFA » : la règle d'affichage vit dans `Money.format()`
      // depuis le lot 2.
      await afficher(tester, course(total: 12500));

      expect(find.text('12${nbsp}500 CFA'), findsWidgets);
      expect(find.text('12500 FCFA'), findsNothing);
    });

    testWidgets('la rémunération du livreur est celle du serveur', (tester) async {
      // Elle vit sur l'affectation, et non sur un pourcentage du panier.
      // `Money` ne definit pas d'egalite de valeur : on compare les champs.
      final due = course().remuneration!;
      expect(due.amountMinor, montant(1000).amountMinor);
      expect(due.currency, 'XOF');
    });
  });
}
