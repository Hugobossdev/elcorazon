import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/dialog_helper.dart';
import '../../services/order_management_service.dart';
import '../../services/driver_management_service.dart';
import '../../models/order.dart';
import '../../models/driver.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/price_formatter.dart';
import '../../ui/ui.dart';

enum OrderSortOption {
  dateAsc,
  dateDesc,
  totalAsc,
  totalDesc,
  status,
}

extension OrderSortOptionExtension on OrderSortOption {
  String get displayName {
    switch (this) {
      case OrderSortOption.dateAsc:
        return 'Date (Ancien)';
      case OrderSortOption.dateDesc:
        return 'Date (Récent)';
      case OrderSortOption.totalAsc:
        return 'Total (Croissant)';
      case OrderSortOption.totalDesc:
        return 'Total (Décroissant)';
      case OrderSortOption.status:
        return 'Statut';
    }
  }
}

class AdvancedOrderManagementScreen extends StatefulWidget {
  const AdvancedOrderManagementScreen({super.key});

  @override
  State<AdvancedOrderManagementScreen> createState() =>
      _AdvancedOrderManagementScreenState();
}

class _AdvancedOrderManagementScreenState
    extends State<AdvancedOrderManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    // IMPORTANT: Écouter les changements d'onglet pour mettre à jour l'IndexedStack
    _tabController.addListener(() {
      if (!mounted) return;
      // Reporter setState après le build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // context.read<OrderManagementService>().initialize(); // Méthode non implémentée
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    // Pas d'AppBar ici car il est déjà géré par AdminNavigationScreen
    // IMPORTANT: cette page peut être affichée dans une arborescence sans ancêtre Material.
    // Or certains widgets Material (TextField, etc.) l'exigent.
    return Material(
      color: scheme.surface,
      child: Column(
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
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher par ID, client, adresse...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                    ),
                    onChanged: (value) {
                      context
                          .read<OrderManagementService>()
                          .searchOrders(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showFilterDialog,
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
                      child: const Icon(Icons.filter_list),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      context.read<OrderManagementService>().refresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rafraîchissement des commandes...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
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
                      child: const Icon(Icons.refresh),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _exportOrders,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.download, color: scheme.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // TabBar
          Container(
            color: scheme.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: scheme.primary,
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard), text: 'Vue d\'ensemble'),
                Tab(icon: Icon(Icons.pending), text: 'En attente'),
                Tab(icon: Icon(Icons.verified), text: 'Confirmées'),
                Tab(icon: Icon(Icons.restaurant), text: 'En préparation'),
                Tab(icon: Icon(Icons.check_circle), text: 'Prêtes'),
                Tab(icon: Icon(Icons.delivery_dining), text: 'En livraison'),
                Tab(icon: Icon(Icons.analytics), text: 'Statistiques'),
              ],
            ),
          ),
          // Contenu
          Expanded(
            child: Consumer<OrderManagementService>(
              builder: (context, orderService, child) {
                // Afficher un indicateur de chargement si en cours et liste vide
                if (orderService.isLoading && orderService.allOrders.isEmpty) {
                  return const LoadingWidget(
                      message: 'Chargement des commandes...');
                }

                // Afficher un message si aucune commande et pas de chargement
                if (!orderService.isLoading && orderService.allOrders.isEmpty) {
                  final scheme = Theme.of(context).colorScheme;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune commande trouvée',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Les commandes apparaîtront ici une fois chargées',
                          style: TextStyle(
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => orderService.refresh(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Rafraîchir'),
                        ),
                      ],
                    ),
                  );
                }

                // IMPORTANT: Construire seulement l'onglet visible pour éviter les problèmes de hit testing
                // Utiliser un switch au lieu d'IndexedStack pour construire seulement l'onglet actif
                switch (_tabController.index) {
                  case 0:
                    return SizedBox.expand(
                        child: _buildOverviewTab(context, orderService));
                  case 1:
                    return SizedBox.expand(
                        child: _buildPendingOrdersTab(context, orderService));
                  case 2:
                    return SizedBox.expand(
                        child: _buildConfirmedOrdersTab(context, orderService));
                  case 3:
                    return SizedBox.expand(
                        child: _buildPreparingOrdersTab(context, orderService));
                  case 4:
                    return SizedBox.expand(
                        child: _buildReadyOrdersTab(context, orderService));
                  case 5:
                    return SizedBox.expand(
                        child: _buildDeliveryOrdersTab(context, orderService));
                  case 6:
                    return SizedBox.expand(
                        child: _buildStatisticsTab(context, orderService));
                  default:
                    return SizedBox.expand(
                        child: _buildOverviewTab(context, orderService));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
      BuildContext context, OrderManagementService orderService) {
    final stats = orderService.getOrderStats();
    final urgentOrders =
        <Order>[]; // orderService.getUrgentOrders(); // Méthode non implémentée
    final overdueOrders =
        <Order>[]; // orderService.getOverdueOrders(); // Méthode non implémentée

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistiques principales
          _buildStatsGrid(context, stats),
          const SizedBox(height: 20),

          // Alertes
          if (urgentOrders.isNotEmpty || overdueOrders.isNotEmpty) ...[
            _buildAlertsSection(context, urgentOrders, overdueOrders),
            const SizedBox(height: 20),
          ],

          // Commandes récentes
          _buildRecentOrdersSection(context, orderService),
          const SizedBox(height: 20),

          // Performance
          _buildPerformanceSection(context, orderService),
        ],
      ),
    );
  }

  Widget _buildPendingOrdersTab(
      BuildContext context, OrderManagementService orderService) {
    // Charger directement depuis la base de données pour utiliser les valeurs dbValue
    return Consumer<OrderManagementService>(
      builder: (context, service, child) {
        final future = service.loadOrdersByStatusFromDB(OrderStatus.pending);

        return FutureBuilder<List<Order>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Erreur: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        service.refresh();
                        setState(() {});
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            final pendingOrders = snapshot.data ?? [];

            return pendingOrders.isEmpty
                ? _buildEmptyState(context, 'Aucune commande en attente')
                : _buildOrdersList(context, pendingOrders, orderService);
          },
        );
      },
    );
  }

  Widget _buildConfirmedOrdersTab(
      BuildContext context, OrderManagementService orderService) {
    // Charger directement depuis la base de données pour utiliser les valeurs dbValue
    return Consumer<OrderManagementService>(
      builder: (context, service, child) {
        final future = service.loadOrdersByStatusFromDB(OrderStatus.confirmed);

        return FutureBuilder<List<Order>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Erreur: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        service.refresh();
                        setState(() {});
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            final confirmedOrders = snapshot.data ?? [];

            return confirmedOrders.isEmpty
                ? _buildEmptyState(context, 'Aucune commande confirmée')
                : _buildOrdersList(context, confirmedOrders, orderService);
          },
        );
      },
    );
  }

  Widget _buildPreparingOrdersTab(
      BuildContext context, OrderManagementService orderService) {
    // Charger directement depuis la base de données pour utiliser les valeurs dbValue
    return Consumer<OrderManagementService>(
      builder: (context, service, child) {
        final future = service.loadOrdersByStatusFromDB(OrderStatus.preparing);

        return FutureBuilder<List<Order>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Erreur: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        service.refresh();
                        setState(() {});
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            final preparingOrders = snapshot.data ?? [];

            return preparingOrders.isEmpty
                ? _buildEmptyState(context, 'Aucune commande en préparation')
                : _buildOrdersList(context, preparingOrders, orderService);
          },
        );
      },
    );
  }

  Widget _buildReadyOrdersTab(
      BuildContext context, OrderManagementService orderService) {
    // Charger directement depuis la base de données pour utiliser les valeurs dbValue
    return Consumer<OrderManagementService>(
      builder: (context, service, child) {
        final future = service.loadOrdersByStatusFromDB(OrderStatus.ready);

        return FutureBuilder<List<Order>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Erreur: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        service.refresh();
                        setState(() {});
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            final readyOrders = snapshot.data ?? [];

            return readyOrders.isEmpty
                ? _buildEmptyState(context, 'Aucune commande prête')
                : _buildOrdersList(context, readyOrders, orderService);
          },
        );
      },
    );
  }

  Widget _buildDeliveryOrdersTab(
      BuildContext context, OrderManagementService orderService) {
    // Utiliser Consumer pour écouter les changements du service
    // Charger directement depuis la base de données pour utiliser les valeurs dbValue (snake_case)
    return Consumer<OrderManagementService>(
      builder: (context, service, child) {
        // Créer un nouveau Future à chaque rebuild pour forcer le rechargement
        final future = service.loadOrdersByStatusFromDB(OrderStatus.onTheWay);

        return FutureBuilder<List<Order>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Erreur: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Forcer le rechargement
                        service.refresh();
                        setState(() {});
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            final deliveryOrders = snapshot.data ?? [];

            return deliveryOrders.isEmpty
                ? _buildEmptyState(context, 'Aucune commande en livraison')
                : _buildOrdersList(context, deliveryOrders, orderService);
          },
        );
      },
    );
  }

  Widget _buildStatisticsTab(
      BuildContext context, OrderManagementService orderService) {
    final stats = orderService.getOrderStats();
    final performanceStats = orderService.getPerformanceStats();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistiques détaillées
          _buildDetailedStats(context, stats),
          const SizedBox(height: 20),

          // Performance
          _buildPerformanceCards(context, performanceStats),
          const SizedBox(height: 20),

          // Répartition par statut
          _buildStatusDistribution(context, stats),
          const SizedBox(height: 20),

          // Évolution des commandes
          _buildOrderEvolution(context, orderService),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          context,
          'Total commandes',
          '${stats['total_orders'] ?? 0}',
          Icons.receipt_long,
          Theme.of(context).colorScheme.primary,
        ),
        _buildStatCard(
          context,
          'En attente',
          '${stats['pending_orders'] ?? 0}',
          Icons.pending,
          AdminColorTokens.semantic(Theme.of(context).colorScheme).warning,
        ),
        _buildStatCard(
          context,
          'En préparation',
          '${stats['preparing_orders'] ?? 0}',
          Icons.restaurant,
          Theme.of(context).colorScheme.tertiary,
        ),
        _buildStatCard(
          context,
          'Livrées',
          '${stats['delivered_orders'] ?? 0}',
          Icons.check_circle,
          AdminColorTokens.semantic(Theme.of(context).colorScheme).success,
        ),
        _buildStatCard(
          context,
          'Revenus totaux',
          PriceFormatter.format(
              (stats['total_revenue'] as num?)?.toDouble() ?? 0.0),
          Icons.monetization_on,
          Theme.of(context).colorScheme.secondary,
        ),
        _buildStatCard(
          context,
          'Panier moyen',
          PriceFormatter.format(
              (stats['average_order_value'] as num?)?.toDouble() ?? 0.0),
          Icons.shopping_cart,
          Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context, List<Order> urgentOrders,
      List<Order> overdueOrders) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: sem.danger),
                const SizedBox(width: 8),
                Text(
                  'Alertes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: sem.danger,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (urgentOrders.isNotEmpty) ...[
              Text(
                '⚠️ ${urgentOrders.length} commande(s) urgente(s)',
                style: TextStyle(color: sem.danger),
              ),
              const SizedBox(height: 4),
            ],
            if (overdueOrders.isNotEmpty) ...[
              Text(
                '🚨 ${overdueOrders.length} commande(s) en retard',
                style: TextStyle(color: sem.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrdersSection(
      BuildContext context, OrderManagementService orderService) {
    // Charger directement depuis la base de données
    return Consumer<OrderManagementService>(
      builder: (context, service, child) {
        final future = service.loadRecentOrdersFromDB(limit: 5);

        return FutureBuilder<List<Order>>(
          future: future,
          builder: (context, snapshot) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commandes récentes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (snapshot.hasError)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Erreur: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    else if (snapshot.data == null || snapshot.data!.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Aucune commande récente'),
                        ),
                      )
                    else
                      ...snapshot.data!.map(
                        (order) =>
                            _buildOrderListItem(context, order, orderService),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPerformanceSection(
      BuildContext context, OrderManagementService orderService) {
    final performanceStats = orderService.getPerformanceStats();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceItem(
                    context,
                    'Temps moyen',
                    '${(performanceStats['average_delivery_time'] as num?)?.toDouble().toInt() ?? 0} min',
                    Icons.timer,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildPerformanceItem(
                    context,
                    'Livraison à temps',
                    '${((performanceStats['on_time_delivery_rate'] as num?)?.toDouble() ?? 0.0) * 100}%',
                    Icons.schedule,
                    AdminColorTokens.semantic(Theme.of(context).colorScheme)
                        .success,
                  ),
                ),
                Expanded(
                  child: _buildPerformanceItem(
                    context,
                    'Satisfaction',
                    '${(performanceStats['customer_satisfaction'] as num?)?.toDouble() ?? 0.0}/5',
                    Icons.star,
                    AdminColorTokens.semantic(Theme.of(context).colorScheme)
                        .warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceItem(BuildContext context, String title, String value,
      IconData icon, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDetailedStats(BuildContext context, Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistiques détaillées',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
                context, 'Commandes totales', '${stats['total_orders'] ?? 0}'),
            _buildStatRow(
                context, 'En attente', '${stats['pending_orders'] ?? 0}'),
            _buildStatRow(
                context, 'Confirmées', '${stats['confirmed_orders'] ?? 0}'),
            _buildStatRow(
                context, 'En préparation', '${stats['preparing_orders'] ?? 0}'),
            _buildStatRow(context, 'Prêtes', '${stats['ready_orders'] ?? 0}'),
            _buildStatRow(
                context, 'Livrées', '${stats['delivered_orders'] ?? 0}'),
            _buildStatRow(
                context, 'Annulées', '${stats['cancelled_orders'] ?? 0}'),
            const Divider(),
            _buildStatRow(
                context,
                'Revenus totaux',
                PriceFormatter.format(
                    (stats['total_revenue'] as num?)?.toDouble() ?? 0.0)),
            _buildStatRow(
                context,
                'Panier moyen',
                PriceFormatter.format(
                    (stats['average_order_value'] as num?)?.toDouble() ?? 0.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCards(
      BuildContext context, Map<String, dynamic> performanceStats) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildPerformanceCard(
          context,
          'Temps moyen',
          '${(performanceStats['average_delivery_time'] as num?)?.toDouble().toInt() ?? 0} min',
          Icons.timer,
          sem.info,
        ),
        _buildPerformanceCard(
          context,
          'Livraison à temps',
          '${((performanceStats['on_time_delivery_rate'] as num?)?.toDouble() ?? 0.0) * 100}%',
          Icons.schedule,
          sem.success,
        ),
        _buildPerformanceCard(
          context,
          'Satisfaction',
          '${(performanceStats['customer_satisfaction'] as num?)?.toDouble() ?? 0.0}/5',
          Icons.star,
          sem.warning,
        ),
      ],
    );
  }

  Widget _buildPerformanceCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
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
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDistribution(
      BuildContext context, Map<String, dynamic> stats) {
    final total = stats['total_orders'] as int? ?? 0;
    if (total == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition par statut',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildStatusBar(
              context,
              'En attente',
              stats['pending_orders'] as int? ?? 0,
              total,
              _getStatusColor(OrderStatus.pending, context),
            ),
            _buildStatusBar(
              context,
              'Confirmées',
              stats['confirmed_orders'] as int? ?? 0,
              total,
              _getStatusColor(OrderStatus.confirmed, context),
            ),
            _buildStatusBar(
              context,
              'En préparation',
              stats['preparing_orders'] as int? ?? 0,
              total,
              _getStatusColor(OrderStatus.preparing, context),
            ),
            _buildStatusBar(
              context,
              'Prêtes',
              stats['ready_orders'] as int? ?? 0,
              total,
              _getStatusColor(OrderStatus.ready, context),
            ),
            _buildStatusBar(
              context,
              'Livrées',
              stats['delivered_orders'] as int? ?? 0,
              total,
              _getStatusColor(OrderStatus.delivered, context),
            ),
            _buildStatusBar(
              context,
              'Annulées',
              stats['cancelled_orders'] as int? ?? 0,
              total,
              _getStatusColor(OrderStatus.cancelled, context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(
      BuildContext context, String label, int count, int total, Color color) {
    final percentage = total > 0 ? count / total : 0.0;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count (${(percentage * 100).toInt()}%)'),
        ],
      ),
    );
  }

  Widget _buildOrderEvolution(
      BuildContext context, OrderManagementService orderService) {
    final orders = orderService.allOrders;

    // Calculer les commandes par jour (7 derniers jours)
    final now = DateTime.now();
    final Map<String, int> dailyOrders = {};

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyOrders[dateKey] = 0;
    }

    for (final order in orders) {
      final orderDate = order.orderTime;
      final dateKey =
          '${orderDate.year}-${orderDate.month.toString().padLeft(2, '0')}-${orderDate.day.toString().padLeft(2, '0')}';
      if (dailyOrders.containsKey(dateKey)) {
        dailyOrders[dateKey] = (dailyOrders[dateKey] ?? 0) + 1;
      }
    }

    final sortedKeys = dailyOrders.keys.toList()..sort();
    final maxValue = dailyOrders.values.isEmpty
        ? 1.0
        : dailyOrders.values.reduce((a, b) => a > b ? a : b).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Évolution des commandes (7 derniers jours)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: sortedKeys.isEmpty
                  ? const Center(
                      child: Text('Aucune donnée disponible'),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxValue +
                            (maxValue * 0.2), // Ajouter 20% d'espace en haut
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) =>
                                Theme.of(context).colorScheme.inverseSurface,
                            tooltipPadding: const EdgeInsets.all(8),
                            tooltipMargin: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final date = sortedKeys[group.x.toInt()];
                              final count = dailyOrders[date] ?? 0;
                              return BarTooltipItem(
                                '$count commande${count > 1 ? 's' : ''}\n$date',
                                TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onInverseSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 &&
                                    value.toInt() < sortedKeys.length) {
                                  final dateStr = sortedKeys[value.toInt()];
                                  final dateParts = dateStr.split('-');
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      '${dateParts[2]}/${dateParts[1]}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              reservedSize: 40,
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
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.20),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.25),
                            ),
                            left: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                        barGroups: sortedKeys.asMap().entries.map((entry) {
                          final index = entry.key;
                          final date = entry.value;
                          final count = dailyOrders[date] ?? 0;

                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: count.toDouble(),
                                color: Theme.of(context).colorScheme.primary,
                                width: 20,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Total: ${orders.length} commandes sur 7 jours',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context, List<Order> orders,
      OrderManagementService orderService) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(context, order, orderService);
      },
    );
  }

  Widget _buildOrderCard(
      BuildContext context, Order order, OrderManagementService orderService) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status, context)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.status.displayName,
                    style: TextStyle(
                      color: _getStatusColor(order.status, context),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  PriceFormatter.format(order.total),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Commande #${order.id.substring(0, 8).toUpperCase()}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${order.items.length} article${order.items.length > 1 ? 's' : ''} • ${_formatTime(order.orderTime)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            // Afficher les articles de la commande
            if (order.items.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Articles:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    ...order.items.take(3).map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                '• ${item.quantity}x ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.menuItemName.isNotEmpty
                                          ? item.menuItemName
                                          : item.name.isNotEmpty
                                              ? item.name
                                              : 'Article',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (item
                                        .getFormattedCustomizations()
                                        .isNotEmpty)
                                      Text(
                                        item
                                                .getFormattedCustomizations()
                                                .take(2)
                                                .join(', ') +
                                            (item
                                                        .getFormattedCustomizations()
                                                        .length >
                                                    2
                                                ? '...'
                                                : ''),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                PriceFormatter.format(item.totalPrice),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (order.items.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+ ${order.items.length - 3} autre${order.items.length - 3 > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      size: 16,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aucun article trouvé dans cette commande',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onTertiaryContainer,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              order.deliveryAddress,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Voir détails',
                    onPressed: () => _showOrderDetails(order),
                    variant: ButtonVariant.outlined,
                    height: 36,
                  ),
                ),
                const SizedBox(width: 8),
                if (order.status == OrderStatus.pending)
                  Expanded(
                    child: CustomButton(
                      text: 'Confirmer',
                      onPressed: () => _confirmOrder(order, orderService),
                      color: AdminColorTokens.semantic(
                        Theme.of(context).colorScheme,
                      ).success,
                      height: 36,
                    ),
                  ),
                if (order.status == OrderStatus.confirmed)
                  Expanded(
                    child: CustomButton(
                      text: 'Préparer',
                      onPressed: () => _prepareOrder(order, orderService),
                      color: Theme.of(context).colorScheme.primary,
                      height: 36,
                    ),
                  ),
                if (order.status == OrderStatus.preparing)
                  Expanded(
                    child: CustomButton(
                      text: 'Prêt',
                      onPressed: () => _readyOrder(order, orderService),
                      color: AdminColorTokens.semantic(
                        Theme.of(context).colorScheme,
                      ).warning,
                      height: 36,
                    ),
                  ),
                if (order.status == OrderStatus.ready)
                  Expanded(
                    child: Consumer<DriverManagementService>(
                      builder: (context, driverService, child) {
                        return CustomButton(
                          text: order.deliveryPersonId != null
                              ? 'Réassigner'
                              : 'Assigner livreur',
                          onPressed: () => _showAssignDriverDialog(
                            context,
                            order,
                            orderService,
                            driverService,
                          ),
                          color: Theme.of(context).colorScheme.primary,
                          height: 36,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderListItem(
      BuildContext context, Order order, OrderManagementService orderService) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            _getStatusColor(order.status, context).withValues(alpha: 0.1),
        child: Text(
          order.status.emoji,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      title: Text('Commande #${order.id.substring(0, 8).toUpperCase()}'),
      subtitle: Text(
          '${order.status.displayName} • ${PriceFormatter.format(order.total)}'),
      trailing: Text(_formatTime(order.orderTime)),
      onTap: () => _showOrderDetails(order),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    switch (status) {
      case OrderStatus.pending:
        return sem.warning;
      case OrderStatus.confirmed:
        return sem.info;
      case OrderStatus.preparing:
        return scheme.tertiary;
      case OrderStatus.ready:
        return sem.success;
      case OrderStatus.pickedUp:
        return scheme.secondary;
      case OrderStatus.onTheWay:
        return scheme.primary;
      case OrderStatus.delivered:
        return sem.success;
      case OrderStatus.cancelled:
        return sem.danger;
      case OrderStatus.refunded:
        return scheme.onSurfaceVariant;
      case OrderStatus.failed:
        return sem.danger;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}min';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  // Méthode _showSearchDialog supprimée car la recherche est maintenant intégrée directement dans l'interface

  void _showFilterDialog() {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 500.0);
    final dialogHeight = 300.0;

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
                        'Filtrer les commandes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    // IMPORTANT: Material + InkWell + Container avec taille explicite
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: const Icon(Icons.close, size: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Contenu
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Consumer<OrderManagementService>(
                    builder: (context, orderService, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<OrderStatus>(
                            decoration: const InputDecoration(
                              labelText: 'Statut',
                              border: OutlineInputBorder(),
                            ),
                            initialValue:
                                null, // orderService.statusFilter; // Propriété non implémentée
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Tous les statuts')),
                              ...OrderStatus.values.map((status) {
                                return DropdownMenuItem(
                                  value: status,
                                  child: Text(status.displayName),
                                );
                              }),
                            ],
                            onChanged: (status) {
                              // orderService.filterByStatus(status); // Méthode non implémentée
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<OrderSortOption>(
                            decoration: const InputDecoration(
                              labelText: 'Trier par',
                              border: OutlineInputBorder(),
                            ),
                            initialValue:
                                null, // orderService.sortOption; // Propriété non implémentée
                            items: OrderSortOption.values.map((option) {
                              return DropdownMenuItem<OrderSortOption>(
                                value: option,
                                child: Text(option.displayName),
                              );
                            }).toList(),
                            onChanged: (option) {
                              if (option != null) {
                                // orderService.setSortOption(option); // Méthode non implémentée
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                      ),
                      child: TextButton(
                        onPressed: () {
                          // context.read<OrderManagementService>().filterByStatus(null); // Méthode non implémentée
                          Navigator.of(context).pop();
                        },
                        child: const Text('Effacer'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fermer'),
                      ),
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

  void _exportOrders() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Export des commandes en cours...'),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
      ),
    );
  }

  void _showOrderDetails(Order order) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(500.0, 900.0);
    final dialogHeight = (screenSize.height * 0.85).clamp(500.0, 900.0);

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
                        'Commande #${order.id.substring(0, 8).toUpperCase()}',
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
              // Contenu scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Informations générales
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                                const SizedBox(width: 8),
                                Text(
                                  'Informations',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow('Statut', order.status.displayName),
                            const SizedBox(height: 4),
                            _buildDetailRow(
                                'Total', PriceFormatter.format(order.total)),
                            const SizedBox(height: 4),
                            _buildDetailRow('Articles',
                                '${order.items.length} article${order.items.length > 1 ? 's' : ''}'),
                            const SizedBox(height: 4),
                            _buildDetailRow('Méthode de paiement',
                                order.paymentMethod.toString().split('.').last),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Articles de la commande
                      if (order.items.isNotEmpty) ...[
                        Text(
                          'Articles commandés:',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.25),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: order.items.map((item) {
                              return Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image ou icône
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: item.menuItemImage.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: Image.network(
                                                item.menuItemImage,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    Icon(
                                                  Icons.fastfood,
                                                  size: 20,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            )
                                          : Icon(
                                              Icons.fastfood,
                                              size: 20,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Détails de l'article
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.menuItemName.isNotEmpty
                                                ? item.menuItemName
                                                : item.name.isNotEmpty
                                                    ? item.name
                                                    : 'Article',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.quantity}x ${PriceFormatter.format(item.unitPrice)} = ${PriceFormatter.format(item.totalPrice)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                          if (item.categoryId.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Catégorie: ${item.categoryId}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: 0.85),
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                          if (item
                                              .getFormattedCustomizations()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            ...item
                                                .getFormattedCustomizations()
                                                .map((customization) => Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 2),
                                                      child: Text(
                                                        '• $customization',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                        ),
                                                      ),
                                                    )),
                                          ],
                                          if (item.notes != null &&
                                              item.notes!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Note: ${item.notes}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onTertiaryContainer,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Prix total
                                    Text(
                                      PriceFormatter.format(item.totalPrice),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onTertiaryContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Aucun article trouvé dans cette commande',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onTertiaryContainer,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Adresse de livraison
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer),
                                const SizedBox(width: 8),
                                Text(
                                  'Adresse de livraison',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.deliveryAddress,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Date
                      Text(
                        'Date: ${_formatTime(order.orderTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
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

  /// Afficher un dialog pour assigner un livreur à une commande
  Future<void> _showAssignDriverDialog(
    BuildContext context,
    Order order,
    OrderManagementService orderService,
    DriverManagementService driverService,
  ) async {
    // Récupérer les livreurs disponibles (déjà chargés au démarrage)
    final availableDrivers = driverService.getAvailableDrivers();

    // Si aucun livreur disponible, montrer un message
    if (availableDrivers.isEmpty) {
      final screenSize = MediaQuery.of(context).size;
      final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 500.0);
      final dialogHeight = 250.0;

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
                      Icon(
                        Icons.warning,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aucun livreur disponible',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
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
                    child: Text(
                      'Il n\'y a actuellement aucun livreur disponible pour cette livraison.\n\n'
                      'Vous pouvez attendre qu\'un livreur devienne disponible ou assigner un livreur manuellement depuis la liste des livreurs.',
                      style: TextStyle(fontSize: 14),
                    ),
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
      return;
    }

    // Livreur sélectionné
    Driver? selectedDriver;

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(500.0, 800.0);
    final dialogHeight = (screenSize.height * 0.7).clamp(500.0, 800.0);

    await DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
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
                      Icon(
                        Icons.local_shipping,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Assigner un livreur',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
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
                // Contenu scrollable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Informations de la commande
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Commande #${order.id.substring(0, 8).toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total: ${PriceFormatter.format(order.total)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Adresse: ${order.deliveryAddress}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Liste des livreurs disponibles
                        Text(
                          'Livreurs disponibles (${availableDrivers.length}):',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 300,
                          child: ListView.builder(
                            itemCount: availableDrivers.length,
                            itemBuilder: (context, index) {
                              final driver = availableDrivers[index];
                              final isSelected =
                                  selectedDriver?.id == driver.id;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: 0.35)
                                    : null,
                                elevation: isSelected ? 4 : 1,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        selectedDriver = driver;
                                      });
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      constraints: const BoxConstraints(
                                        minHeight: 60,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          // Statut du livreur
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: driver.status.color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Informations du livreur
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        driver.name,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                          color: isSelected
                                                              ? Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .onPrimaryContainer
                                                              : null,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isSelected)
                                                      Icon(
                                                        Icons.check_circle,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                        size: 20,
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.star,
                                                      size: 14,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .tertiary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      driver.rating
                                                          .toStringAsFixed(1),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Icon(
                                                      Icons.delivery_dining,
                                                      size: 14,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${driver.totalDeliveries} livraisons',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (driver.vehicleType !=
                                                    null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Véhicule: ${driver.vehicleType}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant
                                                          .withValues(
                                                              alpha: 0.85),
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        constraints: const BoxConstraints(
                          minHeight: 48,
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        constraints: const BoxConstraints(
                          minHeight: 48,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: selectedDriver == null
                              ? null
                              : () async {
                                  // Fermer le dialog
                                  Navigator.of(context).pop();

                                  // Assigner le livreur
                                  // Vérifier que le driver a un userId avant d'assigner
                                  if (selectedDriver!.userId == null ||
                                      selectedDriver!.userId!.isEmpty) {
                                    if (context.mounted) {
                                      final scheme =
                                          Theme.of(context).colorScheme;
                                      final sem = AdminColorTokens.semantic(
                                        scheme,
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          backgroundColor:
                                              scheme.inverseSurface,
                                          duration: const Duration(seconds: 5),
                                          content: Row(
                                            children: [
                                              Icon(
                                                Icons.warning,
                                                color: sem.warning,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Ce livreur n\'a pas d\'utilisateur correspondant dans la table users. Veuillez créer un utilisateur avec role=\'delivery\' pour ce livreur.',
                                                  style: TextStyle(
                                                    color:
                                                        scheme.onInverseSurface,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  // Utiliser userId (obligatoire)
                                  final success =
                                      await orderService.assignDriver(
                                    order.id,
                                    selectedDriver!.userId!,
                                  );

                                  if (success) {
                                    // Marquer la commande comme récupérée (pickedUp) après assignation
                                    await orderService
                                        .markOrderPickedUp(order.id);

                                    // Rafraîchir les commandes
                                    await orderService.refresh();

                                    // Afficher un message de succès
                                    if (context.mounted) {
                                      final scheme =
                                          Theme.of(context).colorScheme;
                                      final sem = AdminColorTokens.semantic(
                                        scheme,
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          backgroundColor:
                                              scheme.inverseSurface,
                                          duration: const Duration(seconds: 3),
                                          content: Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: sem.success,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Livreur ${selectedDriver!.name} assigné avec succès',
                                                  style: TextStyle(
                                                    color:
                                                        scheme.onInverseSurface,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  } else {
                                    // Afficher un message d'erreur
                                    if (context.mounted) {
                                      final scheme =
                                          Theme.of(context).colorScheme;
                                      final sem = AdminColorTokens.semantic(
                                        scheme,
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          backgroundColor:
                                              scheme.inverseSurface,
                                          duration: const Duration(seconds: 3),
                                          content: Row(
                                            children: [
                                              Icon(
                                                Icons.error,
                                                color: sem.danger,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Erreur lors de l\'assignation du livreur',
                                                  style: TextStyle(
                                                    color:
                                                        scheme.onInverseSurface,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.local_shipping),
                          label: const Text('Assigner'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Afficher un dialog de confirmation avant de changer le statut
  Future<void> _showStatusChangeConfirmation({
    required BuildContext context,
    required Order order,
    required OrderStatus currentStatus,
    required OrderStatus newStatus,
    required OrderManagementService orderService,
    String? confirmationMessage,
  }) async {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 600.0);
    final dialogHeight = 400.0;
    // Capturer les valeurs nécessaires avant le gap async
    final inverseSurfaceColor = Theme.of(context).colorScheme.inverseSurface;

    final confirmed = await DialogHelper.showSafeDialog<bool>(
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
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Confirmer le changement',
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
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Contenu scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        confirmationMessage ??
                            'Êtes-vous sûr de vouloir changer le statut de cette commande ?',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Commande #${order.id.substring(0, 8).toUpperCase()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.arrow_forward,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Statut actuel: ${currentStatus.displayName}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: AdminColorTokens.semantic(
                                    Theme.of(context).colorScheme,
                                  ).success,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Nouveau statut: ${newStatus.displayName}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AdminColorTokens.semantic(
                                        Theme.of(context).colorScheme,
                                      ).success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: const Text('Confirmer'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      final success = await orderService.updateOrderStatus(order.id, newStatus);
      // IMPORTANT: sur Web, certains rebuilds peuvent être "perdus" si l'écran
      // n'écoute pas la bonne instance ou si un cache UI est impliqué.
      // Forcer un refresh garantit que la commande apparaît dans le bon onglet.
      if (success) {
        await orderService.refresh();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '✅ Statut changé: ${newStatus.displayName}'
                  : '❌ Erreur lors du changement de statut',
            ),
            backgroundColor: inverseSurfaceColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _confirmOrder(Order order, OrderManagementService orderService) {
    _showStatusChangeConfirmation(
      context: context,
      order: order,
      currentStatus: order.status,
      newStatus: OrderStatus.confirmed,
      orderService: orderService,
      confirmationMessage:
          'Voulez-vous confirmer cette commande ?\n\nCette action valide la commande et commence le processus de préparation.',
    );
  }

  void _prepareOrder(Order order, OrderManagementService orderService) {
    _showStatusChangeConfirmation(
      context: context,
      order: order,
      currentStatus: order.status,
      newStatus: OrderStatus.preparing,
      orderService: orderService,
      confirmationMessage:
          'Voulez-vous commencer la préparation de cette commande ?\n\nCette action indique que la cuisine commence à préparer les articles.',
    );
  }

  void _readyOrder(Order order, OrderManagementService orderService) {
    _showStatusChangeConfirmation(
      context: context,
      order: order,
      currentStatus: order.status,
      newStatus: OrderStatus.ready,
      orderService: orderService,
      confirmationMessage:
          'Voulez-vous marquer cette commande comme prête ?\n\nCette action indique que la commande est prête pour la livraison.',
    );
  }

  /// Widget helper pour afficher une ligne de détail
  Widget _buildDetailRow(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
