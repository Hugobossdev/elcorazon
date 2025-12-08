enum PromoCodeType {
  percentage('Pourcentage', '%'),
  fixedAmount('Montant fixe', 'FCFA'),
  freeDelivery('Livraison gratuite', 'Livraison'),
  buyOneGetOne('Achetez un, obtenez un', 'BOGO');

  const PromoCodeType(this.displayName, this.symbol);
  final String displayName;
  final String symbol;
}

enum PromoCodeStatus {
  active('Actif'),
  inactive('Inactif'),
  expired('Expiré'),
  usedUp('Épuisé');

  const PromoCodeStatus(this.displayName);
  final String displayName;
}

class PromoCode {
  final String id;
  final String code;
  final String name;
  final String description;
  final PromoCodeType type;
  final double value;
  final double? minimumOrderAmount;
  final double? maximumDiscountAmount;
  final int? usageLimit;
  final int usageCount;
  final DateTime startDate;
  final DateTime endDate;
  final PromoCodeStatus status;
  final List<String> applicableCategories;
  final List<String> applicableItems;
  final bool isForNewUsersOnly;
  final DateTime createdAt;
  final DateTime updatedAt;

  PromoCode({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.type,
    required this.value,
    required this.usageCount, required this.startDate, required this.endDate, required this.status, required this.applicableCategories, required this.applicableItems, required this.isForNewUsersOnly, required this.createdAt, required this.updatedAt, this.minimumOrderAmount,
    this.maximumDiscountAmount,
    this.usageLimit,
  });

  PromoCode copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    PromoCodeType? type,
    double? value,
    double? minimumOrderAmount,
    double? maximumDiscountAmount,
    int? usageLimit,
    int? usageCount,
    DateTime? startDate,
    DateTime? endDate,
    PromoCodeStatus? status,
    List<String>? applicableCategories,
    List<String>? applicableItems,
    bool? isForNewUsersOnly,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromoCode(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      value: value ?? this.value,
      minimumOrderAmount: minimumOrderAmount ?? this.minimumOrderAmount,
      maximumDiscountAmount:
          maximumDiscountAmount ?? this.maximumDiscountAmount,
      usageLimit: usageLimit ?? this.usageLimit,
      usageCount: usageCount ?? this.usageCount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      applicableCategories: applicableCategories ?? this.applicableCategories,
      applicableItems: applicableItems ?? this.applicableItems,
      isForNewUsersOnly: isForNewUsersOnly ?? this.isForNewUsersOnly,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'type': type.name,
      'value': value,
      'minimum_order_amount': minimumOrderAmount,
      'maximum_discount_amount': maximumDiscountAmount,
      'usage_limit': usageLimit,
      'usage_count': usageCount,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': status.name,
      'applicable_categories': applicableCategories,
      'applicable_items': applicableItems,
      'is_for_new_users_only': isForNewUsersOnly,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PromoCode.fromJson(Map<String, dynamic> json) {
    return PromoCode(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: PromoCodeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PromoCodeType.percentage,
      ),
      value: (json['value'] as num).toDouble(),
      minimumOrderAmount: json['minimum_order_amount'] != null
          ? (json['minimum_order_amount'] as num).toDouble()
          : null,
      maximumDiscountAmount: json['maximum_discount_amount'] != null
          ? (json['maximum_discount_amount'] as num).toDouble()
          : null,
      usageLimit: json['usage_limit'] as int?,
      usageCount: json['usage_count'] as int? ?? 0,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      status: PromoCodeStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PromoCodeStatus.active,
      ),
      applicableCategories:
          List<String>.from(json['applicable_categories'] ?? []),
      applicableItems: List<String>.from(json['applicable_items'] ?? []),
      isForNewUsersOnly: json['is_for_new_users_only'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isValid {
    final now = DateTime.now();
    return status == PromoCodeStatus.active &&
        now.isAfter(startDate) &&
        now.isBefore(endDate) &&
        (usageLimit == null || usageCount < usageLimit!);
  }

  bool get isExpired => DateTime.now().isAfter(endDate);

  bool get isUsedUp => usageLimit != null && usageCount >= usageLimit!;

  double calculateDiscount(double orderAmount) {
    if (!isValid || orderAmount < (minimumOrderAmount ?? 0)) {
      return 0.0;
    }

    double discount = 0.0;

    switch (type) {
      case PromoCodeType.percentage:
        discount = orderAmount * (value / 100);
        break;
      case PromoCodeType.fixedAmount:
        discount = value;
        break;
      case PromoCodeType.freeDelivery:
        // La livraison gratuite sera gérée séparément
        discount = 0.0;
        break;
      case PromoCodeType.buyOneGetOne:
        // BOGO sera géré séparément
        discount = 0.0;
        break;
    }

    // Appliquer le montant maximum de réduction si défini
    if (maximumDiscountAmount != null && discount > maximumDiscountAmount!) {
      discount = maximumDiscountAmount!;
    }

    return discount;
  }

  String get discountDescription {
    switch (type) {
      case PromoCodeType.percentage:
        return '${value.toInt()}% de réduction';
      case PromoCodeType.fixedAmount:
        return '${value.toInt()} FCFA de réduction';
      case PromoCodeType.freeDelivery:
        return 'Livraison gratuite';
      case PromoCodeType.buyOneGetOne:
        return 'Achetez un, obtenez un gratuit';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PromoCode && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PromoCode(id: $id, code: $code, name: $name, type: $type, value: $value)';
  }
}

class PromoCodeUsage {
  final String id;
  final String userId;
  final String promoCodeId;
  final String orderId;
  final double discountAmount;
  final DateTime usedAt;

  PromoCodeUsage({
    required this.id,
    required this.userId,
    required this.promoCodeId,
    required this.orderId,
    required this.discountAmount,
    required this.usedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'promo_code_id': promoCodeId,
      'order_id': orderId,
      'discount_amount': discountAmount,
      'used_at': usedAt.toIso8601String(),
    };
  }

  factory PromoCodeUsage.fromJson(Map<String, dynamic> json) {
    return PromoCodeUsage(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      promoCodeId: json['promo_code_id'] as String,
      orderId: json['order_id'] as String,
      discountAmount: (json['discount_amount'] as num).toDouble(),
      usedAt: DateTime.parse(json['used_at'] as String),
    );
  }
}
