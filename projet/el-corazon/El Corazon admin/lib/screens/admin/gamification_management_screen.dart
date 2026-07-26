import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/gamification_service.dart';
import '../../utils/dialog_helper.dart';

class GamificationManagementScreen extends StatefulWidget {
  const GamificationManagementScreen({super.key});

  @override
  State<GamificationManagementScreen> createState() =>
      _GamificationManagementScreenState();
}

class _GamificationManagementScreenState
    extends State<GamificationManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GamificationService>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de la Gamification'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Achievements', icon: Icon(Icons.emoji_events)),
            Tab(text: 'Challenges', icon: Icon(Icons.flag)),
            Tab(text: 'Badges', icon: Icon(Icons.workspace_premium)),
            Tab(text: 'Récompenses', icon: Icon(Icons.card_giftcard)),
          ],
        ),
        actions: [
          Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<GamificationService>().refresh(),
              tooltip: 'Rafraîchir',
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () => _showGlobalStats(),
              tooltip: 'Statistiques',
            ),
          ),
        ],
      ),
      body: Consumer<GamificationService>(
        builder: (context, gamificationService, _) {
          if (gamificationService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _AchievementsTab(gamificationService: gamificationService),
              _ChallengesTab(gamificationService: gamificationService),
              _BadgesTab(gamificationService: gamificationService),
              _RewardsTab(gamificationService: gamificationService),
            ],
          );
        },
      ),
    );
  }

  void _showGlobalStats() async {
    final service = context.read<GamificationService>();
    final stats = await service.getGlobalGamificationStats();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Statistiques Globales'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow(
                'Achievements totaux',
                '${stats['total_achievements'] ?? 0}',
              ),
              _buildStatRow(
                'Achievements actifs',
                '${stats['active_achievements'] ?? 0}',
              ),
              _buildStatRow(
                'Challenges totaux',
                '${stats['total_challenges'] ?? 0}',
              ),
              _buildStatRow(
                'Challenges actifs',
                '${stats['active_challenges'] ?? 0}',
              ),
              _buildStatRow('Badges totaux', '${stats['total_badges'] ?? 0}'),
              _buildStatRow('Badges actifs', '${stats['active_badges'] ?? 0}'),
              _buildStatRow(
                'Récompenses totales',
                '${stats['total_loyalty_rewards'] ?? 0}',
              ),
              _buildStatRow(
                'Récompenses actives',
                '${stats['active_loyalty_rewards'] ?? 0}',
              ),
              const Divider(),
              _buildStatRow(
                'Utilisateurs avec achievements',
                '${stats['users_with_achievements'] ?? 0}',
              ),
              _buildStatRow(
                'Utilisateurs avec challenges',
                '${stats['users_with_challenges'] ?? 0}',
              ),
              _buildStatRow(
                'Utilisateurs avec badges',
                '${stats['users_with_badges'] ?? 0}',
              ),
              const Divider(),
              _buildStatRow(
                'Transactions totales',
                '${stats['total_transactions'] ?? 0}',
              ),
              _buildStatRow(
                'Échanges totales',
                '${stats['total_redemptions'] ?? 0}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// =====================================================
// ACHIEVEMENTS TAB
// =====================================================

class _AchievementsTab extends StatelessWidget {
  final GamificationService gamificationService;

  const _AchievementsTab({required this.gamificationService});

  @override
  Widget build(BuildContext context) {
    final achievements = gamificationService.achievements;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAchievementForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Créer un Achievement'),
          ),
        ),
        Expanded(
          child: achievements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun achievement',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: achievements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final achievement = achievements[index];
                    return _buildAchievementCard(context, achievement);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(
    BuildContext context,
    Map<String, dynamic> achievement,
  ) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.amber.withValues(alpha: 0.15),
          child: Text(
            achievement['icon'] ?? '🏆',
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          achievement['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(achievement['description'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text('${achievement['points_reward'] ?? 0} pts'),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(achievement['condition_type'] ?? ''),
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(
                    achievement['is_active'] == true ? 'Actif' : 'Inactif',
                  ),
                  backgroundColor:
                      (achievement['is_active'] == true
                              ? Colors.green
                              : Colors.grey)
                          .withValues(alpha: 0.1),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Modifier'),
                onTap: () =>
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted) {
                        _showAchievementForm(context, achievement: achievement);
                      }
                    }),
              ),
              PopupMenuItem(
                child: Text(
                  achievement['is_active'] == true ? 'Désactiver' : 'Activer',
                ),
                onTap: () {
                  gamificationService.updateAchievement(achievement['id'], {
                    'is_active': !(achievement['is_active'] ?? true),
                  });
                },
              ),
              PopupMenuItem(
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  _confirmDelete(context, achievement['id'], () {
                    gamificationService.deleteAchievement(achievement['id']);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAchievementForm(
    BuildContext context, {
    Map<String, dynamic>? achievement,
  }) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => _AchievementFormDialog(achievement: achievement),
    );
  }

  void _confirmDelete(BuildContext context, String id, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cet achievement ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// CHALLENGES TAB
// =====================================================

class _ChallengesTab extends StatelessWidget {
  final GamificationService gamificationService;

  const _ChallengesTab({required this.gamificationService});

  @override
  Widget build(BuildContext context) {
    final challenges = gamificationService.challenges;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showChallengeForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Créer un Challenge'),
          ),
        ),
        Expanded(
          child: challenges.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun challenge',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: challenges.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final challenge = challenges[index];
                    return _buildChallengeCard(context, challenge);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(
    BuildContext context,
    Map<String, dynamic> challenge,
  ) {
    final endDate = challenge['end_date'] != null
        ? DateTime.parse(challenge['end_date'].toString())
        : DateTime.now();
    final isExpired = endDate.isBefore(DateTime.now());

    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.15),
          child: const Icon(Icons.flag, color: Colors.orange),
        ),
        title: Text(
          challenge['title'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(challenge['description'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text('${challenge['reward_points'] ?? 0} pts'),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(challenge['challenge_type'] ?? ''),
                  backgroundColor: Colors.purple.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(isExpired ? 'Expiré' : 'Actif'),
                  backgroundColor: (isExpired ? Colors.red : Colors.green)
                      .withValues(alpha: 0.1),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Fin: ${_formatDate(endDate)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Modifier'),
                onTap: () =>
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted) {
                        _showChallengeForm(context, challenge: challenge);
                      }
                    }),
              ),
              PopupMenuItem(
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  _confirmDelete(context, challenge['id'], () {
                    gamificationService.deleteChallenge(challenge['id']);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showChallengeForm(
    BuildContext context, {
    Map<String, dynamic>? challenge,
  }) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => _ChallengeFormDialog(challenge: challenge),
    );
  }

  void _confirmDelete(BuildContext context, String id, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce challenge ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// BADGES TAB
// =====================================================

class _BadgesTab extends StatelessWidget {
  final GamificationService gamificationService;

  const _BadgesTab({required this.gamificationService});

  @override
  Widget build(BuildContext context) {
    final badges = gamificationService.badges;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showBadgeForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Créer un Badge'),
          ),
        ),
        Expanded(
          child: badges.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun badge',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: badges.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final badge = badges[index];
                    return _buildBadgeCard(context, badge);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(BuildContext context, Map<String, dynamic> badge) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.withValues(alpha: 0.15),
          child: Text(
            badge['icon'] ?? '🏅',
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          badge['title'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(badge['description'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text('${badge['points_required'] ?? 0} pts requis'),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(badge['is_active'] == true ? 'Actif' : 'Inactif'),
                  backgroundColor:
                      (badge['is_active'] == true ? Colors.green : Colors.grey)
                          .withValues(alpha: 0.1),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Modifier'),
                onTap: () =>
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted) {
                        _showBadgeForm(context, badge: badge);
                      }
                    }),
              ),
              PopupMenuItem(
                child: Text(
                  badge['is_active'] == true ? 'Désactiver' : 'Activer',
                ),
                onTap: () {
                  gamificationService.updateBadge(badge['id'], {
                    'is_active': !(badge['is_active'] ?? true),
                  });
                },
              ),
              PopupMenuItem(
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  _confirmDelete(context, badge['id'], () {
                    gamificationService.deleteBadge(badge['id']);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBadgeForm(BuildContext context, {Map<String, dynamic>? badge}) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => _BadgeFormDialog(badge: badge),
    );
  }

  void _confirmDelete(BuildContext context, String id, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce badge ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// REWARDS TAB
// =====================================================

class _RewardsTab extends StatelessWidget {
  final GamificationService gamificationService;

  const _RewardsTab({required this.gamificationService});

  @override
  Widget build(BuildContext context) {
    final rewards = gamificationService.loyaltyRewards;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showRewardForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Créer une Récompense'),
          ),
        ),
        Expanded(
          child: rewards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.card_giftcard,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune récompense',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rewards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final reward = rewards[index];
                    return _buildRewardCard(context, reward);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRewardCard(BuildContext context, Map<String, dynamic> reward) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.15),
          child: const Icon(Icons.card_giftcard, color: Colors.green),
        ),
        title: Text(
          reward['title'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reward['description'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text('${reward['cost'] ?? 0} pts'),
                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(reward['reward_type'] ?? ''),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(
                    reward['is_active'] == true ? 'Actif' : 'Inactif',
                  ),
                  backgroundColor:
                      (reward['is_active'] == true ? Colors.green : Colors.grey)
                          .withValues(alpha: 0.1),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Modifier'),
                onTap: () =>
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted) {
                        _showRewardForm(context, reward: reward);
                      }
                    }),
              ),
              PopupMenuItem(
                child: Text(
                  reward['is_active'] == true ? 'Désactiver' : 'Activer',
                ),
                onTap: () {
                  gamificationService.updateLoyaltyReward(reward['id'], {
                    'is_active': !(reward['is_active'] ?? true),
                  });
                },
              ),
              PopupMenuItem(
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  _confirmDelete(context, reward['id'], () {
                    gamificationService.deleteLoyaltyReward(reward['id']);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRewardForm(BuildContext context, {Map<String, dynamic>? reward}) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => _RewardFormDialog(reward: reward),
    );
  }

  void _confirmDelete(BuildContext context, String id, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette récompense ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// FORM DIALOGS
// =====================================================

class _AchievementFormDialog extends StatefulWidget {
  final Map<String, dynamic>? achievement;

  const _AchievementFormDialog({this.achievement});

  @override
  State<_AchievementFormDialog> createState() => _AchievementFormDialogState();
}

class _AchievementFormDialogState extends State<_AchievementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _iconController = TextEditingController();
  final _pointsController = TextEditingController();
  final _conditionValueController = TextEditingController();
  final _badgeRewardController = TextEditingController();

  String _conditionType = 'orders_count';
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final a = widget.achievement;
    if (a != null) {
      _nameController.text = a['name'] ?? '';
      _descController.text = a['description'] ?? '';
      _iconController.text = a['icon'] ?? '🏆';
      _pointsController.text = (a['points_reward'] ?? 0).toString();
      _conditionValueController.text = (a['condition_value'] ?? 0).toString();
      _badgeRewardController.text = a['badge_reward'] ?? '';
      _conditionType = a['condition_type'] ?? 'orders_count';
      _isActive = a['is_active'] ?? true;
    } else {
      _iconController.text = '🏆';
      _pointsController.text = '0';
      _conditionValueController.text = '1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _iconController.dispose();
    _pointsController.dispose();
    _conditionValueController.dispose();
    _badgeRewardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 700,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.achievement == null
                          ? 'Créer un Achievement'
                          : 'Modifier un Achievement',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Nom requis' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Description requise'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _iconController,
                              decoration: const InputDecoration(
                                labelText: 'Icône (emoji) *',
                                border: OutlineInputBorder(),
                                hintText: '🏆',
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Icône requise'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _pointsController,
                              decoration: const InputDecoration(
                                labelText: 'Points de récompense *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  v == null || int.tryParse(v) == null
                                  ? 'Points invalides'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _conditionType,
                        decoration: const InputDecoration(
                          labelText: 'Type de condition *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'orders_count',
                            child: Text('Nombre de commandes'),
                          ),
                          DropdownMenuItem(
                            value: 'total_spent',
                            child: Text('Total dépensé'),
                          ),
                          DropdownMenuItem(
                            value: 'streak_days',
                            child: Text('Jours consécutifs'),
                          ),
                          DropdownMenuItem(
                            value: 'category_orders',
                            child: Text('Commandes par catégorie'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _conditionType = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _conditionValueController,
                        decoration: const InputDecoration(
                          labelText: 'Valeur de condition *',
                          border: OutlineInputBorder(),
                          hintText: 'Ex: 10 pour 10 commandes',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || int.tryParse(v) == null
                            ? 'Valeur invalide'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _badgeRewardController,
                        decoration: const InputDecoration(
                          labelText: 'Badge de récompense (optionnel)',
                          border: OutlineInputBorder(),
                          hintText: 'ID du badge',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Actif'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(
                      widget.achievement == null ? 'Créer' : 'Modifier',
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

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final service = context.read<GamificationService>();
      if (widget.achievement == null) {
        service.createAchievement(
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          icon: _iconController.text.trim(),
          pointsReward: int.parse(_pointsController.text),
          badgeReward: _badgeRewardController.text.trim().isEmpty
              ? null
              : _badgeRewardController.text.trim(),
          conditionType: _conditionType,
          conditionValue: int.parse(_conditionValueController.text),
          isActive: _isActive,
        );
      } else {
        service.updateAchievement(widget.achievement!['id'], {
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
          'icon': _iconController.text.trim(),
          'points_reward': int.parse(_pointsController.text),
          'badge_reward': _badgeRewardController.text.trim().isEmpty
              ? null
              : _badgeRewardController.text.trim(),
          'condition_type': _conditionType,
          'condition_value': int.parse(_conditionValueController.text),
          'is_active': _isActive,
        });
      }
      Navigator.pop(context);
    }
  }
}

class _ChallengeFormDialog extends StatefulWidget {
  final Map<String, dynamic>? challenge;

  const _ChallengeFormDialog({this.challenge});

  @override
  State<_ChallengeFormDialog> createState() => _ChallengeFormDialogState();
}

class _ChallengeFormDialogState extends State<_ChallengeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _rewardPointsController = TextEditingController();
  final _rewardDiscountController = TextEditingController();

  String _challengeType = 'orders_count';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final c = widget.challenge;
    if (c != null) {
      _titleController.text = c['title'] ?? '';
      _descController.text = c['description'] ?? '';
      _targetValueController.text = (c['target_value'] ?? 0).toString();
      _rewardPointsController.text = (c['reward_points'] ?? 0).toString();
      _rewardDiscountController.text = (c['reward_discount'] ?? 0.0).toString();
      _challengeType = c['challenge_type'] ?? 'orders_count';
      _startDate = c['start_date'] != null
          ? DateTime.parse(c['start_date'].toString())
          : DateTime.now();
      _endDate = c['end_date'] != null
          ? DateTime.parse(c['end_date'].toString())
          : DateTime.now().add(const Duration(days: 7));
      _isActive = c['is_active'] ?? true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _targetValueController.dispose();
    _rewardPointsController.dispose();
    _rewardDiscountController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 750,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.challenge == null
                          ? 'Créer un Challenge'
                          : 'Modifier un Challenge',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titre *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Titre requis' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Description requise'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _challengeType,
                        decoration: const InputDecoration(
                          labelText: 'Type de challenge *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'orders_count',
                            child: Text('Nombre de commandes'),
                          ),
                          DropdownMenuItem(
                            value: 'total_spent',
                            child: Text('Total dépensé'),
                          ),
                          DropdownMenuItem(
                            value: 'streak_days',
                            child: Text('Jours consécutifs'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _challengeType = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _targetValueController,
                        decoration: const InputDecoration(
                          labelText: 'Valeur cible *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || int.tryParse(v) == null
                            ? 'Valeur invalide'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rewardPointsController,
                              decoration: const InputDecoration(
                                labelText: 'Points de récompense',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _rewardDiscountController,
                              decoration: const InputDecoration(
                                labelText: 'Réduction (%)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('Date de début'),
                              subtitle: Text(
                                '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: _selectStartDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ListTile(
                              title: const Text('Date de fin'),
                              subtitle: Text(
                                '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: _selectEndDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Actif'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(
                      widget.challenge == null ? 'Créer' : 'Modifier',
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

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final service = context.read<GamificationService>();
      if (widget.challenge == null) {
        service.createChallenge(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          challengeType: _challengeType,
          targetValue: int.parse(_targetValueController.text),
          rewardPoints: int.tryParse(_rewardPointsController.text) ?? 0,
          rewardDiscount:
              double.tryParse(_rewardDiscountController.text) ?? 0.0,
          startDate: _startDate,
          endDate: _endDate,
          isActive: _isActive,
        );
      } else {
        service.updateChallenge(widget.challenge!['id'], {
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'challenge_type': _challengeType,
          'target_value': int.parse(_targetValueController.text),
          'reward_points': int.tryParse(_rewardPointsController.text) ?? 0,
          'reward_discount':
              double.tryParse(_rewardDiscountController.text) ?? 0.0,
          'start_date': _startDate.toIso8601String(),
          'end_date': _endDate.toIso8601String(),
          'is_active': _isActive,
        });
      }
      Navigator.pop(context);
    }
  }
}

class _BadgeFormDialog extends StatefulWidget {
  final Map<String, dynamic>? badge;

  const _BadgeFormDialog({this.badge});

  @override
  State<_BadgeFormDialog> createState() => _BadgeFormDialogState();
}

class _BadgeFormDialogState extends State<_BadgeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _iconController = TextEditingController();
  final _pointsRequiredController = TextEditingController();

  String _criteria = 'points';
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final b = widget.badge;
    if (b != null) {
      _titleController.text = b['title'] ?? '';
      _descController.text = b['description'] ?? '';
      _iconController.text = b['icon'] ?? '🏅';
      _pointsRequiredController.text = (b['points_required'] ?? 0).toString();
      _criteria = b['criteria'] ?? 'points';
      _isActive = b['is_active'] ?? true;
    } else {
      _iconController.text = '🏅';
      _pointsRequiredController.text = '0';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _iconController.dispose();
    _pointsRequiredController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 600,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.badge == null
                          ? 'Créer un Badge'
                          : 'Modifier un Badge',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titre *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Titre requis' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _iconController,
                              decoration: const InputDecoration(
                                labelText: 'Icône (emoji) *',
                                border: OutlineInputBorder(),
                                hintText: '🏅',
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Icône requise'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _pointsRequiredController,
                              decoration: const InputDecoration(
                                labelText: 'Points requis *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  v == null || int.tryParse(v) == null
                                  ? 'Points invalides'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _criteria,
                        decoration: const InputDecoration(
                          labelText: 'Critère *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'points',
                            child: Text('Points'),
                          ),
                          DropdownMenuItem(
                            value: 'orders',
                            child: Text('Commandes'),
                          ),
                          DropdownMenuItem(
                            value: 'spending',
                            child: Text('Dépenses'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _criteria = v!),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Actif'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(widget.badge == null ? 'Créer' : 'Modifier'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final service = context.read<GamificationService>();
      if (widget.badge == null) {
        service.createBadge(
          title: _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          icon: _iconController.text.trim(),
          pointsRequired: int.parse(_pointsRequiredController.text),
          criteria: _criteria,
          isActive: _isActive,
        );
      } else {
        service.updateBadge(widget.badge!['id'], {
          'title': _titleController.text.trim(),
          'description': _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          'icon': _iconController.text.trim(),
          'points_required': int.parse(_pointsRequiredController.text),
          'criteria': _criteria,
          'is_active': _isActive,
        });
      }
      Navigator.pop(context);
    }
  }
}

class _RewardFormDialog extends StatefulWidget {
  final Map<String, dynamic>? reward;

  const _RewardFormDialog({this.reward});

  @override
  State<_RewardFormDialog> createState() => _RewardFormDialogState();
}

class _RewardFormDialogState extends State<_RewardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _costController = TextEditingController();
  final _valueController = TextEditingController();

  String _rewardType = 'discount';
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final r = widget.reward;
    if (r != null) {
      _titleController.text = r['title'] ?? '';
      _descController.text = r['description'] ?? '';
      _costController.text = (r['cost'] ?? 0).toString();
      _valueController.text = (r['value'] ?? 0.0).toString();
      _rewardType = r['reward_type'] ?? 'discount';
      _isActive = r['is_active'] ?? true;
    } else {
      _costController.text = '0';
      _valueController.text = '0';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _costController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 650,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.reward == null
                          ? 'Créer une Récompense'
                          : 'Modifier une Récompense',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titre *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Titre requis' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _costController,
                              decoration: const InputDecoration(
                                labelText: 'Coût (points) *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  v == null || int.tryParse(v) == null
                                  ? 'Coût invalide'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _rewardType,
                              decoration: const InputDecoration(
                                labelText: 'Type de récompense *',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'discount',
                                  child: Text('Réduction'),
                                ),
                                DropdownMenuItem(
                                  value: 'free_item',
                                  child: Text('Article gratuit'),
                                ),
                                DropdownMenuItem(
                                  value: 'free_delivery',
                                  child: Text('Livraison gratuite'),
                                ),
                                DropdownMenuItem(
                                  value: 'points',
                                  child: Text('Points bonus'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _rewardType = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _valueController,
                        decoration: InputDecoration(
                          labelText: _rewardType == 'discount'
                              ? 'Valeur de réduction (%) *'
                              : _rewardType == 'free_item'
                              ? 'ID de l\'article *'
                              : _rewardType == 'points'
                              ? 'Nombre de points *'
                              : 'Valeur *',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: _rewardType == 'free_item'
                            ? TextInputType.text
                            : TextInputType.number,
                        validator: (v) {
                          if (_rewardType == 'free_item') {
                            return v == null || v.isEmpty
                                ? 'ID de l\'article requis'
                                : null;
                          }
                          return v == null ||
                                  (_rewardType == 'points'
                                      ? int.tryParse(v) == null
                                      : double.tryParse(v) == null)
                              ? 'Valeur invalide'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Actif'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(widget.reward == null ? 'Créer' : 'Modifier'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final service = context.read<GamificationService>();
      if (widget.reward == null) {
        service.createLoyaltyReward(
          title: _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          cost: int.parse(_costController.text),
          rewardType: _rewardType,
          value: _rewardType == 'free_item'
              ? null
              : (_rewardType == 'points'
                    ? double.tryParse(_valueController.text)?.toDouble()
                    : double.tryParse(_valueController.text)),
          isActive: _isActive,
        );
      } else {
        service.updateLoyaltyReward(widget.reward!['id'], {
          'title': _titleController.text.trim(),
          'description': _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          'cost': int.parse(_costController.text),
          'reward_type': _rewardType,
          'value': _rewardType == 'free_item'
              ? null
              : (_rewardType == 'points'
                    ? double.tryParse(_valueController.text)?.toDouble()
                    : double.tryParse(_valueController.text)),
          'is_active': _isActive,
        });
      }
      Navigator.pop(context);
    }
  }
}
