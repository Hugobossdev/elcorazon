import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrat de `GET /orders/manage/statistics/`.
///
/// La charge ci-dessous est celle que le serveur a **réellement** rendue le
/// 22 septembre 2026 (base locale, Lomé). Ces chiffres remplacent ceux que le
/// back-office calculait sur un an de commandes téléchargées ; les règles de
/// mesure sont vérifiées côté serveur (`tests/orders/test_statistiques_backoffice.py`).
Map<String, dynamic> _reponseReelle() => {
      'orders_count': 23,
      'by_status': {
        'pending': 1,
        'confirmed': 0,
        'preparing': 3,
        'ready': 8,
        'picked_up': 3,
        'on_the_way': 0,
        'delivered': 7,
        'cancelled': 1,
      },
      'revenues': [
        {
          'currency': 'XOF',
          'orders_delivered': 7,
          'revenue_minor': 30950,
          'average_basket_minor': 4421,
        },
      ],
      'delivery': {
        'measured_orders': 7,
        'average_minutes': 538.0,
        'fastest_minutes': 0.1,
        'slowest_minutes': 3715.0,
        'on_time_measured': 5,
        'on_time_rate': 100.0,
      },
      'cancellation_rate': 4.3,
      'per_day': [
        {'day': '2026-08-31', 'orders_count': 4},
        {'day': '2026-09-20', 'orders_count': 8},
      ],
      'per_day_from': '2026-08-23',
      'timezone_name': 'Africa/Lome',
    };

void main() {
  test('la réponse réelle se lit entière', () {
    final stats = OrderStatistics.fromJson(_reponseReelle());

    expect(stats.ordersCount, 23);
    expect(stats.compteDe('ready'), 8);
    expect(stats.revenues.single.currency, 'XOF');
    expect(stats.revenues.single.averageBasketMinor, 4421);
    expect(stats.measuredOrders, 7);
    expect(stats.averageMinutes, 538.0);
    expect(stats.onTimeRate, 100.0);
    expect(stats.cancellationRate, 4.3);
    expect(stats.perDay.last.day, DateTime(2026, 9, 20));
    expect(stats.perDay.last.ordersCount, 8);
    expect(stats.timezoneName, 'Africa/Lome');
  });

  test('sans livraison mesurée, les durées restent nulles — pas zéro', () {
    final json = _reponseReelle()
      ..['delivery'] = {
        'measured_orders': 0,
        'average_minutes': null,
        'fastest_minutes': null,
        'slowest_minutes': null,
        'on_time_measured': 0,
        'on_time_rate': null,
      }
      ..['revenues'] = <Map<String, dynamic>>[];

    final stats = OrderStatistics.fromJson(json);

    expect(stats.averageMinutes, isNull);
    expect(stats.onTimeRate, isNull);
    expect(stats.revenues, isEmpty);
  });

  test('un statut absent vaut zéro', () {
    expect(OrderStatistics.fromJson(_reponseReelle()).compteDe('inconnu'), 0);
  });
}
