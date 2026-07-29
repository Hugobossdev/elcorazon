import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:elcora_fast/models/order.dart';

/// Reçoit les messages quand l'app est fermée ou en arrière-plan. Doit être
/// une fonction de premier niveau annotée `@pragma('vm:entry-point')` : elle
/// est exécutée dans un isolat séparé, sans rien de l'état de l'app.
///
/// Rien à faire ici : Android affiche lui-même la notification portée par le
/// bloc `notification` du message, et l'historique se relit depuis
/// `/api/v1/notifications/` à la réouverture. Ce handler existe pour que le
/// message ne soit pas perdu et pour la trace.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('PushNotificationService: message en arrière-plan ${message.messageId}');
}

/// Notifications de l'app client : locales (programmation, affichage) **et**
/// push FCM (Phase 6).
///
/// La partie push se limite volontairement à trois gestes : obtenir le jeton
/// d'appareil, le tenir à jour, et afficher au premier plan un message que le
/// système n'affiche pas de lui-même. C'est le backend qui décide *quoi*
/// envoyer et *à qui* — cette classe n'a aucune règle d'envoi.
class PushNotificationService extends ChangeNotifier {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _userId;
  String? _fcmToken;
  final StreamController<PushNotification> _notificationController =
      StreamController<PushNotification>.broadcast();

  /// Émet à chaque rotation du jeton d'appareil (FCM le renouvelle de son
  /// propre chef). `AppService` s'y abonne pour ré-enregistrer le nouveau
  /// jeton auprès de `/auth/devices/` — sans cela, l'appareil cesse
  /// silencieusement de recevoir quoi que ce soit.
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();

  // Getters
  bool get isInitialized => _isInitialized;
  String? get userId => _userId;

  /// Jeton d'appareil FCM, `null` tant que Firebase n'est pas initialisé ou
  /// que la permission n'a pas été accordée.
  String? get fcmToken => _fcmToken;
  Stream<PushNotification> get notificationStream =>
      _notificationController.stream;
  Stream<String> get tokenRefreshStream => _tokenRefreshController.stream;

  /// Initialise le service de notifications push
  Future<void> initialize({String? userId}) async {
    if (_isInitialized) return;

    try {
      _userId = userId;

      // Initialiser les timezones
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));

      // Configuration des notifications locales
      await _initializeLocalNotifications();

      // Push FCM — indépendant de ce qui précède : un échec ici (pas de
      // projet Firebase configuré, permission refusée) laisse les
      // notifications locales fonctionnelles.
      await _initializeFirebaseMessaging();

      _isInitialized = true;
      notifyListeners();

