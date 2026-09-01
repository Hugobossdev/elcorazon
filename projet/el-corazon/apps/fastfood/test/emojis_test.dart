import 'package:elcora_fast/presentation/catalogue.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcorazon_core/elcorazon_core.dart'
    show AppEmoji, AppEmojis, emojiDeCategorie;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le design system des emojis El Corazón.
///
/// Ce qui est éprouvé ici, ce n'est pas le dessin — aucun test ne juge une
/// illustration. C'est le **contrat** autour d'elle : que le registre reste
/// cohérent avec l'arborescence d'assets, que le mapping des catégories ne
/// dépende pas de ce que l'établissement saisit, et surtout que l'interface
/// tienne debout tant que les SVG ne sont pas produits.

eccore.Category _categorie({required String slug, String emoji = ''}) =>
    eccore.Category(
      id: 'categorie-1',
      restaurantSlug: 'el-corazon',
      name: 'Peu importe',
      slug: slug,
      emoji: emoji,
      description: '',
      sortOrder: 0,
    );

void main() {
  group('Le registre', () {
    test('compte les trente illustrations annoncées', () {
      expect(AppEmojis.toutes, hasLength(30));
    });

    test('ne nomme jamais deux fois le même fichier', () {
      final chemins = AppEmojis.toutes.map((t) => t.asset).toSet();
      expect(chemins, hasLength(AppEmojis.toutes.length));
    });

    test('range chaque illustration dans le dossier de sa famille', () {
      // Le nom du fichier est la clé du registre : un token rangé sous la
      // mauvaise famille se retrouverait cherché au mauvais endroit dans le
      // bundle, et resterait muet.
      const dossiers = {
        'Food': 'food',
        'Order': 'order',
        'Delivery': 'delivery',
        'UX': 'ux',
      };

      AppEmojis.parFamille.forEach((famille, tokens) {
        for (final token in tokens) {
          expect(
            token.asset,
            startsWith(
              'packages/elcorazon_core/assets/emojis/'
              '${dossiers[famille]}/',
            ),
            reason: '${token.libelle} n’est pas dans le dossier $famille',
          );
          expect(token.asset, endsWith('.svg'));
        }
      });
    });

    test('donne un libellé à prononcer à chacune', () {
      // Une illustration sans libellé se lit « image » à voix haute, ou pas du
      // tout : `AppEmoji` s'en sert comme valeur par défaut.
      for (final token in AppEmojis.toutes) {
        expect(token.libelle, isNotEmpty);
      }
    });
  });

  group('L’illustration d’une catégorie', () {
    test('se choisit sur le slug du serveur, pas sur son emoji', () {
      // Le champ `emoji` reste une donnée métier ; il ne dessine plus rien.
      // Un établissement qui range une pizza sous un emoji de gâteau ne doit
      // pas obtenir un gâteau.
      final categorie = _categorie(slug: 'pizzas', emoji: '🍰');
      expect(categorie.illustration, AppEmojis.pizza);
    });

    test('couvre les rubriques que le catalogue publie', () {
      // Les slugs de `seed_full_catalog` — ce que le client rencontre vraiment.
      expect(_categorie(slug: 'burgers').illustration, AppEmojis.burger);
      expect(_categorie(slug: 'grillades').illustration, AppEmojis.chicken);
      expect(_categorie(slug: 'accompagnements').illustration, AppEmojis.fries);
      expect(_categorie(slug: 'boissons').illustration, AppEmojis.drink);
      expect(_categorie(slug: 'desserts').illustration, AppEmojis.cake);
    });

    test('ne force rien sur ce que le pack ne représente pas', () {
      // « Salades » et « Spécialités Togolaises » n'ont aucune illustration
      // juste dans les trente. La version précédente posait une assiette sur
      // tout ce qu'elle ne savait pas nommer.
      expect(_categorie(slug: 'salades').illustration, isNull);
      expect(_categorie(slug: 'specialites').illustration, isNull);
      expect(_categorie(slug: '').illustration, isNull);
    });

    test('supporte une saisie approximative du slug', () {
      // Les slugs du seed sont propres, mais l'admin Django laisse saisir.
      expect(emojiDeCategorie('  BURGERS '), AppEmojis.burger);
      expect(emojiDeCategorie('ice_cream'), AppEmojis.iceCream);
    });
  });

  group('Le rendu, tant qu’aucun SVG n’est déposé', () {
    testWidgets('sert l’icône de repli plutôt qu’une zone vide',
        (tester) async {
      // C'est la condition qui permet d'avoir migré l'interface avant le pack :
      // sans ce repli, chaque point d'appel serait un carré rouge.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppEmoji(AppEmojis.burger))),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(AppEmojis.burger.repli), findsOneWidget);
    });

    testWidgets('ne retombe jamais sur un emoji Unicode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppEmoji(AppEmojis.cake))),
      );
      await tester.pumpAndSettle();

      // Aucun `Text` : le repli est une icône du design system, pas un glyphe
      // que la police du système dessinerait à notre place.
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('tient la place demandée, quelle que soit la branche',
        (tester) async {
      // Une pastille qui change de largeur en cours de route décalerait la
      // ligne entière au moment où le manifeste répond.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppEmoji(AppEmojis.star, size: 28)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppEmoji)), const Size(28, 28));
    });
  });

  group('L’accessibilité', () {
    testWidgets('annonce le libellé du token par défaut', (tester) async {
      final poignee = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppEmoji(AppEmojis.delivered))),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Commande livrée'), findsOneWidget);
      poignee.dispose();
    });

    testWidgets('se laisse remplacer par un libellé de circonstance',
        (tester) async {
      final poignee = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmoji(AppEmojis.burger, semanticsLabel: 'Nos burgers'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Nos burgers'), findsOneWidget);
      poignee.dispose();
    });

    testWidgets('disparaît de la lecture quand elle est décorative',
        (tester) async {
      // Une pastille posée devant « Burgers » n'a rien à ajouter : l'entendre
      // deux fois alourdit la lecture sans rien apprendre.
      final poignee = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppEmoji(AppEmojis.burger, decoratif: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Burger'), findsNothing);
      poignee.dispose();
    });
  });
}
