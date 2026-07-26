import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:elcora_fast/services/supabase_realtime_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final SupabaseRealtimeService _realtimeService = SupabaseRealtimeService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isInitialized = false;
  String? _currentUserId;
  StreamSubscription<String>? _notificationSubscription;
  RealtimeChannel? _notificationChannel;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isInitialized => _isInitialized;

  Future<void> initialize({String? userId}) async {
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

    // Créer les canaux de notification Android
    await _createNotificationChannels();

    // Charger les notifications depuis la base de données si un userId est fourni
    if (userId != null) {
      _currentUserId = userId;
      await _loadNotificationsFromDatabase(userId);
      await _subscribeToRealtimeNotifications(userId);
    } else {
      _loadNotifications();
    }

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

  /// Charge les notifications depuis la base de données
  Future<void> _loadNotificationsFromDatabase(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      _notifications = (response as List).map((item) {
        final data = item as Map<String, dynamic>;
        return {
          'id': data['id']?.toString() ?? '',
          'title': data['title']?.toString() ?? '',
          'message': data['message']?.toString() ?? '',
          'type': data['type']?.toString() ?? 'info',
          'isRead': data['is_read'] ?? false,
          'time': data['created_at'] != null
              ? DateTime.parse(data['created_at'].toString())
              : DateTime.now(),
          'icon': _getIconForType(data['type']?.toString() ?? 'info'),
          'data': data['data'] ?? {},
          'backendId': data['id']?.toString(),
        };
      }).toList();

      _updateUnreadCount();
      notifyListeners();
      debugPrint(
        'NotificationService: ${_notifications.length} notifications chargées',
      );
    } catch (e) {
      debugPrint(
        'NotificationService: Erreur lors du chargement des notifications - $e',
      );
      // En cas d'erreur, charger les notifications de démo
      _loadNotifications();
    }
  }

  /// S'abonne aux notifications en temps réel depuis Supabase
  Future<void> _subscribeToRealtimeNotifications(String userId) async {
    try {
      // S'abonner au stream du service Realtime
      _notificationSubscription = _realtimeService.notifications.listen(
        (message) {
          debugPrint('NotificationService: Notification reçue: $message');
          // Le message est juste une chaîne, on doit récupérer les détails depuis la DB
          _refreshLatestNotification(userId);
        },
        onError: (error) {
          debugPrint(
            'NotificationService: Erreur dans le stream de notifications - $error',
          );
        },
      );

      // S'abonner directement aux changements de la table notifications
      _notificationChannel = _supabase
          .channel('notifications_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final record = payload.newRecord;
              _handleRealtimeNotification(record);
            },
          )
          .subscribe();

      debugPrint(
        'NotificationService: Abonnement aux notifications Realtime activé',
      );
    } catch (e) {
      debugPrint('NotificationService: Erreur lors de l\'abonnement - $e');
    }
  }

  /// Gère une notification reçue en temps réel
  void _handleRealtimeNotification(Map<String, dynamic> notificationData) {
    try {
      final notification = {
        'id': notificationData['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'title': notificationData['title']?.toString() ?? 'Notification',
        'message': notificationData['message']?.toString() ?? '',
        'type': notificationData['type']?.toString() ?? 'info',
        'isRead': notificationData['is_read'] ?? false,
        'time': notificationData['created_at'] != null
            ? DateTime.parse(notificationData['created_at'].toString())
            : DateTime.now(),
        'icon': _getIconForType(notificationData['type']?.toString() ?? 'info'),
        'data': notificationData['data'] ?? {},
        'backendId': notificationData['id']?.toString(),
      };

      // Ajouter la notification à la liste
      _notifications.insert(0, notification);
      _updateUnreadCount();
      notifyListeners();

      // Afficher la notification locale
      _showLocalNotification(
        title: notification['title'] as String,
        body: notification['message'] as String,
        type: notification['type'] as String,
      );

      debugPrint('NotificationService: Notification traitée et affichée');
    } catch (e) {
      debugPrint(
        'NotificationService: Erreur lors du traitement de la notification - $e',
      );
    }
  }

  /// Rafraîchit la dernière notification depuis la base de données
  Future<void> _refreshLatestNotification(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      _handleRealtimeNotification(response);
    } catch (e) {
      debugPrint('NotificationService: Erreur lors du rafraîchissement - $e');
    }
  }

  /// Affiche une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String type,
    String? payload,
  }) async {
    final channelId = _getChannelIdForType(type);
    final importance = _getImportanceForType(type);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      _getChannelNameForType(type),
      channelDescription: 'Notifications pour ${_getChannelNameForType(type)}',
      importance: importance,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Retourne l'ID du canal selon le type de notification
  String _getChannelIdForType(String type) {
    switch (type.toLowerCase()) {
      case 'order_update':
      case 'order':
        return 'order_channel';
      case 'delivery':
        return 'delivery_channel';
      case 'promotion':
        return 'promotion_channel';
      default:
        return 'general_channel';
    }
  }

  /// Retourne le nom du canal selon le type de notification
  String _getChannelNameForType(String type) {
    switch (type.toLowerCase()) {
      case 'order_update':
      case 'order':
        return 'Commandes';
      case 'delivery':
        return 'Livraisons';
      case 'promotion':
        return 'Promotions';
      default:
        return 'Général';
    }
  }

  /// Retourne l'importance selon le type de notification
  Importance _getImportanceForType(String type) {
    switch (type.toLowerCase()) {
      case 'order_update':
      case 'order':
      case 'delivery':
        return Importance.max;
      case 'promotion':
        return Importance.high;
      default:
        return Importance.defaultImportance;
    }
  }

  /// Retourne l'icône selon le type de notification
  String _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'order_update':
      case 'order':
        return '🍔';
      case 'delivery':
        return '🚚';
      case 'promotion':
        return '🎁';
      case 'success':
        return '✅';
      case 'warning':
        return '⚠️';
      case 'error':
        return '❌';
      case 'social':
        return '👥';
      default:
        return '📢';
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

    _addNotification(
      title: '✅ Commande confirmée',
      message: 'Commande #$orderId: $items',
      type: 'order',
      icon: '🍔',
    );
  }

  Future<void> showDeliveryUpdateNotification(
    String status,
    String orderId,
  ) async {
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

  Future<void> markAsRead(int notificationId) async {
    final index = _notifications.indexWhere((n) => n['id'] == notificationId);
    if (index != -1) {
      _notifications[index]['isRead'] = true;
      _updateUnreadCount();
      notifyListeners();

      // Marquer comme lu dans la base de données si c'est une notification backend
      final backendId = _notifications[index]['backendId'] as String?;
      if (backendId != null && _currentUserId != null) {
        try {
          await _supabase
              .from('notifications')
              .update({
                'is_read': true,
                'read_at': DateTime.now().toIso8601String(),
              })
              .eq('id', backendId)
              .eq('user_id', _currentUserId!);
        } catch (e) {
          debugPrint(
            'NotificationService: Erreur lors du marquage comme lu - $e',
          );
        }
      }
    }
  }

  Future<void> markAllAsRead() async {
    for (final notification in _notifications) {
      notification['isRead'] = true;
    }
    _updateUnreadCount();
    notifyListeners();

    // Marquer toutes comme lues dans la base de données
    if (_currentUserId != null) {
      try {
        await _supabase
            .from('notifications')
            .update({
              'is_read': true,
              'read_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', _currentUserId!)
            .eq('is_read', false);
      } catch (e) {
        debugPrint(
          'NotificationService: Erreur lors du marquage de toutes comme lues - $e',
        );
      }
    }
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
    _unreadCount =
        _notifications.where((n) => !(n['isRead'] as bool? ?? false)).length;
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
        orderId,
        'N\'oubliez pas votre commande!',
      );
    });
  }

  /// Nettoie les ressources
  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _notificationChannel?.unsubscribe();
    super.dispose();
  }
}
