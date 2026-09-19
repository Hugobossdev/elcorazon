import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le bilan d'une campagne — taux d'ouverture, de conversion, chiffre.
///
/// Demandés par le cahier des charges (§4.2.7), jamais calculés : l'écran ne
/// montrait que le nombre de destinataires.
void main() {
  test('un bilan se lit, chiffre par devise', () {
    final bilan = CampaignStats.fromJson({
      'recipients': 200,
      'read': 50,
      'open_rate': 0.25,
      'window_days': 7,
      'customers_who_ordered': 12,
      'conversion_rate': 0.06,
      'revenue': [
        {'amount': '84000', 'currency': 'XOF'},
        {'amount': '1200', 'currency': 'GHS'},
      ],
    });

    expect(bilan.openRate, 0.25);
    expect(bilan.revenue.map((m) => m.currency), ['XOF', 'GHS']);
    expect(bilan.revenue.first.amountMinor, 84000);
  });

  test('sans destinataire, les taux sont absents, pas nuls', () {
    // Un taux sur zéro destinataire n'est pas 0 % : il n'existe pas.
    final bilan = CampaignStats.fromJson({
      'recipients': 0,
      'read': 0,
      'open_rate': null,
      'window_days': 7,
      'customers_who_ordered': 0,
      'conversion_rate': null,
      'revenue': <Object>[],
    });

    expect(bilan.openRate, isNull);
    expect(bilan.conversionRate, isNull);
  });
}
