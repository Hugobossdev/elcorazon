import 'package:admin/presentation/onglets/statistiques_commandes.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'onglet « Statistiques », à l'écran — alimenté par l'agrégat serveur.
///
/// Les règles de mesure (durée réelle, ponctualité sur les seules commandes
/// promises) sont éprouvées côté serveur
/// (`backend/tests/orders/test_statistiques_backoffice.py`). Ce qui l'est ici :
/// que l'onglet lit bien les champs que le serveur rend — il lisait autrefois
/// des clés que le calcul local ne produisait pas, et affichait « 0.0% » sur
/// toutes les commandes — et qu'il ne mêle jamais deux devises.
eccore.OrderStatistics _stats({
  int mesurees = 2,
  double? moyenne = 50,
  int promises = 2,
  double? ponctualite = 50,
  List<Map<String, dynamic>> revenus = const [
    {'currency': 'XOF', 'orders_delivered': 2, 'revenue_minor': 8000, 'average_basket_minor': 4000},
  ],
}) {
  return eccore.OrderStatistics.fromJson({
    'orders_count': 4,
    'by_status': {
      'pending': 1,
      'confirmed': 0,
      'preparing': 0,
      'ready': 0,
      'picked_up': 0,
      'on_the_way': 0,
      'delivered': 2,
      'cancelled': 1,
    },
    'revenues': revenus,
    'delivery': {
      'measured_orders': mesurees,
      'average_minutes': moyenne,
      'fastest_minutes': moyenne,
      'slowest_minutes': moyenne,
      'on_time_measured': promises,
      'on_time_rate': ponctualite,
    },
    'cancellation_rate': 25.0,
    'per_day': const <Map<String, dynamic>>[],
    'per_day_from': '2026-08-01',
    'timezone_name': 'Africa/Lome',
  });
}

void main() {
  Future<void> monter(WidgetTester tester, eccore.OrderStatistics? stats) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OngletStatistiques(
            orderService: OrderManagementService.pourTests(const [], statistiques: stats),
          ),
        ),
      ),
    );
  }

  testWidgets('la ponctualité affichée est celle que le serveur mesure', (tester) async {
    await monter(tester, _stats());

    expect(find.text('50 %'), findsOneWidget);
    expect(find.text('À temps · 2 annoncée(s)'), findsOneWidget);
    expect(find.text('50 min'), findsOneWidget);
    expect(find.text('25.0 %'), findsOneWidget);
  });

  testWidgets('aucune carte ne prétend mesurer une satisfaction', (tester) async {
    await monter(tester, _stats());

    expect(find.textContaining('Satisfaction'), findsNothing);
    expect(find.textContaining('/5'), findsNothing);
    expect(find.text('Annulations'), findsOneWidget);
  });

  testWidgets('sans livraison mesurée, les durées s’affichent « — », pas zéro', (tester) async {
    await monter(
      tester,
      _stats(mesurees: 0, moyenne: null, promises: 0, ponctualite: null, revenus: const []),
    );

    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('0 min'), findsNothing);
    expect(find.text('Aucune livraison'), findsOneWidget);
  });

  testWidgets('deux devises, deux lignes — jamais un total mêlé', (tester) async {
    await monter(
      tester,
      _stats(
        revenus: const [
          {'currency': 'XAF', 'orders_delivered': 1, 'revenue_minor': 10000, 'average_basket_minor': 10000},
          {'currency': 'XOF', 'orders_delivered': 2, 'revenue_minor': 6000, 'average_basket_minor': 3000},
        ],
      ),
    );

    expect(find.text('Revenus livrés (XAF)'), findsOneWidget);
    expect(find.text('Revenus livrés (XOF)'), findsOneWidget);
    expect(find.textContaining('16'), findsNothing);
  });

  testWidgets('avant la première lecture, un indicateur et non des zéros', (tester) async {
    await monter(tester, null);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
