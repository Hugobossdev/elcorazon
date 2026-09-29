import 'package:admin/screens/admin/option_groups_editor.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un groupe d'options emporte tous ses choix : il disparaissait d'un clic,
/// sans confirmation ni retour possible, et se ressaisissait choix par choix.
eccore.Option _choix(String id, String nom) => eccore.Option(
      id: id,
      name: nom,
      priceDelta: const eccore.Money(amountMinor: 0, currency: 'XOF'),
      isDefault: false,
      isAvailable: true,
      sortOrder: 0,
    );

final _cuisson = eccore.OptionGroup(
  id: 'g1',
  name: 'Cuisson',
  minSelect: 1,
  maxSelect: 1,
  isRequired: true,
  sortOrder: 0,
  options: [_choix('o1', 'Saignant'), _choix('o2', 'À point')],
);

void main() {
  late List<List<eccore.OptionGroup>> envois;

  Future<void> monter(WidgetTester tester) async {
    envois = [];
    tester.view.physicalSize = const Size(2400, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OptionGroupsEditor(
              menuItemId: 'plat-1',
              initialGroups: [_cuisson],
              onChanged: envois.add,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('supprimer un groupe se confirme, en disant ce qui part avec lui',
      (tester) async {
    await monter(tester);

    await tester.tap(find.byTooltip('Supprimer le groupe'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer le groupe « Cuisson » ?'), findsOneWidget);
    expect(find.textContaining('Ses 2 choix partent avec lui'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(envois, isEmpty, reason: 'annuler ne touche à rien');
    expect(find.text('Cuisson'), findsOneWidget);

    await tester.tap(find.byTooltip('Supprimer le groupe'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(envois.single, isEmpty);
    expect(find.text('Cuisson'), findsNothing);
  });

  testWidgets('retirer un choix se confirme aussi', (tester) async {
    await monter(tester);
    await tester.tap(find.text('Cuisson'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Retirer le choix').first);
    await tester.pumpAndSettle();
    expect(find.text('Retirer « Saignant » ?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retirer'));
    await tester.pumpAndSettle();

    expect(envois.single.single.options.map((o) => o.name), ['À point']);
  });
}
