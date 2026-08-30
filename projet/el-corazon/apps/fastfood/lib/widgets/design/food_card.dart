import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/food_image.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

/// Carte de plat pleine largeur — la « Food Card » des maquettes.
///
/// ## Ce qu'elle montre, dans cet ordre
///
/// Photo 16:9 avec sa note en surimpression, puis le nom à gauche et le prix à
/// droite sur la même ligne, puis une ligne d'informations secondaires : délai
/// de préparation, séparateur, catégorie.
///
/// L'alignement nom/prix sur une seule ligne est le point délicat : un nom
/// long doit s'élider plutôt que repousser le prix hors de l'écran, et le prix
/// — qui est l'information qu'on cherche du regard — ne doit jamais se
/// tronquer. D'où l'`Expanded` sur le nom et rien sur le prix.
///
/// ## Pourquoi elle coexiste avec `MenuItemCard`
///
/// Ce sont deux formats distincts du même contenu, comme dans les maquettes :
/// celle-ci occupe la largeur d'un écran, [MenuItemCard] tient dans une
/// colonne de grille ou un carrousel. Les fusionner reviendrait à un composant
/// à deux modes dont aucun ne serait juste.
class FoodCard extends StatelessWidget {
  const FoodCard({
    required this.item,
    required this.onTap,
    super.key,
    this.onFavoriteTap,
    this.isFavorite = false,
    this.trailingBadge,
    this.imageHeight = 176,
  });

  final eccore.MenuItem item;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final bool isFavorite;

  /// Pastille libre en haut à gauche de la photo — « Nouveau », « -20 % ».
  final Widget? trailingBadge;

  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(DesignConstants.radiusLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignConstants.radiusLarge),
            boxShadow: DesignConstants.shadowLow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: imageHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FoodImage(
                      url: item.image,
                      heroTag: 'plat_${item.id.isEmpty ? item.slug : item.id}',
                    ),
                    if (item.ratingAverage > 0)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: RatingBadge(rating: item.ratingAverage),
                      ),
                    if (trailingBadge != null)
                      Positioned(top: 12, left: 12, child: trailingBadge!),
                    if (onFavoriteTap != null)
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: _Coeur(
                          actif: isFavorite,
                          onTap: onFavoriteTap!,
                          nom: item.name,
                        ),
                      ),
                    if (!item.isAvailable)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.scrim.withValues(alpha: 0.55),
                        ),
                        child: Center(
                          child: Text(
                            'Indisponible',
                            style: AppTypography.labelLg(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DesignConstants.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleLg(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: DesignConstants.spacingS),
                        Text(
                          item.price.format(),
                          style: AppTypography.priceDisplay(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignConstants.spacingS),
                    _MetaLigne(item: item),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Délai de préparation • catégorie.
///
/// Enveloppée dans un `Wrap` plutôt qu'une `Row` : à l'échelle de police 1,3
/// sur un écran de 320 px, « 25-35 min » et « Grillades » ne tiennent plus
/// côte à côte, et une `Row` déborderait au lieu de passer à la ligne.
class _MetaLigne extends StatelessWidget {
  const _MetaLigne({required this.item});

  final eccore.MenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = AppTypography.bodyMd(color: theme.colorScheme.onSurfaceVariant);

    return Wrap(
      spacing: DesignConstants.spacingS,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (item.preparationMinutes > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text('${item.preparationMinutes} min', style: style),
            ],
          ),
        if (item.preparationMinutes > 0 && item.categoryName.isNotEmpty)
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              shape: BoxShape.circle,
            ),
          ),
        if (item.categoryName.isNotEmpty)
          Text(item.categoryName, style: style),
      ],
    );
  }
}

class _Coeur extends StatelessWidget {
  const _Coeur({required this.actif, required this.onTap, required this.nom});

  final bool actif;
  final VoidCallback onTap;
  final String nom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: actif ? 'Retirer $nom des favoris' : 'Ajouter $nom aux favoris',
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              actif ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 20,
              color: actif
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
