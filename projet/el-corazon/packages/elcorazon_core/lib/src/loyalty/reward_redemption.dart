import 'reward.dart';

/// Échange passé — miroir de `RewardRedemptionSerializer`. `promotionCode`
/// est le code à recopier au panier ; il reste lisible ici même si la
/// promotion sous-jacente a expiré et été purgée du catalogue.
class RewardRedemption {
  const RewardRedemption({
    required this.id,
    required this.reward,
    required this.pointsSpent,
    required this.promotionCode,
    required this.createdAt,
  });

  factory RewardRedemption.fromJson(Map<String, dynamic> json) {
    return RewardRedemption(
      id: json['id'] as String,
      reward: Reward.fromJson(json['reward'] as Map<String, dynamic>),
      pointsSpent: json['points_spent'] as int,
      promotionCode: json['promotion_code'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final Reward reward;
  final int pointsSpent;
  final String promotionCode;
  final DateTime createdAt;
}
