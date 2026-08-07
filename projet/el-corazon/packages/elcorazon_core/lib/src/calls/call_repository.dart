import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/calls/call.dart';

/// Accès à `/api/v1/calls/*` — voir `backend/apps/calls/views.py`.
///
/// Deux choses n'y voyagent jamais, et c'est le cœur du contrat :
/// * **le destinataire** — il est déduit de la course de la commande. L'ancienne
///   implémentation acceptait un `receiver_id` du client, donc n'importe quel
///   compte pouvait faire sonner n'importe quel autre ;
/// * **le canal RTC** — dérivé de l'appel côté serveur, et différent à chaque
///   nouvel appel sur la même commande.
class CallRepository {
  CallRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Appelle l'autre partie de [orderId] : le livreur si l'appelant est le
  /// client, le client s'il est le livreur.
  ///
  /// Refusé (409) tant qu'aucune livraison n'est en cours, ou si un appel est
  /// déjà ouvert sur cette commande.
  Future<Call> place({required String orderId, String kind = 'voice'}) async {
    final response = await apiClient.post('/calls/orders/$orderId/', data: {'kind': kind});
    return Call.fromJson(response.data as Map<String, dynamic>);
  }

  /// Décrocher — seul le destinataire le peut.
  Future<Call> accept(String callId) async {
    final response = await apiClient.post('/calls/$callId/accept/');
    return Call.fromJson(response.data as Map<String, dynamic>);
  }

  /// Refuser — seul le destinataire le peut.
  Future<Call> decline(String callId) async {
    final response = await apiClient.post('/calls/$callId/decline/');
    return Call.fromJson(response.data as Map<String, dynamic>);
  }

  /// Raccrocher — l'une ou l'autre des deux parties. Un appel qui sonnait
  /// encore devient « manqué », pas « terminé ».
  Future<Call> end(String callId) async {
    final response = await apiClient.post('/calls/$callId/end/');
    return Call.fromJson(response.data as Map<String, dynamic>);
  }

  /// Jeton RTC de l'appelant pour cet appel.
  ///
  /// Demandé au moment de rejoindre le canal : le destinataire n'en a pas tant
  /// qu'il n'a pas décroché, et le serveur refuse d'en délivrer un sur un appel
  /// terminé — sans quoi le canal se rouvrirait après le raccrochage.
  Future<RtcCredentials> rtcCredentials(String callId) async {
    final response = await apiClient.get('/calls/$callId/rtc-token/');
    return RtcCredentials.fromJson(response.data as Map<String, dynamic>);
  }

  /// Historique : les appels auxquels l'appelant a pris part.
  Future<List<Call>> history() async {
    final calls = <Call>[];
    String? path = '/calls/';

    while (path != null) {
      final response = await apiClient.get(path);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      calls.addAll(results.map((json) => Call.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
    }

    return calls;
  }
}
