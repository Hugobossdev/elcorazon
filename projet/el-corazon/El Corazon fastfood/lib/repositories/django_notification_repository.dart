import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/services/push_notification_service.dart'
    show NotificationType, PushNotification;

/// Historique des notifications contre le backend Django (Phase 6).
///
/// Traduit `eccore.AppNotification` vers le `PushNotification` local déjà lu
/// par `notifications_screen.dart` et `notification_badge.dart`, sur le même
/// principe que `DjangoMenuRepository`.
class DjangoNotificationRepository {
  DjangoNotificationRepository()
    : _notifications = eccore.NotificationRepository(apiClient: apiClient);

  final eccore.NotificationRepository _notifications;

  Future<List<PushNotification>> getNotifications() async {
    final notifications = await _notifications.getNotifications();
    return notifications.map(_toLocal).toList();
  }

  Future<int> getUnreadCount() => _notifications.getUnreadCount();

  Future<PushNotification> markRead(String notificationId) async {
    return _toLocal(await _notifications.markRead(notificationId));
  }

  Future<void> markAllRead() => _notifications.markAllRead();

  PushNotification _toLocal(eccore.AppNotification notification) {
    return PushNotification(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      data: notification.data,
      type: _toLocalType(notification.kind),
      timestamp: notification.createdAt,
      isRead: notification.isRead,
    );
  }

  /// `NotificationKind` côté serveur ne compte que cinq valeurs, contre dix
  /// dans l'énumération locale. `achievement`, `challenge`, `reward`,
  /// `reminder` et `social` n'ont pas d'émetteur côté backend aujourd'hui :
  /// ce mapping ne les produira jamais.
  NotificationType _toLocalType(String kind) {
    switch (kind) {
      case 'order_status':
        return NotificationType.orderStatus;
      case 'delivery_offer':
        return NotificationType.delivery;
      case 'marketing':
        return NotificationType.promotion;
      case 'account':
      case 'payment':
        return NotificationType.system;
      default:
        return NotificationType.general;
    }
  }
}
