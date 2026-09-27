import 'package:elcora_fast/widgets/design/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Photos des catégories (lot 3) dans les puces de l'accueil : la photo passe
/// avant l'illustration, et une puce sans photo reste une puce.
void main() {
  Future<void> monter(WidgetTester tester, {String? Function(int)? photo}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryChipBar(
            labels: const ['Tout', 'Grillades'],
            selectedIndex: 0,
            onSelected: (_) {},
            photoBuilder: photo,
          ),
        ),
      ),
    );
  }

  testWidgets('une catégorie avec photo la montre dans sa puce', (tester) async {
    await monter(tester, photo: (i) => i == 1 ? 'https://cdn.test/grillades.webp' : null);

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(1));
    expect((images.single.image as NetworkImage).url, 'https://cdn.test/grillades.webp');
    expect(find.text('Grillades'), findsOneWidget);
  });

  testWidgets('sans photo, aucune image n’est demandée', (tester) async {
    await monter(tester);

    expect(find.byType(Image), findsNothing);
    expect(find.text('Grillades'), findsOneWidget);
  });
}
