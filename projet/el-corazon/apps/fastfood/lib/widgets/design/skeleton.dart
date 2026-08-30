import 'package:elcora_fast/utils/design_constants.dart';
import 'package:flutter/material.dart';

/// Bloc gris pulsant, qui occupe la place d'un contenu en cours de chargement.
///
/// ## Pourquoi une silhouette plutôt qu'un rond qui tourne
///
/// Un indicateur circulaire dit « attends » ; une silhouette dit « voici ce
/// qui arrive, et où ». La deuxième information est celle qui compte : l'œil
/// se place avant que le contenu n'apparaisse, et le passage au réel ne
/// déplace plus rien. C'est aussi ce qui évite le saut de mise en page qui
/// suivait chaque fin de chargement.
///
/// L'animation est une **opacité**, pas un balayage de dégradé : un balayage
/// repeint toute la surface à chaque image, ce qui coûte cher quand une liste
/// en affiche dix.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = DesignConstants.radiusSmall,
    this.shape = BoxShape.rectangle,
  });

  /// Silhouette d'une ligne de texte : la largeur est une fraction de celle
  /// disponible, pour que plusieurs lignes n'aient pas toutes la même et
  /// ressemblent à du texte.
  const Skeleton.line({
    super.key,
    this.width,
    this.height = 14,
  })  : radius = 4,
        shape = BoxShape.rectangle;

  const Skeleton.circle({required double size, super.key})
      : width = size,
        height = size,
        radius = 0,
        shape = BoxShape.circle;

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur;

  @override
  void initState() {
    super.initState();
    _controleur = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _controleur, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          shape: widget.shape,
          borderRadius: widget.shape == BoxShape.circle
              ? null
              : BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Silhouette d'une [FoodCard] : photo, titre, prix, ligne d'informations.
///
/// Les proportions sont celles de la vraie carte — c'est tout l'intérêt : une
/// silhouette qui n'occupe pas la place exacte du contenu réintroduit le saut
/// qu'elle est censée supprimer.
class FoodCardSkeleton extends StatelessWidget {
  const FoodCardSkeleton({super.key, this.imageHeight = 176});

  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(DesignConstants.radiusLarge),
        boxShadow: DesignConstants.shadowLow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Skeleton(height: imageHeight, radius: 0),
          const Padding(
            padding: EdgeInsets.all(DesignConstants.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Skeleton.line(height: 18)),
                    SizedBox(width: DesignConstants.spacingM),
                    Skeleton(width: 72, height: 18),
                  ],
                ),
                SizedBox(height: DesignConstants.spacingS + 2),
                Skeleton.line(width: 140, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une liste de silhouettes, pour un écran entier en cours de chargement.
class FoodCardSkeletonList extends StatelessWidget {
  const FoodCardSkeletonList({
    super.key,
    this.count = 3,
    this.padding = const EdgeInsets.symmetric(
      horizontal: DesignConstants.edgeMargin,
    ),
  });

  final int count;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(height: DesignConstants.spacingM),
            const FoodCardSkeleton(),
          ],
        ],
      ),
    );
  }
}
