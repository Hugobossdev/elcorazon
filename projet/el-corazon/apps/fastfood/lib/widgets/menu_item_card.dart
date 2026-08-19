import 'dart:math' as math;

import 'package:elcora_fast/presentation/catalogue.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

/// Carte d'un article du menu.
///
/// ## Pourquoi la hauteur est calculée et non devinée
///
/// La version précédente partageait la carte en `Expanded(flex: 3)` pour la
/// photo et `Expanded(flex: 2)` pour le texte. Un rapport fixe ne sait rien de
/// ce qu'il contient : dès que le nom passait sur deux lignes, ou que le
/// système grossissait la police, la pile texte + prix + bouton dépassait les
/// deux cinquièmes qu'on lui avait concédés et Flutter **écrêtait le bas de la
/// carte** — le prix et le bouton d'ajout disparaissaient sous le bandeau rayé.
/// Cela se produisait sur tous les téléphones, à l'échelle de police par
/// défaut, pas seulement aux extrêmes.
///
/// Le montage est donc inversé :
///
/// * le **texte prend la hauteur qu'il lui faut** — il ne peut plus être
///   comprimé, donc il ne peut plus déborder ;
/// * la **photo absorbe le reste** (`Expanded`) — elle se contente de ce qui
///   demeure, et c'est bien elle qui doit céder ;
/// * [hauteurPour] publie la hauteur idéale d'une carte d'une largeur donnée,
///   pour que la grille et les carrousels la réservent au lieu de l'inventer.
///
/// ## Ce qui flotte sur la photo
///
/// Le cœur, la note et le bouton d'ajout sont posés **sur l'image**. Ce n'est
/// pas un effet de style : rangés en ligne sous le prix, ils se disputaient une
/// largeur de 100 px sur un petit téléphone — et le débordement passait alors
/// à l'horizontale.
class MenuItemCard extends StatelessWidget {
  const MenuItemCard({
    required this.item,
    required this.onTap,
    super.key,
    this.onAddToCart,
    this.onDecrement,
    this.onFavoriteTap,
    this.isFavorite = false,
    this.quantity = 0,
  });

  final eccore.MenuItem item;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onDecrement;

  /// Bascule le favori. `null` masque le cœur — dans un carrousel d'accueil,
  /// par exemple, où il n'aurait pas de sens.
  final VoidCallback? onFavoriteTap;
  final bool isFavorite;

  /// Quantité déjà au panier. Au-delà de zéro, le bouton d'ajout devient un
  /// compteur.
  final int quantity;

  // -- métriques ------------------------------------------------------
  //
  // Les tailles de police et les interlignes sont **explicites** pour que la
  // hauteur du bloc de texte soit calculable à l'avance plutôt que constatée
  // après coup. C'est ce qui permet à la grille de réserver la bonne place.

  static const double _tailleNom = 14;
  static const double _interligneNom = 1.25;
  static const int _lignesNom = 2;
  static const double _taillePrix = 15;
  static const double _interlignePrix = 1.2;
  static const double _margeTexte = 12;
  static const double _margeHauteTexte = 10;
  static const double _espaceNomPrix = 6;

  /// Proportion de la photo : 4/3 en largeur, soit trois quarts de hauteur.
  /// Un plat se photographie en paysage ; le portrait allongé de la version
  /// précédente étirait la carte sans rien montrer de plus.
  static const double _ratioPhoto = 3 / 4;

  /// Hauteur du bloc de texte sous l'échelle de police en vigueur.
  ///
  /// Le nom occupe toujours [_lignesNom] lignes, même s'il en remplit une
  /// seule : les prix s'alignent alors d'une carte à l'autre au lieu de
  /// sautiller au gré de la longueur des intitulés.
  static double hauteurTexte(BuildContext context) {
    final echelle = MediaQuery.textScalerOf(context);
    // Chaque ligne est arrondie au pixel **supérieur** par le moteur de
    // texte. Sans cet arrondi, la prévision tombait 0,85 px sous la
    // réalité à l'échelle 1.3 — assez pour rallumer le bandeau rayé.
    final nom =
        (echelle.scale(_tailleNom) * _interligneNom).ceilToDouble() *
            _lignesNom;
    final prix =
        (echelle.scale(_taillePrix) * _interlignePrix).ceilToDouble();
    return _margeHauteTexte + nom + _espaceNomPrix + prix + _margeTexte;
  }

