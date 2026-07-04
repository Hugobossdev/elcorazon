import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/order_management_service.dart';
import '../../models/order.dart';
import '../../utils/dialog_helper.dart';
import '../../utils/price_formatter.dart';
import '../../ui/ui.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  OrderStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Commandes'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          PopupMenuButton<OrderStatus?>(
            icon: const Icon(Icons.filter_list),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Toutes les commandes'),
              ),
              ...OrderStatus.values.map(
                (status) => PopupMenuItem(
                  value: status,
                  child: Row(
                    children: [
                      Text(status.emoji),
                      const SizedBox(width: 8),
                      Text(status.displayName),
                    ],
                  ),
                ),
              ),
            ],
            onSelected: (status) {
              setState(() {
                _filterStatus = status;
              });
            },
          ),
        ],
      ),
      body: Consumer<OrderManagementService>(
        builder: (context, orderService, child) {
          var orders = orderService.allOrders;

          if (_filterStatus != null) {
            orders = orders
                .where((order) => order.status == _filterStatus)
                .toList();
          }

          if (orders.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              if (index >= orders.length) return const SizedBox.shrink();
              final order = orders[index];
              return _buildOrderCard(order);
            },
          );
        },
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
            Icons.receipt_long_outlined,
            size: 80,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 24),
          Text(
            _filterStatus != null
                ? 'Aucune commande ${_filterStatus!.displayName.toLowerCase()}'
                : 'Aucune commande',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Les commandes apparaîtront ici',
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final isActive =
        order.status != OrderStatus.delivered &&
        order.status != OrderStatus.cancelled;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderHeader(order),
            const SizedBox(height: 12),
            _buildOrderItems(order),
            const SizedBox(height: 12),
            _buildOrderInfo(order),
            if (isActive) ...[
              const SizedBox(height: 16),
              _buildOrderActions(order),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader(Order order) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getStatusColor(context, order.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              order.status.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commande #${order.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _formatDateTime(order.orderTime),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(context, order.status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              order.status.displayName,
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItems(Order order) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${order.items.length} article${order.items.length > 1 ? 's' : ''} commandé${order.items.length > 1 ? 's' : ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...order.items.map(
          (item) {
            final customizations = item.getFormattedCustomizations();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.menuItemImage,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 32,
                            height: 32,
                            color: scheme.surfaceContainerHighest,
                            child: const Icon(Icons.fastfood, size: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.quantity}x ${item.menuItemName}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (customizations.isNotEmpty)
                              Text(
                                '${customizations.length} personnalisation(s)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          formatPrice(item.totalPrice),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  if (customizations.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: customizations.map((custom) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: scheme.tertiary.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            custom,
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: Row(
                        children: [
                          Icon(Icons.note, size: 12, color: scheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.notes!,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.primary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOrderInfo(Order order) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:'),
              Text(
                formatPrice(order.total),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.deliveryAddress,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (order.specialInstructions?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.note, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Note: ${order.specialInstructions}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                order.paymentMethod.emoji,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 4),
              Text(
                order.paymentMethod.displayName,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActions(Order order) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Annuler',
            Icons.cancel,
            scheme.error,
            () => _cancelOrder(order),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            _getNextActionText(order.status),
            _getNextActionIcon(order.status),
            Theme.of(context).colorScheme.primary,
            () => _advanceOrder(order),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _getNextActionText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Confirmer';
      case OrderStatus.confirmed:
        return 'Préparer';
      case OrderStatus.preparing:
        return 'Prêt';
      case OrderStatus.ready:
        return 'Assigner';
      case OrderStatus.pickedUp:
        return 'En route';
      case OrderStatus.onTheWay:
        return 'Livré';
      default:
        return 'Suivant';
    }
  }

  IconData _getNextActionIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.check;
      case OrderStatus.confirmed:
        return Icons.restaurant;
      case OrderStatus.preparing:
        return Icons.done_all;
      case OrderStatus.ready:
        return Icons.assignment_ind;
      case OrderStatus.pickedUp:
        return Icons.delivery_dining;
      case OrderStatus.onTheWay:
        return Icons.home;
      default:
        return Icons.arrow_forward;
    }
  }

  /// Afficher un dialog de confirmation avant de changer le statut
  Future<void> _showStatusChangeConfirmation({
    required Order order,
    required OrderStatus currentStatus,
    required OrderStatus newStatus,
    required OrderManagementService orderService,
    String? confirmationMessage,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    final confirmed = await DialogHelper.showSafeDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.tertiary, size: 28),
            const SizedBox(width: 8),
            const Text('Confirmer le changement'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  color: scheme.surfaceContainerHighest,
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
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Statut actuel: ${currentStatus.displayName}',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: sem.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nouveau statut: ${newStatus.displayName}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: sem.success,
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
        actions: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: sem.success,
                foregroundColor: scheme.onPrimary,
              ),
              child: const Text('Confirmer'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await orderService.updateOrderStatus(order.id, newStatus);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Statut changé: ${newStatus.displayName}'
                : '❌ Erreur lors du changement de statut',
          ),
          backgroundColor: scheme.inverseSurface,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _advanceOrder(Order order) {
    final orderService = Provider.of<OrderManagementService>(
      context,
      listen: false,
    );
    OrderStatus nextStatus;

    switch (order.status) {
      case OrderStatus.pending:
        nextStatus = OrderStatus.confirmed;
        break;
      case OrderStatus.confirmed:
        nextStatus = OrderStatus.preparing;
        break;
      case OrderStatus.preparing:
        nextStatus = OrderStatus.ready;
        break;
      case OrderStatus.ready:
        nextStatus = OrderStatus.pickedUp;
        break;
      case OrderStatus.pickedUp:
        nextStatus = OrderStatus.onTheWay;
        break;
      case OrderStatus.onTheWay:
        nextStatus = OrderStatus.delivered;
        break;
      default:
        return;
    }

    _showStatusChangeConfirmation(
      order: order,
      currentStatus: order.status,
      newStatus: nextStatus,
      orderService: orderService,
      confirmationMessage: _getStatusChangeMessage(order.status, nextStatus),
    );
  }

  String _getStatusChangeMessage(OrderStatus from, OrderStatus to) {
    switch (to) {
      case OrderStatus.confirmed:
        return 'Voulez-vous confirmer cette commande ?\n\nCette action valide la commande et commence le processus de préparation.';
      case OrderStatus.preparing:
        return 'Voulez-vous commencer la préparation de cette commande ?\n\nCette action indique que la cuisine commence à préparer les articles.';
      case OrderStatus.ready:
        return 'Voulez-vous marquer cette commande comme prête ?\n\nCette action indique que la commande est prête pour la livraison.';
      case OrderStatus.pickedUp:
        return 'Voulez-vous marquer cette commande comme récupérée ?\n\nCette action indique que le livreur a récupéré la commande.';
      case OrderStatus.onTheWay:
        return 'Voulez-vous marquer cette commande comme en route ?\n\nCette action indique que la commande est en cours de livraison.';
      case OrderStatus.delivered:
        return 'Voulez-vous marquer cette commande comme livrée ?\n\nCette action finalise la commande.';
      default:
        return 'Êtes-vous sûr de vouloir changer le statut de cette commande ?';
    }
  }

  void _cancelOrder(Order order) {
    final scheme = Theme.of(context).colorScheme;
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la commande'),
        content: Text(
          'Êtes-vous sûr de vouloir annuler la commande #${order.id.substring(0, 8).toUpperCase()}?',
        ),
        actions: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Non'),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: ElevatedButton(
              onPressed: () async {
                final orderService = Provider.of<OrderManagementService>(
                  context,
                  listen: false,
                );
                await orderService.cancelOrderStatus(order.id);
                if (!context.mounted) return;
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Commande #${order.id.substring(0, 8).toUpperCase()} annulée',
                    ),
                    backgroundColor: scheme.inverseSurface,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
              child: const Text('Annuler'),
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
      case OrderStatus.pending:
        return sem.warning;
      case OrderStatus.confirmed:
        return sem.info;
      case OrderStatus.preparing:
        return scheme.secondary;
      case OrderStatus.ready:
        return sem.success;
      case OrderStatus.pickedUp:
        return scheme.primary;
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Il y a ${difference.inMinutes}min';
      }
      return 'Il y a ${difference.inHours}h${difference.inMinutes % 60}min';
    } else if (difference.inDays == 1) {
      return 'Hier ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
