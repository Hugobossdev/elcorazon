enum LoyaltyTransactionType {
  earn,
  redeem,
  adjustment,
  bonus,
  expiration,
}

class LoyaltyTransaction {
  final String id;
  final String userId;
  final LoyaltyTransactionType type;
  final int points;
  final String description;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const LoyaltyTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.points,
    required this.description,
    required this.createdAt,
    this.metadata,
  });

  factory LoyaltyTransaction.fromMap(Map<String, dynamic> map) {
    return LoyaltyTransaction(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      type: _parseType(
        map['transaction_type']?.toString() ?? map['type']?.toString(),
      ),
      points: map['points'] is int
          ? map['points'] as int
          : int.tryParse(map['points']?.toString() ?? '') ?? 0,
      description: map['description']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      metadata: map['metadata'] is Map<String, dynamic>
          ? map['metadata'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'transaction_type': _serializeType(type),
      'points': points,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  static LoyaltyTransactionType _parseType(String? value) {
    switch (value) {
      case 'earn':
        return LoyaltyTransactionType.earn;
      case 'redeem':
        return LoyaltyTransactionType.redeem;
      case 'bonus':
        return LoyaltyTransactionType.bonus;
      case 'expiration':
        return LoyaltyTransactionType.expiration;
      case 'adjustment':
      default:
        return LoyaltyTransactionType.adjustment;
    }
  }

  static String _serializeType(LoyaltyTransactionType type) {
    switch (type) {
      case LoyaltyTransactionType.earn:
        return 'earn';
      case LoyaltyTransactionType.redeem:
        return 'redeem';
      case LoyaltyTransactionType.bonus:
        return 'bonus';
      case LoyaltyTransactionType.expiration:
        return 'expiration';
      case LoyaltyTransactionType.adjustment:
        return 'adjustment';
    }
  }
}

