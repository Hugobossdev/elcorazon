import 'package:admin/services/analytics_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Le graphique « livraisons par livreur » de l'écran Analyses.
///
/// Le rapport rend une ligne par livreur **et par devise**. Indexées par nom,
/// ces lignes s'écrasaient : un livreur payé en deux devises perdait une partie
/// de ses courses, et deux homonymes n'en faisaient qu'un.
void main() {
  eccore.CourierPerformanceRow ligne(
    String id,
    String nom,
    int livraisons, {
    String devise = 'XOF',
  }) =>
      eccore.CourierPerformanceRow(
        courierId: id,
        courierName: nom,
        currency: devise,
        deliveries: livraisons,
        earningsMinor: 0,
      );

  test('un livreur payé en deux devises : ses courses s’additionnent', () {
    final parLivreur = AnalyticsService.livraisonsParLivreur([
      ligne('id-kofi-0001', 'Kofi', 7),
      ligne('id-kofi-0001', 'Kofi', 3, devise: 'XAF'),
    ]);

    expect(parLivreur, {'Kofi': 10});
  });

  test('deux homonymes restent deux barres, distinguées par leur identifiant', () {
    final parLivreur = AnalyticsService.livraisonsParLivreur([
      ligne('id-aaaa-1111', 'Kofi', 4),
      ligne('id-bbbb-2222', 'Kofi', 9),
      ligne('id-cccc-3333', 'Aya', 2),
    ]);

    expect(parLivreur, {'Kofi (…1111)': 4, 'Kofi (…2222)': 9, 'Aya': 2});
  });

  test('aucune ligne, aucune barre', () {
    expect(AnalyticsService.livraisonsParLivreur(const []), isEmpty);
  });
}
