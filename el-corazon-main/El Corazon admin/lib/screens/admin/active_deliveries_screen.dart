import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/order_management_service.dart';
import '../../services/driver_management_service.dart';
import '../../models/order.dart';
import '../../models/driver.dart';
import 'driver_map_screen.dart';
import '../../ui/ui.dart';

class ActiveDeliveriesScreen extends StatefulWidget {
  const ActiveDeliveriesScreen({super.key});

  @override
  State<ActiveDeliveriesScreen> createState() => _ActiveDeliveriesScreenState();
}

class _ActiveDeliveriesScreenState extends State<ActiveDeliveriesScreen> {
  // Filtre par défaut : afficher toutes les livraisons actives
  OrderStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    final orderService = context.read<OrderManagementService>();
    final driverService = context.read<DriverManagementService>();

    await Future.wait([
      orderService.refresh(),
      driverService.refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<OrderManagementService, DriverManagementService>(
        builder: (context, orderService, driverService, child) {
          if (orderService.isLoading && orderService.allOrders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filtrer les commandes actives (prêtes, assignées, en cours)
          final activeOrders = orderService.allOrders.where((order) {
            final isActive = order.status == OrderStatus.ready ||
                order.status == OrderStatus.pickedUp ||
                order.status == OrderStatus.onTheWay;

            if (_statusFilter != null) {
              return isActive && order.status == _statusFilter;
            }
            return isActive;
          }).toList();

          // Trier par date (plus récent en premier)
          activeOrders.sort((a, b) => b.orderTime.compareTo(a.orderTime));

          return Column(
            children: [
              // En-tête avec statistiques et filtres
              _buildHeader(context, activeOrders.length),

              // Liste des livraisons
              Expanded(
                child: activeOrders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _refreshData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: activeOrders.length,
                          itemBuilder: (context, index) {
                            final order = activeOrders[index];
                            final driver = order.deliveryPersonId != null
                                ? driverService.drivers.firstWhere(
                                    (d) => d.userId == order.deliveryPersonId,
                                    orElse: () => Driver(
                                      id: 'unknown',
                                      name: 'Inconnu',
                                      email: '',
                                      phone: '',
                                      status: DriverStatus.unavailable,
                                      createdAt: DateTime.now(),
                                      isActive: false,
                                    ),
                                  )
                                : null;

                            return _buildDeliveryCard(context, order, driver);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Row(
            children: [
              if (Navigator.of(context).canPop())
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              Text(
                'Livraisons en cours ($count)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              // Filtres rapides
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Tout'),
                    selected: _statusFilter == null,
                    onSelected: (selected) {
                      setState(() => _statusFilter = null);
                    },
                  ),
                  FilterChip(
                    label: const Text('Prêtes'),
                    selected: _statusFilter == OrderStatus.ready,
                    backgroundColor: sem.success.withValues(alpha: 0.10),
                    selectedColor: sem.success.withValues(alpha: 0.20),
                    onSelected: (selected) {
                      setState(() =>
                          _statusFilter = selected ? OrderStatus.ready : null);
                    },
                  ),
                  FilterChip(
                    label: const Text('En route'),
                    selected: _statusFilter == OrderStatus.onTheWay,
                    backgroundColor: sem.info.withValues(alpha: 0.10),
                    selectedColor: sem.info.withValues(alpha: 0.20),
                    onSelected: (selected) {
                      setState(() => _statusFilter =
                          selected ? OrderStatus.onTheWay : null);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(BuildContext context, Order order, Driver? driver) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = _getStatusColor(context, order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Badge de statut
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(order.status),
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.status.displayName,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '#${order.id.substring(0, 8).toUpperCase()}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Infos client et adresse
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.deliveryAddress,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Info temps
            Row(
              children: [
                Icon(Icons.access_time, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Commandé à ${_formatTime(order.orderTime)}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
                if (order.estimatedDeliveryTime != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.timer, size: 18, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Estimé: ${_formatTime(order.estimatedDeliveryTime!)}',
                    style: TextStyle(color: scheme.primary, fontSize: 13),
                  ),
                ],
              ],
            ),

            const Divider(height: 24),

            // Section Livreur
            Row(
              children: [
                if (driver != null) ...[
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: driver.profileImageUrl != null
                        ? NetworkImage(driver.profileImageUrl!)
                        : null,
                    child: driver.profileImageUrl == null
                        ? Text(driver.name[0].toUpperCase())
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        driver.phone,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ] else
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: scheme.tertiary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Aucun livreur assigné',
                          style: TextStyle(
                            color: scheme.tertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Actions
                if (driver != null)
                  IconButton(
                    icon: const Icon(Icons.map),
                    color: theme.colorScheme.primary,
                    tooltip: 'Voir sur la carte',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DriverMapScreen(),
                        ),
                      );
                    },
                  ),

                // Bouton d'action principal
                if (order.status == OrderStatus.ready)
                  ElevatedButton.icon(
                    onPressed: () => _showAssignDriverDialog(context, order),
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Assigner'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 64,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune livraison active',
            style: TextStyle(
              fontSize: 18,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les nouvelles livraisons apparaîtront ici',
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BuildContext context, OrderStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    switch (status) {
      case OrderStatus.ready:
        return sem.warning;
      case OrderStatus.pickedUp:
        return sem.info;
      case OrderStatus.onTheWay:
        return scheme.primary;
      case OrderStatus.delivered:
        return sem.success;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.ready:
        return Icons.inventory_2;
      case OrderStatus.pickedUp:
        return Icons.directions_run;
      case OrderStatus.onTheWay:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showAssignDriverDialog(
      BuildContext context, Order order) async {
    final driverService = context.read<DriverManagementService>();
    final orderService = context.read<OrderManagementService>();
    final availableDrivers = driverService.getAvailableDrivers();

    if (availableDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun livreur disponible actuellement')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assigner un livreur'),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableDrivers.length,
            itemBuilder: (context, index) {
              final driver = availableDrivers[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(driver.name[0]),
                ),
                title: Text(driver.name),
                subtitle: Text(
                    '${driver.totalDeliveries} livraisons • ⭐ ${driver.rating}'),
                onTap: () async {
                  Navigator.pop(context);
                  if (driver.userId != null) {
                    await orderService.assignDriver(order.id, driver.userId!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Livreur ${driver.name} assigné')),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}
