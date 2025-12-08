import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/models/loyalty_reward.dart';
import 'package:elcora_fast/models/loyalty_transaction.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/gamification_service.dart';
import 'package:elcora_fast/widgets/custom_button.dart';

/// Écran des récompenses et points de fidélité
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  @override
  void initState() {
    super.initState();
    // Initialiser le service de gamification
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final gamificationService =
            Provider.of<GamificationService>(context, listen: false);
        final appService = Provider.of<AppService>(context, listen: false);

        await gamificationService.initialize(
          userId: appService.currentUser?.id,
          forceRefresh: true,
        );
      } catch (e) {
        debugPrint('Error initializing Gamification service: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Récompenses'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Consumer<GamificationService>(
        builder: (context, gamificationService, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPointsCard(context, gamificationService),
                const SizedBox(height: 24),
                _buildBadgesSection(context, gamificationService),
                const SizedBox(height: 24),
                _buildRewardsSection(context, gamificationService),
                const SizedBox(height: 24),
                _buildTransactionsSection(context, gamificationService),
                const SizedBox(height: 24),
                _buildLevelProgress(context, gamificationService),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPointsCard(
      BuildContext context, GamificationService gamificationService,) {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.secondary,
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.stars,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Points de fidélité',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${gamificationService.currentPoints}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Niveau ${gamificationService.currentLevel}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesSection(
      BuildContext context, GamificationService gamificationService,) {
    final List<dynamic> badges = gamificationService.badges;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mes Badges',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        if (badges.isEmpty)
          _buildEmptyBadges(context)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: badges.length,
            itemBuilder: (context, index) {
              final badge = badges[index];
              return _buildBadgeCard(context, badge);
            },
          ),
      ],
    );
  }

  Widget _buildEmptyBadges(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun badge',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commandez pour débloquer vos premiers badges !',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard(BuildContext context, dynamic badge) {
    late final String name;
    late final bool isUnlocked;

    if (badge is Map<String, dynamic>) {
      name = (badge['title'] ?? badge['name'] ?? '').toString();
      isUnlocked = (badge['isUnlocked'] ?? badge['is_unlocked'] ?? false) == true;
    } else {
      try {
        name = badge.name as String;
        isUnlocked = (badge.isUnlocked ?? false) as bool;
      } catch (_) {
        name = badge?.toString() ?? '';
        isUnlocked = false;
      }
    }

    return Card(
      elevation: 2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events,
            size: 32,
            color: isUnlocked ? Colors.amber : Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? null : Colors.grey,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsSection(
      BuildContext context, GamificationService gamificationService,) {
    final theme = Theme.of(context);
    final rewards = [...gamificationService.rewards]
      ..sort((a, b) => a.cost.compareTo(b.cost));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Récompenses disponibles',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (rewards.isEmpty)
          _buildEmptyRewards(context)
        else
          ...rewards.map((reward) {
            final canRedeem = reward.isActive &&
                gamificationService.currentPoints >= reward.cost;
            final isProcessing =
                gamificationService.isRewardBeingProcessed(reward.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRewardCard(
                context,
                reward: reward,
                canRedeem: canRedeem,
                isProcessing: isProcessing,
                onRedeem: canRedeem && !isProcessing
                    ? () => _confirmRedeem(context, reward)
                    : null,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRewardCard(
    BuildContext context, {
    required LoyaltyReward reward,
    required bool canRedeem,
    required bool isProcessing,
    required VoidCallback? onRedeem,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = _iconForReward(reward.type);
    final accentColor = canRedeem
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.3);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: accentColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.title,
                        style:
                            theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reward.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.stars,
                  size: 18,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${reward.cost} points',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!reward.isActive)
                  Text(
                    'Bientôt disponible',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: canRedeem ? 'Échanger' : 'Indisponible',
              onPressed: onRedeem,
              isLoading: isProcessing,
              backgroundColor: canRedeem ? null : Colors.grey[400],
              icon: canRedeem ? Icons.redeem : Icons.lock,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRewards(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.card_giftcard,
              size: 48,
              color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucune récompense disponible pour le moment',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Continuez à cumuler des points de fidélité pour débloquer des avantages exclusifs.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForReward(LoyaltyRewardType type) {
    switch (type) {
      case LoyaltyRewardType.freeItem:
        return Icons.restaurant;
      case LoyaltyRewardType.freeDelivery:
        return Icons.delivery_dining;
      case LoyaltyRewardType.cashback:
        return Icons.savings;
      case LoyaltyRewardType.exclusiveOffer:
        return Icons.workspace_premium;
      case LoyaltyRewardType.discount:
        return Icons.percent;
    }
  }

  Future<void> _confirmRedeem(
      BuildContext context, LoyaltyReward reward,) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Échanger la récompense'),
            content: Text(
                'Voulez-vous échanger ${reward.cost} points pour "${reward.title}" ?',),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Confirmer'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) return;

    final gamificationService =
        Provider.of<GamificationService>(context, listen: false);
    final success = await gamificationService.redeemReward(reward);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Récompense "${reward.title}" échangée avec succès !'
              : 'Impossible d\'échanger la récompense pour le moment.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildLevelProgress(
      BuildContext context, GamificationService gamificationService,) {
    final currentLevel = gamificationService.currentLevel;
    final currentPoints = gamificationService.currentPoints;
    final pointsForNextLevel =
        (currentLevel + 1) * 100; // Exemple: 100 points par niveau
    final progress = currentPoints / pointsForNextLevel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progression du niveau',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Niveau $currentLevel',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  'Niveau ${currentLevel + 1}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$currentPoints / $pointsForNextLevel points',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsSection(
      BuildContext context, GamificationService gamificationService,) {
    final transactions = gamificationService.transactions;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historique des points',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (transactions.isEmpty)
          _buildEmptyTransactions(context)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _buildTransactionTile(
              context,
              transactions[index],
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionTile(
      BuildContext context, LoyaltyTransaction transaction,) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = _iconForTransaction(transaction.type);
    final color = _colorForTransaction(transaction.type, colorScheme);

    final dateLabel =
        MaterialLocalizations.of(context).formatShortDate(transaction.createdAt);
    final timeLabel =
        TimeOfDay.fromDateTime(transaction.createdAt).format(context);

    final pointsLabel = transaction.points >= 0
        ? '+${transaction.points}'
        : '${transaction.points}';

    return Card(
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Text(transaction.description),
        subtitle: Text('$dateLabel • $timeLabel'),
        trailing: Text(
          pointsLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            color: transaction.points >= 0 ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTransactions(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 48,
              color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucune activité récente',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Passez votre prochaine commande ou participez aux défis pour gagner des points.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForTransaction(LoyaltyTransactionType type) {
    switch (type) {
      case LoyaltyTransactionType.earn:
        return Icons.trending_up;
      case LoyaltyTransactionType.redeem:
        return Icons.redeem;
      case LoyaltyTransactionType.bonus:
        return Icons.bolt;
      case LoyaltyTransactionType.expiration:
        return Icons.timer_off;
      case LoyaltyTransactionType.adjustment:
        return Icons.tune;
    }
  }

  Color _colorForTransaction(
      LoyaltyTransactionType type, ColorScheme colorScheme,) {
    switch (type) {
      case LoyaltyTransactionType.earn:
        return Colors.green;
      case LoyaltyTransactionType.redeem:
        return colorScheme.primary;
      case LoyaltyTransactionType.bonus:
        return Colors.orange;
      case LoyaltyTransactionType.expiration:
        return Colors.grey;
      case LoyaltyTransactionType.adjustment:
        return colorScheme.secondary;
    }
  }
}
