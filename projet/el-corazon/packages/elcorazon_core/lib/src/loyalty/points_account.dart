/// Solde de fidélité — miroir de `PointsAccountSerializer`
/// (`backend/apps/loyalty/serializers.py`). Singleton par utilisateur, sans
/// id : le compte du porteur du jeton, jamais un autre.
class PointsAccount {
  const PointsAccount({
    required this.balance,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    this.lastActivityAt,
  });

  factory PointsAccount.fromJson(Map<String, dynamic> json) {
    return PointsAccount(
      balance: json['balance'] as int,
      lifetimeEarned: json['lifetime_earned'] as int,
      lifetimeSpent: json['lifetime_spent'] as int,
      lastActivityAt:
          json['last_activity_at'] == null ? null : DateTime.parse(json['last_activity_at'] as String),
    );
  }

  final int balance;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final DateTime? lastActivityAt;
}
