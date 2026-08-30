import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/food_image.dart';
import 'package:flutter/material.dart';

/// Bannière promotionnelle en dégradé.
///
/// C'est le seul endroit où le design system autorise le dégradé rouge → doré :
/// « Reserved for hero banners […] to create a sense of movement and heat ».
/// L'employer ailleurs le vide de son sens — s'il est partout, il ne signale
/// plus rien.
///
/// ## Mise en page
///
/// Le texte occupe les deux tiers gauches, l'illustration déborde du coin bas
/// droit. Le débordement est intentionnel : une image cadrée dans la bannière
/// la ferait ressembler à une carte de plus, alors qu'elle doit se lire comme
/// une affiche.
///
/// Le contenu **ne contraint pas** la hauteur à une valeur fixe : à l'échelle
/// de police 1,3, un titre sur trois lignes doit pouvoir pousser la bannière
/// plutôt que déborder.
class PromoBanner extends StatelessWidget {
  const PromoBanner({
    required this.title,
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onPressed,
    this.imageUrl,
    this.icon = Icons.local_fire_department_rounded,
    this.colors = AppColors.heroGradient,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onPressed;

  /// Photo du produit mis en avant. À défaut, [icon] tient le rôle
  /// d'illustration — une bannière sans visuel se lit comme un encart
  /// d'erreur.
  final String? imageUrl;

  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final rayon = BorderRadius.circular(DesignConstants.radiusLarge);

    return Material(
      color: Colors.transparent,
      borderRadius: rayon,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: rayon,
            boxShadow: DesignConstants.shadowLow,
          ),
          child: Stack(
            children: [
              // L'illustration en premier : elle passe sous le texte, et la
              // pile n'impose donc aucune contrainte de hauteur.
              Positioned(
                right: -24,
                bottom: -24,
                child: Opacity(
                  opacity: 0.85,
                  child: SizedBox(
                    width: 168,
                    height: 168,
                    child: imageUrl == null || imageUrl!.isEmpty
                        ? Icon(
                            icon,
                            size: 140,
                            color: Colors.white.withValues(alpha: 0.22),
                          )
                        : ClipOval(
                            child: FoodImage(url: imageUrl, iconSize: 64),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DesignConstants.spacingL - 4),
                child: FractionallySizedBox(
                  widthFactor: 0.72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTypography.headlineMd(color: Colors.white),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: DesignConstants.spacingS),
                        Text(
                          subtitle!,
                          style: AppTypography.bodyMd(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                      if (actionLabel != null && onPressed != null) ...[
                        const SizedBox(height: DesignConstants.spacingM),
                        _PastilleAction(
                          label: actionLabel!,
                          onPressed: onPressed!,
                          couleurTexte: colors.first,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le bouton blanc de la bannière — pilule, texte à la couleur du dégradé.
class _PastilleAction extends StatelessWidget {
  const _PastilleAction({
    required this.label,
    required this.onPressed,
    required this.couleurTexte,
  });

  final String label;
  final VoidCallback onPressed;
  final Color couleurTexte;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignConstants.spacingM,
            vertical: DesignConstants.spacingS + 2,
          ),
          child: Text(
            label,
            style: AppTypography.labelLg(color: couleurTexte),
          ),
        ),
      ),
    );
  }
}

/// Puce d'état — « Préparation », « En route », « Livrée ».
///
/// Le design system leur attribue les rôles tertiaire et secondaire pour
/// marquer la progression, et un rayon de 8 px qui les distingue à la fois des
/// cartes (16) et des boutons (12) : une puce n'est ni un contenu ni une
/// action, c'est une étiquette.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    super.key,
    this.icon,
    this.background,
    this.foreground,
    this.dense = false,
  });

  const StatusChip.neutral({
    required this.label,
    super.key,
    this.icon,
    this.dense = false,
  })  : background = null,
        foreground = null;

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fond = background ?? theme.colorScheme.surfaceContainerHigh;
    final texte = foreground ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : DesignConstants.spacingS + 2,
        vertical: dense ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(DesignConstants.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: texte),
            const SizedBox(width: 4),
          ],
          Text(label, style: AppTypography.labelLg(color: texte)),
        ],
      ),
    );
  }
}