  /// Hauteur à réserver pour une carte de [largeur] pixels.
  ///
  /// À passer en `mainAxisExtent` d'une grille ou en hauteur de carrousel.
  /// En deçà, la carte ne déborde pas — c'est la photo qui rétrécit — mais
  /// elle finit par n'être plus qu'une étiquette.
  static double hauteurPour(BuildContext context, double largeur) {
    return largeur * _ratioPhoto + hauteurTexte(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      // Une carte pleine, et non un verre dépoli : chaque `BackdropFilter`
      // refiltre le fond derrière lui à chaque image. Sur une grille qui
      // défile, la version précédente en empilait autant que d'articles
      // visibles, ce que le web ne pardonne pas.
      color: theme.colorScheme.surface,
      borderRadius: DesignConstants.borderRadiusLarge,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: DesignConstants.borderRadiusLarge,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // La photo cède la place au texte, jamais l'inverse.
              Expanded(child: _photo(theme)),
              _texte(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  // -- photo ----------------------------------------------------------

  Widget _photo(ThemeData theme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          child: (item.image?.isNotEmpty ?? false)
              ? Hero(
                  tag: item.id.isNotEmpty
                      ? 'menu_item_${item.id}'
                      : 'menu_item_${item.slug}',
                  child: Image.network(
                    item.image!,
                    fit: BoxFit.cover,
                    // Le fondu masque le saut d'une image qui arrive après
                    // le premier rendu, très visible sur une grille.
                    frameBuilder: (context, child, frame, wasSynchronous) {
                      if (wasSynchronous || frame != null) {
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 250),
                          child: child,
                        );
                      }
                      return _photoAbsente(theme);
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        _photoAbsente(theme),
                  ),
                )
              : _photoAbsente(theme),
        ),

        // Voile bas : la note et le bouton se posent sur des photos dont on
        // ne connaît ni la couleur ni la luminosité.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 64,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.28),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (onFavoriteTap != null)
          Positioned(top: 8, right: 8, child: _favori(theme)),

        // La note s'efface quand le compteur occupe toute la largeur : sur
        // une carte de 125 px, les deux ne tiennent pas côte à côte.
        if (item.ratingAverage > 0 && quantity == 0)
          Positioned(left: 8, bottom: 8, child: _note(theme)),

        if (onAddToCart != null)
          Positioned(
            right: 8,
            bottom: 8,
            left: quantity > 0 ? 8 : null,
            child: _controleQuantite(theme),
          ),
      ],
    );
  }

  Widget _photoAbsente(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.restaurant_menu,
          size: 40,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _favori(ThemeData theme) {
    return _PastilleAction(
      onTap: onFavoriteTap!,
      semantique: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      child: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        size: 18,
        color: isFavorite ? AppColors.primary : theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _note(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: DesignConstants.borderRadiusSmall,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 13, color: AppColors.secondary),
            const SizedBox(width: 2),
            Text(
              item.ratingAverage.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bouton d'ajout, ou compteur dès qu'un exemplaire est au panier.
  Widget _controleQuantite(ThemeData theme) {
    if (quantity <= 0) {
      return _PastilleAction(
        onTap: onAddToCart!,
        semantique: 'Ajouter ${item.name} au panier',
        couleur: AppColors.primary,
        child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        // Le compteur s'étale sur toute la largeur de la carte : les deux
        // boutons s'écartent au maximum l'un de l'autre, ce qui les rend
        // atteignables au pouce sans les agrandir.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BoutonCompteur(
            icone: Icons.remove_rounded,
            onTap: onDecrement,
            semantique: 'Retirer un ${item.name}',
          ),
          Flexible(
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                height: 1.1,
              ),
            ),
          ),
          _BoutonCompteur(
            icone: Icons.add_rounded,
            onTap: onAddToCart,
            semantique: 'Ajouter un ${item.name}',
          ),
        ],
      ),
    );
  }

  // -- texte ----------------------------------------------------------

  Widget _texte(BuildContext context, ThemeData theme) {
    final echelle = MediaQuery.textScalerOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _margeTexte,
        _margeHauteTexte,
        _margeTexte,
        _margeTexte,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Boîte de deux lignes, remplie ou non : c'est elle qui aligne les
          // prix d'une carte à l'autre. Sa hauteur est exactement celle que
          // `hauteurTexte` annonce à la grille.
          SizedBox(
            height: echelle.scale(_tailleNom) * _interligneNom * _lignesNom,
            child: Text(
              item.name,
              maxLines: _lignesNom,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _tailleNom,
                height: _interligneNom,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: _espaceNomPrix),
          Text(
            formatPrice(item.prixAffiche),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: _taillePrix,
              height: _interlignePrix,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille ronde posée sur la photo — cœur, ajout au panier.
class _PastilleAction extends StatelessWidget {
  const _PastilleAction({
    required this.onTap,
    required this.child,
    required this.semantique,
    this.couleur,
  });

  final VoidCallback onTap;
  final Widget child;
  final String semantique;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantique,
      child: Material(
        color: couleur ?? Colors.white.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 34, height: 34, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Bouton d'un compteur de quantité.
class _BoutonCompteur extends StatelessWidget {
  const _BoutonCompteur({
    required this.icone,
    required this.onTap,
    required this.semantique,
  });

  final IconData icone;
  final VoidCallback? onTap;
  final String semantique;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantique,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icone, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

/// Géométrie d'une grille de cartes de menu.
///
/// Le nombre de colonnes se **déduit** d'une largeur de carte souhaitable, au
/// lieu d'être posé à deux quoi qu'il arrive. Deux colonnes, c'est juste sur un
/// téléphone, ridicule sur une tablette et absurde dans un navigateur de
/// bureau, où la carte s'étirait à 600 px de large.
class GeometrieGrille {
  const GeometrieGrille({
    required this.colonnes,
    required this.largeurCellule,
    required this.hauteurCellule,
  });

  /// Calcule la grille qui tient dans [largeurDisponible].
  ///
  /// [colonnesMin] garantit deux colonnes même sur un écran étroit : une seule
  /// donnerait une carte pleine largeur, qui se lit comme une liste alors
  /// qu'on a demandé une grille.
  factory GeometrieGrille.calculer({
    required BuildContext context,
    required double largeurDisponible,
    required double gouttiere,
    double largeurSouhaitee = 200,
    int colonnesMin = 2,
  }) {
    final colonnes = math.max(
      colonnesMin,
      (largeurDisponible / largeurSouhaitee).floor(),
    );
    final largeurCellule =
        (largeurDisponible - gouttiere * (colonnes - 1)) / colonnes;

    return GeometrieGrille(
      colonnes: colonnes,
      largeurCellule: largeurCellule,
      hauteurCellule: MenuItemCard.hauteurPour(context, largeurCellule),
    );
  }

  final int colonnes;
  final double largeurCellule;
  final double hauteurCellule;
}
