import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isInitialized = false;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response);
      },
    );

    _loadNotifications();
    _isInitialized = true;
    notifyListeners();
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
      String orderId, String items,) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'order_channel',
      'Commandes',
      channelDescription: 'Notifications pour les commandes',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '✅ Commande confirmée',
      'Commande #$orderId: $items',
      notificationDetails,
    );

    _addNotification(
      title: '✅ Commande confirmée',
      message: 'Commande #$orderId: $items',
      type: 'order',
      icon: '🍔',
    );
  }

  Future<void> showDeliveryUpdateNotification(
      String status, String orderId,) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'delivery_channel',
      'Livraisons',
      channelDescription: 'Notifications pour les livraisons',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

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

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '$emoji $status',
      'Commande #$orderId - $status',
      notificationDetails,
    );

    _addNotification(
      title: '$emoji $status',
      message: 'Commande #$orderId - $status',
      type: 'delivery',
      icon: emoji,
    );
  }

  Future<void> showPromotionNotification(String title, String message) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'promotion_channel',
      'Promotions',
      channelDescription: 'Notifications pour les promotions',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '🎁 $title',
      message,
      notificationDetails,
    );

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
    for (final notification in _notifications) {
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

  void _handleNotificationTap(NotificationResponse response) {
    // Gérer l'action quand l'utilisateur tape sur une notification
    debugPrint('Notification tapped: ${response.payload}');
  }

  // Planifier des notifications de rappel
  Future<void> scheduleOrderReminderNotification(String orderId) async {
    // Notification de rappel simplifiée pour le moment
    Future.delayed(const Duration(minutes: 30), () {
      showOrderConfirmationNotification(
          orderId, 'N\'oubliez pas votre commande!',);
    });
  }
}
