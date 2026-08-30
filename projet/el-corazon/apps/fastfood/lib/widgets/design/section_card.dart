import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:flutter/material.dart';

/// Conteneur blanc à coins doux — la brique de fond de tous les écrans.
///
/// Reprend exactement la carte des maquettes : `bg-surface-container-lowest`,
/// rayon 16, et l'ombre de repos `0 2px 8px rgba(26,26,26,.08)`. La factoriser
/// évite que chaque écran redéclare sa propre ombre, ce qui était la source
/// principale d'incohérence : on trouvait cinq valeurs de flou différentes
/// pour la même intention.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(DesignConstants.spacingM),
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = DesignConstants.radiusLarge,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? color;

  /// Un liseré, pour l'état sélectionné d'une carte de choix (mode de
  /// paiement, taille de gâteau…).
  final Color? borderColor;

  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rayon = BorderRadius.circular(radius);

    final Widget contenu = Padding(padding: padding, child: child);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surfaceContainerLowest,
        borderRadius: rayon,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
        boxShadow: shadow ? DesignConstants.shadowLow : null,
      ),
      child: onTap == null
          ? contenu
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: rayon,
                child: contenu,
              ),
            ),
    );
  }
}

/// Titre de section, avec sa légende et son action « Tout voir ».
///
/// Aligné sur les maquettes : titre en `headline-sm`, action en `label-lg`
/// rouge. C'est le même composant que celui de l'accueil, remonté ici pour
/// que les autres écrans cessent d'en réécrire des variantes.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onActionPressed,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment:
            subtitle == null ? CrossAxisAlignment.center : CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style:
                      AppTypography.headlineSm(color: theme.colorScheme.onSurface),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.bodyMd(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onActionPressed != null)
            TextButton(
              onPressed: onActionPressed,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignConstants.spacingS,
                ),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: AppTypography.labelLg(color: theme.colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}
