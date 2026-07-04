import 'package:flutter/material.dart';
import '../models/order.dart';
import 'package:intl/intl.dart';

class OrderTimelineWidget extends StatelessWidget {
  final Order order;

  const OrderTimelineWidget({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final timelineEvents = _buildTimelineEvents();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Timeline de la commande',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...timelineEvents.asMap().entries.map((entry) {
              final index = entry.key;
              final event = entry.value;
              final isLast = index == timelineEvents.length - 1;

              return _buildTimelineItem(
                context,
                event: event,
                isLast: isLast,
                isActive: index == 0 ||
                    (index == 1 && order.status == event['status']),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildTimelineEvents() {
    final events = <Map<String, dynamic>>[];

    // Événements par statut
    if (order.statusUpdates.isNotEmpty) {
      for (final update in order.statusUpdates) {
        events.add({
          'status': update.status,
          'timestamp': update.timestamp,
          'note': update.message ?? update.status.displayName,
        });
      }
    } else {
      // Timeline par défaut basée sur le statut actuel
      events.add({
        'status': OrderStatus.pending,
        'timestamp': order.createdAt,
        'note': 'Commande créée',
      });

      if (order.status.index > OrderStatus.pending.index) {
        events.add({
          'status': OrderStatus.confirmed,
          'timestamp': order.orderTime,
          'note': 'Commande confirmée',
        });
      }

      if (order.status.index > OrderStatus.confirmed.index) {
        events.add({
          'status': OrderStatus.preparing,
          'timestamp': order.orderTime.add(const Duration(minutes: 5)),
          'note': 'En préparation',
        });
      }

      if (order.status.index > OrderStatus.preparing.index) {
        events.add({
          'status': OrderStatus.ready,
          'timestamp': order.orderTime.add(const Duration(minutes: 15)),
          'note': 'Prête pour la livraison',
        });
      }

      if (order.deliveryPersonId != null) {
        events.add({
          'status': OrderStatus.pickedUp,
          'timestamp': order.orderTime.add(const Duration(minutes: 20)),
          'note': 'Livreur assigné et récupéré',
        });
      }

      if (order.status == OrderStatus.onTheWay ||
          order.status == OrderStatus.delivered) {
        events.add({
          'status': OrderStatus.onTheWay,
          'timestamp': order.orderTime.add(const Duration(minutes: 25)),
          'note': 'En route vers le client',
        });
      }

      if (order.status == OrderStatus.delivered) {
        events.add({
          'status': OrderStatus.delivered,
          'timestamp': order.orderTime.add(const Duration(minutes: 30)),
          'note': 'Livrée avec succès',
        });
      }

      if (order.status == OrderStatus.cancelled) {
        events.add({
          'status': OrderStatus.cancelled,
          'timestamp': order.orderTime.add(const Duration(minutes: 10)),
          'note': 'Commande annulée',
        });
      }

      if (order.status == OrderStatus.refunded) {
        events.add({
          'status': OrderStatus.refunded,
          'timestamp': order.orderTime.add(const Duration(hours: 1)),
          'note': 'Remboursement effectué',
        });
      }
    }

    // Trier par timestamp (plus récent en premier)
    events.sort((a, b) => (b['timestamp'] as DateTime)
        .compareTo(a['timestamp'] as DateTime));

    return events;
  }

  Widget _buildTimelineItem(
    BuildContext context, {
    required Map<String, dynamic> event,
    required bool isLast,
    required bool isActive,
  }) {
    final status = event['status'] as OrderStatus;
    final timestamp = event['timestamp'] as DateTime;
    final note = event['note'] as String?;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne verticale et icône
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300],
                  border: Border.all(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: Icon(
                  _getStatusIcon(status),
                  size: 16,
                  color: isActive
                      ? Theme.of(context).colorScheme.onPrimary
                      : Colors.grey[600],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Contenu
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note ?? status.displayName,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (isActive && status != OrderStatus.delivered &&
                    status != OrderStatus.cancelled &&
                    status != OrderStatus.refunded)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'En cours',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return Icons.check_circle_outline;
      case OrderStatus.pickedUp:
        return Icons.shopping_bag;
      case OrderStatus.onTheWay:
        return Icons.directions_bike;
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.refunded:
        return Icons.payment;
      case OrderStatus.failed:
        return Icons.error;
    }
  }
}


