import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:flutter/material.dart';

/// Cinq étoiles à toucher, pour donner une note.
///
/// ## Pourquoi elle double `RatingBar` de `flutter_rating_bar`
///
/// Le paquet reste utilisé en **lecture** (les notes affichées sur les avis) ;
/// c'est en saisie qu'il gênait. Trois raisons :
///
/// * sa couleur était `Colors.amber`, qui n'appartient pas à la palette. Le
///   doré du design system est `secondary` (`#e4c44d`) ;
/// * ses étoiles mesuraient 40 px d'espacement compris, sous la cible tactile
///   de 44 px que `DESIGN.md` impose ;
/// * il n'annonce rien aux lecteurs d'écran. Ici chaque étoile est un bouton
///   nommé (« 4 étoiles sur 5 »).
class RatingStars extends StatelessWidget {
  const RatingStars({
    required this.note,
    required this.onChanged,
    super.key,
    this.taille = 40,
  });

  /// Note courante, de 0 (aucune) à 5.
  final int note;

  final ValueChanged<int> onChanged;

  final double taille;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, contraintes) {
        // ## Pourquoi la taille se calcule
        //
        // Une icône Material suit l'échelle de texte du système. Cinq étoiles
        // de 40 px, chacune avec ses 4 px de marge, tiennent sur 240 px — mais
        // au réglage « grand » (×1,3) elles en réclament 312, pour 256
        // disponibles sur un téléphone de 320 px. La rangée débordait de 51 px,
        // c'est-à-dire que la cinquième étoile était **hors de l'écran** : on
        // ne pouvait pas mettre 5/5.
        //
        // Plutôt que de refuser l'agrandissement — ce que ferait
        // `applyTextScaling: false`, au détriment de qui a besoin de voir — la
        // rangée mesure ce dont elle dispose et rend la plus grande étoile qui
        // tienne.
        final echelle = MediaQuery.textScalerOf(context).scale(1);
        final disponible = contraintes.maxWidth.isFinite
            ? contraintes.maxWidth
            : taille * 5 + 40;
        final parEtoile = disponible / 5 - DesignConstants.spacingS;
        final cote = (parEtoile / (echelle <= 0 ? 1 : echelle))
            .clamp(16.0, taille);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var etoile = 1; etoile <= 5; etoile++)
              Semantics(
                label: '$etoile étoile${etoile > 1 ? 's' : ''} sur 5',
                selected: note == etoile,
                button: true,
                child: InkResponse(
                  onTap: () => onChanged(etoile),
                  radius: cote * 0.7,
                  child: Padding(
                    padding: const EdgeInsets.all(DesignConstants.spacingXS),
                    child: Icon(
                      etoile <= note
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: cote,
                      color: etoile <= note
                          ? AppColors.secondary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Les puces d'appréciation — « Bien emballé », « Livraison rapide ».
///
/// ## Ce qu'elles deviennent une fois envoyées
///
/// Le contrat n'a **pas de champ d'étiquettes**. Elles ne sont donc pas
/// inventées côté serveur : elles alimentent le `title` d'un avis produit — un
/// champ qui existe et que l'écran laissait vide — ou la tête du commentaire
/// d'une note de livraison. L'information part réellement, dans un champ
/// prévu, plutôt que d'être collectée pour rien.
class AppreciationChips extends StatelessWidget {
  const AppreciationChips({
    required this.options,
    required this.retenues,
    required this.onChanged,
    super.key,
  });

  final List<String> options;
  final Set<String> retenues;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: DesignConstants.spacingS,
      runSpacing: DesignConstants.spacingS,
      children: [
        for (final option in options)
          _Puce(
            libelle: option,
            retenue: retenues.contains(option),
            onTap: () {
              final suite = Set<String>.from(retenues);
              if (!suite.remove(option)) suite.add(option);
              onChanged(suite);
            },
            theme: theme,
          ),
      ],
    );
  }
}

class _Puce extends StatelessWidget {
  const _Puce({
    required this.libelle,
    required this.retenue,
    required this.onTap,
    required this.theme,
  });

  final String libelle;
  final bool retenue;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: retenue,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: DesignConstants.borderRadiusMedium,
        child: AnimatedContainer(
          duration: DesignConstants.animationFast,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignConstants.spacingM,
            vertical: DesignConstants.spacingS + 2,
          ),
          decoration: BoxDecoration(
            color: retenue
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: DesignConstants.borderRadiusMedium,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (retenue) ...[
                Icon(
                  Icons.check_rounded,
                  size: DesignConstants.iconSizeSmall,
                  color: theme.colorScheme.onPrimary,
                ),
                const SizedBox(width: DesignConstants.spacingXS + 2),
              ],
              // `Wrap` donne à ses enfants une largeur **non bornée** : une
              // puce plus large que la ligne ne passe pas à la suivante, elle
              // déborde. « Portion généreuse » avec sa coche y suffisait au
              // réglage « grand ». Le `Flexible` la laisse se rogner plutôt
              // que sortir de l'écran.
              Flexible(
                child: Text(
                  libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLg(
                    color: retenue
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
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
