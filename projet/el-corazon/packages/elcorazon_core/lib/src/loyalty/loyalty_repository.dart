import '../network/api_client.dart';
import 'points_account.dart';
import 'points_entry.dart';
import 'reward.dart';
import 'reward_redemption.dart';

/// Accès à `/api/v1/loyalty/*` — voir
/// `backend/apps/loyalty/{serializers,views}.py`. Tout est en lecture seule
/// sauf [redeem] : un point ne s'obtient qu'à la livraison d'une commande
/// (côté serveur, jamais depuis ce repository) et ne se dépense qu'en
/// échangeant une récompense du catalogue (C1 — aucune méthode ici n'accepte
/// de solde ni de coût en entrée).
class LoyaltyRepository {
  LoyaltyRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<PointsAccount> getAccount() async {
    final response = await apiClient.get('/loyalty/account/');
    return PointsAccount.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Reward>> getRewards() async {
    final rewards = <Reward>[];
    String? path = '/loyalty/rewards/';

    while (path != null) {
      final response = await apiClient.get(path);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      rewards.addAll(results.map((json) => Reward.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
    }

    return rewards;
  }

  Future<List<PointsEntry>> getEntries() async {
    final entries = <PointsEntry>[];
    String? path = '/loyalty/entries/';

    while (path != null) {
      final response = await apiClient.get(path);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      entries.addAll(results.map((json) => PointsEntry.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
    }

    return entries;
  }

  /// Corps vide : la récompense est désignée par l'URL, son coût lu en base
  /// côté serveur — rien que l'appelant puisse déclarer à son avantage.
  Future<RewardRedemption> redeem(String rewardId) async {
    final response = await apiClient.post('/loyalty/rewards/$rewardId/redeem/');
    final body = response.data as Map<String, dynamic>;
    return RewardRedemption.fromJson(body['redemption'] as Map<String, dynamic>);
  }
}
