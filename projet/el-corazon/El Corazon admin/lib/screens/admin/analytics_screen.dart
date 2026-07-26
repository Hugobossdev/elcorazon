import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/analytics_service.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/price_formatter.dart';
import '../../ui/ui.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  Map<String, dynamic>? _generalStats;
  Map<String, dynamic>? _revenueData;
  Map<String, dynamic>? _orderData;
  Map<String, dynamic>? _categoryData;
  Map<String, dynamic>? _driverData;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final analyticsService =
        Provider.of<AnalyticsService>(context, listen: false);

    // Charger les statistiques générales
    _generalStats = await analyticsService.getGeneralStats();

    // Charger les données de revenus
    _revenueData = await analyticsService.getRevenueAnalytics(
      startDate: _startDate,
      endDate: _endDate,
    );

    // Charger les données des commandes
    _orderData = await analyticsService.getOrderAnalytics(
      startDate: _startDate,
      endDate: _endDate,
    );

    // Charger les données des catégories
    _categoryData = await analyticsService.getCategoryAnalytics(
      startDate: _startDate,
      endDate: _endDate,
    );

    // Charger les données des livreurs
    _driverData = await analyticsService.getDriverAnalytics(
      startDate: _startDate,
      endDate: _endDate,
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    // Pas d'AppBar ici car il est déjà géré par AdminNavigationScreen
    return Column(
      children: [
        // Barre d'actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            boxShadow: [
              BoxShadow(
                color: sem.shadow,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Material(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
                child: InkWell(
                  onTap: _loadAnalytics,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    // IMPORTANT: Row avec contraintes pour garantir des contraintes
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh, size: 20),
                        SizedBox(width: 8),
                        Text('Actualiser'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Contenu
        Expanded(
          child: Consumer<AnalyticsService>(
        builder: (context, analyticsService, child) {
          if (analyticsService.isLoading) {
            return const LoadingWidget(message: 'Chargement des analytics...');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateRangeSelector(),
                const SizedBox(height: 20),
                _buildGeneralStatsCard(),
                const SizedBox(height: 20),
                _buildRevenueCard(),
                const SizedBox(height: 20),
                _buildOrdersCard(),
                const SizedBox(height: 20),
                _buildCategoriesCard(),
                const SizedBox(height: 20),
                _buildDriversCard(),
              ],
            ),
          );
        },
      ),
    ),
    ],
    );
  }

  Widget _buildDateRangeSelector() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Période d\'analyse',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date de début'),
                      const SizedBox(height: 8),
                      Material(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                _startDate = date;
                              });
                              _loadAnalytics();
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(
                              minHeight: 48,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: scheme.outline.withValues(alpha: 0.35),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            // IMPORTANT: Row sans mainAxisSize.min car le Container a width: double.infinity
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date de fin'),
                      const SizedBox(height: 8),
                      Material(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: _startDate,
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                _endDate = date;
                              });
                              _loadAnalytics();
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(
                              minHeight: 48,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: scheme.outline.withValues(alpha: 0.35),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            // IMPORTANT: Row sans mainAxisSize.min car le Container a width: double.infinity
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralStatsCard() {
    if (_generalStats == null) return const SizedBox.shrink();

    final orders = _generalStats!['orders'] as Map<String, dynamic>;
    final revenue = _generalStats!['revenue'] as Map<String, dynamic>;
    final users = _generalStats!['users'] as Map<String, dynamic>;
    final products = _generalStats!['products'] as Map<String, dynamic>;
    final drivers = _generalStats!['drivers'] as Map<String, dynamic>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistiques Générales',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildStatCard(
                  'Commandes Total',
                  orders['total'].toString(),
                  Icons.shopping_cart,
                  Theme.of(context).colorScheme.primary,
                ),
                _buildStatCard(
                  'Commandes Complétées',
                  orders['completed'].toString(),
                  Icons.check_circle,
                  AdminColorTokens.semantic(Theme.of(context).colorScheme).success,
                ),
                _buildStatCard(
                  'Revenus Total',
                  formatPrice(revenue['total']),
                  Icons.attach_money,
                  AdminColorTokens.semantic(Theme.of(context).colorScheme).warning,
                ),
                _buildStatCard(
                  'Valeur Moyenne',
                  formatPrice(revenue['averageOrderValue']),
                  Icons.trending_up,
                  Theme.of(context).colorScheme.tertiary,
                ),
                _buildStatCard(
                  'Utilisateurs',
                  users['total'].toString(),
                  Icons.people,
                  Theme.of(context).colorScheme.secondary,
                ),
                _buildStatCard(
                  'Produits',
                  products['total'].toString(),
                  Icons.restaurant,
                  Theme.of(context).colorScheme.error,
                ),
                _buildStatCard(
                  'Livreurs Actifs',
                  drivers['active'].toString(),
                  Icons.delivery_dining,
                  Theme.of(context).colorScheme.primary,
                ),
                _buildStatCard(
                  'Taux de Complétion',
                  '${orders['completionRate'].toStringAsFixed(1)}%',
                  Icons.percent,
                  AdminColorTokens.semantic(Theme.of(context).colorScheme).warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    if (_revenueData == null) return const SizedBox.shrink();

    final totalRevenue = _revenueData!['totalRevenue'] as double;
    final dailyRevenue = _revenueData!['dailyRevenue'] as Map<String, double>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyses des Revenus',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Revenus Total',
                    formatPrice(totalRevenue),
                    Icons.attach_money,
                    AdminColorTokens.semantic(Theme.of(context).colorScheme).success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Jours Actifs',
                    dailyRevenue.length.toString(),
                    Icons.calendar_today,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (dailyRevenue.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: _buildRevenueLineChart(dailyRevenue),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersCard() {
    if (_orderData == null) return const SizedBox.shrink();

    final totalOrders = _orderData!['totalOrders'] as int;
    final statusCounts = _orderData!['statusCounts'] as Map<String, int>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyses des Commandes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              'Total Commandes',
              totalOrders.toString(),
              Icons.shopping_cart,
              Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _buildStatusBarChart(statusCounts),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesCard() {
    if (_categoryData == null) return const SizedBox.shrink();

    final categoryCounts = _categoryData!['categoryCounts'] as Map<String, int>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyses par Catégorie',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (categoryCounts.isNotEmpty) ...[
              SizedBox(
                height: 300,
                child: _buildCategoryPieChart(categoryCounts),
              ),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('Aucune donnée disponible pour cette période.'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDriversCard() {
    if (_driverData == null) return const SizedBox.shrink();

    final driverDeliveries =
        _driverData!['driverDeliveries'] as Map<String, int>;
    // final driverRatings = _driverData!['driverRatings'] as Map<String, double>; // Variable non utilisée

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyses des Livreurs',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (driverDeliveries.isNotEmpty) ...[
              SizedBox(
                height: 300,
                child: _buildDriverBarChart(driverDeliveries),
              ),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('Aucune donnée disponible pour cette période.'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Méthodes de construction des graphiques

  Widget _buildRevenueLineChart(Map<String, double> dailyRevenue) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    final sortedKeys = dailyRevenue.keys.toList()..sort();
    final maxRevenue = dailyRevenue.values.isEmpty
        ? 1.0
        : dailyRevenue.values.reduce((a, b) => a > b ? a : b);
    
    final spots = sortedKeys.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), dailyRevenue[entry.value] ?? 0.0);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxRevenue > 0 ? (maxRevenue / 5) : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: scheme.outline.withValues(alpha: 0.20),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < sortedKeys.length) {
                  final dateStr = sortedKeys[value.toInt()];
                  final date = DateTime.tryParse(dateStr);
                  if (date != null) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${date.day}/${date.month}',
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  formatPrice(value),
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
            left: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: sem.success,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: sem.success.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBarChart(Map<String, int> statusCounts) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    final entries = statusCounts.entries.toList();
    final maxValue = entries.isEmpty
        ? 1.0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue + (maxValue * 0.2),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => scheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final status = entries[group.x.toInt()].key;
              final count = entries[group.x.toInt()].value;
              return BarTooltipItem(
                '$count\n$status',
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
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < entries.length) {
                  final status = entries[value.toInt()].key;
                  // Raccourcir les noms de statut pour l'affichage
                  final shortStatus = status.length > 10
                      ? '${status.substring(0, 10)}...'
                      : status;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      shortStatus,
                      style: TextStyle(
                        fontSize: 9,
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 50,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue > 0 ? (maxValue / 5) : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: scheme.outline.withValues(alpha: 0.20),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
            left: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
          ),
        ),
        barGroups: entries.asMap().entries.map((entry) {
          final index = entry.key;
          final count = entry.value.value;
          final colors = [
            sem.info,
            sem.success,
            sem.warning,
            scheme.tertiary,
            sem.danger,
            scheme.secondary,
            scheme.primaryContainer,
          ];
          final color = colors[index % colors.length];

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: color,
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryPieChart(Map<String, int> categoryCounts) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    final total = categoryCounts.values.fold(0, (sum, val) => sum + val);
    final colors = [
      sem.warning,
      sem.danger,
      sem.info,
      scheme.tertiary,
      sem.success,
      scheme.secondary,
      scheme.primaryContainer,
      scheme.tertiaryContainer,
      scheme.secondaryContainer,
    ];

    final sections = categoryCounts.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final categoryEntry = entry.value;
      final percentage = total > 0 ? (categoryEntry.value / total * 100) : 0.0;
      final color = colors[index % colors.length];

      return PieChartSectionData(
        color: color,
        value: categoryEntry.value.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: scheme.onPrimary,
        ),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: categoryCounts.entries.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final categoryEntry = entry.value;
              final color = colors[index % colors.length];
              final percentage = total > 0
                  ? (categoryEntry.value / total * 100)
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        categoryEntry.key,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${categoryEntry.value} (${percentage.toStringAsFixed(1)}%)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverBarChart(Map<String, int> driverDeliveries) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    final entries = driverDeliveries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Trier par nombre de livraisons
    final topDrivers = entries.take(10).toList(); // Top 10 livreurs
    final maxValue = topDrivers.isEmpty
        ? 1.0
        : topDrivers.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue + (maxValue * 0.2),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => scheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (group.x.toInt() >= 0 && group.x.toInt() < topDrivers.length) {
                final driver = topDrivers[group.x.toInt()];
                return BarTooltipItem(
                  '${driver.value} livraisons\n${driver.key}',
                  TextStyle(
                    color: scheme.onInverseSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }
              return BarTooltipItem('', const TextStyle());
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < topDrivers.length) {
                  final driverName = topDrivers[value.toInt()].key;
                  final shortName = driverName.length > 8
                      ? '${driverName.substring(0, 8)}...'
                      : driverName;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      shortName,
                      style: TextStyle(
                        fontSize: 9,
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 50,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue > 0 ? (maxValue / 5) : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: scheme.outline.withValues(alpha: 0.20),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
            left: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
          ),
        ),
        barGroups: topDrivers.asMap().entries.map((entry) {
          final index = entry.key;
          final count = entry.value.value;
          final color = index < 3
              ? [sem.warning, scheme.onSurfaceVariant, scheme.tertiary][index]
              : sem.info;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: color,
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
