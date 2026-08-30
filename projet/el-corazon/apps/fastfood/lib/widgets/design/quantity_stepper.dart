import 'package:elcora_fast/theme.dart';
import 'package:flutter/material.dart';

/// Sélecteur de quantité en pilule.
///
/// Le design system le décrit précisément : « Pill-shaped, Primary Red
/// buttons with a neutral count in the center ». Le compte reste neutre —
/// c'est une valeur, pas une action — et seules les deux flèches portent le
/// rouge, ce qui indique où toucher sans avoir à lire.
///
/// La largeur du compteur est **fixée** par le nombre de chiffres attendus :
/// laissée libre, la pilule s'élargit en passant de 9 à 10 et fait sauter tout
/// ce qui l'entoure.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    super.key,
    this.minQuantity = 1,
    this.maxQuantity = 99,
    this.compact = false,
    this.backgroundColor,
  });

  final int quantity;

  /// `null` désactive la flèche — utile quand retirer le dernier exemplaire
  /// doit passer par une confirmation plutôt que par le décrément.
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  final int minQuantity;
  final int maxQuantity;

  /// Version 32 px pour une ligne de panier ; 44 px sinon, la cible tactile
  /// pleine des écrans où le choix de la quantité est l'action principale.
  final bool compact;

  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cote = compact ? 32.0 : 44.0;

    return Container(
      height: cote,
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(cote / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Fleche(
            icone: Icons.remove_rounded,
            cote: cote,
            semantique: 'Diminuer la quantité',
            onTap: quantity > minQuantity ? onDecrement : null,
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: compact ? 22 : 32),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: (compact
                      ? AppTypography.titleLg(color: theme.colorScheme.onSurface)
                      : AppTypography.headlineSm(
                          color: theme.colorScheme.onSurface,
                        ))
                  .copyWith(height: 1.1),
            ),
          ),
          _Fleche(
            icone: Icons.add_rounded,
            cote: cote,
            semantique: 'Augmenter la quantité',
            onTap: quantity < maxQuantity ? onIncrement : null,
          ),
        ],
      ),
    );
  }
}

class _Fleche extends StatelessWidget {
  const _Fleche({
    required this.icone,
    required this.cote,
    required this.onTap,
    required this.semantique,
  });

  final IconData icone;
  final double cote;
  final VoidCallback? onTap;
  final String semantique;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actif = onTap != null;

    return Semantics(
      button: true,
      enabled: actif,
      label: semantique,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: cote,
          height: cote,
          child: Icon(
            icone,
            size: cote * 0.55,
            color: actif
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}
