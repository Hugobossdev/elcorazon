import 'package:elcorazon_core/src/network/api_client.dart';

/// Accès à `/api/v1/analytics/events/` — voir `backend/apps/analytics/views.py`.
///
/// Écriture seule côté client : les rapports (chiffre d'affaires, articles,
/// livreurs) sont réservés à l'exploitation et n'ont rien à faire dans une app
/// cliente.
class AnalyticsRepository {
  AnalyticsRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Consigne un événement d'usage.
  ///
  /// L'auteur n'est pas un champ du corps : le serveur le déduit du jeton, et
  /// accepte l'événement même sans compte (visite anonyme du catalogue).
  /// L'implémentation Supabase envoyait un `user_id` choisi par le client,
  /// qui pouvait donc attribuer son activité à quelqu'un d'autre.
  ///
  /// N'échoue jamais du fait du serveur : un `event_type` inconnu est accepté
  /// (201) plutôt que refusé — mesurer ne doit pas casser ce qu'on mesure.
  Future<void> record({
    required String eventType,
    Map<String, dynamic> eventData = const {},
    String sessionId = '',
  }) async {
    await apiClient.post(
      '/analytics/events/',
      data: {
        'event_type': eventType,
        'event_data': eventData,
        if (sessionId.isNotEmpty) 'session_id': sessionId,
      },
    );
  }
}
