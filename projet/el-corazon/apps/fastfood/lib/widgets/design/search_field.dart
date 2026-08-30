import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:flutter/material.dart';

/// Champ de recherche du design system.
///
/// « 12px radius, Surface Variant background, no border. Leading icon is Text
/// Secondaire. » Le fond plein remplace la bordure : sur un fond blanc cassé,
/// un liseré gris et un fond gris disent la même chose, et le liseré ajoute du
/// bruit visuel sans rien préciser.
///
/// [onTap] rend le champ **non modifiable** : c'est le mode « bouton » de
/// l'accueil, où toucher la barre ouvre l'écran de recherche au lieu de
/// déplier le clavier sur place.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.hintText = 'Que voulez-vous manger ?',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.trailing,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Non nul, le champ devient une surface tactile qui n'accepte pas la
  /// saisie.
  final VoidCallback? onTap;

  final Widget? trailing;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: onTap != null,
      onTap: onTap,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: AppTypography.bodyLg(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(
          Icons.search_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        suffixIcon: trailing,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignConstants.spacingM,
          vertical: DesignConstants.spacingS + 4,
        ),
        border: const OutlineInputBorder(
          borderRadius: DesignConstants.borderRadiusMedium,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: DesignConstants.borderRadiusMedium,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesignConstants.borderRadiusMedium,
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}

/// Rangée horizontale de puces de filtre.
///
/// La sélection est **portée par l'appelant** ([selectedIndex]) et non par la
/// puce : le filtre appartient à l'écran, qui doit pouvoir le remettre à zéro
/// ou le pré-remplir depuis une route. Une puce qui garderait son propre état
/// se désynchroniserait de la liste qu'elle filtre.
///
/// Le débordement horizontal est voulu — c'est un rail qui se fait glisser,
/// pas une grille qui passe à la ligne : les catégories restent alors sur une
/// seule hauteur quel que soit leur nombre.
class CategoryChipBar extends StatelessWidget {
  const CategoryChipBar({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
    this.padding = const EdgeInsets.symmetric(
      horizontal: DesignConstants.edgeMargin,
    ),
    this.leadingBuilder,
  });

  final List<String> labels;

  /// `-1` n'en sélectionne aucune.
  final int selectedIndex;

  final ValueChanged<int> onSelected;
  final EdgeInsets padding;

  /// Pastille (emoji) posée avant l'intitulé.
  final String? Function(int index)? leadingBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      // Assez pour la puce (40 px) plus le débordement du texte agrandi.
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: labels.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: DesignConstants.spacingS),
        itemBuilder: (context, index) {
          final actif = index == selectedIndex;
          final pastille = leadingBuilder?.call(index);

          return Center(
            child: Material(
              color: actif
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainer,
              shape: const StadiumBorder(),
              child: InkWell(
                onTap: () => onSelected(index),
                customBorder: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignConstants.spacingM + 4,
                    vertical: DesignConstants.spacingS + 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pastille != null && pastille.isNotEmpty) ...[
                        Text(pastille, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        labels[index],
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: actif
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
