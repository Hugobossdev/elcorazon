enum LoyaltyRewardType {
  discount,
  freeItem,
  freeDelivery,
  cashback,
  exclusiveOffer,
}

class LoyaltyReward {
  final String id;
  final String title;
  final String description;
  final int cost;
  final LoyaltyRewardType type;
  final double? value;
  final bool isActive;
  final String? imageUrl;
  final String? terms;

  const LoyaltyReward({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.type,
    this.value,
    this.isActive = true,
    this.imageUrl,
    this.terms,
  });

  factory LoyaltyReward.fromMap(Map<String, dynamic> map) {
    return LoyaltyReward(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Récompense',
      description: map['description']?.toString() ?? '',
      cost: map['cost'] is int
          ? map['cost'] as int
          : int.tryParse(map['cost']?.toString() ?? '') ?? 0,
      type: _parseType(
        map['reward_type']?.toString() ?? map['type']?.toString(),
      ),
      value: map['value'] != null
          ? (map['value'] is num
              ? (map['value'] as num).toDouble()
              : double.tryParse(map['value'].toString()))
          : null,
      isActive: map['is_active'] as bool? ?? true,
      imageUrl: map['image_url']?.toString(),
      terms: map['terms']?.toString(),
    );
  }

  LoyaltyReward copyWith({
    String? id,
    String? title,
    String? description,
    int? cost,
    LoyaltyRewardType? type,
    double? value,
    bool? isActive,
    String? imageUrl,
    String? terms,
  }) {
    return LoyaltyReward(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      cost: cost ?? this.cost,
      type: type ?? this.type,
      value: value ?? this.value,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
      terms: terms ?? this.terms,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'cost': cost,
      'reward_type': _serializeType(type),
      if (value != null) 'value': value,
      'is_active': isActive,
      if (imageUrl != null) 'image_url': imageUrl,
      if (terms != null) 'terms': terms,
    };
  }

  static LoyaltyRewardType _parseType(String? rawType) {
    switch (rawType) {
      case 'free_item':
        return LoyaltyRewardType.freeItem;
      case 'free_delivery':
        return LoyaltyRewardType.freeDelivery;
      case 'cashback':
        return LoyaltyRewardType.cashback;
      case 'exclusive_offer':
        return LoyaltyRewardType.exclusiveOffer;
      case 'freeItem':
        return LoyaltyRewardType.freeItem;
      case 'freeDelivery':
        return LoyaltyRewardType.freeDelivery;
      case 'exclusiveOffer':
        return LoyaltyRewardType.exclusiveOffer;
      case 'cashBack':
        return LoyaltyRewardType.cashback;
      default:
        return LoyaltyRewardType.discount;
    }
  }

  static String _serializeType(LoyaltyRewardType type) {
    switch (type) {
      case LoyaltyRewardType.freeItem:
        return 'free_item';
      case LoyaltyRewardType.freeDelivery:
        return 'free_delivery';
      case LoyaltyRewardType.cashback:
        return 'cashback';
      case LoyaltyRewardType.exclusiveOffer:
        return 'exclusive_offer';
      case LoyaltyRewardType.discount:
        return 'discount';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LoyaltyReward) return false;
    return other.id == id &&
        other.title == title &&
        other.description == description &&
        other.cost == cost &&
        other.type == type &&
        other.value == value &&
        other.isActive == isActive &&
        other.imageUrl == imageUrl &&
        other.terms == terms;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        cost,
        type,
        value,
        isActive,
        imageUrl,
        terms,
      );
}

