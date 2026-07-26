import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:elcora_fast/services/database_service.dart';
import 'package:elcora_fast/services/push_notification_service.dart';

/// Service de gestion des notifications en base de données
class NotificationDatabaseService extends ChangeNotifier {
  static final NotificationDatabaseService _instance =
      NotificationDatabaseService._internal();
  factory NotificationDatabaseService() => _instance;
  NotificationDatabaseService._internal();

  final DatabaseService _databaseService = DatabaseService();
  String? _currentUserId;

  List<PushNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  
  final StreamController<int> _unreadCountController = StreamController<int>.broadcast();

  // Getters
  List<PushNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  /// Charge les notifications depuis la base de données
  Future<void> loadNotifications(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUserId = userId;
      // Récupérer les notifications depuis la base de données
      final response = await _databaseService.supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _notifications = response
          .map((data) => PushNotification.fromMap(data))
          .toList();

      _updateUnreadCount();
      debugPrint('NotificationDatabaseService: ${_notifications.length} notifications chargées');
    } catch (e) {
      debugPrint(
          'NotificationDatabaseService: Erreur chargement notifications - $e',);
      _notifications = [];
      _updateUnreadCount();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sauvegarde une notification en base de données
  Future<void> saveNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      // Sauvegarder en base de données
      final response = await _databaseService.supabase
          .from('notifications')
          .insert({
            'user_id': userId,
            'title': title,
            'message': body,
            'type': type,
            'data': data ?? {},
            'is_read': false,
          })
          .select()
          .single();

      // Ajouter à la liste locale
      final notification = PushNotification.fromMap(response);
      _notifications.insert(0, notification);
      _updateUnreadCount();
      notifyListeners();

      debugPrint('NotificationDatabaseService: Notification sauvegardée en base de données');
    } catch (e) {
      debugPrint('NotificationDatabaseService: Erreur sauvegarde - $e');
    }
  }


  /// Marque toutes les notifications comme lues
  Future<void> markAllAsRead() async {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint(
          'NotificationDatabaseService: impossible de marquer comme lues sans utilisateur chargé',);
      return;
    }

    try {
      // Mettre à jour en base de données
      await _databaseService.supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);

      // Mettre à jour localement
      _notifications = _notifications.map((notification) {
        return PushNotification(
          id: notification.id,
          title: notification.title,
          body: notification.body,
          data: notification.data,
          type: notification.type,
          timestamp: notification.timestamp,
          isRead: true,
        );
      }).toList();

      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint(
          'NotificationDatabaseService: Erreur marquage toutes lues - $e',);
    }
  }

  /// Supprime une notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _databaseService.supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);

      // Supprimer localement
      _notifications.removeWhere((n) => n.id == notificationId);
      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationDatabaseService: Erreur suppression - $e');
    }
  }

  /// Supprime toutes les notifications
  Future<void> deleteAllNotifications() async {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint(
          'NotificationDatabaseService: impossible de supprimer sans utilisateur chargé',);
      return;
    }

    try {
      await _databaseService.supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId);

      // Supprimer localement
      _notifications.clear();
      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationDatabaseService: Erreur suppression toutes - $e');
    }
  }

  /// Filtre les notifications par type
  List<PushNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  /// Filtre les notifications non lues
  List<PushNotification> getUnreadNotifications() {
    return _notifications.where((n) => !n.isRead).toList();
  }

  /// Filtre les notifications par période
  List<PushNotification> getNotificationsByPeriod({
    required DateTime start,
    required DateTime end,
  }) {
    return _notifications.where((n) {
      return n.timestamp.isAfter(start) && n.timestamp.isBefore(end);
    }).toList();
  }

  /// Recherche dans les notifications
  List<PushNotification> searchNotifications(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _notifications.where((n) {
      return n.title.toLowerCase().contains(lowercaseQuery) ||
          n.body.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Marque une notification comme lue
  Future<void> markAsRead(String notificationId) async {
    try {
      // Mettre à jour dans la base de données
      await _databaseService.supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);

      // Mettre à jour localement
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = PushNotification(
          id: _notifications[index].id,
          title: _notifications[index].title,
          body: _notifications[index].body,
          data: _notifications[index].data,
          type: _notifications[index].type,
          timestamp: _notifications[index].timestamp,
          isRead: true,
        );
        _updateUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NotificationDatabaseService: Erreur marquer comme lu - $e');
    }
  }

  /// Met à jour le compteur de notifications non lues
  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    _unreadCountController.add(_unreadCount);
  }
  
  /// Stream du compteur de notifications non lues
  Stream<int> get unreadCountStream => _unreadCountController.stream;


  /// Envoie une notification de test
  Future<void> sendTestNotification(String userId) async {
    await saveNotification(
      userId: userId,
      title: '🧪 Test de notification',
      body: 'Ceci est une notification de test d\'El Corazón!',
      type: 'test',
      data: {
        'timestamp': DateTime.now().toIso8601String(),
        'isTest': true,
      },
    );
  }

  /// Envoie une notification de bienvenue
  Future<void> sendWelcomeNotification(String userId, String userName) async {
    await saveNotification(
      userId: userId,
      title: '🎉 Bienvenue chez El Corazón!',
      body:
          'Bonjour $userName! Profitez de 20% de réduction sur votre première commande avec le code WELCOME20',
      type: 'promotion',
      data: {
        'promoCode': 'WELCOME20',
        'discount': '20',
        'isWelcome': true,
      },
    );
  }

  /// Envoie une notification de rappel de commande
  Future<void> sendOrderReminderNotification(
      String userId, String orderId,) async {
    await saveNotification(
      userId: userId,
      title: '⏰ Rappel de commande',
      body: 'N\'oubliez pas votre commande #$orderId',
      type: 'reminder',
      data: {
        'orderId': orderId,
        'isReminder': true,
      },
    );
  }

  /// Envoie une notification de promotion personnalisée
  Future<void> sendPersonalizedPromotionNotification({
    required String userId,
    required String title,
    required String description,
    String? promoCode,
    String? discount,
  }) async {
    await saveNotification(
      userId: userId,
      title: '🎁 $title',
      body: promoCode != null
          ? '$description\n\nCode promo: $promoCode'
          : description,
      type: 'promotion',
      data: {
        'promoCode': promoCode,
        'discount': discount,
        'isPersonalized': true,
      },
    );
  }

  /// Envoie une notification d'achievement
  Future<void> sendAchievementNotification({
    required String userId,
    required String achievementName,
    required String description,
    required int points,
  }) async {
    await saveNotification(
      userId: userId,
      title: '🏆 Achievement débloqué!',
      body: '$achievementName: $description (+$points points)',
      type: 'achievement',
      data: {
        'achievementName': achievementName,
        'points': points,
        'isAchievement': true,
      },
    );
  }

  /// Envoie une notification de livraison
  Future<void> sendDeliveryNotification({
    required String userId,
    required String orderId,
    required String deliveryPersonName,
    required String estimatedTime,
  }) async {
    await saveNotification(
      userId: userId,
      title: '🚗 Votre livreur arrive!',
      body: '$deliveryPersonName livrera votre commande dans $estimatedTime',
      type: 'delivery',
      data: {
        'orderId': orderId,
        'deliveryPersonName': deliveryPersonName,
        'estimatedTime': estimatedTime,
      },
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
    await saveNotification(
      userId: userId,
      title: title,
      body: message,
      type: 'social',
      data: {
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'isSocial': true,
      },
    );
  }

  /// Obtient les statistiques des notifications
  Map<String, int> getNotificationStats() {
    final stats = <String, int>{
      'total': _notifications.length,
      'unread': _unreadCount,
      'read': _notifications.where((n) => n.isRead).length,
    };

    // Statistiques par type
    for (final type in NotificationType.values) {
      stats[type.name] = _notifications.where((n) => n.type == type).length;
    }

    return stats;
  }

  /// Nettoie les anciennes notifications
  Future<void> cleanupOldNotifications({int daysToKeep = 30}) async {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint(
          'NotificationDatabaseService: impossible de nettoyer sans utilisateur chargé',);
      return;
    }

    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      await _databaseService.supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId)
          .lte('created_at', cutoffDate.toIso8601String());

      // Nettoyer localement
      _notifications.removeWhere((n) => n.timestamp.isBefore(cutoffDate));
      _updateUnreadCount();
      notifyListeners();

      debugPrint('NotificationDatabaseService: Nettoyage terminé');
    } catch (e) {
      debugPrint('NotificationDatabaseService: Erreur nettoyage - $e');
    }
  }
}
