import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/app_service.dart';
import '../../services/analytics_service.dart';
import '../../services/driver_management_service.dart';
import '../../services/database_service.dart';
import '../../models/order.dart';
import '../../models/menu_models.dart';
import '../../models/driver.dart';
import '../../core/utils/admin_helpers.dart';
import '../../widgets/modern/enhanced_stat_card.dart';
import '../../utils/dialog_helper.dart';
import '../../utils/price_formatter.dart';
import '../../theme/modern_theme.dart';
import 'advanced_order_management_screen.dart';
import 'analytics_screen.dart';
import 'driver_management_screen.dart';
import 'promotions_screen.dart';
import 'send_notification_dialog.dart';
import 'driver_documents_dashboard_screen.dart';
import 'active_deliveries_screen.dart';
import 'menu_management_screen.dart';
import '../../ui/ui.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeData();
      }
    });
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    final appService = context.read<AppService>();
    if (!appService.isInitialized) {
      await appService.initializeWithAdminUser();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AppService, AnalyticsService, DriverManagementService>(
      builder: (context, appService, analyticsService, driverService, child) {
        if (!appService.isInitialized && appService.currentUser == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final currentUser = appService.currentUser;
        final allOrders = appService.allOrders;
        final menuItems = appService.menuItems;

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return Scaffold(
          backgroundColor: scheme.surface,
          body: Column(
            children: [
              Container(
                color: scheme.surface,
                child: TabBar(
                  controller: _tabController,
                  labelColor: scheme.primary,
                  unselectedLabelColor: scheme.onSurfaceVariant,
                  indicatorColor: scheme.primary,
                  tabs: const [
                    Tab(
                        icon: Icon(Icons.dashboard_outlined),
                        text: 'Vue d\'ensemble'),
                    Tab(icon: Icon(Icons.analytics_outlined), text: 'Analyses'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context, currentUser, allOrders,
                        menuItems, driverService),
                    _buildAnalyticsTab(context, analyticsService),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    dynamic user,
    List<Order> orders,
    List<MenuItem> menuItems,
    DriverManagementService driverService,
  ) {
    final todayRevenue = _calculateTodayRevenue(orders);
    final totalOrders = orders.length;
    final activeDrivers = driverService.drivers
        .where((d) =>
            d.status == DriverStatus.available ||
            d.status == DriverStatus.onDelivery)
        .length;

    // Calculate additional stats
    final weekStart =
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final weekOrders =
        orders.where((o) => o.orderTime.isAfter(weekStart)).toList();
    final weekRevenue = weekOrders
        .where((order) => order.status == OrderStatus.delivered)
        .fold(0.0, (sum, order) => sum + order.total);

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<AppService>().initializeWithAdminUser();
        setState(() {});
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(context, user),
            const SizedBox(height: 20),
            _buildKeyMetricsGrid(
              context,
              todayRevenue,
              weekRevenue,
              totalOrders,
              activeDrivers,
              _calculateAverageOrderValue(totalOrders, orders),
            ),
            const SizedBox(height: 20),
            _buildQuickActions(context),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildRecentOrders(context, orders.take(5).toList()),
                ),
                if (MediaQuery.of(context).size.width > 900) ...[
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: _buildTopSellingItems(context),
                  ),
                ],
              ],
            ),
            if (MediaQuery.of(context).size.width <= 900) ...[
              const SizedBox(height: 20),
              _buildTopSellingItems(context),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab(
      BuildContext context, AnalyticsService analyticsService) {
    // Déclencher le chargement des données si elles sont vides et qu'on ne charge pas déjà
    // Utiliser addPostFrameCallback pour éviter les updates pendant le build
    if (analyticsService.analyticsData.isEmpty &&
        !analyticsService.isLoading &&
        analyticsService.error == null) {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 7));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        analyticsService.loadAnalyticsData(
            startDate: startDate, endDate: endDate);
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangeSelector(context),
          const SizedBox(height: 20),
          if (analyticsService.isLoading)
            const SizedBox(
              height: 400,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (analyticsService.error != null)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text('Erreur: ${analyticsService.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final endDate = DateTime.now();
                      final startDate =
                          endDate.subtract(const Duration(days: 7));
                      analyticsService.loadAnalyticsData(
                          startDate: startDate, endDate: endDate);
                    },
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                _buildRevenueChart(
                    context, analyticsService.analyticsData['revenue'] ?? {}),
                const SizedBox(height: 20),
                _buildOrdersChart(
                    context, analyticsService.analyticsData['orders'] ?? {}),
                const SizedBox(height: 20),
                _buildCategoryPerformance(context,
                    analyticsService.analyticsData['categories'] ?? {}),
              ],
            ),
        ],
      ),
    );
  }

  // --- Widgets for Overview Tab ---

  Widget _buildWelcomeCard(BuildContext context, dynamic user) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bonjour'
        : hour < 18
            ? 'Bon après-midi'
            : 'Bonsoir';
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, ${user?.name ?? 'Admin'}! 👋',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Voici ce qui se passe aujourd\'hui chez El Corazón',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.restaurant, color: scheme.onPrimary, size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetricsGrid(
    BuildContext context,
    double todayRevenue,
    double weekRevenue,
    int totalOrders,
    int activeDrivers,
    double averageOrderValue,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final sem = AdminColorTokens.semantic(scheme);

        final crossAxisCount = constraints.maxWidth > 1100
            ? 4
            : constraints.maxWidth > 700
                ? 2
                : 1;
        final spacing = 16.0;
        final width = (constraints.maxWidth - (crossAxisCount - 1) * spacing) /
            crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: width,
              child: EnhancedStatCard(
                title: 'Revenus du jour',
                value: formatPrice(todayRevenue),
                icon: Icons.euro,
                color: sem.success,
                subtitle: '${formatPrice(weekRevenue)} cette semaine',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  );
                },
              ),
            ),
            SizedBox(
              width: width,
              child: EnhancedStatCard(
                title: 'Commandes',
                value: totalOrders.toString(),
                icon: Icons.receipt_long,
                color: sem.info,
                subtitle: 'Total cumulé',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdvancedOrderManagementScreen()),
                  );
                },
              ),
            ),
            SizedBox(
              width: width,
              child: EnhancedStatCard(
                title: 'Livreurs Actifs',
                value: activeDrivers.toString(),
                icon: Icons.delivery_dining,
                color: sem.warning,
                subtitle: 'En ligne maintenant',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DriverManagementScreen()),
                  );
                },
              ),
            ),
            SizedBox(
              width: width,
              child: EnhancedStatCard(
                title: 'Panier Moyen',
                value: formatPrice(averageOrderValue),
                icon: Icons.shopping_basket,
                color: scheme.tertiary,
                subtitle: 'Par commande',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 900
              ? 6
              : constraints.maxWidth > 600
                  ? 3
                  : 2;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildActionButton(
                  context, 'Promotions', Icons.local_offer, sem.warning, () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PromotionsScreen()));
              }),
              _buildActionButton(
                  context, 'Menu', Icons.restaurant_menu, sem.success, () {
                // Normally handled by navigation, but direct push for quick action
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MenuManagementScreen()));
              }),
              _buildActionButton(
                  context, 'Commandes', Icons.shopping_cart, sem.info, () {
                // Assuming AdvancedOrderManagementScreen is the main one now
                // But usually handled by main navigation. We can push or switch tab.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdvancedOrderManagementScreen()),
                );
              }),
              _buildActionButton(
                  context, 'Notifications', Icons.send, scheme.tertiary, () {
                DialogHelper.showSafeDialog(
                    context: context,
                    builder: (_) => const SendNotificationDialog());
              }),
              _buildActionButton(
                  context, 'Documents', Icons.verified_user, scheme.secondary,
                  () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const DriverDocumentsDashboardScreen()));
              }),
              _buildActionButton(
                  context, 'Livraisons', Icons.local_shipping, sem.danger, () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ActiveDeliveriesScreen()));
              }),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon,
      Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders(BuildContext context, List<Order> recentOrders) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Commandes récentes',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdvancedOrderManagementScreen()),
                    );
                  }, // Navigate to full list
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (recentOrders.isEmpty)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucune commande récente')))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentOrders.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final order = recentOrders[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor:
                          _getStatusColor(order.status).withValues(alpha: 0.1),
                      child: Text(order.status.emoji),
                    ),
                    title:
                        Text('CMD #${order.id.substring(0, 8).toUpperCase()}'),
                    subtitle: Text(
                        '${AdminHelpers.formatRelativeTime(order.orderTime)} • ${order.items.length} articles'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatPrice(order.total),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(order.status.displayName,
                            style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(order.status))),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSellingItems(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
        future: _getTopSellingItems(),
        builder: (context, snapshot) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final sem = AdminColorTokens.semantic(scheme);

          // ... rest of the code is same but handling states better
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          final topProducts = snapshot.data ?? [];

          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top ventes (30 jours)',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.hasError)
                    Center(child: Text('Erreur: ${snapshot.error}'))
                  else if (topProducts.isEmpty)
                    const Center(child: Text('Aucune donnée'))
                  else
                    ...topProducts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final product = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _getRankColor(index),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                  child: Text('${index + 1}',
                                      style: TextStyle(
                                        color: scheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                      ))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product['menu_item_name'] ?? 'Produit',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text('${product['total_quantity']} vendus',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      )),
                                ],
                              ),
                            ),
                            Text(
                                formatPrice((product['total_revenue'] as num)
                                    .toDouble()),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: sem.success,
                                )),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        });
  }

  // Cache/Store for top selling items to avoid reload on every build
  Future<List<Map<String, dynamic>>>? _topSellingItemsFuture;

  Future<List<Map<String, dynamic>>> _getTopSellingItems() {
    _topSellingItemsFuture ??= DatabaseService().getMenuItemsOrderStatistics(
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      limit: 5,
    );
    return _topSellingItemsFuture!;
  }

  // --- Widgets for Analytics Tab ---

  Widget _buildDateRangeSelector(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 20),
        const SizedBox(width: 8),
        Text(
          '7 derniers jours',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        // Could add a dropdown here later
      ],
    );
  }

  Widget _buildRevenueChart(BuildContext context, Map<String, dynamic> data) {
    final dailyRevenue = data['dailyRevenue'] as Map<String, double>? ?? {};
    if (dailyRevenue.isEmpty) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Pas de données de revenus'))));
    }

    final sortedKeys = dailyRevenue.keys.toList()..sort();
    final spots = sortedKeys.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), dailyRevenue[entry.value] ?? 0.0);
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenus',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData:
                      const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < sortedKeys.length) {
                            final date =
                                DateTime.parse(sortedKeys[value.toInt()]);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('${date.day}/${date.month}',
                                  style: const TextStyle(fontSize: 10)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        interval: 1,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 40)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
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

  Widget _buildOrdersChart(BuildContext context, Map<String, dynamic> data) {
    final dailyOrders = data['dailyOrders'] as Map<String, int>? ?? {};
    if (dailyOrders.isEmpty) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Pas de données de commandes'))));
    }
    final sortedKeys = dailyOrders.keys.toList()..sort();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commandes par jour',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < sortedKeys.length) {
                            final date =
                                DateTime.parse(sortedKeys[value.toInt()]);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('${date.day}/${date.month}',
                                  style: const TextStyle(fontSize: 10)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 30)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: sortedKeys.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: (dailyOrders[entry.value] ?? 0).toDouble(),
                          color: Theme.of(context).colorScheme.primary,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPerformance(
      BuildContext context, Map<String, dynamic> data) {
    final categoryCounts = data['categoryCounts'] as Map<String, int>? ?? {};
    if (categoryCounts.isEmpty) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Pas de données de catégories'))));
    }

    final scheme = Theme.of(context).colorScheme;
    final total = categoryCounts.values.fold(0, (sum, val) => sum + val);
    final sections = categoryCounts.entries.map((entry) {
      final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
      final color = _colorFromKey(scheme, entry.key);

      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      );
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition par catégorie',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 200,
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
                    children: categoryCounts.entries.map((entry) {
                      final color = _colorFromKey(scheme, entry.key);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, color: color),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(entry.key,
                                    style: const TextStyle(fontSize: 12))),
                            Text('${entry.value}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---

  double _calculateTodayRevenue(List<Order> orders) {
    final now = DateTime.now();
    return orders
        .where((o) =>
            o.orderTime.day == now.day &&
            o.orderTime.month == now.month &&
            o.orderTime.year == now.year &&
            o.status == OrderStatus.delivered)
        .fold(0.0, (sum, o) => sum + o.total);
  }

  double _calculateAverageOrderValue(int totalOrders, List<Order> orders) {
    if (orders.isEmpty) return 0.0;
    final deliveredOrders =
        orders.where((o) => o.status == OrderStatus.delivered).toList();
    if (deliveredOrders.isEmpty) return 0.0;

    final totalRevenue = deliveredOrders.fold(0.0, (sum, o) => sum + o.total);
    return totalRevenue / deliveredOrders.length;
  }

  Color _getStatusColor(OrderStatus status) {
    // Mapping sémantique basé sur le ColorScheme (compatible light/dark)
    // Note: méthode non-contextuelle, on retourne une "intention" via palette statique.
    // Les widgets qui l'appellent appliquent généralement .withOpacity(...) etc.
    // Ici on conserve un mapping stable (à refactorer si besoin vers un helper contextuel).
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

  Color _getRankColor(int index) {
    // Couleurs de podium issues du thème (light/dark) sans hardcode.
    switch (index) {
      case 0:
        return ModernTheme.warning;
      case 1:
        return ModernTheme.info;
      case 2:
        return ModernTheme.success;
      default:
        return ModernTheme.textSecondary;
    }
  }

  Color _colorFromKey(ColorScheme scheme, String key) {
    // Génère une couleur stable à partir d'une clé, en dérivant du primary.
    final hash = key.hashCode;
    final base = HSLColor.fromColor(scheme.primary);
    final hue = (base.hue + (hash % 360)).toDouble();
    final sat = (0.55 + ((hash % 20) / 100)).clamp(0.45, 0.75);
    final light = (0.50 + ((hash % 15) / 100)).clamp(0.40, 0.65);
    return base.withHue(hue).withSaturation(sat).withLightness(light).toColor();
  }
}
