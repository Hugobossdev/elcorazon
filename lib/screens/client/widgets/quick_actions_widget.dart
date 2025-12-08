import 'package:flutter/material.dart';

import 'package:elcora_fast/navigation/app_router.dart';

/// Widget pour les actions rapides depuis l'écran d'accueil
class QuickActionsWidget extends StatelessWidget {
  const QuickActionsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      const _QuickAction(
        icon: Icons.account_balance_wallet,
        title: 'Portefeuille',
        subtitle: 'Gérer mes fonds',
        route: AppRouter.wallet,
      ),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context, rootNavigator: true)
            .pushNamed(action.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                action.icon,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                action.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                action.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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

