import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/driver_management_service.dart';
import '../../services/order_management_service.dart';
import '../../models/driver.dart';
import '../../models/order.dart';
import '../../widgets/custom_bar_chart.dart';
import '../../utils/price_formatter.dart';

class DriverHistoryScreen extends StatefulWidget {
  final Driver driver;

  const DriverHistoryScreen({super.key, required this.driver});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'week';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historique', style: TextStyle(fontSize: 16)),
            Text(widget.driver.name,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Vue globale'),
            Tab(text: 'Liste courses'),
            Tab(text: 'Performance'),
          ],
        ),
      ),
      body: Consumer2<OrderManagementService, DriverManagementService>(
        builder: (context, orderService, driverService, child) {
          final driverOrders = _getDriverOrders(orderService.allOrders);
          final stats = _calculateStats(driverOrders);

          return Column(
            children: [
              _buildFilters(context),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStatsTab(stats, driverOrders),
                    _buildHistoryTab(driverOrders),
                    _buildPerformanceTab(stats, driverOrders),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'week', label: Text('7j')),
                ButtonSegment(value: 'month', label: Text('30j')),
                ButtonSegment(value: 'year', label: Text('1 an')),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedPeriod = newSelection.first;
                  _updateDateRange();
                });
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'week':
        _startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        _startDate = now.subtract(const Duration(days: 30));
        break;
      case 'year':
        _startDate = now.subtract(const Duration(days: 365));
        break;
    }
    _endDate = now;
  }

  List<Order> _getDriverOrders(List<Order> allOrders) {
    final driverUserId = widget.driver.userId ?? widget.driver.id;

    return allOrders.where((order) {
      if (order.deliveryPersonId != driverUserId &&
          order.deliveryPersonId != widget.driver.id) {
        return false;
      }
      final orderDate = order.createdAt;
      return orderDate.isAfter(_startDate) &&
          orderDate.isBefore(_endDate.add(const Duration(days: 1)));
    }).toList();
  }

  Map<String, dynamic> _calculateStats(List<Order> orders) {
    final completedOrders =
        orders.where((o) => o.status == OrderStatus.delivered).toList();
    final totalRevenue =
        completedOrders.fold(0.0, (sum, order) => sum + order.total);

    return {
      'total_orders': orders.length,
      'completed_orders': completedOrders.length,
      'total_revenue': totalRevenue,
      'average_order_value': completedOrders.isNotEmpty
          ? totalRevenue / completedOrders.length
          : 0.0,
      'completion_rate': orders.isNotEmpty
          ? (completedOrders.length / orders.length) * 100
          : 0.0,
    };
  }

  Widget _buildStatsTab(Map<String, dynamic> stats, List<Order> orders) {
    // Calculer les commandes par jour pour les 7 derniers jours
    final dailyCounts = List<double>.filled(7, 0);
    final days = <String>[];
    final now = DateTime.now();

    const dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      days.add(dayNames[date.weekday - 1]);

      final count = orders.where((o) {
        return o.createdAt.year == date.year &&
            o.createdAt.month == date.month &&
            o.createdAt.day == date.day;
      }).length;
      dailyCounts[6 - i] = count.toDouble();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(stats),
        const SizedBox(height: 24),
        const Text('Commandes des 7 derniers jours',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: CustomBarChart(
            data: dailyCounts,
            labels: days,
            color: Colors.blue,
            height: 150,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> stats) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                    'Revenu',
                    PriceFormatter.format(stats['total_revenue'] is num ? (stats['total_revenue'] as num).toDouble() : 0.0),
                    Icons.monetization_on,
                    Colors.green),
                _buildSummaryItem('Commandes', '${stats['total_orders']}',
                    Icons.shopping_bag, Colors.blue),
                _buildSummaryItem(
                    'Taux Succès',
                    '${(stats['completion_rate'] as double).toInt()}%',
                    Icons.check_circle,
                    Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildHistoryTab(List<Order> orders) {
    if (orders.isEmpty) {
      return const Center(child: Text('Aucune commande sur cette période'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(Icons.local_shipping_outlined, color: Colors.blue[700]),
            ),
            title: Text(
              '#${order.id.substring(0, 6).toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(DateFormat('dd MMM HH:mm').format(order.createdAt)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  PriceFormatter.format(order.total),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  order.status.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: order.status == OrderStatus.delivered
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerformanceTab(Map<String, dynamic> stats, List<Order> orders) {
    // Calculer la performance mensuelle (par semaine)
    // Pour simplifier, on va juste montrer les 4 dernières semaines
    final weeklyData = List<double>.filled(4, 0);
    final weeklyLabels = ['Sem -3', 'Sem -2', 'Sem -1', 'Cette sem'];
    final now = DateTime.now();

    for (int i = 0; i < 4; i++) {
      final start = now.subtract(Duration(days: (3 - i) * 7 + now.weekday - 1));
      final end = start.add(const Duration(days: 6));

      final count = orders.where((o) {
        return o.createdAt
                .isAfter(start.subtract(const Duration(seconds: 1))) &&
            o.createdAt.isBefore(end.add(const Duration(seconds: 1)));
      }).length;
      weeklyData[i] = count.toDouble();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Performance Mensuelle (Courses / Semaine)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  CustomBarChart(
                    data: weeklyData.every((v) => v == 0)
                        ? [0, 0, 0, 0]
                        : weeklyData,
                    labels: weeklyLabels,
                    color: Colors.purple,
                    height: 200,
                  ),
                  if (weeklyData.every((v) => v == 0))
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Center(
                          child: Text('Pas assez de données',
                              style: TextStyle(color: Colors.grey))),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
