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
              radius: taille * 0.7,
              child: Padding(
                padding: const EdgeInsets.all(DesignConstants.spacingXS),
                child: Icon(
                  etoile <= note
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: taille,
                  color: etoile <= note
                      ? AppColors.secondary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
      ],
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
              Text(
                libelle,
                style: AppTypography.labelLg(
                  color: retenue
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
