import 'package:admin/widgets/suivi_activite.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce qui compte comme une activité de l'opérateur.
///
/// `AdminAuthService.recordActivity` n'avait aucun appelant : la déconnexion
/// automatique tombait trente minutes après la connexion, en plein travail.
/// Ces cas gardent le branchement — et ce qu'il ne doit pas casser.
void main() {
  Future<int Function()> monter(WidgetTester tester, {Widget? enfant}) async {
    var activites = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SuiviActivite(
          onActivite: () => activites++,
          child: child!,
        ),
        home: Scaffold(body: enfant ?? const SizedBox.expand()),
      ),
    );
    return () => activites;
  }

  testWidgets('un clic est une activité', (tester) async {
    final compte = await monter(tester);

    await tester.tapAt(const Offset(100, 100));

    expect(compte(), 1);
  });

  testWidgets('une frappe au clavier est une activité', (tester) async {
    // Saisir un long formulaire sans toucher la souris, c'est travailler.
    final compte = await monter(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

    expect(compte(), 1, reason: 'seul l’appui compte, pas le relâchement');
  });

  testWidgets('un tour de molette est une activité', (tester) async {
    final compte = await monter(tester);

    final pointeur = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointeur.hover(const Offset(50, 50)));
    await tester.sendEventToBinding(pointeur.scroll(const Offset(0, 40)));

    expect(compte(), 1, reason: 'le survol seul ne compte pas, la molette si');
  });

  testWidgets('le clic arrive toujours au bouton visé', (tester) async {
    // Le suivi est translucide : il observe, il n'intercepte rien.
    var presse = false;
    final compte = await monter(
      tester,
      enfant: Center(
        child: ElevatedButton(onPressed: () => presse = true, child: const Text('Valider')),
      ),
    );

    await tester.tap(find.text('Valider'));

    expect(presse, isTrue);
    expect(compte(), 1);
  });

  testWidgets('une boîte de dialogue est couverte', (tester) async {
    // C'est dans un formulaire en boîte de dialogue qu'une déconnexion coûte
    // le plus — d'où le suivi posé au-dessus du `Navigator`.
    final compte = await monter(
      tester,
      enfant: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const AlertDialog(content: Text('Formulaire')),
          ),
          child: const Text('Ouvrir'),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Formulaire'));

    expect(compte(), 2);
  });
}
