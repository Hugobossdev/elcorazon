import 'package:flutter/material.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/widgets/custom_button.dart';
import 'package:elcora_fast/widgets/loading_widget.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/utils/price_formatter.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({
    required this.order, super.key,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Commande #${widget.order.id}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _shareOrder,
            icon: const Icon(Icons.share),
            tooltip: 'Partager',
          ),
        ],
      ),
      body: OverlayLoadingWidget(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status card
              _buildStatusCard(),
              const SizedBox(height: 16),

              // Timeline
              _buildTimeline(),
              const SizedBox(height: 16),

              // Order items
              _buildOrderItems(),
              const SizedBox(height: 16),

              // Delivery information
              if (widget.order.deliveryAddress.isNotEmpty) _buildDeliveryInfo(),
              const SizedBox(height: 16),

              // Payment information
              _buildPaymentInfo(),
              const SizedBox(height: 16),

              // Actions
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final theme = Theme.of(context);

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
              _getStatusColor(widget.order.status.displayName),
              _getStatusColor(widget.order.status.displayName)
                  .withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Column(
          children: [
            Icon(
              _getStatusIcon(widget.order.status.displayName),
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              _getStatusText(widget.order.status.displayName),
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getStatusDescription(widget.order.status.displayName),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Commande passée le ${_formatDate(widget.order.orderTime)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final theme = Theme.of(context);
    final steps = _getOrderSteps();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suivi de commande',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isLast = index == steps.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline indicator
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: step['completed']
                              ? theme.primaryColor
                              : theme.colorScheme.outline
                                  .withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          step['completed'] ? Icons.check : Icons.circle,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 40,
                          color: step['completed']
                              ? theme.primaryColor
                              : theme.colorScheme.outline
                                  .withValues(alpha: 0.3),
                        ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // Step content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['title'],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: step['completed']
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: step['completed']
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                          ),
                        ),
                        if (step['time'] != null)
                          Text(
                            step['time'],
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems() {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Articles commandés',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ...widget.order.items.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.restaurant),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.menuItemName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Quantité: ${item.quantity}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        PriceFormatter.format(item.totalPrice),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),),

            const Divider(),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  PriceFormatter.format(widget.order.total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Adresse de livraison',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.order.deliveryAddress,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (widget.order.status == OrderStatus.onTheWay)
              CustomButton(
                text: 'Suivre le livreur',
                onPressed: () {
                  // Navigate to live tracking
                  Navigator.pushNamed(
                    context,
                    AppRouter.deliveryTracking,
                    arguments: {'orderId': widget.order.id},
                  );
                },
                icon: Icons.map,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfo() {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payment,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Paiement',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mode de paiement'),
                Text(widget.order.paymentMethod.displayName),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Statut'),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Payé',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
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

  Widget _buildActions() {
    final theme = Theme.of(context);

    return Column(
      children: [
        if (widget.order.status == OrderStatus.pending) ...[
          CustomButton(
            text: 'Annuler la commande',
            onPressed: _cancelOrder,
            backgroundColor: theme.colorScheme.error,
            icon: Icons.cancel,
          ),
          const SizedBox(height: 12),
        ],
        CustomButton(
          text: 'Contacter le support',
          onPressed: _contactSupport,
          outlined: true,
          icon: Icons.support_agent,
        ),
        const SizedBox(height: 12),
        CustomButton(
          text: 'Renouveler la commande',
          onPressed: _reorderItems,
          outlined: true,
          icon: Icons.refresh,
        ),
      ],
    );
  }

  void _shareOrder() {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Partage de la commande...')),
    );
  }

  void _cancelOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la commande'),
        content:
            const Text('Êtes-vous sûr de vouloir annuler cette commande ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement cancellation logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Commande annulée'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }

  void _contactSupport() {
    // Implement support contact
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ouverture du chat support...')),
    );
  }

  void _reorderItems() {
    // Implement reorder functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Articles ajoutés au panier')),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'en_attente':
        return Colors.orange;
      case 'confirmed':
      case 'confirmé':
        return Colors.blue;
      case 'preparing':
      case 'en_preparation':
        return Colors.purple;
      case 'ready':
      case 'prêt':
        return Colors.green;
      case 'delivering':
      case 'en_livraison':
        return Colors.teal;
      case 'delivered':
      case 'livré':
        return Colors.green;
      case 'cancelled':
      case 'annulé':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'en_attente':
        return Icons.hourglass_empty;
      case 'confirmed':
      case 'confirmé':
        return Icons.check_circle;
      case 'preparing':
      case 'en_preparation':
        return Icons.restaurant;
      case 'ready':
      case 'prêt':
        return Icons.done_all;
      case 'delivering':
      case 'en_livraison':
        return Icons.delivery_dining;
      case 'delivered':
      case 'livré':
        return Icons.check_circle;
      case 'cancelled':
      case 'annulé':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'en_attente':
        return 'En attente';
      case 'confirmed':
      case 'confirmé':
        return 'Confirmée';
      case 'preparing':
      case 'en_preparation':
        return 'En préparation';
      case 'ready':
      case 'prêt':
      case 'prête':
        return 'Prête';
      case 'picked_up':
      case 'pickedup':
      case 'récupérée':
        return 'Récupérée';
      case 'on_the_way':
      case 'ontheway':
      case 'delivering':
      case 'en_livraison':
        return 'En livraison';
      case 'delivered':
      case 'livré':
      case 'livrée':
        return 'Livrée';
      case 'cancelled':
      case 'annulé':
      case 'annulée':
        return 'Annulée';
      default:
        return status;
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'en_attente':
        return 'Nous traitons votre commande';
      case 'confirmed':
      case 'confirmé':
        return 'Votre commande a été confirmée';
      case 'preparing':
      case 'en_preparation':
        return 'Nos chefs préparent votre commande';
      case 'ready':
      case 'prêt':
        return 'Votre commande est prête';
      case 'delivering':
      case 'en_livraison':
        return 'Notre livreur est en route';
      case 'delivered':
      case 'livré':
        return 'Votre commande a été livrée';
      case 'cancelled':
      case 'annulé':
        return 'Cette commande a été annulée';
      default:
        return 'Statut de la commande';
    }
  }

  List<Map<String, dynamic>> _getOrderSteps() {
    final currentStatus = widget.order.status;

    return [
      {
        'title': 'Commande passée',
        'completed': true,
        'time': _formatTime(widget.order.orderTime),
      },
      {
        'title': 'Commande confirmée',
        'completed': _isStatusCompleted(OrderStatus.confirmed, currentStatus),
        'time': _isStatusCompleted(OrderStatus.confirmed, currentStatus)
            ? '5 min'
            : null,
      },
      {
        'title': 'En préparation',
        'completed': _isStatusCompleted(OrderStatus.preparing, currentStatus),
        'time': _isStatusCompleted(OrderStatus.preparing, currentStatus)
            ? '15 min'
            : null,
      },
      {
        'title': 'Prête',
        'completed': _isStatusCompleted(OrderStatus.ready, currentStatus),
        'time': _isStatusCompleted(OrderStatus.ready, currentStatus)
            ? '25 min'
            : null,
      },
      {
        'title': 'En livraison',
        'completed': _isStatusCompleted(OrderStatus.onTheWay, currentStatus),
        'time': _isStatusCompleted(OrderStatus.onTheWay, currentStatus)
            ? '35 min'
            : null,
      },
      {
        'title': 'Livrée',
        'completed': _isStatusCompleted(OrderStatus.delivered, currentStatus),
        'time': _isStatusCompleted(OrderStatus.delivered, currentStatus)
            ? '45 min'
            : null,
      },
    ];
  }

  bool _isStatusCompleted(OrderStatus stepStatus, OrderStatus currentStatus) {
    const statusOrder = [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.onTheWay,
      OrderStatus.delivered,
    ];

    final stepIndex = statusOrder.indexOf(stepStatus);
    final currentIndex = statusOrder.indexOf(currentStatus);

    return currentIndex >= stepIndex;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