      debugPrint('PushNotificationService: Service initialisé avec succès');
    } catch (e) {
      debugPrint('PushNotificationService: Erreur d\'initialisation - $e');
    }
  }

  Future<void> _initializeFirebaseMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // iOS et Android 13+ exigent un consentement explicite ; Android
      // antérieur le renvoie accordé d'office.
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('PushNotificationService: notifications push refusées');
        return;
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      _fcmToken = await messaging.getToken();
      debugPrint(
        'PushNotificationService: jeton FCM ${_fcmToken == null ? 'indisponible' : 'obtenu'}',
      );

      messaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _tokenRefreshController.add(token);
      });

      // Au premier plan, le système n'affiche rien de lui-même sur Android :
      // on rejoue le message dans une notification locale.
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedFromMessage);
    } catch (e) {
      // Notamment quand aucun projet Firebase réel n'est configuré (voir
      // `lib/firebase_options.dart`) : l'app tourne sans push plutôt que de
      // refuser de démarrer.
      debugPrint('PushNotificationService: FCM indisponible - $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    unawaited(
      _showLocalNotification(
        title: notification.title ?? 'El Corazón',
        body: notification.body ?? '',
        payload: json.encode(message.data),
        channelId: _channelForKind(message.data['kind']?.toString()),
      ),
    );
  }

  void _handleOpenedFromMessage(RemoteMessage message) {
    _notificationController.add(
      PushNotification(
        // `data` porte de quoi ouvrir le bon écran, pas l'objet métier — il
        // aura changé d'ici la lecture (contrat des notifications).
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
        data: Map<String, dynamic>.from(message.data),
        type: PushNotification._getNotificationType(message.data),
        timestamp: message.sentTime ?? DateTime.now(),
      ),
    );
  }

  /// Canal Android d'après `NotificationKind` du serveur.
  String _channelForKind(String? kind) {
    switch (kind) {
      case 'delivery_offer':
        return 'delivery';
      case 'marketing':
        return 'promotions';
      default:
        return 'orders';
    }
  }

  /// Initialise les notifications locales
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Créer les canaux de notification Android
    await _createNotificationChannels();
  }

  /// Crée les canaux de notification Android
  Future<void> _createNotificationChannels() async {
    const List<AndroidNotificationChannel> channels = [
      AndroidNotificationChannel(
        'orders',
        'Commandes',
        description: 'Notifications pour les commandes',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        'delivery',
        'Livraisons',
        description: 'Notifications pour les livraisons',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        'promotions',
        'Promotions',
        description: 'Notifications pour les promotions',
        importance: Importance.high,
        enableVibration: false,
      ),
      AndroidNotificationChannel(
        'achievements',
        'Achievements',
        description: 'Notifications pour les achievements',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'social',
        'Social',
        description: 'Notifications sociales',
        playSound: false,
        enableVibration: false,
      ),
    ];

    for (final channel in channels) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Gère les clics sur les notifications locales
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('PushNotificationService: Notification locale cliquée');
    debugPrint('Payload: ${response.payload}');

    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        final notification = PushNotification.fromMap(data);
        _notificationController.add(notification);
      } catch (e) {
        debugPrint('PushNotificationService: Erreur parsing payload - $e');
      }
    }
  }

  /// Affiche une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'orders',
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'orders',
      'Commandes',
      channelDescription: 'Notifications pour les commandes',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  /// Envoie une notification de statut de commande
  Future<void> sendOrderStatusNotification({
    required String userId,
    required Order order,
    required String status,
  }) async {
    const title = 'Statut de votre commande';
    String body;
    String emoji;

    switch (status.toLowerCase()) {
      case 'confirmed':
        body =
            'Votre commande #${order.id.substring(0, 8)} a été confirmée! 🎉';
        emoji = '🎉';
        break;
      case 'preparing':
        body =
            'Votre commande #${order.id.substring(0, 8)} est en cours de préparation 👨‍🍳';
        emoji = '👨‍🍳';
        break;
      case 'ready':
        body = 'Votre commande #${order.id.substring(0, 8)} est prête! 🍔';
        emoji = '🍔';
        break;
      case 'on_the_way':
        body = 'Votre commande #${order.id.substring(0, 8)} est en route! 🚗';
        emoji = '🚗';
        break;
      case 'delivered':
        body =
            'Votre commande #${order.id.substring(0, 8)} a été livrée! Bon appétit! 😋';
        emoji = '😋';
        break;
      default:
        body = 'Mise à jour de votre commande #${order.id.substring(0, 8)}';
        emoji = '📦';
    }

    await _showLocalNotification(
      title: '$emoji $title',
      body: body,
      payload: json.encode({
        'type': 'order_status',
        'orderId': order.id,
        'status': status,
        'userId': userId,
      }),
    );

  }

  /// Envoie une notification de promotion
  Future<void> sendPromotionNotification({
    required String userId,
    required String title,
    required String description,
    String? promoCode,
    String? imageUrl,
  }) async {
    final notificationTitle = '🎁 $title';
    final notificationBody = promoCode != null
        ? '$description\n\nCode promo: $promoCode'
        : description;

    await _showLocalNotification(
      title: notificationTitle,
      body: notificationBody,
      payload: json.encode({
        'type': 'promotion',
        'promoCode': promoCode,
        'userId': userId,
      }),
      channelId: 'promotions',
    );

  }

  /// Envoie une notification d'achievement
  Future<void> sendAchievementNotification({
    required String userId,
    required String achievementName,
    required String description,
    required int points,
    String? badgeImageUrl,
  }) async {
    const title = '🏆 Achievement débloqué!';
    final body = '$achievementName: $description (+$points points)';

    await _showLocalNotification(
      title: title,
      body: body,
      payload: json.encode({
        'type': 'achievement',
        'achievementName': achievementName,
        'points': points,
        'userId': userId,
      }),
      channelId: 'achievements',
    );

  }

  /// Envoie une notification de livraison
  Future<void> sendDeliveryNotification({
    required String userId,
    required String orderId,
    required String deliveryPersonName,
    required String estimatedTime,
    String? deliveryPersonPhone,
  }) async {
    const title = '🚗 Votre livreur arrive!';
    final body =
        '$deliveryPersonName livrera votre commande dans $estimatedTime';

    await _showLocalNotification(
      title: title,
      body: body,
      payload: json.encode({
        'type': 'delivery',
        'orderId': orderId,
        'deliveryPersonName': deliveryPersonName,
        'estimatedTime': estimatedTime,
        'userId': userId,
      }),
      channelId: 'delivery',
    );

  }

  /// Envoie une notification sociale
  Future<void> sendSocialNotification({
    required String userId,
    required String title,
    required String message,
    String? fromUserId,
    String? fromUserName,
  }) async {
    await _showLocalNotification(
      title: title,
      body: message,
      payload: json.encode({
        'type': 'social',
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'userId': userId,
      }),
      channelId: 'social',
    );

  }

  /// Planifie une notification
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String channelId = 'orders',
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'orders',
      'Commandes',
      channelDescription: 'Notifications pour les commandes',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.getLocation('Europe/Paris')),
      platformDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // `_saveNotificationToDatabase` supprimé : il traçait chaque notification
  // locale dans Supabase (`trackEvent`). L'historique lisible après coup vit
  // désormais dans `/api/v1/notifications/`, alimenté par le serveur —
  // dupliquer côté client ce qu'il produit ferait deux listes divergentes.

  /// Envoie une notification personnalisée (méthode publique)
  Future<void> sendCustomNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'general',
  }) async {
    await _showLocalNotification(
      title: title,
      body: body,
      payload: payload,
      channelId: channelId,
    );
  }

  /// Envoie une notification de test
  Future<void> sendTestNotification() async {
    await _showLocalNotification(
      title: '🧪 Test de notification',
      body: 'Ceci est une notification de test d\'El Corazón!',
      payload: json.encode({
        'type': 'test',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  /// Annule une notification
  Future<void> cancelNotification(int notificationId) async {
    await _localNotifications.cancel(notificationId);
  }

  /// Annule toutes les notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Obtient les notifications en attente
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _localNotifications.pendingNotificationRequests();
  }

  @override
  void dispose() {
    _notificationController.close();
    _tokenRefreshController.close();
    super.dispose();
  }
}

/// Modèle de données pour les notifications push
class PushNotification {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;

  PushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory PushNotification.fromMap(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final dynamicData = map['data'];

    return PushNotification(
      id: map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? '',
      body: map['message']?.toString() ?? map['body']?.toString() ?? '',
      data: dynamicData is Map<String, dynamic>
          ? dynamicData
          : (dynamicData is Map ? Map<String, dynamic>.from(dynamicData) : {}),
      type: _getNotificationType(map),
      timestamp: DateTime.tryParse(
            map['created_at']?.toString() ?? map['timestamp']?.toString() ?? '',
          ) ??
          DateTime.now(),
      isRead: (map['is_read'] ?? map['isRead'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'data': data,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  static NotificationType _getNotificationType(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase();

    switch (type) {
      case 'order_status':
      case 'order':
      case 'order_update':
        return NotificationType.orderStatus;
      case 'promotion':
        return NotificationType.promotion;
      case 'delivery':
        return NotificationType.delivery;
      case 'achievement':
        return NotificationType.achievement;
      case 'challenge':
        return NotificationType.challenge;
      case 'reward':
        return NotificationType.reward;
      case 'reminder':
        return NotificationType.reminder;
      case 'system':
        return NotificationType.system;
      case 'social':
        return NotificationType.social;
      default:
        return NotificationType.general;
    }
  }
}

/// Types de notifications
enum NotificationType {
  orderStatus,
  promotion,
  delivery,
  achievement,
  challenge,
  reward,
  reminder,
  system,
  social,
  general,
}
