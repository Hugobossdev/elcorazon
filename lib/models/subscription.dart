import 'package:uuid/uuid.dart';

class Subscription {
  final String id;
  final String userId;
  final String subscriptionType; // 'weekly', 'monthly'
  final String planName;
  final int mealsPerWeek;
  final double pricePerMeal;
  final double monthlyPrice;
  final String status; // 'active', 'paused', 'cancelled', 'expired'
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final int mealsUsedThisPeriod;
  final bool autoRenew;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subscription({
    required this.userId, required this.subscriptionType, required this.mealsPerWeek, required this.pricePerMeal, required this.monthlyPrice, required this.currentPeriodStart, required this.currentPeriodEnd, String? id,
    this.planName = 'Burger Pass',
    this.status = 'active',
    this.mealsUsedThisPeriod = 0,
    this.autoRenew = true,
    this.cancelledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      subscriptionType: json['subscription_type'] as String,
      planName: json['plan_name'] as String? ?? 'Burger Pass',
      mealsPerWeek: json['meals_per_week'] as int,
      pricePerMeal: (json['price_per_meal'] as num).toDouble(),
      monthlyPrice: (json['monthly_price'] as num).toDouble(),
      status: json['status'] as String? ?? 'active',
      currentPeriodStart: DateTime.parse(json['current_period_start'] as String),
      currentPeriodEnd: DateTime.parse(json['current_period_end'] as String),
      mealsUsedThisPeriod: json['meals_used_this_period'] as int? ?? 0,
      autoRenew: json['auto_renew'] as bool? ?? true,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'subscription_type': subscriptionType,
      'plan_name': planName,
      'meals_per_week': mealsPerWeek,
      'price_per_meal': pricePerMeal,
      'monthly_price': monthlyPrice,
      'status': status,
      'current_period_start': currentPeriodStart.toIso8601String(),
      'current_period_end': currentPeriodEnd.toIso8601String(),
      'meals_used_this_period': mealsUsedThisPeriod,
      'auto_renew': autoRenew,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  int get mealsRemaining => mealsPerWeek - mealsUsedThisPeriod;

  bool get canUseMeal => status == 'active' && mealsRemaining > 0;

  bool get isExpired => currentPeriodEnd.isBefore(DateTime.now());

  Duration get timeUntilRenewal => currentPeriodEnd.difference(DateTime.now());

  Subscription copyWith({
    String? id,
    String? userId,
    String? subscriptionType,
    String? planName,
    int? mealsPerWeek,
    double? pricePerMeal,
    double? monthlyPrice,
    String? status,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    int? mealsUsedThisPeriod,
    bool? autoRenew,
    DateTime? cancelledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      planName: planName ?? this.planName,
      mealsPerWeek: mealsPerWeek ?? this.mealsPerWeek,
      pricePerMeal: pricePerMeal ?? this.pricePerMeal,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      status: status ?? this.status,
      currentPeriodStart: currentPeriodStart ?? this.currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      mealsUsedThisPeriod: mealsUsedThisPeriod ?? this.mealsUsedThisPeriod,
      autoRenew: autoRenew ?? this.autoRenew,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final int mealsPerWeek;
  final double monthlyPrice;
  final double pricePerMeal;
  final List<String> features;
  final bool isPopular;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.mealsPerWeek,
    required this.monthlyPrice,
    required this.features,
    this.isPopular = false,
  }) : pricePerMeal = monthlyPrice / (mealsPerWeek * 4); // Approximate

  static List<SubscriptionPlan> getDefaultPlans() {
    return [
      SubscriptionPlan(
        id: 'weekly_5',
        name: 'Burger Pass Hebdomadaire',
        description: '5 repas par semaine à prix fixe',
        mealsPerWeek: 5,
        monthlyPrice: 15000.0, // XOF
        features: [
          '5 repas par semaine',
          'Prix fixe avantageux',
          'Renouvellement automatique',
          'Annulation possible',
        ],
      ),
      SubscriptionPlan(
        id: 'monthly_5',
        name: 'Burger Pass Mensuel',
        description: '5 repas par semaine pendant 1 mois',
        mealsPerWeek: 5,
        monthlyPrice: 50000.0, // XOF
        features: [
          '5 repas par semaine',
          'Économies jusqu\'à 20%',
          'Renouvellement automatique',
          'Annulation possible',
          'Support prioritaire',
        ],
        isPopular: true,
      ),
      SubscriptionPlan(
        id: 'monthly_10',
        name: 'Burger Pass Premium',
        description: '10 repas par semaine pendant 1 mois',
        mealsPerWeek: 10,
        monthlyPrice: 90000.0, // XOF
        features: [
          '10 repas par semaine',
          'Économies jusqu\'à 30%',
          'Renouvellement automatique',
          'Annulation possible',
          'Support prioritaire',
          'Livraison gratuite',
        ],
      ),
    ];
  }
}

