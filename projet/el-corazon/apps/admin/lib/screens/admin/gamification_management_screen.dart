import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin/services/gamification_service.dart';
import 'package:admin/screens/admin/gamification/achievements.dart';
import 'package:admin/screens/admin/gamification/badges.dart';
import 'package:admin/screens/admin/gamification/challenges.dart';
import 'package:admin/screens/admin/gamification/rewards.dart';

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
              AchievementsTab(gamificationService: gamificationService),
              ChallengesTab(gamificationService: gamificationService),
              BadgesTab(gamificationService: gamificationService),
              RewardsTab(gamificationService: gamificationService),
            ],
          );
        },
      ),
    );
  }

  void _showGlobalStats() {
    final service = context.read<GamificationService>();
    // Compteurs du catalogue : « combien de clients ont débloqué ceci »
    // demandait de charger toutes les lignes de progression de tous les
    // comptes sur un poste de travail. C'est un agrégat, il appartient aux
    // rapports.
    final stats = service.catalogueStats;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Catalogue de fidélisation'),
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
