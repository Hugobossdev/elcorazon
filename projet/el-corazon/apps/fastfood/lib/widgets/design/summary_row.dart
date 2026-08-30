import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:flutter/material.dart';

/// Une ligne de récapitulatif : un libellé à gauche, un montant à droite.
///
/// Trois variantes, et le sens tient à la couleur autant qu'au poids :
///
/// * **ordinaire** — sous-total, frais : gris, poids normal ;
/// * **remise** ([isDiscount]) — en rouge de marque, parce qu'elle joue en
///   faveur du client et doit se remarquer ;
/// * **total** ([isTotal]) — en `headline-sm`, noir, précédée d'un filet.
///
/// Le montant ne s'élide jamais ; c'est le libellé qui cède. Un total tronqué
/// est pire qu'un libellé tronqué.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    required this.label,
    required this.value,
    super.key,
    this.isTotal = false,
    this.isDiscount = false,
    this.subtitle,
    this.icon,
  });

  final String label;
  final String value;
  final bool isTotal;
  final bool isDiscount;

  /// Précision sous le libellé — « Zone Cocody », « 3 articles »…
  final String? subtitle;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color couleur;
    final TextStyle styleLibelle;
    final TextStyle styleMontant;

    if (isTotal) {
      couleur = theme.colorScheme.onSurface;
      styleLibelle = AppTypography.headlineSm(color: couleur);
      styleMontant = AppTypography.headlineSm(color: couleur);
    } else if (isDiscount) {
      couleur = theme.colorScheme.primary;
      styleLibelle = AppTypography.bodyLg(color: couleur);
      styleMontant = AppTypography.bodyLg(color: couleur).copyWith(
        fontWeight: FontWeight.w600,
      );
    } else {
      couleur = theme.colorScheme.onSurfaceVariant;
      styleLibelle = AppTypography.bodyLg(color: couleur);
      styleMontant = AppTypography.bodyLg(color: couleur).copyWith(
        fontWeight: FontWeight.w600,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: couleur),
            const SizedBox(width: DesignConstants.spacingS),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: styleLibelle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.bodyMd(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Text(value, style: styleMontant),
        ],
      ),
    );
  }
}

/// Filet de séparation d'un récapitulatif, avant la ligne de total.
class SummaryDivider extends StatelessWidget {
  const SummaryDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignConstants.spacingS),
      child: Divider(
        height: 1,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(
              alpha: 0.6,
            ),
      ),
    );
  }
}

/// Barre collante de bas d'écran : le total à gauche, l'action à droite.
///
/// Le design system la décrit comme « Cart Summary (Sticky) » : total en
/// `headline-sm`, fond flouté, rayon 12. Elle sert autant au panier qu'au
/// règlement et à la personnalisation d'un article, avec le même
/// positionnement à chaque fois — c'est ce qui la rend prévisible : quel que
/// soit l'écran, le montant est au même endroit, et l'action à côté.
///
/// [action] est libre plutôt qu'un simple libellé : certains écrans y placent
/// un sélecteur de quantité **et** un bouton.
class StickySummaryBar extends StatelessWidget {
  const StickySummaryBar({
    required this.action,
    super.key,
    this.label,
    this.amount,
    this.leading,
  });

  /// Libellé au-dessus du montant — « Total », « 3 articles ».
  final String? label;

  final String? amount;

  /// Remplace complètement le bloc libellé/montant.
  final Widget? leading;

  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        if (leading != null)
          leading!
        else if (amount != null) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: AppTypography.bodyMd(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              Text(
                amount!,
                style: AppTypography.priceDisplay(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(width: DesignConstants.spacingM),
        ],
        Expanded(child: action),
      ],
    );
  }
}
