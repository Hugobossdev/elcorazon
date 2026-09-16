import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/changement_de_cuisine.dart';
import 'package:elcora_fast/services/kitchen_context_service.dart';
import 'package:elcora_fast/widgets/zone_not_serviceable_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que le client lit quand sa cuisine change, ou qu'aucune ne le livre.
void main() {
  group('le panier ne suit pas la cuisine, et le client le sait', () {
    test('la confirmation nomme les deux cuisines et ce qui reste', () {
      final phrase = ChangementDeCuisine.confirmation(
        ancienne: 'El Corazón Cocody',
        nouvelle: 'El Corazón Yopougon',
        articles: 3,
      );

      expect(phrase, contains('3 articles de El Corazón Cocody'));
      expect(phrase, contains('reste enregistré'));
    });

    test('l\'avis dit l\'adresse, et le singulier', () {
      expect(
        ChangementDeCuisine.avis(ancienne: 'Cocody', nouvelle: 'Plateau', articles: 1),
        'Votre adresse est livrée par Plateau. Votre panier de Cocody '
        '(1 article) reste enregistré si vous y revenez.',
      );
    });

    testWidgets('refuser la confirmation garde la cuisine', (tester) async {
      late Future<bool> reponse;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => reponse = ChangementDeCuisine.confirmer(
                context,
                ancienne: 'Cocody',
                nouvelle: 'Plateau',
                articles: 2,
              ),
              child: const Text('changer'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('changer'));
      await tester.pumpAndSettle();
      expect(find.text('Passer à Plateau ?'), findsOneWidget);

      await tester.tap(find.text('Rester sur Cocody'));
      await tester.pumpAndSettle();
      expect(await reponse, isFalse);
    });
  });

  group('aucune cuisine ne livre l\'adresse', () {
    testWidgets('le titre du cahier, le motif du serveur, et deux issues', (tester) async {
      var villeChangee = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => ZoneNotServiceableDialog.show(
                context,
                raison: 'Adresse à 18,2 km, au-delà des 15 km desservis.',
                onChooseAnotherAddress: () {},
                onChangeCity: () => villeChangee = true,
              ),
              child: const Text('vérifier'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('vérifier'));
      await tester.pumpAndSettle();

      expect(find.text('Nous ne livrons pas encore dans cette zone.'), findsOneWidget);
      expect(find.text('Adresse à 18,2 km, au-delà des 15 km desservis.'), findsOneWidget);

      await tester.tap(find.text('Changer de ville'));
      await tester.pumpAndSettle();

      // Le dialogue se ferme **avant** l'action : il restait ouvert par-dessus.
      expect(villeChangee, isTrue);
      expect(find.byType(ZoneNotServiceableDialog), findsNothing);
    });
  });

  test('une fermeture exceptionnelle se lit comme une fermeture', () {
    expect(
      SituationCuisine.depuisMotif(eccore.MotifIndisponibilite.cuisineFermeeExceptionnellement),
      SituationCuisine.fermee,
    );
  });
}
