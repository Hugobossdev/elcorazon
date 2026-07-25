import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/dialog_helper.dart';
import '../../services/marketing_service.dart';
import '../../ui/ui.dart';

class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Marketing & Campagnes'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: 'Campagnes'),
            Tab(text: 'Analytics'),
            Tab(text: 'Clients'),
          ],
        ),
      ),
      body: Consumer<MarketingService>(
        builder: (context, marketingService, child) {
          if (!marketingService.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _CampaignsTab(),
              _AnalyticsTab(),
              _CustomersTab(),
            ],
          );
        },
      ),
    );
  }
}

class _CampaignsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer<MarketingService>(
      builder: (context, marketingService, child) {
        final campaigns = marketingService.campaigns;

        return Column(
          children: [
            _buildCampaignStats(context, campaigns),
            Expanded(
              child: campaigns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.campaign,
                            size: 64,
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune campagne active',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: campaigns.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final campaign = campaigns[index];
                        return _buildCampaignCard(context, campaign);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCampaignStats(
      BuildContext context, List<MarketingCampaign> campaigns) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    final active = campaigns.where((c) => c.isActive).length;
    final total = campaigns.length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
                context, 'Total', '$total', Icons.campaign, scheme.primary),
          ),
          Expanded(
            child: _buildStatItem(
                context, 'Actives', '$active', Icons.check_circle, sem.success),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value,
      IconData icon, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignCard(BuildContext context, MarketingCampaign campaign) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 56,
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _getCampaignColor(scheme, campaign.type)
                .withValues(alpha: 0.15),
            child: Icon(
              _getCampaignIcon(campaign.type),
              color: _getCampaignColor(scheme, campaign.type),
            ),
          ),
          title: Text(
            campaign.name,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                campaign.title,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Chip(
                    label: Text(
                      campaign.type.toUpperCase(),
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: _getCampaignColor(scheme, campaign.type)
                        .withValues(alpha: 0.1),
                  ),
                  const SizedBox(width: 4),
                  Chip(
                    label: Text(
                      campaign.isActive ? 'Actif' : 'Inactif',
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: campaign.isActive
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerHighest,
                  ),
                ],
              ),
            ],
          ),
          trailing: Material(
            color: scheme.surface,
            child: InkWell(
              onTap: () => _showCampaignOptions(context, campaign),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(Icons.more_vert, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getCampaignColor(ColorScheme scheme, String type) {
    switch (type) {
      case 'personalized':
        return scheme.secondary;
      case 'seasonal':
        return scheme.tertiary;
      case 'promotional':
        return scheme.primary;
      case 'retention':
        return scheme.error;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  IconData _getCampaignIcon(String type) {
    switch (type) {
      case 'personalized':
        return Icons.person;
      case 'seasonal':
        return Icons.event;
      case 'promotional':
        return Icons.local_offer;
      case 'retention':
        return Icons.loyalty;
      default:
        return Icons.campaign;
    }
  }

  void _showCampaignOptions(BuildContext context, MarketingCampaign campaign) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        children: [
          Container(
            constraints: const BoxConstraints(
              minHeight: 56,
            ),
            child: ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Voir les détails'),
              onTap: () => _showCampaignDetails(context, campaign),
            ),
          ),
          Container(
            constraints: const BoxConstraints(
              minHeight: 56,
            ),
            child: ListTile(
              leading: Icon(campaign.isActive ? Icons.pause : Icons.play_arrow),
              title: Text(campaign.isActive ? 'Désactiver' : 'Activer'),
              onTap: () async {
                Navigator.pop(context);
                await _toggleCampaignStatus(context, campaign);
              },
            ),
          ),
          Container(
            constraints: const BoxConstraints(
              minHeight: 56,
            ),
            child: ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Voir les métriques'),
              onTap: () {
                Navigator.pop(context);
                _showCampaignMetrics(context, campaign);
              },
            ),
          ),
          Container(
            constraints: const BoxConstraints(
              minHeight: 56,
            ),
            child: ListTile(
              leading: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.error),
              title: Text(
                'Supprimer',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteCampaign(context, campaign);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCampaignDetails(BuildContext context, MarketingCampaign campaign) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(campaign.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Type: ${campaign.type}'),
              const SizedBox(height: 8),
              Text('Titre: ${campaign.title}'),
              const SizedBox(height: 8),
              Text('Message: ${campaign.message}'),
              const SizedBox(height: 8),
              Text('Cible: ${campaign.targetUserIds.length} utilisateurs'),
              const SizedBox(height: 8),
              Text('Début: ${_formatDate(campaign.startDate)}'),
              const SizedBox(height: 8),
              Text('Fin: ${_formatDate(campaign.endDate)}'),
              const SizedBox(height: 8),
              Text('Statut: ${campaign.isActive ? "Actif" : "Inactif"}'),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _toggleCampaignStatus(
      BuildContext context, MarketingCampaign campaign) async {
    final marketingService =
        Provider.of<MarketingService>(context, listen: false);
    final newStatus = !campaign.isActive;

    try {
      final success = await marketingService.updateCampaign(
        campaign.id,
        {'is_active': newStatus},
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Campagne activée avec succès'
                  : 'Campagne désactivée avec succès',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de la mise à jour de la campagne'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showCampaignMetrics(BuildContext context, MarketingCampaign campaign) {
    final marketingService =
        Provider.of<MarketingService>(context, listen: false);
    final performance = marketingService.getCampaignPerformance(campaign.id);

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Métriques - ${campaign.name}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMetricRow(
                  'Notifications envoyées', '${performance['sent']}'),
              const SizedBox(height: 8),
              _buildMetricRow('Clics', '${performance['clicks']}'),
              const SizedBox(height: 8),
              _buildMetricRow('Conversions', '${performance['conversions']}'),
              const SizedBox(height: 8),
              _buildMetricRow(
                'Taux de clic',
                '${performance['clickRate']}%',
              ),
              const SizedBox(height: 8),
              _buildMetricRow(
                'Taux de conversion',
                '${performance['conversionRate']}%',
              ),
              const SizedBox(height: 8),
              _buildMetricRow(
                'Statut',
                performance['isActive'] ? 'Actif' : 'Inactif',
              ),
              const SizedBox(height: 8),
              _buildMetricRow(
                'Jours restants',
                '${performance['daysRemaining']}',
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

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _confirmDeleteCampaign(
      BuildContext context, MarketingCampaign campaign) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer la campagne "${campaign.name}" ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteCampaign(context, campaign);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCampaign(
      BuildContext context, MarketingCampaign campaign) async {
    final marketingService =
        Provider.of<MarketingService>(context, listen: false);

    try {
      final success = await marketingService.deleteCampaign(campaign.id);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Campagne supprimée avec succès'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de la suppression de la campagne'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _AnalyticsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer<MarketingService>(
      builder: (context, marketingService, child) {
        final analytics = marketingService.analytics;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: analytics.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final analytic = analytics[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.insights, color: scheme.primary),
                ),
                title: Text(analytic.type),
                subtitle: Text(
                    'Confiance: ${(analytic.confidence * 100).toStringAsFixed(1)}%'),
                trailing: Material(
                  color: scheme.surface,
                  child: InkWell(
                    onTap: () => _showAnalyticDetails(context, analytic),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_forward, size: 24),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAnalyticDetails(
      BuildContext context, PredictiveAnalytics analytic) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(analytic.type),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Confiance: ${(analytic.confidence * 100).toStringAsFixed(1)}%'),
              const SizedBox(height: 16),
              const Text(
                'Prédictions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...analytic.predictions.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${entry.key}: ${entry.value}'),
                  )),
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
}

class _CustomersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    return Consumer<MarketingService>(
      builder: (context, marketingService, child) {
        final insights = marketingService.customerInsights;

        if (insights.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people,
                  size: 64,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune donnée client disponible',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: insights.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final entry = insights.entries.elementAt(index);
            final insight = entry.value;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: insight.churnRisk > 0.7
                      ? scheme.error.withValues(alpha: 0.15)
                      : sem.success.withValues(alpha: 0.15),
                  child: Icon(
                    insight.churnRisk > 0.7 ? Icons.warning : Icons.favorite,
                    color: insight.churnRisk > 0.7 ? scheme.error : sem.success,
                  ),
                ),
                title: Text('Client ${entry.key.substring(0, 8)}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Risque d\'abandon: ${(insight.churnRisk * 100).toStringAsFixed(0)}%'),
                    if (insight.recommendedActions.isNotEmpty)
                      Text(
                        'Actions: ${insight.recommendedActions.first}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                trailing: Material(
                  color: scheme.surface,
                  child: InkWell(
                    onTap: () => _showCustomerDetails(context, entry),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_forward, size: 24),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomerDetails(
      BuildContext context, MapEntry<String, CustomerInsight> entry) {
    final insight = entry.value;
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Client ${entry.key.substring(0, 8)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Risque d\'abandon: '),
                  Text(
                    '${(insight.churnRisk * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: insight.churnRisk > 0.7
                          ? Theme.of(context).colorScheme.error
                          : AdminColorTokens.semantic(
                              Theme.of(context).colorScheme,
                            ).success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Actions recommandées:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...insight.recommendedActions.map((action) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $action'),
                  )),
              const SizedBox(height: 16),
              const Text(
                'Préférences:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...insight.preferences.entries.map((pref) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${pref.key}: ${pref.value}'),
                  )),
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
}
