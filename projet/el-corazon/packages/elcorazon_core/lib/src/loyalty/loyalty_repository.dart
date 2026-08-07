import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/loyalty/points_account.dart';
import 'package:elcorazon_core/src/loyalty/points_entry.dart';
import 'package:elcorazon_core/src/loyalty/reward.dart';
import 'package:elcorazon_core/src/loyalty/reward_redemption.dart';
import 'package:elcorazon_core/src/loyalty/subscription.dart';

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

  /// Catalogue des plans ouverts à la souscription.
  Future<List<SubscriptionPlan>> getPlans() async {
    final plans = <SubscriptionPlan>[];
    String? path = '/loyalty/plans/';

    while (path != null) {
      final response = await apiClient.get(path);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      plans.addAll(results.map((json) => SubscriptionPlan.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
    }

    return plans;
  }

  /// Les abonnements de l'appelant, courant et passés — le serveur cloisonne
  /// sur le jeton, il n'y a pas d'identifiant à passer.
  Future<List<Subscription>> getSubscriptions() async {
    final subscriptions = <Subscription>[];
    String? path = '/loyalty/subscriptions/';

    while (path != null) {
      final response = await apiClient.get(path);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      subscriptions
          .addAll(results.map((json) => Subscription.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
    }

    return subscriptions;
  }

  /// L'abonnement qui ouvre des droits aujourd'hui, s'il y en a un. Le serveur
  /// garantit qu'il n'y en a jamais deux ouverts à la fois (contrainte de base
  /// sur `Subscription`).
  Future<Subscription?> getCurrentSubscription() async {
    final subscriptions = await getSubscriptions();
    for (final subscription in subscriptions) {
      if (subscription.isCurrent) return subscription;
    }
    return null;
  }

  /// Ouvre un abonnement au plan désigné. Seul l'identifiant du plan voyage :
  /// le montant et la période sont relus en base côté serveur (P4).
  Future<SubscriptionResult> subscribe(String planId) async {
    final response = await apiClient.post(
      '/loyalty/subscriptions/subscribe/',
      data: {'plan': planId},
    );
    return SubscriptionResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Subscription> cancelSubscription(String subscriptionId) async {
    final response = await apiClient.post('/loyalty/subscriptions/$subscriptionId/cancel/');
    return Subscription.fromJson(response.data as Map<String, dynamic>);
  }
}
