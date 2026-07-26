import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  // Web-compatible notification service without flutter_local_notifications

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  Future<void> initialize() async {
    // Web-compatible initialization
    debugPrint(
        'NotificationService: Initializing web-compatible notifications');
    _loadNotifications();
  }

  void _loadNotifications() {
    _notifications = [
      {
        'id': 1,
        'title': '🎉 Bienvenue chez El Corazón!',
        'message': 'Profitez de 20% de réduction sur votre première commande',
        'time': DateTime.now().subtract(const Duration(minutes: 5)),
        'type': 'promotion',
        'isRead': false,
        'icon': '🎁',
      },
      {
        'id': 2,
        'title': '⚡ Commande confirmée',
        'message': 'Votre commande #1234 est en préparation',
        'time': DateTime.now().subtract(const Duration(minutes: 15)),
        'type': 'order',
        'isRead': false,
        'icon': '🍔',
      },
      {
        'id': 3,
        'title': '🚗 Livraison en cours',
        'message': 'Votre livreur arrivera dans 10 minutes',
        'time': DateTime.now().subtract(const Duration(minutes: 25)),
        'type': 'delivery',
        'isRead': true,
        'icon': '🚚',
      },
    ];
    _updateUnreadCount();
  }

  Future<void> showOrderConfirmationNotification(
      String orderId, String items) async {
    // Web-compatible notification
    debugPrint('Notification: Commande confirmée #$orderId: $items');

    _addNotification(
      title: '✅ Commande confirmée',
      message: 'Commande #$orderId: $items',
      type: 'order',
      icon: '🍔',
    );
  }

  Future<void> showDeliveryUpdateNotification(
      String status, String orderId) async {
    String emoji = '';
    switch (status.toLowerCase()) {
      case 'en préparation':
        emoji = '👨‍🍳';
        break;
      case 'en route':
        emoji = '🚗';
        break;
      case 'livré':
        emoji = '🎉';
        break;
      default:
        emoji = '📦';
    }

    // Web-compatible notification
    debugPrint('Notification: $emoji $status - Commande #$orderId');

    _addNotification(
      title: '$emoji $status',
      message: 'Commande #$orderId - $status',
      type: 'delivery',
      icon: emoji,
    );
  }

  Future<void> showPromotionNotification(String title, String message) async {
    // Web-compatible notification
    debugPrint('Notification: 🎁 $title - $message');

    _addNotification(
      title: '🎁 $title',
      message: message,
      type: 'promotion',
      icon: '🎁',
    );
  }

  void _addNotification({
    required String title,
    required String message,
    required String type,
    required String icon,
  }) {
    _notifications.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch,
      'title': title,
      'message': message,
      'time': DateTime.now(),
      'type': type,
      'isRead': false,
      'icon': icon,
    });
    _updateUnreadCount();
    notifyListeners();
  }

  void markAsRead(int notificationId) {
    final index = _notifications.indexWhere((n) => n['id'] == notificationId);
    if (index != -1) {
      _notifications[index]['isRead'] = true;
      _updateUnreadCount();
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var notification in _notifications) {
      notification['isRead'] = true;
    }
    _updateUnreadCount();
    notifyListeners();
  }

  void deleteNotification(int notificationId) {
    _notifications.removeWhere((n) => n['id'] == notificationId);
    _updateUnreadCount();
    notifyListeners();
  }

  void clearAllNotifications() {
    _notifications.clear();
    _updateUnreadCount();
    notifyListeners();
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n['isRead']).length;
  }

  // Planifier des notifications de rappel
  Future<void> scheduleOrderReminderNotification(String orderId) async {
    // Notification de rappel simplifiée pour le moment
    Future.delayed(const Duration(minutes: 30), () {
      showOrderConfirmationNotification(
          orderId, 'N\'oubliez pas votre commande!');
    });
  }

  /// S'abonner aux notifications en temps réel depuis Supabase
  void subscribeToRealtimeNotifications(Function(Map<String, dynamic>) onNotification) {
    try {
      _supabase
          .channel('admin_notifications')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            callback: (payload) {
              final notification = payload.newRecord;
              _addNotification(
                title: notification['title']?.toString() ?? 'Notification',
                message: notification['message']?.toString() ?? '',
                type: notification['type']?.toString() ?? 'info',
                icon: _getIconForType(notification['type']?.toString() ?? 'info'),
              );
              onNotification(notification);
            },
          )
          .subscribe();
      
      debugPrint('✅ Abonnement aux notifications en temps réel activé');
    } catch (e) {
      debugPrint('❌ Erreur abonnement notifications: $e');
    }
  }

  String _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return '🍔';
      case 'delivery':
        return '🚚';
      case 'promotion':
        return '🎁';
      case 'alert':
        return '⚠️';
      case 'success':
        return '✅';
      default:
        return '📢';
    }
  }

  /// Charger les notifications depuis la base de données
  Future<void> loadNotificationsFromDatabase({String? userId}) async {
    try {
      var query = _supabase
          .from('notifications')
          .select();

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(50);

      _notifications = (response as List).map((data) {
        return {
          'id': data['id'],
          'title': data['title']?.toString() ?? 'Notification',
          'message': data['message']?.toString() ?? '',
          'time': data['created_at'] != null 
              ? DateTime.parse(data['created_at'])
              : DateTime.now(),
          'type': data['type']?.toString() ?? 'info',
          'isRead': data['is_read'] ?? false,
          'icon': _getIconForType(data['type']?.toString() ?? 'info'),
        };
      }).toList();

      _updateUnreadCount();
      notifyListeners();
      
      debugPrint('✅ ${_notifications.length} notifications chargées depuis la base de données');
    } catch (e) {
      debugPrint('❌ Erreur chargement notifications: $e');
    }
  }
}
