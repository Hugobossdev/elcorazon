import 'package:admin/presentation/onglets/statistiques_commandes.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aide_commande.dart';

/// Les cartes de l'onglet « Statistiques », à l'écran.
///
/// Les tests de `statistiques_livraison_test.dart` prouvent que le service
/// calcule juste ; ils ne voyaient pas que l'onglet lisait d'autres clés que
/// celles qu'il rend. « Livraison à temps » affichait `0.0%` et
/// « Satisfaction » `0.0/5` quelles que soient les commandes — le calcul était
/// bon, et personne ne le lisait.
void main() {
  final passeeLe = DateTime(2026, 8, 8, 12);

  Future<void> monter(WidgetTester tester, OrderManagementService service) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: OngletStatistiques(orderService: service))),
    );
  }

  testWidgets('la ponctualité affichée est celle que le service mesure', (tester) async {
    // Deux livraisons annoncées : l'une tient sa promesse, l'autre non.
    final service = OrderManagementService.pourTests([
      commandeDeTest(
        id: 'a-l-heure',
        statut: 'delivered',
        passeeLe: passeeLe,
        livraisonPrevueLe: passeeLe.add(const Duration(minutes: 40)),
        livreeLe: passeeLe.add(const Duration(minutes: 30)),
      ),
      commandeDeTest(
        id: 'en-retard',
        statut: 'delivered',
        passeeLe: passeeLe,
        livraisonPrevueLe: passeeLe.add(const Duration(minutes: 40)),
        livreeLe: passeeLe.add(const Duration(minutes: 70)),
      ),
    ]);

    await monter(tester, service);

    expect(find.text('50 %'), findsOneWidget);
    expect(find.text('À temps · 2 annoncée(s)'), findsOneWidget);
    expect(find.text('50 min'), findsOneWidget);
  });

  testWidgets('aucune carte ne prétend mesurer une satisfaction', (tester) async {
    // Aucun client ne note une commande : un « /5 » sous une étoile ne
    // pouvait être qu'un zéro ou un nombre inventé.
    await monter(tester, OrderManagementService.pourTests(const []));

    expect(find.textContaining('Satisfaction'), findsNothing);
    expect(find.textContaining('/5'), findsNothing);
    expect(find.text('Annulations'), findsOneWidget);
  });

  testWidgets('sans livraison mesurée, les durées s’affichent « — », pas zéro', (tester) async {
    await monter(
      tester,
      OrderManagementService.pourTests([
        commandeDeTest(statut: 'confirmed', passeeLe: passeeLe),
      ]),
    );

    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('0 min'), findsNothing);
  });
}
