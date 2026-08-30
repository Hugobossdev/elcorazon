import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:flutter/material.dart';

/// Bascule à deux ou trois volets, posée sous la barre translucide.
///
/// ## Pourquoi elle double `TabBar`
///
/// Le `TabBar` de Material signale l'onglet retenu par un trait de deux
/// pixels sous son libellé. Sur le blanc cassé chaud du design system, ce
/// trait se perd — et les maquettes ne le montrent nulle part : elles posent
/// une **pilule pleine** qui glisse d'un volet à l'autre, sur un rail teinté.
///
/// Ce n'est pas un `SegmentedButton` non plus : celui-ci ne pilote pas de
/// `TabBarView`, faute de `TabController`. Ce widget garde donc le contrôleur
/// de Material et ne remplace que la peinture.
///
/// ## Où elle sert
///
/// Partout où un écran porte deux vues sœurs sous un même titre — le catalogue
/// et l'atelier d'une commande de gâteau, les commandes en cours et
/// l'historique. Un troisième volet tient encore ; au-delà, les libellés se
/// rognent et il faut une autre forme.
class SegmentedTabs extends StatelessWidget implements PreferredSizeWidget {
  const SegmentedTabs({
    required this.controller,
    required this.labels,
    super.key,
    this.icons,
  });

  final TabController controller;

  /// Un libellé par volet. Court : c'est une pilule, pas une phrase.
  final List<String> labels;

  /// Facultatif, et de même longueur que [labels] quand il est fourni.
  final List<IconData>? icons;

  /// Hauteur de la pilule, hors marge basse.
  static const double _hauteurPilule = 44;

  @override
  Size get preferredSize =>
      const Size.fromHeight(_hauteurPilule + DesignConstants.spacingS);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    assert(
      icons == null || icons!.length == labels.length,
      'Autant d’icônes que de libellés, ou aucune.',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignConstants.edgeMargin,
        0,
        DesignConstants.edgeMargin,
        DesignConstants.spacingS,
      ),
      child: Container(
        height: _hauteurPilule,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: DesignConstants.borderRadiusMedium,
        ),
        child: TabBar(
          controller: controller,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          padding: const EdgeInsets.all(4),
          indicator: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(DesignConstants.radiusSmall),
          ),
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: AppTypography.labelLg(),
          unselectedLabelStyle: AppTypography.labelLg(),
          // Les onglets ne rendent qu'une ligne : une icône **au-dessus** du
          // libellé doublerait la hauteur de la pilule, et une pilule de 76 px
          // n'est plus une bascule mais une seconde barre de navigation.
          tabs: [
            for (var i = 0; i < labels.length; i++)
              Tab(
                height: _hauteurPilule - 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icons != null) ...[
                      Icon(icons![i], size: DesignConstants.iconSizeSmall),
                      const SizedBox(width: DesignConstants.spacingXS + 2),
                    ],
                    Flexible(
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
