import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/presentation/genre_notification.dart';

/// Historique des notifications, contre le backend Django (Phase 6).
///
/// Ce qui a disparu avec Supabase, et ne reviendra pas : l'écriture de
/// notifications depuis le client (`saveNotification` et toute la famille des
/// `sendWelcomeNotification`/`sendPromotionNotification`...), la suppression
/// unitaire ou globale, et la purge des anciennes. Le contrat n'expose que la
/// lecture et le marquage — une notification est produite par le serveur, qui
/// est aussi le seul à savoir quand elle cesse d'être pertinente.
class NotificationDatabaseService extends ChangeNotifier {
  static final NotificationDatabaseService _instance =
      NotificationDatabaseService._internal();
  factory NotificationDatabaseService() => _instance;
  NotificationDatabaseService._internal();

  final eccore.NotificationRepository _repository =
      eccore.NotificationRepository(apiClient: apiClient);

  List<eccore.AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  final StreamController<int> _unreadCountController = StreamController<int>.broadcast();

  List<eccore.AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  /// Charge l'historique du compte connecté. Plus d'identifiant en paramètre :
  /// le serveur cloisonne sur le jeton.
  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await _repository.getNotifications();
      // Le compteur vient de la route dédiée, pas d'un décompte de la liste :
      // les deux coïncident ici (toutes les pages sont suivies) mais c'est le
      // serveur qui fait foi.
      _unreadCount = await _repository.getUnreadCount();
      _unreadCountController.add(_unreadCount);
      eccore.Journal.trace('✅ ${_notifications.length} notifications chargées');
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('❌ Chargement des notifications: ${e.code}');
      _notifications = [];
      _updateUnreadCountLocally();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Vide l'état local à la déconnexion — l'historique appartient au compte
  /// qui vient de partir.
  void clearSession() {
    _notifications = [];
    _updateUnreadCountLocally();
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final updated = await _repository.markRead(notificationId);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = updated;
      }
      _updateUnreadCountLocally();
      notifyListeners();
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('❌ Marquage lu de $notificationId: ${e.code}');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllRead();
      _notifications = _notifications.map(_asRead).toList();
      _updateUnreadCountLocally();
      notifyListeners();
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('❌ Marquage global lu: ${e.code}');
    }
  }

  List<eccore.AppNotification> parGenre(GenreNotification genre) {
    return _notifications.where((n) => n.genre == genre).toList();
  }

  List<eccore.AppNotification> getUnreadNotifications() {
    return _notifications.where((n) => !n.isRead).toList();
  }

  List<eccore.AppNotification> getNotificationsByPeriod({
    required DateTime start,
    required DateTime end,
  }) {
    return _notifications
        .where((n) => n.createdAt.isAfter(start) && n.createdAt.isBefore(end))
        .toList();
  }

  List<eccore.AppNotification> searchNotifications(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _notifications.where((n) {
      return n.title.toLowerCase().contains(lowercaseQuery) ||
          n.body.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  Map<String, int> getNotificationStats() {
    final stats = <String, int>{
      'total': _notifications.length,
      'unread': _unreadCount,
      'read': _notifications.where((n) => n.isRead).length,
    };

    for (final genre in GenreNotification.values) {
      stats[genre.name] = _notifications.where((n) => n.genre == genre).length;
    }

    return stats;
  }

  /// Le socle sait se marquer lu — inutile de recopier tous les champs pour
  /// n'en changer qu'un, et l'heure de lecture arrive avec.
  eccore.AppNotification _asRead(eccore.AppNotification notification) =>
      notification.asRead(DateTime.now());

  /// Recompte sur l'état en mémoire — utilisé après un marquage, dont on
  /// connaît l'effet exact, plutôt que de refaire un aller-retour.
  void _updateUnreadCountLocally() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    _unreadCountController.add(_unreadCount);
  }
}
