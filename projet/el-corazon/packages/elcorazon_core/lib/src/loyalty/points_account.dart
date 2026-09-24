/// Solde de fidélité — miroir de `PointsAccountSerializer`
/// (`backend/apps/loyalty/serializers.py`). Singleton par utilisateur, sans
/// id : le compte du porteur du jeton, jamais un autre.
class PointsAccount {
  const PointsAccount({
    required this.balance,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    this.lastActivityAt,
    this.tier,
    this.nextTier,
    this.pointsToNextTier,
  });

  factory PointsAccount.fromJson(Map<String, dynamic> json) {
    return PointsAccount(
      balance: json['balance'] as int,
      lifetimeEarned: json['lifetime_earned'] as int,
      lifetimeSpent: json['lifetime_spent'] as int,
      lastActivityAt:
          json['last_activity_at'] == null ? null : DateTime.parse(json['last_activity_at'] as String),
      tier: LoyaltyTier.tryFromJson(json['tier']),
      nextTier: LoyaltyTier.tryFromJson(json['next_tier']),
      pointsToNextTier: json['points_to_next_tier'] as int?,
    );
  }

  final int balance;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final DateTime? lastActivityAt;

  /// Palier atteint, calculé par le serveur sur [lifetimeEarned] — nul si
  /// l'échelle n'en a pas encore d'atteint. Le client ne le recalcule pas :
  /// il tenait jusqu'ici ses propres seuils, écrits dans son code (BR-006).
  final LoyaltyTier? tier;

  /// Palier suivant, nul au sommet de l'échelle.
  final LoyaltyTier? nextTier;

  /// Points cumulés qui manquent pour [nextTier], nul au sommet.
  final int? pointsToNextTier;
}

/// Un palier de fidélité — `LoyaltyTierSerializer`.
class LoyaltyTier {
  const LoyaltyTier({required this.name, required this.threshold});

  static LoyaltyTier? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return LoyaltyTier(name: json['name'] as String, threshold: json['threshold'] as int);
  }

  final String name;

  /// Points cumulés gagnés à partir desquels le palier est atteint.
  final int threshold;
}
