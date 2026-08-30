import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/catalogue.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_fast/services/customization_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/design/design.dart';

/// Le récapitulatif d'un gâteau sur mesure : sa photo, son prix de base, les
/// options retenues et le total estimé.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// 407 lignes dans une méthode de `cake_order_screen.dart`, qui en comptait
/// 2 886. Le récapitulatif ne décide de rien : il relit la composition en
/// cours et l'affiche. Le rendre nommé le rend lisible.
///
/// Ce que la reprise Stitch a changé
/// ---------------------------------
///
/// La carte tenait sa propre mise en forme — rayon 24, `Image.network` nue,
/// deux dégradés imbriqués, six `Container` décorés à la main. Elle passe aux
/// briques du design system : [SectionCard] pour le cadre, [FoodImage] pour la
/// photo (avec son repli quand l'article n'en a pas), [SummaryRow] pour les
/// montants. Le total garde son emphase — c'est le chiffre que l'on vient
/// chercher — mais l'obtient du jeton `priceDisplay`, non d'un pavé rouge.
class RecapitulatifGateau extends StatelessWidget {
  const RecapitulatifGateau({
    required this.gateau,
    required this.customizationId,
    required this.priceModifier,
    required this.finalPrice,
    super.key,
  });

  final eccore.MenuItem gateau;
  final String customizationId;

  /// Ce que les options ajoutent au prix de base.
  final double priceModifier;

  /// Prix de base plus [priceModifier].
  final double finalPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final customizationService =
        Provider.of<CustomizationService>(context, listen: false);
    final current =
        customizationService.getCurrentCustomization(customizationId);
    final optionsByCategory = customizationService.getOptionsByCategory(
      gateau.id,
      fallbackName: gateau.name,
    );
    final optionLookup = <String, CustomizationOption>{};
    for (final entry in optionsByCategory.entries) {
      for (final option in entry.value) {
        optionLookup[option.id] = option;
      }
    }

    final hasSelections = current != null && current.selections.isNotEmpty;

    return SectionCard(
      padding: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _photo(theme),
          Padding(
            padding: const EdgeInsets.all(DesignConstants.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gateau.name,
                  style: AppTypography.titleLg(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: DesignConstants.spacingXS),
                Text(
                  'Composez-le pièce par pièce : le total suit vos choix.',
                  style: AppTypography.bodyMd(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignConstants.spacingM),
                SummaryRow(
                  label: 'Prix de base',
                  value: PriceFormatter.format(gateau.prixAffiche),
                ),
                if (priceModifier > 0)
                  SummaryRow(
                    label: 'Options retenues',
                    value: '+${PriceFormatter.format(priceModifier)}',
                    icon: Icons.tune_rounded,
                  ),
                const SummaryDivider(),
                // « Estimé », parce qu'il l'est : ce cumul sert à composer, le
                // montant facturé est celui que le serveur relit du catalogue
                // au devis du panier (invariant C1).
                SummaryRow(
                  label: 'Total estimé',
                  value: PriceFormatter.format(finalPrice),
                  isTotal: true,
                ),
                if (hasSelections) ...[
                  const SizedBox(height: DesignConstants.spacingM),
                  _selection(theme, current, customizationService, optionLookup),
                ],
                if (current?.specialInstructions?.isNotEmpty == true) ...[
                  const SizedBox(height: DesignConstants.spacingS),
                  _message(theme, current!.specialInstructions!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// La photo du gâteau, sous la puce « Sur mesure ».
  ///
  /// [FoodImage] porte son propre repli : quand l'article n'a pas d'image — le
  /// cas nominal tant que l'établissement n'a pas publié le gâteau sur mesure
  /// — il rend une plaque teintée plutôt qu'un carré d'erreur.
  Widget _photo(ThemeData theme) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(DesignConstants.radiusLarge),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FoodImage(
              url: gateau.image,
              icon: Icons.cake_rounded,
              iconSize: 56,
            ),
            const ImageScrim(opacity: 0.45),
            Positioned(
              top: DesignConstants.spacingM,
              right: DesignConstants.spacingM,
              child: StatusChip(
                label: 'Sur mesure',
                icon: Icons.palette_rounded,
                background: theme.colorScheme.primary,
                foreground: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selection(
    ThemeData theme,
    ItemCustomization current,
    CustomizationService service,
    Map<String, CustomizationOption> optionLookup,
  ) {
    final lignes = <Widget>[];

    current.selections.forEach((categorie, optionIds) {
      final libelles = optionIds
          .map((id) => optionLookup[id])
          .whereType<CustomizationOption>()
          .map(
            (option) => option.priceModifier == 0
                ? option.name
                : '${option.name} (+${PriceFormatter.format(option.priceModifier)})',
          )
          .toList();
      if (libelles.isEmpty) return;

      lignes.add(
        Padding(
          padding: const EdgeInsets.only(bottom: DesignConstants.spacingS),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 7, right: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.translateCategory(categorie),
                      style: AppTypography.labelLg(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      libelles.join(', '),
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });

    if (lignes.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(DesignConstants.spacingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: DesignConstants.borderRadiusMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: DesignConstants.iconSizeSmall,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: DesignConstants.spacingS),
              Text(
                'Votre sélection',
                style: AppTypography.labelLg(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingS),
          ...lignes,
        ],
      ),
    );
  }

  Widget _message(ThemeData theme, String texte) {
    return Container(
      padding: const EdgeInsets.all(DesignConstants.spacingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: DesignConstants.borderRadiusMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.message_rounded,
            size: DesignConstants.iconSizeSmall,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: DesignConstants.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message sur le gâteau',
                  style: AppTypography.labelLg(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texte,
                  style: AppTypography.bodyMd(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
