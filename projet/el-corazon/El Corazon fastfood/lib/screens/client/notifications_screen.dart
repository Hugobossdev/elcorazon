import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/notification_database_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/genre_notification.dart';
import 'package:elcora_fast/theme.dart';
// import '../../widgets/enhanced_animations.dart'; // Supprimé
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/navigation/app_router.dart';

/// Écran des notifications
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  GenreNotification? _selectedFilter;
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
    // Plus de garde sur l'utilisateur courant : la requête part avec le jeton
    // de session et le serveur cloisonne lui-même l'historique.
    await Provider.of<NotificationDatabaseService>(context, listen: false)
        .loadNotifications();
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
              // « Tout supprimer » retiré : le contrat n'expose que la lecture
              // et le marquage. Le serveur décide seul de la durée de vie d'une
              // notification.
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
              itemCount: GenreNotification.values.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildFilterChip(
                    null,
                    'Tous',
                    Icons.notifications,
                    _selectedFilter == null,
                  );
                }
                final type = GenreNotification.values[index - 1];
                return _buildFilterChip(
                  type,
                  type.libelle,
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
    GenreNotification? type,
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

        // L'écran lisait ces notifications au travers de deux traductions
        // successives, dont la seconde remplaçait l'identifiant du serveur par
        // un `hashCode` avant de le ranger à côté sous un autre nom.
        var notifications = unreadOnly
            ? notificationService.getUnreadNotifications()
            : notificationService.notifications;

        if (_selectedFilter != null) {
          notifications =
              notifications.where((n) => n.genre == _selectedFilter).toList();
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
    eccore.AppNotification notification,
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
              color: _getTypeColor(notification.genre).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getTypeIcon(notification.genre),
              color: _getTypeColor(notification.genre),
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
            ],
          ),
          onTap: () {
            if (!notification.isRead) {
              service.markAsRead(notification.id);
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
    }
  }

  void _handleNotificationAction(
    String action,
    eccore.AppNotification notification,
    NotificationDatabaseService service,
  ) {
    switch (action) {
      case 'mark_read':
        service.markAsRead(notification.id);
        break;
    }
  }


  IconData _getTypeIcon(GenreNotification type) {
    switch (type) {
      case GenreNotification.commande:
        return Icons.shopping_bag;
      case GenreNotification.livraison:
        return Icons.delivery_dining;
      case GenreNotification.paiement:
        return Icons.payment;
      case GenreNotification.compte:
        return Icons.person;
      case GenreNotification.promotion:
        return Icons.local_offer;
    }
  }

  Color _getTypeColor(GenreNotification type) {
    switch (type) {
      case GenreNotification.commande:
        return Colors.green;
      case GenreNotification.livraison:
        return Colors.orange;
      case GenreNotification.paiement:
        return Colors.blue;
      case GenreNotification.compte:
        return Colors.grey;
      case GenreNotification.promotion:
        return Colors.purple;
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

  /// Ouvre l'écran que la notification désigne.
  ///
  /// Deux choses empechaient cette navigation d'aboutir, et aucune ne se
  /// voyait : la charge utile arrivait ici sous forme de `Map.toString()`, que
  /// `jsonDecode` refusait à chaque fois ; et la clé cherchée était `orderId`
  /// la ou le serveur ecrit `order`. Elle lit maintenant `data` directement.
  void _navigateBasedOnNotification(eccore.AppNotification notification) {
    final commande = notification.commandeVisee;

    switch (notification.genre) {
      case GenreNotification.commande:
      case GenreNotification.livraison:
        Navigator.of(context).pushNamed(
          commande == null ? AppRouter.orders : AppRouter.deliveryTracking,
          arguments: commande == null ? null : {'orderId': commande},
        );
      case GenreNotification.promotion:
        Navigator.of(context).pushNamed(AppRouter.menu);
      case GenreNotification.paiement:
      case GenreNotification.compte:
        // Rien à ouvrir : ces notifications se lisent, elles ne menent pas
        // ailleurs.
        break;
    }
  }
}
