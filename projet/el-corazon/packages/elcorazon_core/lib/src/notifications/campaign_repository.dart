import '../network/api_client.dart';
import 'campaign.dart';

/// Campagnes de notifications — `/api/v1/notifications/campaigns/`
/// (`backend/apps/notifications/backoffice.py`), sous `notifications.send`.
///
/// Deux temps, comme pour les codes promotionnels : on **rédige**, puis on
/// **envoie**. Ce n'est pas une lourdeur d'interface mais la seule protection
/// possible contre la faute de frappe dans un message qui part à plusieurs
/// milliers de personnes — un envoi de masse ne se rappelle pas.
class CampaignRepository {
  CampaignRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<Campaign>> list({String? status, String? audience}) async {
    final campagnes = <Campaign>[];
    String? path = '/notifications/campaigns/';
    Map<String, dynamic>? queryParameters = {
      if (status != null) 'status': status,
      if (audience != null) 'audience': audience,
    };

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      campagnes.addAll(
        (body['results'] as List<dynamic>).map(
          (json) => Campaign.fromJson(json as Map<String, dynamic>),
        ),
      );
      path = body['next'] as String?;
      queryParameters = null;
    }

    return campagnes;
  }

  Future<Campaign> getById(String campaignId) async {
    final response = await apiClient.get(
      '/notifications/campaigns/$campaignId/',
    );
    return Campaign.fromJson(response.data as Map<String, dynamic>);
  }

  /// Rédige une campagne. Elle part en brouillon : rien n'est envoyé ici.
  Future<Campaign> create({
    required String title,
    required String body,
    required String audience,
    int segmentDays = 30,
  }) async {
    final response = await apiClient.post(
      '/notifications/campaigns/',
      data: {
        'title': title,
        'body': body,
        'audience': audience,
        'segment_days': segmentDays,
      },
    );
    return Campaign.fromJson(response.data as Map<String, dynamic>);
  }

  /// Corrige un brouillon. Le serveur refuse (403) une campagne déjà envoyée.
  Future<Campaign> update({
    required String campaignId,
    String? title,
    String? body,
    String? audience,
    int? segmentDays,
  }) async {
    final response = await apiClient.patch(
      '/notifications/campaigns/$campaignId/',
      data: {
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (audience != null) 'audience': audience,
        if (segmentDays != null) 'segment_days': segmentDays,
      },
    );
    return Campaign.fromJson(response.data as Map<String, dynamic>);
  }

  /// Combien de personnes cette campagne viserait, si on l'envoyait.
  ///
  /// C'est un **majorant** : le chiffre compte le segment, pas les envois
  /// aboutis, puisque le consentement au marketing ne se vérifie qu'à
  /// l'écriture de chaque notification.
  Future<int> estimateAudience(String campaignId) async {
    final response = await apiClient.get(
      '/notifications/campaigns/$campaignId/audience/',
    );
    return (response.data as Map<String, dynamic>)['recipients'] as int;
  }

  /// Envoie la campagne, une seule fois.
  ///
  /// Le rejeu est absorbé plutôt que refusé : un double clic renvoie la
  /// campagne telle qu'elle est partie, avec son horodatage et son compte, au
  /// lieu d'une erreur qui ferait croire à un échec — et inviterait à
  /// réessayer.
  Future<Campaign> send(String campaignId) async {
    final response = await apiClient.post(
      '/notifications/campaigns/$campaignId/send/',
    );
    return Campaign.fromJson(response.data as Map<String, dynamic>);
  }
}
