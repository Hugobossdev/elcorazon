import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Bannières de notification **locales** (plugin système) — Phase 6.
///
/// Ce service n'a plus ni historique ni temps réel. L'historique du compte vit
/// dans `NotificationDatabaseService` (backend Django : lecture et marquage de
/// lecture), la réception distante dans `PushNotificationService` (FCM). Ce qui
/// reste ici n'est qu'un affichage sur l'appareil, sans aucun aller-retour
/// serveur.
///
/// Ce qui a disparu avec Supabase : la liste `_notifications` et son compteur
/// de non-lues — un doublon de l'historique, alimenté par un abonnement direct
/// à la table `notifications` — ainsi que les écritures `is_read` faites depuis
/// le client. Aucun écran ne les lisait : ils consomment tous
/// `NotificationDatabaseService`.
class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

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

    await _createNotificationChannels();

    _isInitialized = true;
    notifyListeners();
  }

  /// Crée les canaux de notification Android
  Future<void> _createNotificationChannels() async {
    const List<AndroidNotificationChannel> channels = [
      AndroidNotificationChannel(
        'order_channel',
        'Commandes',
        description: 'Notifications pour les commandes',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        'delivery_channel',
        'Livraisons',
        description: 'Notifications pour les livraisons',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        'promotion_channel',
        'Promotions',
        description: 'Notifications pour les promotions',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'general_channel',
        'Général',
        description: 'Notifications générales',
      ),
    ];

    for (final channel in channels) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> showOrderConfirmationNotification(
    String orderId,
    String items,
  ) async {
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
  }

  void _handleNotificationTap(NotificationResponse response) {
    // Gérer l'action quand l'utilisateur tape sur une notification
    debugPrint('Notification tapped: ${response.payload}');
  }
}
