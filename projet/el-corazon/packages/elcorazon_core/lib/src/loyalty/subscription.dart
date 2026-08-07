import 'package:elcorazon_core/src/models/money.dart';

/// Plan tarifé du catalogue — miroir de `SubscriptionPlanSerializer`.
///
/// Le prix vient d'ici et de nulle part ailleurs (P4) : souscrire n'envoie
/// qu'un identifiant de plan, jamais un montant.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.billingPeriodDays,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: Money.fromJson(json['price'] as Map<String, dynamic>),
      billingPeriodDays: json['billing_period_days'] as int,
    );
  }

  final String id;
  final String name;
  final String description;
  final Money price;
  final int billingPeriodDays;
}

/// Abonnement d'un client à un plan — miroir de `SubscriptionSerializer`.
class Subscription {
  const Subscription({
    required this.id,
    required this.plan,
    required this.status,
    required this.autoRenew,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.createdAt,
    this.cancelledAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      plan: SubscriptionPlan.fromJson(json['plan'] as Map<String, dynamic>),
      status: json['status'] as String,
      autoRenew: json['auto_renew'] as bool,
      currentPeriodStart: DateTime.parse(json['current_period_start'] as String),
      currentPeriodEnd: DateTime.parse(json['current_period_end'] as String),
      cancelledAt:
          json['cancelled_at'] == null ? null : DateTime.parse(json['cancelled_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final SubscriptionPlan plan;

  /// `pending` | `active` | `cancelled` | `expired` (`SubscriptionStatus`).
  /// `pending` est un abonnement ouvert dont le premier paiement n'a pas
  /// encore abouti : il ne donne aucun droit.
  final String status;
  final bool autoRenew;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime? cancelledAt;
  final DateTime createdAt;

  /// Droit ouvert *à cet instant*. Le statut ne suffit pas : un abonnement
  /// reste `active` en base jusqu'à ce que la tâche de renouvellement passe,
  /// donc la période est vérifiée aussi. Un `cancelled` avec `auto_renew` à
  /// faux garde ses droits jusqu'au terme déjà payé — c'est voulu.
  bool get isCurrent {
    final now = DateTime.now();
    return (status == 'active' || status == 'cancelled') &&
        now.isBefore(currentPeriodEnd) &&
        !now.isBefore(currentPeriodStart);
  }
}

/// Réponse d'une souscription — miroir de `SubscriptionResultSerializer`.
///
/// L'abonnement naît `pending` : c'est le règlement, via [checkoutUrl] ou les
/// [instructions] du fournisseur, qui l'active — jamais le client.
class SubscriptionResult {
  const SubscriptionResult({
    required this.subscription,
    this.checkoutUrl,
    this.instructions,
  });

  factory SubscriptionResult.fromJson(Map<String, dynamic> json) {
    return SubscriptionResult(
      subscription: Subscription.fromJson(json['subscription'] as Map<String, dynamic>),
      checkoutUrl: json['checkout_url'] as String?,
      instructions: json['instructions'] as String?,
    );
  }

  final Subscription subscription;
  final String? checkoutUrl;
  final String? instructions;
}
