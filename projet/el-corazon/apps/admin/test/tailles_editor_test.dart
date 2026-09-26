import 'package:admin/screens/admin/tailles_editor.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tailles d'un plat au back-office (lot 2) : ce qu'on voit est ce que le
/// serveur a retenu, et chaque geste lui est confié avant d'être montré.

eccore.TailleGeree _taille(
  String id,
  String nom,
  int prix, {
  bool disponible = true,
  bool active = true,
  int ordre = 0,
}) =>
    eccore.TailleGeree(
      id: id,
      menuItemId: 'pizza',
      name: nom,
      price: eccore.Money(amountMinor: prix, currency: 'XOF'),
      isAvailable: disponible,
      isActive: active,
      sortOrder: ordre,
    );

class _Depot implements eccore.ManagedCatalogRepository {
  _Depot(this.enBase);

  List<eccore.TailleGeree> enBase;
  final List<String> ecritures = [];
  Object? refus;

  @override
  Future<List<eccore.TailleGeree>> tailles(String menuItemId) async => List.unmodifiable(enBase);

  @override
  Future<eccore.TailleGeree> modifierTaille(
    String tailleId, {
    String? nom,
    eccore.Money? prix,
    String? sku,
    bool? disponible,
    bool? active,
    int? ordre,
  }) async {
    if (refus != null) throw refus!;
    ecritures.add('$tailleId disponible=$disponible active=$active');
    enBase = [
      for (final t in enBase)
        t.id == tailleId
            ? _taille(
                t.id,
                t.name,
                t.price.amountMinor,
                disponible: disponible ?? t.isAvailable,
                active: active ?? t.isActive,
                ordre: t.sortOrder,
              )
            : t,
    ];
    return enBase.firstWhere((t) => t.id == tailleId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _monter(WidgetTester tester, _Depot depot, {String menuItemId = 'pizza'}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TaillesEditor(menuItemId: menuItemId, devise: 'XOF', depot: depot),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('les tailles s’affichent dans l’ordre du catalogue, avec leur prix', (tester) async {
    final depot = _Depot([
      _taille('g', 'Grande', 3500, ordre: 2),
      _taille('p', 'Petite', 2500),
      _taille('m', 'Moyenne', 3000, ordre: 1, active: false),
    ]);

    await _monter(tester, depot);

    final noms = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tuile) => (tuile.title! as Text).data)
        .toList();
    expect(noms, ['Petite', 'Moyenne', 'Grande']);
    expect(find.textContaining('retirée de la carte'), findsOneWidget);
  });

  testWidgets('marquer une taille épuisée passe par le serveur, puis relit', (tester) async {
    final depot = _Depot([_taille('p', 'Petite', 2500)]);
    await _monter(tester, depot);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(depot.ecritures, ['p disponible=false active=null']);
    expect(find.textContaining('épuisée'), findsOneWidget);
  });

  testWidgets('un refus du serveur est dit, et la taille reste telle quelle', (tester) async {
    final depot = _Depot([_taille('p', 'Petite', 2500)])
      ..refus = const eccore.ApiException(status: 403, code: 'permission_denied', detail: 'Refusé');
    await _monter(tester, depot);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('un plat pas encore créé ne propose pas d’ajouter une taille', (tester) async {
    await _monter(tester, _Depot(const []), menuItemId: '');

    expect(find.text('Ajouter une taille'), findsNothing);
    expect(find.textContaining('Enregistrez d’abord le plat'), findsOneWidget);
  });
}
