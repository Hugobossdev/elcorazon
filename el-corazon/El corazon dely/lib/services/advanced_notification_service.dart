import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/order.dart';

class AdvancedNotificationService extends ChangeNotifier {
  static final AdvancedNotificationService _instance =
      AdvancedNotificationService._internal();
  factory AdvancedNotificationService() => _instance;
  AdvancedNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  bool _isInitialized = false;
  String? _fcmToken;
  final StreamController<NotificationData> _notificationController =
      StreamController<NotificationData>.broadcast();

  Stream<NotificationData> get notificationStream =>
      _notificationController.stream;
  bool get isInitialized => _isInitialized;
  String? get fcmToken => _fcmToken;

  /// Initialise le service de notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configuration des notifications locales
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Configuration Firebase Messaging
      await _initializeFirebaseMessaging();

      _isInitialized = true;
      notifyListeners();

      debugPrint('AdvancedNotificationService: Service initialisé avec succès');
    } catch (e) {
      debugPrint('AdvancedNotificationService: Erreur d\'initialisation - $e');
    }
  }

  /// Initialise Firebase Messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Demander les permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('AdvancedNotificationService: Permissions accordées');
    } else {
      debugPrint('AdvancedNotificationService: Permissions refusées');
    }

    // Obtenir le token FCM
    _fcmToken = await _firebaseMessaging.getToken();
    debugPrint('AdvancedNotificationService: Token FCM - $_fcmToken');

    // Écouter les messages en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Écouter les messages au premier plan
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Écouter les clics sur les notifications
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);
  }

  /// Gère les notifications reçues en premier plan
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('AdvancedNotificationService: Message reçu en premier plan');
    debugPrint('Titre: ${message.notification?.title}');
    debugPrint('Corps: ${message.notification?.body}');
    debugPrint('Données: ${message.data}');

    // Afficher une notification locale
    _showLocalNotification(
      title: message.notification?.title ?? 'Nouvelle notification',
      body: message.notification?.body ?? '',
      payload: json.encode(message.data),
    );

    // Émettre l'événement
    final notificationData = NotificationData(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      data: message.data,
      type: _getNotificationType(message.data),
      timestamp: DateTime.now(),
    );

    _notificationController.add(notificationData);
  }

  /// Gère les clics sur les notifications
  void _handleNotificationClick(RemoteMessage message) {
    debugPrint('AdvancedNotificationService: Notification cliquée');
    debugPrint('Données: ${message.data}');

    final notificationData = NotificationData(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      data: message.data,
      type: _getNotificationType(message.data),
      timestamp: DateTime.now(),
    );

    _notificationController.add(notificationData);
  }

  /// Gère les clics sur les notifications locales
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('AdvancedNotificationService: Notification locale cliquée');
    debugPrint('Payload: ${response.payload}');

    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        final notificationData = NotificationData(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: data['title'] ?? '',
          body: data['body'] ?? '',
          data: data,
          type: _getNotificationType(data),
          timestamp: DateTime.now(),
        );

        _notificationController.add(notificationData);
      } catch (e) {
        debugPrint(
            'AdvancedNotificationService: Erreur de parsing du payload - $e');
      }
    }
  }

  /// Détermine le type de notification
  NotificationType _getNotificationType(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase();

    switch (type) {
      case 'order_status':
        return NotificationType.orderStatus;
      case 'promotion':
        return NotificationType.promotion;
      case 'delivery':
        return NotificationType.delivery;
      case 'achievement':
        return NotificationType.achievement;
      case 'challenge':
        return NotificationType.challenge;
      case 'social':
        return NotificationType.social;
      default:
        return NotificationType.general;
    }
  }

  /// Affiche une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'el_corazon_channel',
      'El Corazón Notifications',
      channelDescription: 'Notifications pour El Corazón',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Envoie une notification de statut de commande
  Future<void> sendOrderStatusNotification({
    required String userId,
    required Order order,
    required String status,
  }) async {
    final title = 'Statut de votre commande';
    String body;

    switch (status.toLowerCase()) {
      case 'confirmed':
        body =
            'Votre commande #${order.id.substring(0, 8)} a été confirmée! 🎉';
        break;
      case 'preparing':
        body =
            'Votre commande #${order.id.substring(0, 8)} est en cours de préparation 👨‍🍳';
        break;
      case 'ready':
        body = 'Votre commande #${order.id.substring(0, 8)} est prête! 🍔';
        break;
      case 'on_the_way':
        body = 'Votre commande #${order.id.substring(0, 8)} est en route! 🚗';
        break;
      case 'delivered':
        body =
            'Votre commande #${order.id.substring(0, 8)} a été livrée! Bon appétit! 😋';
        break;
      default:
        body = 'Mise à jour de votre commande #${order.id.substring(0, 8)}';
    }

    await _showLocalNotification(
      title: title,
      body: body,
      payload: json.encode({
        'type': 'order_status',
        'orderId': order.id,
        'status': status,
      }),
    );
  }

  /// Envoie une notification de promotion
  Future<void> sendPromotionNotification({
    required String userId,
    required String title,
    required String description,
    String? promoCode,
  }) async {
    await _showLocalNotification(
      title: title,
      body: promoCode != null ? '$description\nCode: $promoCode' : description,
      payload: json.encode({
        'type': 'promotion',
        'promoCode': promoCode,
      }),
    );
  }

  /// Envoie une notification d'achievement
  Future<void> sendAchievementNotification({
    required String userId,
    required String achievementName,
    required String description,
    required int points,
  }) async {
    await _showLocalNotification(
      title: 'Achievement débloqué! 🏆',
      body: '$achievementName: $description (+$points points)',
      payload: json.encode({
        'type': 'achievement',
        'achievementName': achievementName,
        'points': points,
      }),
    );
  }

  /// Envoie une notification de défi
  Future<void> sendChallengeNotification({
    required String userId,
    required String challengeName,
    required String description,
  }) async {
    await _showLocalNotification(
      title: 'Nouveau défi disponible! 🎯',
      body: '$challengeName: $description',
      payload: json.encode({
        'type': 'challenge',
        'challengeName': challengeName,
      }),
    );
  }

  /// Envoie une notification sociale
  Future<void> sendSocialNotification({
    required String userId,
    required String title,
    required String message,
    String? fromUserId,
  }) async {
    await _showLocalNotification(
      title: title,
      body: message,
      payload: json.encode({
        'type': 'social',
        'fromUserId': fromUserId,
      }),
    );
  }

  /// Envoie une notification de livraison
  Future<void> sendDeliveryNotification({
    required String userId,
    required String orderId,
    required String deliveryPersonName,
    required String estimatedTime,
  }) async {
    await _showLocalNotification(
      title: 'Votre livreur arrive! 🚗',
      body: '$deliveryPersonName livrera votre commande dans $estimatedTime',
      payload: json.encode({
        'type': 'delivery',
        'orderId': orderId,
        'deliveryPersonName': deliveryPersonName,
        'estimatedTime': estimatedTime,
      }),
    );
  }

  /// Planifie une notification
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'el_corazon_scheduled_channel',
      'El Corazón Scheduled Notifications',
      channelDescription: 'Notifications programmées pour El Corazón',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.getLocation('Europe/Paris')),
      platformChannelSpecifics,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Annule une notification programmée
  Future<void> cancelNotification(int notificationId) async {
    await _flutterLocalNotificationsPlugin.cancel(notificationId);
  }

  /// Annule toutes les notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Obtient les notifications en attente
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  /// S'abonne à un topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    debugPrint('AdvancedNotificationService: Abonné au topic $topic');
  }

  /// Se désabonne d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    debugPrint('AdvancedNotificationService: Désabonné du topic $topic');
  }

  /// Envoie une notification de test
  Future<void> sendTestNotification() async {
    await _showLocalNotification(
      title: 'Test de notification',
      body: 'Ceci est une notification de test d\'El Corazón!',
      payload: json.encode({
        'type': 'test',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  @override
  void dispose() {
    _notificationController.close();
    super.dispose();
  }
}

/// Handler pour les messages Firebase en arrière-plan
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('AdvancedNotificationService: Message en arrière-plan reçu');
  debugPrint('Titre: ${message.notification?.title}');
  debugPrint('Corps: ${message.notification?.body}');
  debugPrint('Données: ${message.data}');
}

class NotificationData {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final NotificationType type;
  final DateTime timestamp;

  NotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.type,
    required this.timestamp,
  });
}

enum NotificationType {
  orderStatus,
  promotion,
  delivery,
  achievement,
  challenge,
  social,
  general,
}
