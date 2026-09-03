import 'package:elcora_dely/widgets/code_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// La grille de saisie du code à usage unique.
///
/// Chacun de ces tests correspond à un geste que le livreur fait réellement, et
/// qu'un simple champ de texte casserait : coller le code lu dans son courriel,
/// corriger une faute au clavier plutôt qu'au doigt, retaper après un refus.
void main() {
  Future<void> monter(
    WidgetTester tester, {
    required void Function(String) onCompleted,
    int length = 6,
    GlobalKey<CodeInputFieldState>? key,
    void Function(String)? onChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeInputField(
            key: key,
            length: length,
            onCompleted: onCompleted,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('affiche une case par chiffre attendu', (tester) async {
    await monter(tester, onCompleted: (_) {}, length: 4);

    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('la longueur suit celle annoncée par le serveur', (tester) async {
    // Elle vient de `code_length`, pas d'une constante : une grille figée à six
    // refuserait un code que le serveur vient d'envoyer.
    await monter(tester, onCompleted: (_) {}, length: 5);

    expect(find.byType(TextField), findsNWidgets(5));
  });

  testWidgets('un chiffre saisi fait avancer d\'une case', (tester) async {
    await monter(tester, onCompleted: (_) {});

    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text, '1');
    expect(
      FocusScope.of(tester.element(find.byType(TextField).at(1))).hasFocus,
      isTrue,
    );
  });

  testWidgets('la validation part dès la dernière case remplie', (tester) async {
    String? recu;
    await monter(tester, onCompleted: (code) => recu = code, length: 3);

    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.pump();
    expect(recu, isNull);

    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.pump();
    expect(recu, isNull);

    await tester.enterText(find.byType(TextField).at(2), '3');
    await tester.pump();

    expect(recu, '123');
  });

  testWidgets('coller le code entier le répartit sur toutes les cases', (tester) async {
    // Le geste naturel après « copier » depuis le courriel. Un champ par
    // chiffre le casse par défaut : le collage n'atterrit que dans la case
    // visée.
    String? recu;
    await monter(tester, onCompleted: (code) => recu = code);

    await tester.enterText(find.byType(TextField).at(0), '482913');
    await tester.pump();

    expect(recu, '482913');
    for (var i = 0; i < 6; i++) {
      expect(
        tester.widget<TextField>(find.byType(TextField).at(i)).controller?.text,
        '482913'[i],
      );
    }
  });

  testWidgets('coller dans une case du milieu répartit quand même depuis le début',
      (tester) async {
    String? recu;
    await monter(tester, onCompleted: (code) => recu = code);

    await tester.enterText(find.byType(TextField).at(3), '482913');
    await tester.pump();

    expect(recu, '482913');
  });

  testWidgets('les caractères non numériques sont écartés', (tester) async {
    String? recu;
    await monter(tester, onCompleted: (code) => recu = code, length: 3);

    await tester.enterText(find.byType(TextField).at(0), '1a2b3c');
    await tester.pump();

    expect(recu, '123');
  });

  testWidgets('retour arrière sur une case vide revient à la précédente', (tester) async {
    await monter(tester, onCompleted: (_) {});

    await tester.enterText(find.byType(TextField).at(0), '7');
    await tester.pump();
    // Le curseur est en case 1, vide. Sans ce comportement, le livreur doit
    // viser la case précédente au doigt pour corriger.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text, isEmpty);
  });

  testWidgets('clear vide la grille après un refus du serveur', (tester) async {
    final key = GlobalKey<CodeInputFieldState>();
    await monter(tester, onCompleted: (_) {}, length: 3, key: key);

    await tester.enterText(find.byType(TextField).at(0), '123');
    await tester.pump();
    expect(key.currentState?.value, '123');

    key.currentState!.clear();
    await tester.pump();

    // Le code refusé ne vaut plus rien : le laisser affiché invite à réappuyer
    // sur « Valider » avec la même valeur.
    expect(key.currentState?.value, isEmpty);
  });

  testWidgets('onChanged est appelé à chaque frappe, pour effacer l\'erreur affichée',
      (tester) async {
    final vus = <String>[];
    await monter(tester, onCompleted: (_) {}, length: 3, onChanged: vus.add);

    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.pump();

    expect(vus, ['1', '12']);
  });
}
