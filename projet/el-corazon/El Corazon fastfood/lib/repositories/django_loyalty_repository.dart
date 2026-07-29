import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/models/loyalty_reward.dart';
import 'package:elcora_fast/models/loyalty_transaction.dart';

/// Fidélité contre le backend Django (Phase 6). Tout est en lecture seule
/// sauf [redeem] : un point ne s'obtient qu'à la livraison d'une commande
/// (côté serveur) et ne se dépense qu'en échangeant une récompense — jamais
/// par un calcul côté client (C1).
class DjangoLoyaltyRepository {
  DjangoLoyaltyRepository() : _loyalty = eccore.LoyaltyRepository(apiClient: apiClient);

  final eccore.LoyaltyRepository _loyalty;

  Future<int> getAccountBalance() async {
    final account = await _loyalty.getAccount();
    return account.balance;
  }

  Future<List<LoyaltyReward>> getRewards() async {
    final rewards = await _loyalty.getRewards();
    return rewards.map(_toLocalReward).toList();
  }

  Future<List<LoyaltyTransaction>> getTransactions() async {
    final entries = await _loyalty.getEntries();
    return entries.map(_toLocalTransaction).toList();
  }

  Future<bool> redeem(String rewardId) async {
    try {
      await _loyalty.redeem(rewardId);
      return true;
    } on eccore.ApiException catch (_) {
      // Solde insuffisant (409) ou récompense introuvable/inactive (404) —
      // l'appelant n'a besoin que de savoir que l'échange n'a pas eu lieu.
      return false;
    }
  }

  LoyaltyReward _toLocalReward(eccore.Reward reward) {
    return LoyaltyReward(
      id: reward.id,
      title: reward.name,
      description: reward.description,
      cost: reward.pointsCost,
      type: _toLocalRewardType(reward.kind),
      value: reward.discount.toMajorUnits(),
    );
  }

  /// `RewardKind` côté serveur ne connaît que `discount`/`free_delivery` — le
  /// reste de l'énumération locale (`freeItem`, `cashback`, `exclusiveOffer`)
  /// n'a pas d'équivalent et ne sera jamais produit par ce mapping.
  LoyaltyRewardType _toLocalRewardType(String kind) {
    switch (kind) {
      case 'free_delivery':
        return LoyaltyRewardType.freeDelivery;
      case 'discount':
      default:
        return LoyaltyRewardType.discount;
    }
  }

  LoyaltyTransaction _toLocalTransaction(eccore.PointsEntry entry) {
    return LoyaltyTransaction(
      id: entry.id,
      userId: '',
      type: _toLocalEntryKind(entry.kind),
      points: entry.delta,
      description: entry.description,
      createdAt: entry.createdAt,
    );
  }

  LoyaltyTransactionType _toLocalEntryKind(String kind) {
    switch (kind) {
      case 'earned':
        return LoyaltyTransactionType.earn;
      case 'spent':
        return LoyaltyTransactionType.redeem;
      case 'expired':
        return LoyaltyTransactionType.expiration;
      case 'adjusted':
      default:
        return LoyaltyTransactionType.adjustment;
    }
  }
}
