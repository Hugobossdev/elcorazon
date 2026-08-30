import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/section_card.dart';
import 'package:flutter/material.dart';

/// Groupe d'options d'un article — « Choisir la taille », « Suppléments ».
///
/// L'exigence du groupe est affichée en clair, à droite du titre : « Requis »,
/// « Facultatif », « Choisir 2 ». C'est ce que la maquette appelle le badge de
/// contrainte, et il évite la faute la plus commune de ces écrans — un bouton
/// « Ajouter » grisé sans que rien ne dise pourquoi.
///
/// Le badge « Requis » porte le rouge de marque ; les autres restent neutres.
/// Un écran où six groupes crient tous en rouge n'indique plus lequel bloque.
class OptionGroupCard extends StatelessWidget {
  const OptionGroupCard({
    required this.title,
    required this.children,
    super.key,
    this.constraintLabel,
    this.isRequired = false,
    this.error,
  });

  final String title;
  final List<Widget> children;

  /// Texte du badge. À défaut, il est déduit de [isRequired].
  final String? constraintLabel;

  final bool isRequired;

  /// Message affiché sous le titre quand la contrainte n'est pas satisfaite.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libelle =
        constraintLabel ?? (isRequired ? 'Requis' : 'Facultatif');

    return SectionCard(
      color: theme.colorScheme.surfaceContainerLow,
      borderColor: error == null ? null : theme.colorScheme.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleLg(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: DesignConstants.spacingS),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isRequired
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  libelle.toUpperCase(),
                  style: AppTypography.labelLg(
                    color: isRequired
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error!,
              style: AppTypography.bodyMd(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: DesignConstants.spacingS),
          ...children,
        ],
      ),
    );
  }
}

/// Ligne d'option : une case ou un bouton radio, un intitulé, un écart de prix.
///
/// La case suit les standards Material 3 « pour une familiarité maximale » —
/// c'est le seul endroit du design system qui renonce explicitement à styliser
/// quelque chose, et pour une bonne raison : personne n'apprend une nouvelle
/// forme de case à cocher au moment de payer.
///
/// L'écart de prix n'est affiché que s'il est non nul : « +0 F » est du bruit.
class OptionRow extends StatelessWidget {
  const OptionRow({
    required this.label,
    required this.selected,
    required this.onChanged,
    super.key,
    this.priceDelta,
    this.multiple = false,
    this.enabled = true,
    this.subtitle,
    this.showDivider = true,
  });

  final String label;
  final bool selected;

  /// `null` désactive la ligne — un supplément épuisé, ou une option
  /// incompatible avec un choix déjà fait ailleurs.
  final ValueChanged<bool>? onChanged;

  /// Déjà formaté (« +500 CFA »). `null` ou vide n'affiche rien.
  final String? priceDelta;

  /// Case à cocher plutôt que bouton radio.
  final bool multiple;

  final bool enabled;
  final String? subtitle;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actif = enabled && onChanged != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: actif ? () => onChanged!(!selected) : null,
          borderRadius: DesignConstants.borderRadiusSmall,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Un **glyphe**, pas un `Checkbox` ni un `Radio`.
                //
                // Ces deux widgets portent leur propre zone tactile de 48 px
                // et leur propre effet d'encre : posés dans une ligne déjà
                // cliquable, ils créaient une cible dans la cible — viser la
                // case cochait, viser trois pixels à côté ne faisait rien,
                // alors que toute la ligne se présente comme cliquable. Le
                // glyphe rend exactement la même forme (ce sont les icônes
                // Material) sans revendiquer le toucher.
                Padding(
                  padding: const EdgeInsets.all(DesignConstants.spacingS),
                  child: Icon(
                    multiple
                        ? (selected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded)
                        : (selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded),
                    size: 22,
                    color: !actif
                        ? theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.35)
                        : selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppTypography.bodyLg(
                          color: actif
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppTypography.bodyMd(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (priceDelta != null && priceDelta!.isNotEmpty) ...[
                  const SizedBox(width: DesignConstants.spacingS),
                  Text(
                    priceDelta!,
                    style: AppTypography.bodyMd(
                      color: theme.colorScheme.onSurfaceVariant,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

/// Puce de choix à deux étages : un intitulé, un prix dessous.
///
/// C'est la « Selected Chip » des maquettes, pour les choix courts et
/// mutuellement exclusifs — une taille, un format. Au-delà de trois ou quatre
/// valeurs, ou dès que les intitulés s'allongent, [OptionRow] reste plus
/// lisible : une rangée de puces qui passe à la ligne perd son alignement.
class OptionChoiceChip extends StatelessWidget {
  const OptionChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
    this.priceLabel,
    this.enabled = true,
  });

  final String label;
  final String? priceLabel;
  final bool selected;
  final VoidCallback? onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actif = enabled && onSelected != null;
    final rayon = BorderRadius.circular(DesignConstants.radiusMedium);

    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : theme.colorScheme.surface,
      borderRadius: rayon,
      child: InkWell(
        onTap: actif ? onSelected : null,
        borderRadius: rayon,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: rayon,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignConstants.spacingM,
              vertical: DesignConstants.spacingS + 2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: actif
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                  ),
                ),
                if (priceLabel != null && priceLabel!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    priceLabel!,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelLg(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
