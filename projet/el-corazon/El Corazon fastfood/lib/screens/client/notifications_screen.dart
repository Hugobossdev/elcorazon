import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/notification_database_service.dart';
import 'package:elcora_fast/models/notification_model.dart';
import 'package:elcora_fast/theme.dart';
// import '../../widgets/enhanced_animations.dart'; // Supprimé
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'dart:convert';

/// Écran des notifications
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  NotificationType? _selectedFilter;
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotifications());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final appService = Provider.of<AppService>(context, listen: false);
    final notificationService =
        Provider.of<NotificationDatabaseService>(context, listen: false);

    final user = appService.currentUser;
    if (user == null) {
      return;
    }

    await notificationService.loadNotifications(user.id);
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all),
                    SizedBox(width: 8),
                    Text('Tout marquer comme lu'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep),
                    SizedBox(width: 8),
                    Text('Tout supprimer'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications, size: 20),
                  SizedBox(width: 8),
                  Text('Toutes'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mark_email_unread, size: 20),
                  SizedBox(width: 8),
                  Text('Non lues'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationsList(false),
                _buildNotificationsList(true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Switch(
                value: _showUnreadOnly,
                onChanged: (value) {
                  setState(() {
                    _showUnreadOnly = value;
                  });
                },
                activeThumbColor: AppColors.primary,
              ),
              const Text(
                'Non lues seulement',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: NotificationType.values.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildFilterChip(
                    null,
                    'Tous',
                    Icons.notifications,
                    _selectedFilter == null,
                  );
                }
                final type = NotificationType.values[index - 1];
                return _buildFilterChip(
                  type,
                  _getTypeLabel(type),
                  _getTypeIcon(type),
                  _selectedFilter == type,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    NotificationType? type,
    String label,
    IconData icon,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = isSelected ? null : type;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsList(bool unreadOnly) {
    return Consumer<NotificationDatabaseService>(
      builder: (context, notificationService, child) {
        if (notificationService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Convertir PushNotification en NotificationModel
        final pushNotifications = unreadOnly
            ? notificationService.getUnreadNotifications()
            : notificationService.notifications;

        final filteredPushNotifications = pushNotifications.where((pn) {
          // Ignorer les notifications sans ID valide (UUID)
          return _isValidUuid(pn.id);
        }).toList();

        List<NotificationModel> notifications =
            filteredPushNotifications.map((pn) {
          return NotificationModel(
            id: pn.id.hashCode,
            title: pn.title,
            body: pn.body,
            type: _mapNotificationType(pn.type.name),
            priority: NotificationPriority.normal,
            payload: pn.data.toString(),
            createdAt: pn.timestamp,
            isRead: pn.isRead,
            backendId: pn.id,
          );
        }).toList();

        // Appliquer les filtres
        if (_selectedFilter != null) {
          notifications =
              notifications.where((n) => n.type == _selectedFilter).toList();
        }

        if (_showUnreadOnly && !unreadOnly) {
          notifications = notifications.where((n) => !n.isRead).toList();
        }

        // Trier par date (plus récentes en premier)
        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (notifications.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshNotifications,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 40),
                _buildEmptyState(unreadOnly),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshNotifications,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(notification, notificationService);
            },
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(
    NotificationModel notification,
    NotificationDatabaseService service,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DesignEnhancementService.createEnhancedCard(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getTypeColor(notification.type).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getTypeIcon(notification.type),
              color: _getTypeColor(notification.type),
              size: 24,
            ),
          ),
          title: Text(
            notification.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  notification.isRead ? FontWeight.normal : FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.body,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(notification.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                  const Spacer(),
                  if (!notification.isRead)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Nouveau',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) =>
                _handleNotificationAction(value, notification, service),
            itemBuilder: (context) => [
              if (!notification.isRead)
                const PopupMenuItem(
                  value: 'mark_read',
                  child: Row(
                    children: [
                      Icon(Icons.done),
                      SizedBox(width: 8),
                      Text('Marquer comme lu'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete),
                    SizedBox(width: 8),
                    Text('Supprimer'),
                  ],
                ),
              ),
            ],
          ),
          onTap: () {
            if (!notification.isRead) {
              final backendId = notification.backendId;
              if (backendId != null && _isValidUuid(backendId)) {
                service.markAsRead(backendId);
              }
            }
            _navigateBasedOnNotification(notification);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool unreadOnly) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            unreadOnly ? Icons.mark_email_read : Icons.notifications_none,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 20),
          Text(
            unreadOnly ? 'Aucune notification non lue' : 'Aucune notification',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            unreadOnly
                ? 'Vous êtes à jour !'
                : 'Vous recevrez des notifications ici',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  NotificationType _mapNotificationType(String type) {
    switch (type.toLowerCase()) {
      case 'order':
      case 'orderstatus':
        return NotificationType.order;
      case 'promotion':
        return NotificationType.promotion;
      case 'system':
        return NotificationType.system;
      case 'delivery':
        return NotificationType.delivery;
      case 'general':
        return NotificationType.general;
      default:
        return NotificationType.general;
    }
  }

  void _handleMenuAction(String action) {
    final service =
        Provider.of<NotificationDatabaseService>(context, listen: false);

    switch (action) {
      case 'mark_all_read':
        service.markAllAsRead();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les notifications marquées comme lues'),
            backgroundColor: AppColors.primary,
          ),
        );
        break;
      case 'delete_all':
        _showDeleteAllDialog(service);
        break;
    }
  }

  void _handleNotificationAction(
    String action,
    NotificationModel notification,
    NotificationDatabaseService service,
  ) {
    switch (action) {
      case 'mark_read':
        final backendId = notification.backendId;
        if (backendId != null && _isValidUuid(backendId)) {
          service.markAsRead(backendId);
        }
        break;
      case 'delete':
        final backendId = notification.backendId;
        if (backendId != null && _isValidUuid(backendId)) {
          service.deleteNotification(backendId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification supprimée'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
        break;
    }
  }

  void _showDeleteAllDialog(NotificationDatabaseService service) {
    context.showEnhancedDialog(
      title: 'Supprimer toutes les notifications',
      content:
          'Êtes-vous sûr de vouloir supprimer toutes les notifications ? Cette action est irréversible.',
      confirmText: 'Supprimer',
      cancelText: 'Annuler',
      isDestructive: true,
      onConfirm: () {
        service.deleteAllNotifications();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les notifications supprimées'),
            backgroundColor: AppColors.primary,
          ),
        );
      },
    );
  }

  String _getTypeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.general:
        return 'Général';
      case NotificationType.order:
        return 'Commande';
      case NotificationType.delivery:
        return 'Livraison';
      case NotificationType.promotion:
        return 'Promotion';
      case NotificationType.reminder:
        return 'Rappel';
      case NotificationType.reward:
        return 'Récompense';
      case NotificationType.system:
        return 'Système';
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.general:
        return Icons.notifications;
      case NotificationType.order:
        return Icons.shopping_bag;
      case NotificationType.delivery:
        return Icons.delivery_dining;
      case NotificationType.promotion:
        return Icons.local_offer;
      case NotificationType.reminder:
        return Icons.alarm;
      case NotificationType.reward:
        return Icons.stars;
      case NotificationType.system:
        return Icons.settings;
    }
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.general:
        return Colors.blue;
      case NotificationType.order:
        return Colors.green;
      case NotificationType.delivery:
        return Colors.orange;
      case NotificationType.promotion:
        return Colors.purple;
      case NotificationType.reminder:
        return Colors.amber;
      case NotificationType.reward:
        return Colors.pink;
      case NotificationType.system:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'Maintenant';
    }
  }

  bool _isValidUuid(String value) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return value.isNotEmpty && uuidRegex.hasMatch(value);
  }

  /// Navigue vers la page appropriée selon le type et le payload de la notification
  void _navigateBasedOnNotification(NotificationModel notification) {
    try {
      // Parser le payload si disponible
      Map<String, dynamic>? payloadData;
      if (notification.payload != null && notification.payload!.isNotEmpty) {
        try {
          payloadData = jsonDecode(notification.payload!);
        } catch (e) {
          // Si le payload n'est pas du JSON, essayer de l'interpréter comme une Map
          debugPrint('Notification payload parsing error: $e');
        }
      }

      // Navigation basée sur le type de notification
      switch (notification.type) {
        case NotificationType.order:
          // Naviguer vers les détails de la commande si orderId est disponible
          final orderId = payloadData?['orderId'] as String?;
          if (orderId != null && orderId.isNotEmpty) {
            Navigator.of(context).pushNamed(
              AppRouter.deliveryTracking,
              arguments: {'orderId': orderId},
            );
          } else {
            // Sinon, naviguer vers la liste des commandes
            Navigator.of(context).pushNamed(AppRouter.orders);
          }
          break;

        case NotificationType.delivery:
          // Naviguer vers le suivi de livraison
          final orderId = payloadData?['orderId'] as String?;
          if (orderId != null && orderId.isNotEmpty) {
            Navigator.of(context).pushNamed(
              AppRouter.deliveryTracking,
              arguments: {'orderId': orderId},
            );
          } else {
            Navigator.of(context).pushNamed(AppRouter.orders);
          }
          break;

        case NotificationType.promotion:
          // Naviguer vers les codes promo ou le menu
          final promoCode = payloadData?['promoCode'] as String?;
          if (promoCode != null && promoCode.isNotEmpty) {
            Navigator.of(context).pushNamed(
              AppRouter.promoCodes,
              arguments: {
                'orderAmount': 0.0,
                'onPromoCodeApplied': (_, __) {},
              },
            );
          } else {
            Navigator.of(context).pushNamed(AppRouter.menu);
          }
          break;

        case NotificationType.reward:
          // Naviguer vers les récompenses
          Navigator.of(context).pushNamed(AppRouter.rewards);
          break;

        case NotificationType.reminder:
          // Naviguer vers les commandes si orderId est disponible
          final orderId = payloadData?['orderId'] as String?;
          if (orderId != null && orderId.isNotEmpty) {
            Navigator.of(context).pushNamed(
              AppRouter.deliveryTracking,
              arguments: {'orderId': orderId},
            );
          } else {
            Navigator.of(context).pushNamed(AppRouter.orders);
          }
          break;

        case NotificationType.general:
        case NotificationType.system:
          // Pour les notifications générales, ne rien faire ou rester sur la page
          break;
      }
    } catch (e) {
      debugPrint('Error navigating from notification: $e');
    }
  }
}
