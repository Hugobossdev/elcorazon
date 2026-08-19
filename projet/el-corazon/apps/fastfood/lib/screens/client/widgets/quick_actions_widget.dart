import 'package:flutter/material.dart';

import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';

/// Widget pour les actions rapides depuis l'écran d'accueil
class QuickActionsWidget extends StatelessWidget {
  const QuickActionsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      const _QuickAction(
        icon: Icons.card_giftcard,
        title: 'Récompenses',
        subtitle: 'Mes points de fidélité',
        route: AppRouter.rewards,
      ),
      const _QuickAction(
        icon: Icons.cake_outlined,
        title: 'Gâteaux',
        subtitle: 'Prêts ou personnalisés',
        route: AppRouter.cakeOrder,
      ),
      const _QuickAction(
        icon: Icons.group,
        title: 'Commandes groupées',
        subtitle: 'Commander entre amis',
        route: AppRouter.groupOrder,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        // Hauteur **réservée** plutôt que déduite d'un rapport largeur/hauteur.
        // Avec `childAspectRatio: 1.25`, la tuile mesurait 110 px de haut sur
        // un téléphone courant alors que son contenu — pastille de 40 px,
        // titre, sous-titre sur deux lignes — en réclamait 143 : le sous-titre
        // passait sous le bandeau de débordement.
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: _QuickActionCard.hauteur(context),
        ),
        itemBuilder: (context, index) {
          final action = actions[index];
          return _QuickActionCard(action: action);
        },
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final _QuickAction action;

  static const double _cotePastille = 40; // 8 de marge + 24 d'icône + 8
  static const double _marge = 12;
  static const double _espacePastilleTitre = 10;
  static const double _tailleTitre = 13;
  static const double _tailleSousTitre = 11;
  static const double _interligne = 1.3;
  static const int _lignesSousTitre = 2;
  static const double _espaceTitreSousTitre = 2;

  /// Bordure du conteneur de verre. `Container` l'ajoute à sa marge
  /// intérieure, donc elle mange de la hauteur utile.
  static const double _bordureVerre = 1.5;

  /// Hauteur qu'il faut à la tuile sous l'échelle de police en vigueur.
  ///
  /// La marge est passée explicitement au conteneur de verre plus bas : s'en
  /// remettre à son défaut — `EdgeInsets.all(16)`, décidé dans un autre
  /// fichier — revenait à calculer une hauteur fausse de 35 px, et la tuile
  /// débordait de nouveau.
  static double hauteur(BuildContext context) {
    final echelle = MediaQuery.textScalerOf(context);
    // Chaque ligne est arrondie au pixel **supérieur** par le moteur de
    // texte. Sans cet arrondi, la prévision tombait 0,85 px sous la
    // réalité à l'échelle 1.3 — assez pour rallumer le bandeau rayé.
    final titre =
        (echelle.scale(_tailleTitre) * _interligne).ceilToDouble();
    final sousTitre =
        (echelle.scale(_tailleSousTitre) * _interligne).ceilToDouble() *
            _lignesSousTitre;
    return (_marge + _bordureVerre) * 2 +
        _cotePastille +
        _espacePastilleTitre +
        titre +
        _espaceTitreSousTitre +
        sousTitre;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () =>
          Navigator.of(context, rootNavigator: true).pushNamed(action.route),
      child: DesignEnhancementService.createGlassContainer(
        blur: 5,
        opacity: 0.7,
        // Marge **explicite**, pour que `hauteur` la connaisse.
        padding: const EdgeInsets.all(_marge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // Le `Spacer` d'avant réclamait toute la place restante avant que
          // les textes n'aient la leur ; quand il n'en restait pas, c'est le
          // sous-titre qui débordait. L'espace est maintenant fixe, et c'est
          // la grille qui accorde la hauteur nécessaire.
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                action.icon,
                size: 24,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: _espacePastilleTitre),
            Text(
              action.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: _tailleTitre,
                height: _interligne,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              action.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: _tailleSousTitre,
                height: _interligne,
              ),
              maxLines: _lignesSousTitre,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}
