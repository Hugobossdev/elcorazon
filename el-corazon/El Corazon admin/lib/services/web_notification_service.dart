import 'package:flutter/foundation.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;
  final List<Map<String, dynamic>> _notifications = [];

  bool get isInitialized => _isInitialized;
  List<Map<String, dynamic>> get notifications =>
      List.unmodifiable(_notifications);

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Web-compatible notification initialization
      _isInitialized = true;
      notifyListeners();
      debugPrint('Web: Notification service initialized');
    } catch (e) {
      debugPrint('Error initializing Notification Service: $e');
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      Map<String, dynamic> notification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'body': body,
        'payload': payload,
        'timestamp': DateTime.now(),
        'isRead': false,
      };

      _notifications.insert(0, notification);
      notifyListeners();

      debugPrint('Web Notification: $title - $body');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    // Web doesn't support scheduled notifications
    await showNotification(title: title, body: body, payload: payload);
  }

  void markAsRead(String notificationId) {
    int index = _notifications.indexWhere((n) => n['id'] == notificationId);
    if (index != -1) {
      _notifications[index]['isRead'] = true;
      notifyListeners();
    }
  }

  void clearAllNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  int get unreadCount => _notifications.where((n) => !n['isRead']).length;
}
