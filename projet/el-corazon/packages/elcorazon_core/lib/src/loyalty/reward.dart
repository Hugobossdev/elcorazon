import 'package:elcorazon_core/src/models/money.dart';

/// Récompense du catalogue de fidélité — miroir de `RewardSerializer`.
class Reward {
  const Reward({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required this.pointsCost,
    required this.discount,
    required this.validityDays,
    this.restaurantId,
  });

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      kind: json['kind'] as String,
      pointsCost: json['points_cost'] as int,
      discount: Money.fromJson(json['discount'] as Map<String, dynamic>),
      validityDays: json['validity_days'] as int,
      restaurantId: json['restaurant'] as String?,
    );
  }

  final String id;
  final String name;
  final String description;

  /// `discount` | `free_delivery` (`RewardKind` côté serveur — deux valeurs
  /// seulement, contrairement à l'énumération locale plus large).
  final String kind;
  final int pointsCost;
  final Money discount;
  final int validityDays;
  final String? restaurantId;
}
