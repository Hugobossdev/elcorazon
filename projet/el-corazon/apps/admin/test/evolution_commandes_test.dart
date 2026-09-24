import 'package:admin/presentation/evolution_commandes.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// La série du graphe « Évolution des commandes (7 derniers jours) ».
///
/// Les comptes viennent du serveur (`per_day` de
/// `/orders/manage/statistics/`) ; il reste ici à combler les jours sans
/// commande, que le serveur n'émet pas.
eccore.OrderStatistics _statistiques(List<(String, int)> parJour) {
  return eccore.OrderStatistics.fromJson({
    'orders_count': parJour.fold<int>(0, (total, ligne) => total + ligne.$2),
    'by_status': <String, int>{},
    'revenues': <Map<String, dynamic>>[],
    'delivery': {
      'measured_orders': 0,
      'average_minutes': null,
      'fastest_minutes': null,
      'slowest_minutes': null,
      'on_time_measured': 0,
      'on_time_rate': null,
    },
    'cancellation_rate': 0.0,
    'per_day': [
      for (final (jour, nombre) in parJour) {'day': jour, 'orders_count': nombre},
    ],
    'per_day_from': '2026-07-09',
    'timezone_name': 'Africa/Lome',
  });
}

void main() {
  final aujourdhui = DateTime(2026, 8, 8, 14, 30);

  Map<String, int> serie(List<(String, int)> parJour) =>
      serieQuotidienne(_statistiques(parJour), aujourdhui: aujourdhui);

  test('couvre sept jours, aujourd’hui compris', () {
    final parJour = serie(const []);

    expect(parJour, hasLength(7));
    expect(parJour.keys.first, '2026-08-02');
    expect(parJour.keys.last, '2026-08-08');
  });

  test('les jours sans commande valent zéro, ils ne manquent pas', () {
    expect(serie(const [('2026-08-05', 3)]).values, [0, 0, 0, 3, 0, 0, 0]);
  });

  test('un jour hors de la fenêtre n’ouvre pas de colonne', () {
    final parJour = serie(const [('2026-07-20', 9), ('2026-08-08', 2)]);

    expect(parJour.containsKey('2026-07-20'), isFalse);
    expect(parJour['2026-08-08'], 2);
  });

  test('l’ordre alphabétique des clés est l’ordre chronologique', () {
    final clefs = serie(const []).keys.toList();
    expect(clefs, orderedEquals(List<String>.of(clefs)..sort()));
  });
}
