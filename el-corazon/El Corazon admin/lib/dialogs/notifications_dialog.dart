import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/app_service.dart';
import 'package:provider/provider.dart';
import '../utils/price_formatter.dart';
import '../ui/admin_color_tokens.dart';

class NotificationsDialog extends StatefulWidget {
  const NotificationsDialog({super.key});

  @override
  State<NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<NotificationsDialog> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 600.0);
    final dialogHeight = (screenSize.height * 0.8).clamp(400.0, 700.0);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  // IMPORTANT: Material + InkWell + Container avec taille explicite pour éviter l'erreur de hit testing
                  Material(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Contenu - Liste des notifications
            Expanded(
              child: Consumer<AppService>(
                builder: (context, appService, child) {
                  final notifications = _getNotifications(appService);

                  if (notifications.isEmpty) {
                    final scheme = Theme.of(context).colorScheme;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off,
                            size: 64,
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.55),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune notification',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vous serez notifié des nouvelles commandes et événements',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationItem(context, notification);
                    },
                  );
                },
              ),
            ),
            // Footer avec actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                    ),
                    child: TextButton.icon(
                      onPressed: () {
                        // Marquer toutes comme lues
                      },
                      icon: const Icon(Icons.done_all),
                      label: const Text('Tout marquer comme lu'),
                    ),
                  ),
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
    );
  }

  List<Map<String, dynamic>> _getNotifications(AppService appService) {
    final allOrders = appService.allOrders;
    final pendingOrders = appService.pendingOrders;
    final recentOrders = allOrders.take(5).toList();

    final notifications = <Map<String, dynamic>>[];

    // Notifications pour commandes en attente
    if (pendingOrders.isNotEmpty) {
      notifications.add({
        'id': 'pending_orders',
        'title': '⚠️ Commandes en attente',
        'message':
            '${pendingOrders.length} commande(s) nécessitent votre attention',
        'time': DateTime.now(),
        'type': 'warning',
        'icon': Icons.pending,
        'color': 'warning',
        'action': () {
          // Naviguer vers la gestion des commandes
        },
      });
    }

    // Notifications pour commandes récentes
    for (final order in recentOrders.take(3)) {
      notifications.add({
        'id': 'order_${order.id}',
        'title': '📦 Nouvelle commande',
        'message':
            'Commande #${order.id.substring(0, 8).toUpperCase()} - ${PriceFormatter.format(order.total)}',
        'time': order.orderTime,
        'type': 'order',
        'icon': Icons.shopping_cart,
        'color': 'info',
        'action': () {
          // Afficher les détails de la commande
        },
      });
    }

    return notifications;
  }

  Widget _buildNotificationItem(
      BuildContext context, Map<String, dynamic> notification) {
    final timeAgo = _formatTimeAgo(notification['time'] as DateTime);
    final icon = notification['icon'] as IconData;
    final scheme = Theme.of(context).colorScheme;
    final tokens = AdminColorTokens.semantic(scheme);
    final colorKey = notification['color'];
    final Color color = switch (colorKey) {
      'warning' => tokens.warning,
      'danger' => tokens.danger,
      'success' => tokens.success,
      'info' => tokens.info,
      _ => scheme.primary,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 56,
        ),
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            notification['title'] as String,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification['message'] as String,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeAgo,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
          onTap: () {
            final action = notification['action'] as VoidCallback?;
            if (action != null) {
              Navigator.of(context).pop();
              action();
            }
          },
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }
}
