import 'package:admin/presentation/relecture_en_direct.dart';
import 'package:admin/services/dashboard_realtime_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Les écrans qui suivent le service sans rechargement manuel.
///
/// « Livraisons actives » et le tableau de bord, laissés ouverts, montraient
/// une liste figée : le temps réel n'était écouté que par l'écran Commandes.
class _Ecran extends StatefulWidget {
  const _Ecran({required this.relectures});

  final List<DateTime> relectures;

  @override
  State<_Ecran> createState() => _EcranState();
}

class _EcranState extends State<_Ecran> with RelectureEnDirect<_Ecran> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => brancherLeDirect());
  }

  @override
  Future<void> relireEnDirect() async => widget.relectures.add(DateTime.now());

  // Pas de socket en test : les événements sont injectés.
  @override
  Future<void> connecterLeDirect(DashboardRealtimeService temps) async {}

  @override
  Widget build(BuildContext context) => const SizedBox();
}

eccore.RealtimeEvent _statut(String commande) => eccore.RealtimeEvent.fromJson({
      'seq': 1,
      'type': 'order.status',
      'order': commande,
      'reference': 'EC000001',
      'from_status': 'preparing',
      'status': 'ready',
    });

void main() {
  late DashboardRealtimeService temps;
  late List<DateTime> relectures;

  setUp(() {
    temps = DashboardRealtimeService.pourTests();
    relectures = [];
  });
  tearDown(() => temps.dispose());

  Future<void> monter(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DashboardRealtimeService>.value(
        value: temps,
        child: MaterialApp(home: _Ecran(relectures: relectures)),
      ),
    );
    await tester.pump();
  }

  testWidgets('un coup de feu ne déclenche qu’une relecture', (tester) async {
    await monter(tester);

    for (var i = 0; i < 5; i++) {
      temps.traiterPourTests(_statut('commande-$i'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(relectures, isEmpty, reason: 'regroupées, pas encore relues');

    await tester.pump(const Duration(seconds: 2));
    expect(relectures, hasLength(1));
  });

  testWidgets('un canal muet est rattrapé par le filet', (tester) async {
    await monter(tester);

    await tester.pump(const Duration(minutes: 1));

    expect(relectures, hasLength(1));
  });

  testWidgets('l’écran quitté n’écoute plus', (tester) async {
    await monter(tester);
    await tester.pumpWidget(const SizedBox());

    temps.traiterPourTests(_statut('commande-1'));
    await tester.pump(const Duration(minutes: 2));

    expect(relectures, isEmpty);
  });

  testWidgets('« Actualiser » a une infobulle, et se neutralise pendant la lecture',
      (tester) async {
    var appuis = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BoutonActualiser(onPressed: () => appuis++)),
      ),
    );
    await tester.tap(find.byTooltip('Actualiser'));
    expect(appuis, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BoutonActualiser(onPressed: () => appuis++, enCours: true)),
      ),
    );
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
  });
}
