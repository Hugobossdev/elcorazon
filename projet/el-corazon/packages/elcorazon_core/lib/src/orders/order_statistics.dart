import 'package:elcorazon_core/src/analytics/report.dart';

/// Statistiques d'une sélection de commandes — `GET /orders/manage/statistics/`.
///
/// Mêmes filtres et même cloisonnement que la liste. Le back-office calculait
/// ces chiffres en téléchargeant **un an** de commandes ; le serveur les agrège
/// en SQL, selon les règles que l'écran appliquait :
///
/// * la durée de livraison est le réel (`delivered_at − placed_at`) ;
/// * la ponctualité ne se juge que sur les commandes qui portaient une heure
///   annoncée ;
/// * le chiffre d'affaires est **par devise** ([revenues]).
///
/// Les mesures absentes sont **nulles**, pas nulles au sens de zéro : « 0 min »
/// affirmerait une livraison instantanée, « 0 % à l'heure » un échec complet.
class OrderStatistics {
  const OrderStatistics({
    required this.ordersCount,
    required this.byStatus,
    required this.revenues,
    required this.measuredOrders,
    required this.averageMinutes,
    required this.fastestMinutes,
    required this.slowestMinutes,
    required this.onTimeMeasured,
    required this.onTimeRate,
    required this.cancellationRate,
    required this.perDay,
    required this.perDayFrom,
    required this.timezoneName,
  });

  factory OrderStatistics.fromJson(Map<String, dynamic> json) {
    final livraison = json['delivery'] as Map<String, dynamic>;
    double? decimal(Object? valeur) => (valeur as num?)?.toDouble();
    return OrderStatistics(
      ordersCount: json['orders_count'] as int,
      byStatus: {
        for (final entree in (json['by_status'] as Map<String, dynamic>).entries)
          entree.key: (entree.value as num).toInt(),
      },
      revenues: (json['revenues'] as List<dynamic>)
          .map((ligne) => CurrencyRevenue.fromJson(ligne as Map<String, dynamic>))
          .toList(growable: false),
      measuredOrders: livraison['measured_orders'] as int,
      averageMinutes: decimal(livraison['average_minutes']),
      fastestMinutes: decimal(livraison['fastest_minutes']),
      slowestMinutes: decimal(livraison['slowest_minutes']),
      onTimeMeasured: livraison['on_time_measured'] as int,
      onTimeRate: decimal(livraison['on_time_rate']),
      cancellationRate: (json['cancellation_rate'] as num).toDouble(),
      perDay: [
        for (final ligne in json['per_day'] as List<dynamic>)
          (
            day: DateTime.parse((ligne as Map<String, dynamic>)['day'] as String),
            ordersCount: ligne['orders_count'] as int,
          ),
      ],
      perDayFrom: DateTime.parse(json['per_day_from'] as String),
      timezoneName: json['timezone_name'] as String? ?? 'UTC',
    );
  }

  final int ordersCount;

  /// Tous les statuts, à zéro le cas échéant.
  final Map<String, int> byStatus;

  /// Chiffre d'affaires livré, une ligne par devise, la dominante en tête.
  final List<CurrencyRevenue> revenues;

  /// Livraisons horodatées — celles qui ont servi à mesurer les durées.
  final int measuredOrders;
  final double? averageMinutes;
  final double? fastestMinutes;
  final double? slowestMinutes;

  /// Livraisons qui portaient une heure annoncée — la base du taux.
  final int onTimeMeasured;
  final double? onTimeRate;
  final double cancellationRate;

  /// Commandes passées par jour, dans [timezoneName], depuis [perDayFrom].
  final List<({DateTime day, int ordersCount})> perDay;
  final DateTime perDayFrom;
  final String timezoneName;

  int compteDe(String statut) => byStatus[statut] ?? 0;
}
