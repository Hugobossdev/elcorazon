import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/notifications/app_notification.dart';

/// Accès à `/api/v1/notifications/*` — voir
/// `backend/apps/notifications/views.py`.
///
/// Lecture seule, plus un marquage. Trois gestes que l'implémentation Supabase
/// se permettait n'existent pas ici, et c'est délibéré côté serveur : écrire
/// une notification (elle est produite par le backend, y compris les messages
/// de bienvenue et de promotion), en supprimer une, et purger l'historique.
class NotificationRepository {
  NotificationRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Historique de l'appelant, les plus récentes d'abord (tri du serveur).
  /// [kind] filtre sur `NotificationKind`.
  Future<List<AppNotification>> getNotifications({String? kind}) async {
    final notifications = <AppNotification>[];
    String? path = '/notifications/';
    Map<String, dynamic>? queryParameters = kind == null ? null : {'kind': kind};

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      notifications.addAll(
        results.map((json) => AppNotification.fromJson(json as Map<String, dynamic>)),
      );
      path = body['next'] as String?;
      queryParameters = null;
    }

    return notifications;
  }

  /// Compteur de la pastille. Route dédiée plutôt qu'un décompte local : la
  /// liste est paginée, compter les non-lues d'une page donnerait un nombre
  /// faux dès la vingt-et-unième.
  Future<int> getUnreadCount() async {
    final response = await apiClient.get('/notifications/unread-count/');
    return (response.data as Map<String, dynamic>)['unread'] as int;
  }

  /// Idempotent côté serveur : relire n'écrase pas la date de première
  /// lecture.
  Future<AppNotification> markRead(String notificationId) async {
    final response = await apiClient.post('/notifications/$notificationId/read/');
    return AppNotification.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> markAllRead() async {
    await apiClient.post('/notifications/read-all/');
  }
}
