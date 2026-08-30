import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/screens/onboarding_screen.dart';
import 'package:elcora_fast/screens/client/widgets/quick_actions_widget.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/cart_item_card.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/menu_item_card.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Débordements de mise en page — le bandeau rayé jaune et noir.
///
/// Un débordement n'est pas un défaut d'esthétique : Flutter **écrête** ce qui
/// dépasse. Le prix, le bouton d'ajout ou le total d'une ligne disparaissent
/// alors sous la bordure, et l'écran devient inutilisable là où il sert le
/// plus.
///
/// Ces cas rejouent les contraintes **réelles** — celles que la grille du menu,
/// les carrousels de l'accueil et le panier imposent à leurs cartes — sur un
/// éventail de tailles d'écran et d'échelles de texte. Une taille moyenne ne
/// prouve rien : le débordement se produit aux extrêmes, sur le petit téléphone
/// et chez qui a grossi la police de son système.
///
/// Rien n'est asserté : un débordement lève de lui-même, et `flutter_test`
/// fait échouer le cas. L'assertion, c'est le rendu.
void main() {
  /// Tailles d'écran de référence, en pixels logiques.
  const ecrans = <String, Size>{
    'petit téléphone (320x640)': Size(320, 640),
    'téléphone courant (360x740)': Size(360, 740),
    'grand téléphone (412x915)': Size(412, 915),
    'tablette (768x1024)': Size(768, 1024),
    'navigateur de bureau (1280x800)': Size(1280, 800),
  };

  /// Échelles de texte. 1.0 est le défaut ; 1.3 est courant chez qui a besoin
  /// de lire sans lunettes, et reste en deçà des réglages d'accessibilité
  /// extrêmes qu'Android et iOS autorisent.
  const echelles = <double>[1.0, 1.3];

  eccore.MenuItem article({
    String nom = 'Demi-poulet yassa braisé au feu de bois',
    double note = 4.6,
  }) {
    return eccore.MenuItem(
      id: 'article-1',
      restaurantSlug: 'el-corazon',
      categorySlug: 'grillades',
      categoryName: 'Grillades',
      name: nom,
      slug: 'demi-poulet-yassa',
      description: 'Poulet mariné au citron confit, servi avec attiéké',
      image:
          'http://localhost:9000/elcorazon-products/menu/demi-poulet-yassa.jpg',
      price: const eccore.Money(amountMinor: 4500, currency: 'XOF'),
      preparationMinutes: 25,
      allergens: const [],
      dietaryTags: const [],
      isAvailable: true,
      isPopular: true,
      vipExclusive: false,
      ratingAverage: note,
      ratingCount: 42,
      sortOrder: 1,
    );
  }

  /// Pompe [enfant] sur un écran de taille donnée.
  ///
  /// C'est [enfant] qui se contraint lui-même, à partir du `BuildContext` :
  /// les cas ci-dessous rejouent le calcul de l'écran de production plutôt que
  /// d'inventer des dimensions, faute de quoi ils prouveraient seulement que
  /// des nombres choisis par le test s'accordent entre eux.
  Future<void> poser(
    WidgetTester tester,
    Widget enfant, {
    required Size ecran,
    required double echelle,
  }) async {
    tester.view.physicalSize = ecran;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: ecran,
          textScaler: TextScaler.linear(echelle),
        ),
        child: MaterialApp(
          theme: lightTheme,
          home: Scaffold(body: enfant),
        ),
      ),
    );
    await tester.pump();
  }

  group('Grille du menu', () {
    /// Reprend le montage de `menu_screen.dart` : marge, gouttière, puis la
    /// géométrie partagée avec l'écran.
    Widget grille({int quantite = 0}) {
      return Builder(
        builder: (context) {
          final taille = MediaQuery.sizeOf(context);
          final petit = taille.width < 360 || taille.height < 640;
          final marge = petit ? 12.0 : 16.0;
          final geometrie = GeometrieGrille.calculer(
            context: context,
            largeurDisponible: taille.width - 2 * marge,
            gouttiere: marge,
          );

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: marge),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: geometrie.colonnes,
                crossAxisSpacing: marge,
                mainAxisSpacing: marge,
                mainAxisExtent: geometrie.hauteurCellule,
              ),
              itemCount: 6,
              itemBuilder: (context, index) => MenuItemCard(
                item: article(),
                onTap: () {},
                onAddToCart: () {},
                onDecrement: () {},
                onFavoriteTap: () {},
                quantity: quantite,
              ),
            ),
          );
        },
      );
    }

    for (final ecran in ecrans.entries) {
      for (final echelle in echelles) {
        testWidgets(
          'les cartes tiennent dans leur cellule — ${ecran.key}, texte x$echelle',
          (tester) async {
            await poser(tester, grille(), ecran: ecran.value, echelle: echelle);
          },
        );
      }
    }

    testWidgets('les cartes tiennent quand l\'article est déjà au panier',
        (tester) async {
      // La quantité remplace le bouton d'ajout par un compteur pleine largeur.
      await poser(
        tester,
        grille(quantite: 12),
        ecran: const Size(320, 640),
        echelle: 1.3,
      );
    });

    testWidgets('la grille s\'élargit au lieu d\'étirer les cartes',
        (tester) async {
      // Le défaut que corrige `GeometrieGrille` : deux colonnes imposées
      // donnaient des cartes de 600 px de large dans un navigateur.
      late GeometrieGrille surBureau;
      await poser(
        tester,
        Builder(
          builder: (context) {
            surBureau = GeometrieGrille.calculer(
              context: context,
              largeurDisponible: 1280 - 32,
              gouttiere: 16,
            );
            return const SizedBox.shrink();
          },
        ),
        ecran: const Size(1280, 800),
        echelle: 1.0,
      );

      expect(surBureau.colonnes, 6);
      expect(surBureau.largeurCellule, lessThan(220));
    });
  });

  group('Carrousels de l\'accueil', () {
    for (final ecran in ecrans.entries) {
      for (final echelle in echelles) {
        testWidgets(
          'une carte tient dans le carrousel — ${ecran.key}, texte x$echelle',
          (tester) async {
            await poser(
              tester,
              Builder(
                builder: (context) {
                  // `client_home_screen.dart` : largeur fixe, hauteur demandée
                  // à la carte.
                  final petit = MediaQuery.sizeOf(context).width < 360;
                  final largeur = petit ? 170.0 : 190.0;
                  return SizedBox(
                    height: MenuItemCard.hauteurPour(context, largeur) +
                        (petit ? 4 : 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      itemBuilder: (context, index) => Container(
                        width: largeur,
                        margin: EdgeInsets.only(
                          right: petit ? 12 : 16,
                          bottom: petit ? 4 : 8,
                        ),
                        child: MenuItemCard(
                          item: article(),
                          onTap: () {},
                          onAddToCart: () {},
                        ),
                      ),
                    ),
                  );
                },
              ),
              ecran: ecran.value,
              echelle: echelle,
            );
          },
        );
      }
    }
  });

  group('Panier', () {
    for (final echelle in echelles) {
      testWidgets('une ligne de panier tient sur la largeur — texte x$echelle',
          (tester) async {
        // Dans `cart_screen.dart` la ligne vit dans une liste : sa largeur est
        // contrainte, sa hauteur libre. La contraindre aussi en hauteur
        // inventerait un débordement qui ne se produit pas.
        await poser(
          tester,
          ListView(
            padding: const EdgeInsets.all(12),
            children: [
              CartItemCard(
                item: CartItem(
                  id: 'ligne-1',
                  menuItemId: 'article-1',
                  name: 'Demi-poulet yassa braisé au feu de bois',
                  price: 4500,
                  quantity: 12,
                  customizations: const {
                    'cuisson': 'bien cuit',
                    'piment': 'fort',
                  },
                ),
                onRemove: () {},
                onQuantityChanged: (_) {},
              ),
            ],
          ),
          ecran: const Size(320, 640),
          echelle: echelle,
        );
      });
    }
  });

  group('Presentation d’ouverture', () {
    // Les trois pages sont bâties sur des dégradés et des icônes, sans
    // photographie : leur hauteur suit donc entièrement le texte, et c'est ce
    // que ce cas surveille. L'illustration prend une **part** de la hauteur
    // disponible plutôt qu'un nombre de pixels, précisément pour qu'un
    // téléphone court avec la police grossie garde de la place pour le titre.
    for (final ecran in ecrans.entries) {
      for (final echelle in echelles) {
        testWidgets(
          'la page courante tient — ${ecran.key}, texte x$echelle',
          (tester) async {
            await poser(
              tester,
              const OnboardingScreen(),
              ecran: ecran.value,
              echelle: echelle,
            );
          },
        );
      }
    }
  });

  group('Commande de gateau', () {
    // La maquette `cake_order` empile des etapes numerotees et ancre un
    // bandeau « total estime + action » en bas. Ces deux montages sont ceux
    // que `cake_order_screen.dart` construit, rejoues sans service : ce qui se
    // casse ici est une contrainte de mise en page, pas un etat applicatif.

    /// Le couple date / heure de l’etape « Retrait ou livraison ».
    ///
    /// Ce montage a **deja casse** : les deux boutons vivaient dans un `Wrap`
    /// et se declaraient `Expanded`, or `Expanded` exige un parent `Flex`.
    /// L’etape levait donc des son ouverture. Le cas la tient fermee.
    Widget couplageDateHeure() {
      return Row(
        children: [
          Expanded(
            child: ActionButton(
              label: 'Choisir une date',
              emphasis: ActionEmphasis.outlined,
              icon: Icons.calendar_month_rounded,
              height: 48,
              onPressed: () {},
            ),
          ),
          const SizedBox(width: DesignConstants.gutter),
          Expanded(
            child: ActionButton(
              label: 'Choisir une heure',
              emphasis: ActionEmphasis.outlined,
              icon: Icons.schedule_rounded,
              height: 48,
              onPressed: () {},
            ),
          ),
        ],
      );
    }

    /// Une etape numerotee, avec le plus long libelle d’option realiste.
    Widget etapeNumerotee() {
      return OptionGroupCard(
        title: '3. Taille et nombre de parts',
        isRequired: true,
        constraintLabel: 'Un seul choix',
        children: [
          Column(
            children: [
              OptionRow(
                label: 'Deux etages sur mesure (16 a 20 parts)',
                subtitle: 'Genoise vanille de Madagascar, ganache montee',
                selected: true,
                priceDelta: '+25 000 F CFA',
                onChanged: (_) {},
              ),
              OptionRow(
                label: '20 cm (10 a 12 parts)',
                selected: false,
                priceDelta: '+8 000 F CFA',
                showDivider: false,
                onChanged: (_) {},
              ),
            ],
          ),
        ],
      );
    }

    /// Le bandeau ancre : le montant le plus large que la carte puisse porter,
    /// a cote d’une action qui ne doit pas se faire ecraser.
    Widget bandeau() {
      return GlassBottomBar(
        child: StickySummaryBar(
          label: 'Total estime',
          amount: '125 000 F CFA',
          action: ActionButton(
            label: 'Commander',
            emphasis: ActionEmphasis.gradient,
            icon: Icons.cake_rounded,
            onPressed: () {},
          ),
        ),
      );
    }

    for (final ecran in ecrans.entries) {
      for (final echelle in echelles) {
        testWidgets(
          'l’etape date/heure tient — ${ecran.key}, texte x$echelle',
          (tester) async {
            await poser(
              tester,
              Padding(
                padding: const EdgeInsets.all(DesignConstants.edgeMargin),
                child: couplageDateHeure(),
              ),
              ecran: ecran.value,
              echelle: echelle,
            );
          },
        );

        testWidgets(
          'une etape numerotee tient — ${ecran.key}, texte x$echelle',
          (tester) async {
            await poser(
              tester,
              ListView(
                padding: const EdgeInsets.all(DesignConstants.edgeMargin),
                children: [etapeNumerotee()],
              ),
              ecran: ecran.value,
              echelle: echelle,
            );
          },
        );

        testWidgets(
          'le bandeau total + action tient — ${ecran.key}, texte x$echelle',
          (tester) async {
            await poser(
              tester,
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [bandeau()],
              ),
              ecran: ecran.value,
              echelle: echelle,
            );
          },
        );
      }
    }
  });

  group('Fidelite et notation', () {
    // Ces montages viennent des ecrans du second lot Stitch. Ils n'ont besoin
    // d'aucun service : ce qui se casse ici est une contrainte de mise en
    // page, pas un etat applicatif.

    /// La carte de palier des recompenses : un grand nombre, une barre, une
    /// phrase. Le nombre est ce qui deborde — un solde a cinq chiffres avec la
    /// police grossie occupe la moitie de la largeur.
    Widget cartePalier() {
      return Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final encre = theme.colorScheme.onSecondaryContainer;
          return Container(
            padding: const EdgeInsets.all(DesignConstants.spacingL),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.secondaryGradient,
              ),
              borderRadius: DesignConstants.borderRadiusLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: encre),
                    const SizedBox(width: DesignConstants.spacingS),
                    Expanded(
                      child: Text(
                        'Palier Standard',
                        style: AppTypography.titleLg(color: encre),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignConstants.spacingM),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        '128450',
                        style: AppTypography.displayLg(color: encre),
                      ),
                    ),
                    const SizedBox(width: DesignConstants.spacingS),
                    Text('pts', style: AppTypography.titleLg(color: encre)),
                  ],
                ),
                const SizedBox(height: DesignConstants.spacingM),
                Text(
                  '550 points jusqu’au palier Fidele',
                  style: AppTypography.bodyMd(color: encre),
                ),
              ],
            ),
          );
        },
      );
    }

    /// Le bloc de notation d'un plat : cinq etoiles, des puces, un champ.
    Widget blocDeNotation() {
      return SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) => Text(
                'Demi-poulet yassa braise au feu de bois',
                style: AppTypography.titleLg(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: DesignConstants.spacingM),
            RatingStars(note: 4, onChanged: (_) {}),
            const SizedBox(height: DesignConstants.spacingM),
            AppreciationChips(
              options: const [
                'Tres bon',
                'Bien assaisonne',
                'Servi chaud',
                'Portion genereuse',
                'Bien emballe',
              ],
              retenues: const {'Servi chaud'},
              onChanged: (_) {},
            ),
          ],
        ),
      );
    }

    for (final ecran in ecrans.entries) {
      for (final echelle in echelles) {
        testWidgets(
          'la carte de palier tient — ${ecran.key}, texte x$echelle',
          (tester) async {
            await poser(
              tester,
              ListView(
                padding: const EdgeInsets.all(DesignConstants.edgeMargin),
                children: [cartePalier()],
              ),
              ecran: ecran.value,
              echelle: echelle,
            );
          },
        );

        testWidgets(
          'le bloc de notation tient — ${ecran.key}, texte x$echelle',
          (tester) async {
            await poser(
              tester,
              ListView(
                padding: const EdgeInsets.all(DesignConstants.edgeMargin),
                children: [blocDeNotation()],
              ),
              ecran: ecran.value,
              echelle: echelle,
            );
          },
        );
      }
    }
  });

  group('Actions rapides de l\'accueil', () {
    for (final ecran in ecrans.entries) {
      for (final echelle in echelles) {
        testWidgets(
          'les tuiles tiennent — ${ecran.key}, texte x$echelle',
          (tester) async {
            await poser(
              tester,
              const SingleChildScrollView(child: QuickActionsWidget()),
              ecran: ecran.value,
              echelle: echelle,
            );
          },
        );
      }
    }
  });
}
