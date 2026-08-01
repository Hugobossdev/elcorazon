import '../models/money.dart';

/// Fiche chiffrée d'un client — miroir de `CustomerStatsSerializer`
/// (`GET /analytics/reports/customers/{id}/`).
///
/// Tout est calculé côté serveur. L'implémentation précédente chargeait les
/// commandes, les adresses et les points depuis le navigateur pour en faire la
/// somme : cinq requêtes, et un panier moyen qui ne portait que sur la page
/// affichée — il changeait quand on tournait la page.
class CustomerStats {
  const CustomerStats({
    required this.ordersCount,
    required this.ordersDelivered,
    required this.ordersCancelled,
    required this.totalSpent,
    required this.averageBasket,
    required this.addressesCount,
    required this.loyaltyBalance,
    required this.loyaltyLifetimeEarned,
    this.firstOrderAt,
    this.lastOrderAt,
  });

  factory CustomerStats.fromJson(Map<String, dynamic> json) {
    return CustomerStats(
      ordersCount: json['orders_count'] as int,
      ordersDelivered: json['orders_delivered'] as int,
      ordersCancelled: json['orders_cancelled'] as int,
      totalSpent: Money.fromJson(json['total_spent'] as Map<String, dynamic>),
      averageBasket: Money.fromJson(
        json['average_basket'] as Map<String, dynamic>,
      ),
      firstOrderAt: _date(json['first_order_at']),
      lastOrderAt: _date(json['last_order_at']),
      addressesCount: json['addresses_count'] as int,
      loyaltyBalance: json['loyalty_balance'] as int,
      loyaltyLifetimeEarned: json['loyalty_lifetime_earned'] as int,
    );
  }

  final int ordersCount;
  final int ordersDelivered;
  final int ordersCancelled;

  /// Somme des commandes **livrées** seulement : une commande annulée n'a rien
  /// encaissé, et une commande en cours n'a rien encaissé *encore*.
  final Money totalSpent;
  final Money averageBasket;
  final DateTime? firstOrderAt;
  final DateTime? lastOrderAt;
  final int addressesCount;
  final int loyaltyBalance;
  final int loyaltyLifetimeEarned;

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
