import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:elcora_fast/models/order.dart';

class AdvancedNotificationService extends ChangeNotifier {
  static final AdvancedNotificationService _instance =
      AdvancedNotificationService._internal();
  factory AdvancedNotificationService() => _instance;
  AdvancedNotificationService._internal();

  // Web-compatible notification service without external dependencies

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
      // Web-compatible initialization
      _isInitialized = true;
      notifyListeners();

      debugPrint(
          'AdvancedNotificationService: Service initialisé avec succès (Web)',);
    } catch (e) {
      debugPrint('AdvancedNotificationService: Erreur d\'initialisation - $e');
    }
  }

  /// Demande les permissions de notification
  Future<bool> requestPermissions() async {
    try {
      // Web-compatible permission request
      debugPrint('AdvancedNotificationService: Permissions accordées (Web)');
      return true;
    } catch (e) {
      debugPrint('AdvancedNotificationService: Permissions refusées (Web)');
      return false;
    }
  }

  /// Obtient le token FCM (Web-compatible)
  Future<String?> getFCMToken() async {
    _fcmToken = 'web_token_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('AdvancedNotificationService: Token FCM - $_fcmToken');
    return _fcmToken;
  }

  /// Affiche une notification locale (Web-compatible)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Web-compatible notification display
    debugPrint('AdvancedNotificationService: Notification affichée (Web)');
    debugPrint('Titre: $title');
    debugPrint('Corps: $body');
    debugPrint('Payload: $payload');
  }

  /// Envoie une notification de statut de commande
  Future<void> sendOrderStatusNotification({
    required String userId,
    required Order order,
    required String status,
  }) async {
    const title = 'Statut de votre commande';
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

  /// Planifie une notification (Web-compatible)
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    // Web-compatible notification scheduling
    debugPrint('AdvancedNotificationService: Notification programmée (Web)');
    debugPrint('Titre: $title');
    debugPrint('Corps: $body');
    debugPrint('Date: $scheduledDate');
    debugPrint('Payload: $payload');
  }

  /// Annule une notification programmée (Web-compatible)
  Future<void> cancelNotification(int notificationId) async {
    debugPrint(
        'AdvancedNotificationService: Notification annulée (Web) - ID: $notificationId',);
  }

  /// Annule toutes les notifications (Web-compatible)
  Future<void> cancelAllNotifications() async {
    debugPrint(
        'AdvancedNotificationService: Toutes les notifications annulées (Web)',);
  }

  /// Obtient les notifications en attente (Web-compatible)
  Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    debugPrint(
        'AdvancedNotificationService: Récupération des notifications en attente (Web)',);
    return []; // Retourne une liste vide pour le web
  }

  /// S'abonne à un topic (Web-compatible)
  Future<void> subscribeToTopic(String topic) async {
    debugPrint('AdvancedNotificationService: Abonné au topic $topic (Web)');
  }

  /// Se désabonne d'un topic (Web-compatible)
  Future<void> unsubscribeFromTopic(String topic) async {
    debugPrint('AdvancedNotificationService: Désabonné du topic $topic (Web)');
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
