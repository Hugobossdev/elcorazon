import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/app_service.dart';
import '../../models/order.dart';
import '../../models/menu_models.dart';
import '../../models/category.dart' as app_models;
import '../../core/constants/admin_constants.dart';
import '../../core/utils/admin_helpers.dart';
import '../../core/widgets/admin_card.dart';
import '../../utils/dialog_helper.dart';
import '../../ui/ui.dart';
import '../../theme/modern_theme.dart';
import 'driver_map_screen.dart';

class EnhancedAdminDashboard extends StatefulWidget {
  const EnhancedAdminDashboard({super.key});

  @override
  State<EnhancedAdminDashboard> createState() => _EnhancedAdminDashboardState();
}

class _EnhancedAdminDashboardState extends State<EnhancedAdminDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTimeRange = 'today';
  String _selectedZone = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin - FastEat'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        actions: [
          Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Refresh data
                setState(() {});
              },
              tooltip: 'Actualiser',
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                _showSettingsDialog(context);
              },
              tooltip: 'Paramètres',
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: scheme.onPrimary,
          labelColor: scheme.onPrimary,
          unselectedLabelColor: scheme.onPrimary.withValues(alpha: 0.7),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Vue d\'ensemble'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.map), text: 'Carte'),
            Tab(icon: Icon(Icons.trending_up), text: 'Tendances'),
          ],
        ),
      ),
      body: Consumer<AppService>(
        builder: (context, appService, child) {
          final allOrders = appService.allOrders;
          final menuItems = appService.menuItems;

          // IMPORTANT: LayoutBuilder garantit que TabBarView a des contraintes de taille
          // pour éviter l'erreur "Cannot hit test a render box with no size"
          return LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context, allOrders, menuItems),
                    _buildAnalyticsTab(context, allOrders, menuItems),
                    _buildMapTab(context, allOrders),
                    _buildTrendsTab(context, allOrders, menuItems),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    List<Order> orders,
    List<MenuItem> menuItems,
  ) {
    final todayRevenue = _calculateTodayRevenue(orders);
    final totalOrders = orders.length;
    final activeDrivers = _getActiveDriversCount(orders);
    final topSellingItems = _getTopSellingItems(orders, menuItems);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AdminConstants.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Range Selector
          _buildTimeRangeSelector(),
          const SizedBox(height: AdminConstants.spacingMD),

          // Welcome Card
          _buildWelcomeCard(context),
          const SizedBox(height: AdminConstants.spacingLG),

          // Key Metrics Grid
          _buildKeyMetricsGrid(
            context,
            todayRevenue,
            totalOrders,
            activeDrivers,
          ),
          const SizedBox(height: AdminConstants.spacingLG),

          // Quick Actions
          _buildQuickActions(context),
          const SizedBox(height: AdminConstants.spacingLG),

          // Top Selling Items
          _buildTopSellingItems(context, topSellingItems),
          const SizedBox(height: AdminConstants.spacingLG),

          // Recent Orders
          _buildRecentOrders(
            context,
            orders.take(AdminConstants.dashboardRecentItemsLimit).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(
    BuildContext context,
    List<Order> orders,
    List<MenuItem> menuItems,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue Chart
          _buildRevenueChart(context, orders),
          const SizedBox(height: 20),

          // Orders Chart
          _buildOrdersChart(context, orders),
          const SizedBox(height: 20),

          // Category Performance
          _buildCategoryPerformance(context, orders, menuItems),
          const SizedBox(height: 20),

          // Driver Performance
          _buildDriverPerformance(context, orders),
        ],
      ),
    );
  }

  Widget _buildMapTab(BuildContext context, List<Order> orders) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone Selector
          _buildZoneSelector(),
          const SizedBox(height: 16),

          // Map Container
          _buildMapContainer(context, orders),
          const SizedBox(height: 20),

          // Driver Locations
          _buildDriverLocations(context, orders),
          const SizedBox(height: 20),

          // Hot Zones
          _buildHotZones(context, orders),
        ],
      ),
    );
  }

  Widget _buildTrendsTab(
    BuildContext context,
    List<Order> orders,
    List<MenuItem> menuItems,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sales Trends
          _buildSalesTrends(context, orders),
          const SizedBox(height: 20),

          // Popular Items
          _buildPopularItems(context, orders, menuItems),
          const SizedBox(height: 20),

          // Peak Hours
          _buildPeakHours(context, orders),
          const SizedBox(height: 20),

          // Customer Insights
          _buildCustomerInsights(context, orders),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.calendar_today),
            const SizedBox(width: 8),
            const Text('Période: '),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                value: _selectedTimeRange,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'today', child: Text('Aujourd\'hui')),
                  DropdownMenuItem(value: 'week', child: Text('Cette semaine')),
                  DropdownMenuItem(value: 'month', child: Text('Ce mois')),
                  DropdownMenuItem(value: 'year', child: Text('Cette année')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTimeRange = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bonjour'
        : hour < 18
            ? 'Bon après-midi'
            : 'Bonsoir';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, Admin! 👨‍💼',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tableau de bord FastEat - Gestion complète',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.restaurant,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Système opérationnel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ONLINE',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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

  Widget _buildKeyMetricsGrid(
    BuildContext context,
    double todayRevenue,
    int totalOrders,
    int activeDrivers,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = AdminConstants.dashboardGridCrossAxisCount;
        final itemWidth = (constraints.maxWidth -
                (crossAxisCount - 1) * AdminConstants.dashboardGridSpacing) /
            crossAxisCount;
        final itemHeight =
            itemWidth / AdminConstants.dashboardGridChildAspectRatio;

        return SizedBox(
          height: ((4 / crossAxisCount).ceil() * itemHeight) +
              ((4 / crossAxisCount).ceil() - 1) *
                  AdminConstants.dashboardGridSpacing,
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AdminConstants.dashboardGridSpacing,
            mainAxisSpacing: AdminConstants.dashboardGridSpacing,
            childAspectRatio: AdminConstants.dashboardGridChildAspectRatio,
            children: [
              _buildMetricCard(
                context,
                'Revenus du jour',
                AdminHelpers.formatPrice(todayRevenue),
                Icons.euro,
                AdminColorTokens.semantic(Theme.of(context).colorScheme)
                    .success,
                '+12.5%',
              ),
              _buildMetricCard(
                context,
                'Commandes totales',
                AdminHelpers.formatNumber(totalOrders),
                Icons.receipt_long,
                Theme.of(context).colorScheme.primary,
                '+8.2%',
              ),
              _buildMetricCard(
                context,
                'Livreurs actifs',
                '$activeDrivers',
                Icons.delivery_dining,
                AdminColorTokens.semantic(Theme.of(context).colorScheme)
                    .warning,
                AdminHelpers.formatPercentage((activeDrivers / 10 * 100)),
              ),
              _buildMetricCard(
                context,
                'Panier moyen',
                AdminHelpers.formatPrice(
                  _calculateAverageOrderValue(totalOrders, todayRevenue),
                ),
                Icons.shopping_cart,
                Theme.of(context).colorScheme.tertiary,
                '+5.1%',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    String change,
  ) {
    return StatCard(
      title: title,
      value: value,
      icon: icon,
      color: color,
      trend: change,
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AdminConstants.spacingMD),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount =
                AdminConstants.quickActionsGridCrossAxisCount;
            final itemWidth = (constraints.maxWidth -
                    (crossAxisCount - 1) *
                        AdminConstants.quickActionsGridSpacing) /
                crossAxisCount;
            final itemHeight =
                itemWidth / AdminConstants.quickActionsGridChildAspectRatio;
            final itemCount = 6;

            return SizedBox(
              height: ((itemCount / crossAxisCount).ceil() * itemHeight) +
                  ((itemCount / crossAxisCount).ceil() - 1) *
                      AdminConstants.quickActionsGridSpacing,
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AdminConstants.quickActionsGridSpacing,
                mainAxisSpacing: AdminConstants.quickActionsGridSpacing,
                childAspectRatio:
                    AdminConstants.quickActionsGridChildAspectRatio,
                children: [
                  _buildActionButton(
                    context,
                    'Créer promotion',
                    Icons.local_offer,
                    AdminColorTokens.semantic(Theme.of(context).colorScheme)
                        .warning,
                    () => _navigateToPromotions(),
                  ),
                  _buildActionButton(
                    context,
                    'Commandes',
                    Icons.shopping_cart,
                    AdminColorTokens.semantic(Theme.of(context).colorScheme)
                        .success,
                    () => _navigateToOrderManagement(),
                  ),
                  _buildActionButton(
                    context,
                    'Gérer livreurs',
                    Icons.delivery_dining,
                    Theme.of(context).colorScheme.primary,
                    () => _navigateToDriverManagement(),
                  ),
                  _buildActionButton(
                    context,
                    'Notifications',
                    Icons.send,
                    Theme.of(context).colorScheme.tertiary,
                    () => _navigateToNotifications(),
                  ),
                  _buildActionButton(
                    context,
                    'Rapports',
                    Icons.analytics,
                    Theme.of(context).colorScheme.secondary,
                    () => _navigateToReports(),
                  ),
                  _buildActionButton(
                    context,
                    'Paramètres',
                    Icons.settings,
                    Theme.of(context).colorScheme.onSurfaceVariant,
                    () => _navigateToSettings(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // IMPORTANT: Material explicite pour garantir le hit testing correct
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(minHeight: 50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSellingItems(
    BuildContext context,
    List<Map<String, dynamic>> topItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top ventes',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: topItems.take(5).map((item) {
              return Container(
                constraints: const BoxConstraints(minHeight: 56),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .tertiary
                        .withValues(alpha: 0.12),
                    child: Text(
                      '${topItems.indexOf(item) + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                  title: Text(item['name']),
                  subtitle: Text('${item['quantity']} vendus'),
                  trailing: Text(
                    AdminHelpers.formatPrice(item['revenue']),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AdminColorTokens.semantic(
                        Theme.of(context).colorScheme,
                      ).success,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrders(BuildContext context, List<Order> recentOrders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Commandes récentes',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _navigateToOrderManagement(),
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: recentOrders.map((order) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(
                    order.status,
                  ).withValues(alpha: 0.1),
                  child: Text(order.status.emoji),
                ),
                title: Text(
                  'Commande #${AdminHelpers.formatOrderId(order.id)}',
                ),
                subtitle: Text(
                  '${order.status.displayName} - ${AdminHelpers.formatRelativeTime(order.orderTime)}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AdminHelpers.formatPrice(order.total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${order.items.length} articles',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                onTap: () => _showOrderDetails(order),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Placeholder methods for charts and analytics
  Widget _buildRevenueChart(BuildContext context, List<Order> orders) {
    final filteredOrders = _filterOrdersByRange(orders, _selectedTimeRange);
    final List<FlSpot> spots = [];
    double maxRevenue = 0;

    // Group data based on time range
    if (_selectedTimeRange == 'today') {
      // Group by hour (0-23)
      final Map<int, double> hourlyRevenue = {};
      for (var i = 0; i < 24; i++) {
        hourlyRevenue[i] = 0;
      }

      for (var order in filteredOrders) {
        hourlyRevenue[order.orderTime.hour] =
            (hourlyRevenue[order.orderTime.hour] ?? 0) + order.total;
      }

      hourlyRevenue.forEach((hour, revenue) {
        spots.add(FlSpot(hour.toDouble(), revenue));
        if (revenue > maxRevenue) maxRevenue = revenue;
      });
    } else if (_selectedTimeRange == 'year') {
      // Group by month (1-12)
      final Map<int, double> monthlyRevenue = {};
      for (var i = 1; i <= 12; i++) {
        monthlyRevenue[i] = 0;
      }

      for (var order in filteredOrders) {
        monthlyRevenue[order.orderTime.month] =
            (monthlyRevenue[order.orderTime.month] ?? 0) + order.total;
      }

      monthlyRevenue.forEach((month, revenue) {
        spots.add(FlSpot(month.toDouble(), revenue));
        if (revenue > maxRevenue) maxRevenue = revenue;
      });
    } else {
      // Group by day of month (1-31)
      final Map<int, double> dailyRevenue = {};
      // Initialize based on range?? For simplicity, just use day of month
      // For week, we might want day of week, but let's stick to day of month for consistency
      // Actually for week it's better to show Mon, Tue...
      // Let's stick to day of month index for now or 0-6 for week?

      for (var order in filteredOrders) {
        int key;
        if (_selectedTimeRange == 'week') {
          key = order.orderTime.weekday; // 1=Mon, 7=Sun
        } else {
          key = order.orderTime.day;
        }
        dailyRevenue[key] = (dailyRevenue[key] ?? 0) + order.total;
      }

      // Fill gaps if needed or just plot existing
      // For week, fill 1-7
      if (_selectedTimeRange == 'week') {
        for (var i = 1; i <= 7; i++) {
          double revenue = dailyRevenue[i] ?? 0;
          spots.add(FlSpot(i.toDouble(), revenue));
          if (revenue > maxRevenue) maxRevenue = revenue;
        }
      } else {
        // Month
        final daysInMonth =
            DateUtils.getDaysInMonth(DateTime.now().year, DateTime.now().month);
        for (var i = 1; i <= daysInMonth; i++) {
          double revenue = dailyRevenue[i] ?? 0;
          spots.add(FlSpot(i.toDouble(), revenue));
          if (revenue > maxRevenue) maxRevenue = revenue;
        }
      }
    }

    if (maxRevenue == 0) {
      maxRevenue = 100; // Prevent flat line at bottom with 0 height
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Évolution des revenus',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                            AdminHelpers.formatPrice(value)
                                .replaceAll('CFA', '')
                                .trim(),
                            style: const TextStyle(fontSize: 10));
                      },
                    )),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                      showTitles: true,
                      interval: _selectedTimeRange == 'today' ? 4 : 1,
                      getTitlesWidget: (value, meta) {
                        if (_selectedTimeRange == 'today') {
                          return Text('${value.toInt()}h',
                              style: const TextStyle(fontSize: 10));
                        } else if (_selectedTimeRange == 'week') {
                          const days = ['', 'L', 'M', 'M', 'J', 'V', 'S', 'D'];
                          if (value >= 1 && value <= 7) {
                            return Text(days[value.toInt()],
                                style: const TextStyle(fontSize: 10));
                          }
                        } else if (_selectedTimeRange == 'year') {
                          const months = [
                            '',
                            'J',
                            'F',
                            'M',
                            'A',
                            'M',
                            'J',
                            'J',
                            'A',
                            'S',
                            'O',
                            'N',
                            'D'
                          ];
                          if (value >= 1 && value <= 12) {
                            return Text(months[value.toInt()],
                                style: const TextStyle(fontSize: 10));
                          }
                        }
                        return Text('${value.toInt()}',
                            style: const TextStyle(fontSize: 10));
                      },
                    )),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  minX: _selectedTimeRange == 'today' ? 0 : 1,
                  maxX: _selectedTimeRange == 'today'
                      ? 23
                      : (_selectedTimeRange == 'week'
                          ? 7
                          : (_selectedTimeRange == 'year' ? 12 : 31)),
                  minY: 0,
                  maxY: maxRevenue * 1.2,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersChart(BuildContext context, List<Order> orders) {
    final filteredOrders = _filterOrdersByRange(orders, _selectedTimeRange);
    final List<BarChartGroupData> barGroups = [];
    double maxOrders = 0;

    if (_selectedTimeRange == 'today') {
      final Map<int, int> hourlyOrders = {};
      for (var i = 0; i < 24; i++) {
        hourlyOrders[i] = 0;
      }
      for (var order in filteredOrders) {
        hourlyOrders[order.orderTime.hour] =
            (hourlyOrders[order.orderTime.hour] ?? 0) + 1;
      }
      hourlyOrders.forEach((hour, count) {
        barGroups.add(
          BarChartGroupData(
            x: hour,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        );
        if (count > maxOrders) maxOrders = count.toDouble();
      });
    } else if (_selectedTimeRange == 'year') {
      final Map<int, int> monthlyOrders = {};
      for (var i = 1; i <= 12; i++) {
        monthlyOrders[i] = 0;
      }
      for (var order in filteredOrders) {
        monthlyOrders[order.orderTime.month] =
            (monthlyOrders[order.orderTime.month] ?? 0) + 1;
      }
      monthlyOrders.forEach((month, count) {
        barGroups.add(
          BarChartGroupData(
            x: month,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        );
        if (count > maxOrders) maxOrders = count.toDouble();
      });
    } else {
      final Map<int, int> dailyOrders = {};
      for (var order in filteredOrders) {
        int key;
        if (_selectedTimeRange == 'week') {
          key = order.orderTime.weekday;
        } else {
          key = order.orderTime.day;
        }
        dailyOrders[key] = (dailyOrders[key] ?? 0) + 1;
      }

      if (_selectedTimeRange == 'week') {
        for (var i = 1; i <= 7; i++) {
          int count = dailyOrders[i] ?? 0;
          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: count.toDouble(),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          );
          if (count > maxOrders) maxOrders = count.toDouble();
        }
      } else {
        final daysInMonth =
            DateUtils.getDaysInMonth(DateTime.now().year, DateTime.now().month);
        for (var i = 1; i <= daysInMonth; i++) {
          int count = dailyOrders[i] ?? 0;
          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: count.toDouble(),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          );
          if (count > maxOrders) maxOrders = count.toDouble();
        }
      }
    }

    if (maxOrders == 0) maxOrders = 10;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Évolution des commandes',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: maxOrders > 5 ? maxOrders / 5 : 1)),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (_selectedTimeRange == 'today') {
                          if (value % 4 == 0) {
                            return Text('${value.toInt()}h',
                                style: const TextStyle(fontSize: 10));
                          }
                          return const SizedBox.shrink();
                        } else if (_selectedTimeRange == 'week') {
                          const days = ['', 'L', 'M', 'M', 'J', 'V', 'S', 'D'];
                          if (value >= 1 && value <= 7) {
                            return Text(days[value.toInt()],
                                style: const TextStyle(fontSize: 10));
                          }
                        } else if (_selectedTimeRange == 'year') {
                          const months = [
                            '',
                            'J',
                            'F',
                            'M',
                            'A',
                            'M',
                            'J',
                            'J',
                            'A',
                            'S',
                            'O',
                            'N',
                            'D'
                          ];
                          if (value >= 1 && value <= 12) {
                            return Text(months[value.toInt()],
                                style: const TextStyle(fontSize: 10));
                          }
                        }
                        return Text('${value.toInt()}',
                            style: const TextStyle(fontSize: 10));
                      },
                    )),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                  maxY: maxOrders * 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPerformance(
    BuildContext context,
    List<Order> orders,
    List<MenuItem> menuItems,
  ) {
    final appService = Provider.of<AppService>(context, listen: false);
    final categories = appService.categoriesList;
    final Map<String, double> categoryRevenue = {};
    double totalRevenue = 0;

    for (var order in orders) {
      if (order.status != OrderStatus.cancelled &&
          order.status != OrderStatus.refunded) {
        for (var item in order.items) {
          // Find menu item to get category ID
          final menuItem = menuItems
              .cast<MenuItem?>()
              .firstWhere((m) => m?.id == item.menuItemId, orElse: () => null);

          if (menuItem != null) {
            categoryRevenue[menuItem.categoryId] =
                (categoryRevenue[menuItem.categoryId] ?? 0) + item.totalPrice;
            totalRevenue += item.totalPrice;
          }
        }
      }
    }

    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    final List<Color> colors = [
      sem.warning,
      sem.danger,
      sem.info,
      scheme.tertiary,
      scheme.primary,
      scheme.secondary,
      sem.success,
    ];

    final sections = categoryRevenue.entries.map((entry) {
      final categoryId = entry.key;
      final revenue = entry.value;
      final percentage =
          totalRevenue > 0 ? (revenue / totalRevenue) * 100 : 0.0;

      // Find category name
      final category = categories
          .cast<app_models.Category?>()
          .firstWhere((c) => c?.id == categoryId, orElse: () => null);
      final categoryName = category?.name ?? 'Autre';
      final index = categoryRevenue.keys.toList().indexOf(categoryId);

      return PieChartSectionData(
        value: percentage,
        title: '${percentage.toStringAsFixed(0)}%\n$categoryName',
        color: colors[index % colors.length],
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
        ),
      );
    }).toList();

    if (sections.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance par catégorie',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              const Center(child: Text('Aucune donnée disponible')),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance par catégorie',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverPerformance(BuildContext context, List<Order> orders) {
    // Group orders by deliveryPersonId
    final Map<String, int> driverOrders = {};
    for (var order in orders) {
      if (order.deliveryPersonId != null &&
          (order.status == OrderStatus.delivered ||
              order.status == OrderStatus.pickedUp)) {
        driverOrders[order.deliveryPersonId!] =
            (driverOrders[order.deliveryPersonId!] ?? 0) + 1;
      }
    }

    final sortedDrivers = driverOrders.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance des livreurs',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (sortedDrivers.isEmpty)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('Aucune donnée de livraison'),
              ))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: min(5, sortedDrivers.length),
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = sortedDrivers[index];
                  // Try to find driver name if we could, for now use ID
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                        'Livreur #${entry.key.substring(0, min(6, entry.key.length))}...'),
                    trailing: Text('${entry.value} courses',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.location_on),
            const SizedBox(width: 8),
            const Text('Zone: '),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                value: _selectedZone,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Toutes les zones'),
                  ),
                  DropdownMenuItem(
                    value: 'zone1',
                    child: Text('Zone 1 - Centre'),
                  ),
                  DropdownMenuItem(
                    value: 'zone2',
                    child: Text('Zone 2 - Nord'),
                  ),
                  DropdownMenuItem(value: 'zone3', child: Text('Zone 3 - Sud')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedZone = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapContainer(BuildContext context, List<Order> orders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Carte interactive',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverMapScreen()),
                );
              },
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Ouvrir la carte des livreurs',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverLocations(BuildContext context, List<Order> orders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Positions des livreurs',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Liste des livreurs en ligne\n(À implémenter)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotZones(BuildContext context, List<Order> orders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zones chaudes',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Heatmap des commandes\n(À implémenter)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTrends(BuildContext context, List<Order> orders) {
    // Daily revenue for last 7 days
    final now = DateTime.now();
    final List<BarChartGroupData> barGroups = [];
    double maxRevenue = 0;

    for (int i = 6; i >= 0; i--) {
      final dayStart =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayEnd = dayStart.add(const Duration(days: 1));

      double dailyTotal = 0;
      for (var order in orders) {
        if (order.status == OrderStatus.delivered &&
            order.orderTime.isAfter(dayStart) &&
            order.orderTime.isBefore(dayEnd)) {
          dailyTotal += order.total;
        }
      }

      barGroups.add(BarChartGroupData(x: 6 - i, barRods: [
        BarChartRodData(
          toY: dailyTotal,
          color: Theme.of(context).primaryColor,
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        )
      ]));

      if (dailyTotal > maxRevenue) maxRevenue = dailyTotal;
    }

    if (maxRevenue == 0) maxRevenue = 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tendances des ventes (7 derniers jours)',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (val, meta) => Text(
                                AdminHelpers.formatPrice(val)
                                    .replaceAll('CFA', '')
                                    .trim(),
                                style: const TextStyle(fontSize: 10)))),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final date = now
                                  .subtract(Duration(days: 6 - value.toInt()));
                              return Text('${date.day}/${date.month}',
                                  style: const TextStyle(fontSize: 10));
                            })),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                  maxY: maxRevenue * 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularItems(
    BuildContext context,
    List<Order> orders,
    List<MenuItem> menuItems,
  ) {
    final Map<String, int> itemCounts = {};
    final Map<String, double> itemRevenue = {};

    for (var order in orders) {
      if (order.status != OrderStatus.cancelled &&
          order.status != OrderStatus.refunded) {
        for (var item in order.items) {
          // Use menuItemId if available, otherwise name
          final id = item.menuItemId.isNotEmpty ? item.menuItemId : item.name;
          itemCounts[id] = (itemCounts[id] ?? 0) + item.quantity;
          itemRevenue[id] = (itemRevenue[id] ?? 0) + item.totalPrice;
        }
      }
    }

    final sortedItems = itemCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Articles populaires',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (sortedItems.isEmpty)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('Aucune donnée de vente'),
              ))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: min(5, sortedItems.length),
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = sortedItems[index];
                  // Find menu item name if possible
                  final menuItem = menuItems.cast<MenuItem?>().firstWhere(
                      (item) => item?.id == entry.key,
                      orElse: () => null);
                  final name = menuItem?.name ??
                      entry
                          .key; // Fallback to ID if name not found (or if key was name)
                  // Actually if key was name (from OrderItem.name fallback), it is the name.
                  // But if key was ID, we look it up.
                  // To be safe: OrderItem usually has name.

                  // Let's improve lookup: iterate orders again? No, OrderItem has menuItemName.
                  // But we aggregated by ID.
                  // We can store name in another map during aggregation.

                  return ListTile(
                    leading: Icon(
                      Icons.fastfood,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    title: Text(name),
                    subtitle: Text('${entry.value} vendus'),
                    trailing: Text(
                        AdminHelpers.formatPrice(itemRevenue[entry.key] ?? 0)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakHours(BuildContext context, List<Order> orders) {
    final Map<int, int> hourlyOrders = {};
    for (int i = 0; i < 24; i++) {
      hourlyOrders[i] = 0;
    }

    for (var order in orders) {
      if (order.status != OrderStatus.cancelled) {
        hourlyOrders[order.orderTime.hour] =
            (hourlyOrders[order.orderTime.hour] ?? 0) + 1;
      }
    }

    final List<BarChartGroupData> barGroups = [];
    double maxOrders = 0;

    hourlyOrders.forEach((hour, count) {
      barGroups.add(BarChartGroupData(x: hour, barRods: [
        BarChartRodData(
          toY: count.toDouble(),
          color: Theme.of(context).colorScheme.tertiary,
          width: 8,
        )
      ]));
      if (count > maxOrders) maxOrders = count.toDouble();
    });

    if (maxOrders == 0) maxOrders = 10;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heures de pointe',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: maxOrders > 5 ? maxOrders / 5 : 1)),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            interval: 4,
                            getTitlesWidget: (value, meta) {
                              return Text('${value.toInt()}h',
                                  style: const TextStyle(fontSize: 10));
                            })),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                  maxY: maxOrders * 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInsights(BuildContext context, List<Order> orders) {
    final Map<String, double> customerSpending = {};
    final Map<String, int> customerOrders = {};

    for (var order in orders) {
      if (order.userId.isNotEmpty && order.status == OrderStatus.delivered) {
        customerSpending[order.userId] =
            (customerSpending[order.userId] ?? 0) + order.total;
        customerOrders[order.userId] = (customerOrders[order.userId] ?? 0) + 1;
      }
    }

    final sortedCustomers = customerSpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meilleurs clients',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (sortedCustomers.isEmpty)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('Aucune donnée client'),
              ))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: min(5, sortedCustomers.length),
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = sortedCustomers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.tertiary.withValues(
                                alpha: 0.12,
                              ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.tertiary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                        'Client #${entry.key.substring(0, min(6, entry.key.length))}...'),
                    subtitle: Text('${customerOrders[entry.key]} commandes'),
                    trailing: Text(
                      AdminHelpers.formatPrice(entry.value),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AdminColorTokens.semantic(
                          Theme.of(context).colorScheme,
                        ).success,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  List<Order> _filterOrdersByRange(List<Order> orders, String range) {
    final now = DateTime.now();
    return orders.where((order) {
      if (order.status == OrderStatus.cancelled ||
          order.status == OrderStatus.refunded ||
          order.status == OrderStatus.failed) {
        return false;
      }

      final date = order.orderTime;
      switch (range) {
        case 'today':
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        case 'week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          return date.isAfter(startOfWeek.subtract(const Duration(seconds: 1)));
        case 'month':
          return date.year == now.year && date.month == now.month;
        case 'year':
          return date.year == now.year;
        default:
          return true;
      }
    }).toList();
  }

  double _calculateTodayRevenue(List<Order> orders) {
    final today = DateTime.now();
    return orders
        .where(
          (order) =>
              order.orderTime.day == today.day &&
              order.orderTime.month == today.month &&
              order.orderTime.year == today.year &&
              order.status == OrderStatus.delivered,
        )
        .fold(0.0, (sum, order) => sum + order.total);
  }

  int _getActiveDriversCount(List<Order> orders) {
    // This would typically come from a real-time service
    return 8; // Placeholder
  }

  List<Map<String, dynamic>> _getTopSellingItems(
    List<Order> orders,
    List<MenuItem> menuItems,
  ) {
    // This would calculate actual top selling items
    return [
      {'name': 'Burger Classique', 'quantity': 45, 'revenue': 225.0},
      {'name': 'Pizza Margherita', 'quantity': 38, 'revenue': 190.0},
      {'name': 'Frites', 'quantity': 52, 'revenue': 104.0},
      {'name': 'Coca-Cola', 'quantity': 67, 'revenue': 134.0},
      {'name': 'Salade César', 'quantity': 23, 'revenue': 115.0},
    ];
  }

  double _calculateAverageOrderValue(int totalOrders, double totalRevenue) {
    if (totalOrders == 0) return 0.0;
    return totalRevenue / totalOrders;
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return ModernTheme.warning;
      case OrderStatus.confirmed:
        return ModernTheme.info;
      case OrderStatus.preparing:
        return ModernTheme.primaryLight;
      case OrderStatus.ready:
        return ModernTheme.success;
      case OrderStatus.pickedUp:
        return ModernTheme.secondary;
      case OrderStatus.onTheWay:
        return ModernTheme.primaryDark;
      case OrderStatus.delivered:
        return ModernTheme.success;
      case OrderStatus.cancelled:
        return ModernTheme.error;
      case OrderStatus.refunded:
        return ModernTheme.textSecondary;
      case OrderStatus.failed:
        return ModernTheme.error;
    }
  }

  // Navigation methods
  void _navigateToPromotions() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Navigation vers promotions')));
  }

  void _navigateToDriverManagement() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation vers gestion des livreurs')),
    );
  }

  void _navigateToNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation vers notifications')),
    );
  }

  void _navigateToReports() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Navigation vers rapports')));
  }

  void _navigateToSettings() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Navigation vers paramètres')));
  }

  void _navigateToOrderManagement() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation vers gestion des commandes')),
    );
  }

  void _showOrderDetails(Order order) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Commande #${order.id.substring(0, 8).toUpperCase()}'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Statut: ${order.status.displayName}'),
                const SizedBox(height: 8),
                Text('Total: ${AdminHelpers.formatPrice(order.total)}'),
                const SizedBox(height: 8),
                Text('Articles: ${order.items.length}'),
                const SizedBox(height: 8),
                Text('Adresse: ${order.deliveryAddress}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 500.0);
    final dialogHeight = 200.0;

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Paramètres',
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
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Contenu
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Paramètres du tableau de bord'),
                ),
              ),
              const Divider(height: 1),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
