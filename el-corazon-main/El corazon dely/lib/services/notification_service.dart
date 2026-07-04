import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

// Background message handler must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Handling a background message: ${message.messageId}');
}

class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // Firebase Messaging instance
  late final FirebaseMessaging _firebaseMessaging;

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  String? _fcmToken;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    // Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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
    
    // Initialize Firebase
    try {
      // Assuming Firebase is already initialized in main.dart, but strictly safer to check or just use instance
      // If we initialized in main, accessing instance here is safe.
      _firebaseMessaging = FirebaseMessaging.instance;

      // Set background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Request permission
      await _requestPermission();
      
      // Get token
      await _getToken();
      
      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          
          // Show local notification
          showNotification(
            title: message.notification!.title ?? 'Notification',
            body: message.notification!.body ?? '',
            channelId: 'firebase_channel',
            channelName: 'Firebase Notifications',
          );
        }
      });
      
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }

    _loadNotifications();
  }
  
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');
  }
  
  Future<void> _getToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $_fcmToken');
      // Here you would typically send the token to your backend
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
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
      String status, String orderId) async {
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

  /// Méthode générique pour afficher une notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? channelId,
    String? channelName,
    String? channelDescription,
  }) async {
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      channelId ?? 'general_channel',
      channelName ?? 'Notifications générales',
      channelDescription: channelDescription ?? 'Notifications générales de l\'application',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
    );

    _addNotification(
      title: title,
      message: body,
      type: 'general',
      icon: '🔔',
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

  void _handleNotificationTap(NotificationResponse response) {
    // Gérer l'action quand l'utilisateur tape sur une notification
    debugPrint('Notification tapped: ${response.payload}');
  }

  // Planifier des notifications de rappel
  Future<void> scheduleOrderReminderNotification(String orderId) async {
    // Notification de rappel simplifiée pour le moment
    Future.delayed(const Duration(minutes: 30), () {
      showOrderConfirmationNotification(
          orderId, 'N\'oubliez pas votre commande!');
    });
  }
}
