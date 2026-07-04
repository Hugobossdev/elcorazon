import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/performance_service.dart';
import '../../services/error_handler_service.dart';
import '../../services/app_service.dart';
import '../../models/order.dart';
import 'settings_screen.dart';
import 'driver_profile_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    if (!mounted) return;

    try {
      await Provider.of<PerformanceService>(context, listen: false)
          .initialize()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      if (mounted) {
        Provider.of<ErrorHandlerService>(context, listen: false)
            .logError('Erreur initialisation analytics', details: e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Performance'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverProfileScreen(),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Mon profil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Paramètres'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: 'Performance', icon: Icon(Icons.speed)),
            Tab(text: 'Statistiques', icon: Icon(Icons.analytics)),
            Tab(text: 'Rapports', icon: Icon(Icons.assessment)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPerformanceTab(),
          _buildStatisticsTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return Consumer<PerformanceService>(
      builder: (context, performanceService, child) {
        if (!performanceService.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPerformanceOverview(performanceService),
              const SizedBox(height: 20),
              _buildOperationTimes(performanceService),
              const SizedBox(height: 20),
              _buildPerformanceMetrics(performanceService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatisticsTab() {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final deliveries = appService.assignedDeliveries;
        final completedToday = deliveries
            .where((order) =>
                order.status == OrderStatus.delivered &&
                _isToday(order.orderTime))
            .length;
        final completedThisWeek = deliveries
            .where((order) =>
                order.status == OrderStatus.delivered &&
                _isThisWeek(order.orderTime))
            .length;
        final completedThisMonth = deliveries
            .where((order) =>
                order.status == OrderStatus.delivered &&
                _isThisMonth(order.orderTime))
            .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsOverview(
                  completedToday, completedThisWeek, completedThisMonth),
              const SizedBox(height: 20),
              _buildDeliveryChart(deliveries),
              const SizedBox(height: 20),
              _buildEarningsBreakdown(deliveries),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportActions(),
          const SizedBox(height: 20),
          _buildRecentReports(),
        ],
      ),
    );
  }

  Widget _buildPerformanceOverview(PerformanceService performanceService) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vue d\'ensemble des performances',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceMetric(
                    'Temps moyen',
                    '${performanceService.averageOperationTime?.inMinutes ?? 0} min',
                    Icons.timer,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPerformanceMetric(
                    'Opérations',
                    '${performanceService.operationCount}',
                    Icons.assignment_turned_in,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceMetric(
                    'Erreurs',
                    '${performanceService.errorCount}',
                    Icons.error_outline,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPerformanceMetric(
                    'Score',
                    '${performanceService.performanceScore}/100',
                    Icons.star,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetric(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOperationTimes(PerformanceService performanceService) {
    final operations = performanceService.operationTimes.entries.toList();

    if (operations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.timer_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'Aucune donnée de performance',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Temps d\'opération',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...operations.map(
                (entry) => _buildOperationTimeItem(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationTimeItem(String operation, Duration? duration) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatOperationName(operation),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            duration != null ? '${duration.inSeconds}s' : 'N/A',
            style: TextStyle(
              color: duration != null ? Colors.green : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(PerformanceService performanceService) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Métriques de performance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildMetricBar(
                'Efficacité', performanceService.efficiencyScore, Colors.blue),
            const SizedBox(height: 8),
            _buildMetricBar(
                'Fiabilité', performanceService.reliabilityScore, Colors.green),
            const SizedBox(height: 8),
            _buildMetricBar(
                'Rapidité', performanceService.speedScore, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('${(value * 100).toInt()}%'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildStatsOverview(int today, int week, int month) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Livraisons complétées',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                      'Aujourd\'hui', '$today', Icons.today, Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                      'Cette semaine', '$week', Icons.date_range, Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                      'Ce mois', '$month', Icons.calendar_month, Colors.orange),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
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
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryChart(List<Order> deliveries) {
    // Grouper les livraisons par jour de la semaine
    final Map<int, int> weeklyData = {};
    for (int i = 0; i < 7; i++) {
      weeklyData[i] = 0;
    }

    for (final delivery
        in deliveries.where((d) => d.status == OrderStatus.delivered)) {
      final weekday = delivery.orderTime.weekday % 7;
      weeklyData[weekday] = (weeklyData[weekday] ?? 0) + 1;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Livraisons par jour de la semaine',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: weeklyData.entries.map((entry) {
                  final maxValue =
                      weeklyData.values.reduce((a, b) => a > b ? a : b);
                  final height =
                      maxValue > 0 ? (entry.value / maxValue) * 150 : 0.0;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${entry.value}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 30,
                        height: height,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getWeekdayName(entry.key),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsBreakdown(List<Order> deliveries) {
    final completedDeliveries =
        deliveries.where((d) => d.status == OrderStatus.delivered);
    final totalEarnings = completedDeliveries.fold<double>(
        0, (sum, order) => sum + (order.total * 0.1)); // 10% commission

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gains estimés',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total des gains'),
                Text(
                  '${totalEarnings.toStringAsFixed(2)} FCFA',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Livraisons complétées'),
                Text('${completedDeliveries.length}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Gain moyen par livraison'),
                Text(
                    '${(totalEarnings / completedDeliveries.length).toStringAsFixed(2)} FCFA'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportActions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Générer un rapport',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateDailyReport,
                    icon: const Icon(Icons.today),
                    label: const Text('Rapport quotidien'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateWeeklyReport,
                    icon: const Icon(Icons.date_range),
                    label: const Text('Rapport hebdomadaire'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentReports() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rapports récents',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildReportItem('Rapport quotidien', 'Aujourd\'hui', Icons.today),
            _buildReportItem(
                'Rapport hebdomadaire', 'Cette semaine', Icons.date_range),
            _buildReportItem(
                'Rapport mensuel', 'Ce mois', Icons.calendar_month),
          ],
        ),
      ),
    );
  }

  Widget _buildReportItem(String title, String date, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(date),
      trailing: IconButton(
        icon: const Icon(Icons.download),
        onPressed: () => _downloadReport(title),
      ),
    );
  }

  void _generateDailyReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Génération du rapport quotidien...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _generateWeeklyReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Génération du rapport hebdomadaire...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _downloadReport(String reportName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Téléchargement de $reportName...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  String _formatOperationName(String operation) {
    switch (operation) {
      case 'accept_delivery':
        return 'Acceptation livraison';
      case 'process_payment':
        return 'Traitement paiement';
      case 'save_address':
        return 'Sauvegarde adresse';
      case 'set_default_address':
        return 'Définition adresse par défaut';
      case 'delete_address':
        return 'Suppression adresse';
      case 'apply_promo_code':
        return 'Application code promo';
      default:
        return operation;
    }
  }

  String _getWeekdayName(int weekday) {
    const days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
    return days[weekday];
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day &&
        date.month == now.month &&
        date.year == now.year;
  }

  bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        date.isBefore(weekEnd.add(const Duration(days: 1)));
  }

  bool _isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.month == now.month && date.year == now.year;
  }
}
















