import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/order_management_service.dart';
import '../../models/order.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/order_status_widget.dart';
import '../../widgets/custom_button.dart';
import '../../utils/dialog_helper.dart';
import '../../utils/price_formatter.dart';

class UpdatedOrderManagementScreen extends StatefulWidget {
  const UpdatedOrderManagementScreen({super.key});

  @override
  State<UpdatedOrderManagementScreen> createState() =>
      _UpdatedOrderManagementScreenState();
}

class _UpdatedOrderManagementScreenState
    extends State<UpdatedOrderManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
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
        title: const Text('Gestion des Commandes'),
        actions: [
          Container(
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                Provider.of<OrderManagementService>(context, listen: false)
                    .refresh();
              },
            ),
          ),
          Container(
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            child: IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportOrders,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Vue d\'ensemble'),
            Tab(icon: Icon(Icons.schedule), text: 'En attente'),
            Tab(icon: Icon(Icons.check), text: 'Confirmées'),
            Tab(icon: Icon(Icons.restaurant), text: 'En préparation'),
            Tab(icon: Icon(Icons.check_circle), text: 'Prêtes'),
            Tab(icon: Icon(Icons.person), text: 'Récupérées'),
            Tab(icon: Icon(Icons.delivery_dining), text: 'En route'),
            Tab(icon: Icon(Icons.done_all), text: 'Livrées'),
          ],
        ),
      ),
      body: Consumer<OrderManagementService>(
        builder: (context, orderService, child) {
          if (orderService.isLoading) {
            return const LoadingWidget(message: 'Chargement des commandes...');
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(context, orderService),
              _buildOrdersTab(context, orderService, OrderStatus.pending),
              _buildOrdersTab(context, orderService, OrderStatus.confirmed),
              _buildOrdersTab(context, orderService, OrderStatus.preparing),
              _buildOrdersTab(context, orderService, OrderStatus.ready),
              _buildOrdersTab(context, orderService, OrderStatus.pickedUp),
              _buildOrdersTab(context, orderService, OrderStatus.onTheWay),
              _buildOrdersTab(context, orderService, OrderStatus.delivered),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(
      BuildContext context, OrderManagementService orderService) {
    final stats = orderService.getOrderStats();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsGrid(context, stats),
          const SizedBox(height: 24),
          _buildStatusDistribution(context, orderService),
          const SizedBox(height: 24),
          _buildRecentOrders(context, orderService),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(context, 'Total', stats['total_orders'] ?? 0,
            Icons.shopping_cart, Colors.blue),
        _buildStatCard(context, 'En attente', stats['pending_orders'] ?? 0,
            Icons.schedule, Colors.orange),
        _buildStatCard(context, 'Confirmées', stats['confirmed_orders'] ?? 0,
            Icons.check, Colors.green),
        _buildStatCard(context, 'En préparation',
            stats['preparing_orders'] ?? 0, Icons.restaurant, Colors.blue),
        _buildStatCard(context, 'Prêtes', stats['ready_orders'] ?? 0,
            Icons.check_circle, Colors.purple),
        _buildStatCard(context, 'Récupérées', stats['picked_up_orders'] ?? 0,
            Icons.person, Colors.orange),
        _buildStatCard(context, 'En route', stats['on_the_way_orders'] ?? 0,
            Icons.delivery_dining, Colors.cyan),
        _buildStatCard(context, 'Livrées', stats['delivered_orders'] ?? 0,
            Icons.done_all, Colors.green),
        _buildStatCard(context, 'Annulées', stats['cancelled_orders'] ?? 0,
            Icons.cancel, Colors.red),
        _buildStatCard(context, 'Remboursées', stats['refunded_orders'] ?? 0,
            Icons.money, Colors.grey),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, int value,
      IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  Text(
                    value.toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
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

  Widget _buildStatusDistribution(
      BuildContext context, OrderManagementService orderService) {
    final stats = orderService.getOrderStats();
    final total = stats['total_orders'] as int? ?? 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition des statuts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...OrderStatus.values
                .where((status) =>
                    status != OrderStatus.refunded &&
                    status != OrderStatus.failed)
                .map((status) {
              final count = _getStatusCount(stats, status);
              final percentage = total > 0 ? count / total : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    OrderStatusWidget(status: status, isCompact: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getStatusColor(status),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(percentage * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders(
      BuildContext context, OrderManagementService orderService) {
    final recentOrders = orderService.allOrders.take(5).toList();

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
            ...recentOrders.map(
                (order) => _buildOrderListItem(context, order, orderService)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderListItem(
      BuildContext context, Order order, OrderManagementService orderService) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 56,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(order.status),
          child: Text(
            order.status.emoji,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        title: Text('Commande #${order.id.substring(0, 8)}'),
        subtitle: Text(
            '${PriceFormatter.format(order.total)} • ${order.orderTime.day}/${order.orderTime.month}'),
        trailing: OrderStatusWidget(status: order.status, isCompact: true),
        onTap: () => _showOrderDetails(context, order, orderService),
      ),
    );
  }

  Widget _buildOrdersTab(BuildContext context,
      OrderManagementService orderService, OrderStatus status) {
    final orders = orderService.getOrdersByStatus(status);

    return orders.isEmpty
        ? _buildEmptyState(
            context, 'Aucune commande ${status.displayName.toLowerCase()}')
        : _buildOrdersList(context, orders, orderService);
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Commande #${order.id.substring(0, 8)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                OrderStatusWidget(status: order.status, isCompact: true),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${PriceFormatter.format(order.total)} • ${order.items.length} article(s)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${order.orderTime.day}/${order.orderTime.month}/${order.orderTime.year} à ${order.orderTime.hour}:${order.orderTime.minute.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Voir détails',
                    onPressed: () =>
                        _showOrderDetails(context, order, orderService),
                    variant: ButtonVariant.outlined,
                  ),
                ),
                const SizedBox(width: 8),
                if (order.status.canBeModified)
                  Expanded(
                    child: CustomButton(
                      text: 'Modifier',
                      onPressed: () =>
                          _showStatusChangeDialog(context, order, orderService),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(
      BuildContext context, Order order, OrderManagementService orderService) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Commande #${order.id.substring(0, 8)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              OrderStatusWidget(status: order.status),
              const SizedBox(height: 16),
              Text('Total: ${PriceFormatter.format(order.total)}'),
              Text('Adresse: ${order.deliveryAddress}'),
              Text('Méthode de paiement: ${order.paymentMethod.displayName}'),
              Text(
                  'Date: ${order.orderTime.day}/${order.orderTime.month}/${order.orderTime.year}'),
              if (order.deliveryNotes != null) ...[
                const SizedBox(height: 8),
                Text('Notes: ${order.deliveryNotes}'),
              ],
            ],
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

  void _showStatusChangeDialog(
      BuildContext context, Order order, OrderManagementService orderService) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer le statut'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: order.status.nextPossibleStatuses.map((status) {
            return ListTile(
              leading: Text(status.emoji, style: const TextStyle(fontSize: 20)),
              title: Text(status.displayName),
              onTap: () async {
                Navigator.of(context).pop();
                await orderService.updateOrderStatus(order.id, status);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportOrders() async {
    try {
      final orderService =
          Provider.of<OrderManagementService>(context, listen: false);
      final allOrders = orderService.allOrders;

      if (allOrders.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucune commande à exporter'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Créer le contenu CSV
      final csvBuffer = StringBuffer();
      csvBuffer.writeln(
          'ID,Date,Client,Adresse,Statut,Total,Articles,Méthode de paiement');

      final supabase = Supabase.instance.client;

      for (final order in allOrders) {
        try {
          // Récupérer le nom du client
          final userData = await supabase
              .from('users')
              .select('name')
              .eq('auth_user_id', order.userId)
              .maybeSingle();

          final clientName = userData?['name'] as String? ?? 'Inconnu';

          csvBuffer.writeln(
            [
              order.id,
              order.orderTime.toIso8601String(),
              '"${clientName.replaceAll('"', '""')}"', // Échapper les guillemets pour CSV
              '"${order.deliveryAddress.replaceAll('"', '""')}"',
              order.status.displayName,
              PriceFormatter.format(order.total).replaceAll(' ', ''),
              order.items.length,
              order.paymentMethod.displayName,
            ].join(','),
          );
        } catch (e) {
          // Si on ne peut pas récupérer le nom, continuer sans
          csvBuffer.writeln(
            [
              order.id,
              order.orderTime.toIso8601String(),
              'Inconnu',
              '"${order.deliveryAddress.replaceAll('"', '""')}"',
              order.status.displayName,
              PriceFormatter.format(order.total).replaceAll(' ', ''),
              order.items.length,
              order.paymentMethod.displayName,
            ].join(','),
          );
        }
      }

      final csvContent = csvBuffer.toString();

      // Afficher le CSV dans une boîte de dialogue pour permettre la copie
      if (mounted) {
        DialogHelper.showSafeDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Export CSV (${allOrders.length} commande(s))'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Copiez le contenu CSV ci-dessous:'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.all(8),
                    height: 400,
                    child: SingleChildScrollView(
                      child: SelectableText(csvContent),
                    ),
                  ),
                ],
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${allOrders.length} commande(s) exportée(s)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _getStatusCount(Map<String, dynamic> stats, OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return stats['pending_orders'] ?? 0;
      case OrderStatus.confirmed:
        return stats['confirmed_orders'] ?? 0;
      case OrderStatus.preparing:
        return stats['preparing_orders'] ?? 0;
      case OrderStatus.ready:
        return stats['ready_orders'] ?? 0;
      case OrderStatus.pickedUp:
        return stats['picked_up_orders'] ?? 0;
      case OrderStatus.onTheWay:
        return stats['on_the_way_orders'] ?? 0;
      case OrderStatus.delivered:
        return stats['delivered_orders'] ?? 0;
      case OrderStatus.cancelled:
        return stats['cancelled_orders'] ?? 0;
      case OrderStatus.refunded:
        return stats['refunded_orders'] ?? 0;
      case OrderStatus.failed:
        return stats['failed_orders'] ?? 0;
    }
  }

  Color _getStatusColor(OrderStatus status) {
    final colorHex = status.colorHex;
    final colorValue = int.parse(colorHex.replaceAll('#', '0xFF'));
    return Color(colorValue);
  }
}
