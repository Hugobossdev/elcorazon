import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/statut_commande.dart';
import 'package:admin/presentation/couleur_statut.dart';
import 'package:admin/presentation/evolution_commandes.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/ui/ui.dart';
import 'package:admin/utils/price_formatter.dart';

/// L'onglet « Statistiques » de la gestion avancée des commandes.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// 477 lignes de l'écran ne lisaient **rien** de son état : ni la recherche,
/// ni le tri, ni l'onglet courant. Elles n'avaient donc aucune raison d'y
/// être. Le comptage par jour qu'elles portaient est parti dans
/// `evolution_commandes.dart`, où des tests peuvent l'atteindre.
class OngletStatistiques extends StatelessWidget {
  const OngletStatistiques({required this.orderService, super.key});

  final OrderManagementService orderService;

  @override
  Widget build(BuildContext context) {
    // Un seul relevé pour les deux blocs qui le lisent : deux appels
    // pourraient rendre des chiffres qui ne s'accordent pas.
    final stats = orderService.getOrderStats();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatistiquesDetaillees(stats: stats),
          const SizedBox(height: 20),
          _CartesDePerformance(stats: orderService.getPerformanceStats()),
          const SizedBox(height: 20),
          _RepartitionParStatut(stats: stats),
          const SizedBox(height: 20),
          _EvolutionDesCommandes(commandes: orderService.allOrders),
        ],
      ),
    );
  }
}

class _StatistiquesDetaillees extends StatelessWidget {
  const _StatistiquesDetaillees({required this.stats});

  final Map<String, dynamic> stats;

  String _montant(String cle) =>
      PriceFormatter.format((stats[cle] as num?)?.toDouble() ?? 0.0);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistiques détaillées',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _LigneDeStat('Commandes totales', '${stats['total_orders'] ?? 0}'),
            _LigneDeStat('En attente', '${stats['pending_orders'] ?? 0}'),
            _LigneDeStat('Confirmées', '${stats['confirmed_orders'] ?? 0}'),
            _LigneDeStat('En préparation', '${stats['preparing_orders'] ?? 0}'),
            _LigneDeStat('Prêtes', '${stats['ready_orders'] ?? 0}'),
            _LigneDeStat('Livrées', '${stats['delivered_orders'] ?? 0}'),
            _LigneDeStat('Annulées', '${stats['cancelled_orders'] ?? 0}'),
            const Divider(),
            _LigneDeStat('Revenus totaux', _montant('total_revenue')),
            _LigneDeStat('Panier moyen', _montant('average_order_value')),
          ],
        ),
      ),
    );
  }
}

class _LigneDeStat extends StatelessWidget {
  const _LigneDeStat(this.label, this.valeur);

  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(valeur, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _CartesDePerformance extends StatelessWidget {
  const _CartesDePerformance({required this.stats});

  final Map<String, dynamic> stats;

  double _nombre(String cle) => (stats[cle] as num?)?.toDouble() ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final sem = AdminColorTokens.semantic(Theme.of(context).colorScheme);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _CartePerformance(
          titre: 'Temps moyen',
          valeur: '${_nombre('average_delivery_time').toInt()} min',
          icone: Icons.timer,
          couleur: sem.info,
        ),
        _CartePerformance(
          titre: 'Livraison à temps',
          valeur: '${_nombre('on_time_delivery_rate') * 100}%',
          icone: Icons.schedule,
          couleur: sem.success,
        ),
        _CartePerformance(
          titre: 'Satisfaction',
          valeur: '${_nombre('customer_satisfaction')}/5',
          icone: Icons.star,
          couleur: sem.warning,
        ),
      ],
    );
  }
}

class _CartePerformance extends StatelessWidget {
  const _CartePerformance({
    required this.titre,
    required this.valeur,
    required this.icone,
    required this.couleur,
  });

  final String titre;
  final String valeur;
  final IconData icone;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, color: couleur, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              valeur,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: couleur,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              titre,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RepartitionParStatut extends StatelessWidget {
  const _RepartitionParStatut({required this.stats});

  final Map<String, dynamic> stats;

  static const _lignes = <(String, String, StatutCommande)>[
    ('En attente', 'pending_orders', StatutCommande.enAttente),
    ('Confirmées', 'confirmed_orders', StatutCommande.confirmee),
    ('En préparation', 'preparing_orders', StatutCommande.enPreparation),
    ('Prêtes', 'ready_orders', StatutCommande.prete),
    ('Livrées', 'delivered_orders', StatutCommande.livree),
    ('Annulées', 'cancelled_orders', StatutCommande.annulee),
  ];

  @override
  Widget build(BuildContext context) {
    final total = stats['total_orders'] as int? ?? 0;
    if (total == 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition par statut',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            for (final (label, cle, statut) in _lignes)
              _BarreDeStatut(
                label: label,
                nombre: stats[cle] as int? ?? 0,
                total: total,
                couleur: couleurDeStatut(statut, scheme),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarreDeStatut extends StatelessWidget {
  const _BarreDeStatut({
    required this.label,
    required this.nombre,
    required this.total,
    required this.couleur,
  });

  final String label;
  final int nombre;
  final int total;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final part = total > 0 ? nombre / total : 0.0;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label)),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: part,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(couleur),
            ),
          ),
          const SizedBox(width: 8),
          Text('$nombre (${(part * 100).toInt()}%)'),
        ],
      ),
    );
  }
}

class _EvolutionDesCommandes extends StatelessWidget {
  const _EvolutionDesCommandes({required this.commandes});

  final List<eccore.Order> commandes;

  @override
  Widget build(BuildContext context) {
    final parJour = commandesParJour(commandes);
    final jours = parJour.keys.toList();
    final maximum = parJour.values.isEmpty
        ? 1.0
        : parJour.values.reduce((a, b) => a > b ? a : b).toDouble();
    final surLaFenetre = parJour.values.fold<int>(0, (a, b) => a + b);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Évolution des commandes (7 derniers jours)',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: jours.isEmpty
                  ? const Center(child: Text('Aucune donnée disponible'))
                  : BarChart(
                      _donneesDuGraphe(context, parJour, jours, maximum),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Total: $surLaFenetre commandes sur 7 jours',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  BarChartData _donneesDuGraphe(
    BuildContext context,
    Map<String, int> parJour,
    List<String> jours,
    double maximum,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final discret = TextStyle(fontSize: 10, color: scheme.onSurfaceVariant);

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      // 20 % d'air au-dessus de la plus haute barre.
      maxY: maximum + (maximum * 0.2),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => scheme.inverseSurface,
          tooltipPadding: const EdgeInsets.all(8),
          tooltipMargin: 8,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final jour = jours[group.x.toInt()];
            final nombre = parJour[jour] ?? 0;

            return BarTooltipItem(
              '$nombre commande${nombre > 1 ? 's' : ''}\n$jour',
              TextStyle(
                color: scheme.onInverseSurface,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= jours.length) {
                return const SizedBox.shrink();
              }

              final parties = jours[index].split('-');
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${parties[2]}/${parties[1]}', style: discret),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              if (value == meta.min || value == meta.max) {
                return const SizedBox.shrink();
              }
              return Text(value.toInt().toString(), style: discret);
            },
          ),
        ),
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
      ),
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: maximum > 0 ? (maximum / 5) : 1,
        getDrawingHorizontalLine: (value) => FlLine(
          color: scheme.outline.withValues(alpha: 0.20),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(
        border: Border(
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
          left: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
        ),
      ),
      barGroups: [
        for (final (index, jour) in jours.indexed)
          BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (parJour[jour] ?? 0).toDouble(),
                color: scheme.primary,
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
