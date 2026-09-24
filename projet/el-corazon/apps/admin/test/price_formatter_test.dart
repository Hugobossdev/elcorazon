import 'package:admin/utils/price_formatter.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as socle;
import 'package:flutter_test/flutter_test.dart';

/// Affichage des montants du back-office — **toujours avec leur devise**.
///
/// Le back-office formatait n'importe quel `double` en francs CFA d'Afrique de
/// l'Ouest. Depuis l'ouverture de Douala et Yaoundé, une commande en XAF
/// s'affichait comme une somme togolaise. Ces tests fixent les deux règles :
/// la règle de formatage reste celle du socle (une seule), et le code ISO de
/// la devise est toujours écrit.
void main() {
  /// L'espace des milliers d'`intl` change avec sa version — insécable
  /// (U+00A0) hier, insécable étroite (U+202F) aujourd'hui. Ce n'est pas ce
  /// que ces cas vérifient : ils portent sur le **groupement** et sur le code
  /// ISO. Le figer à l'octet près ferait échouer la suite à chaque montée de
  /// version pour une différence que personne ne voit.
  String lisible(String montant) =>
      montant.replaceAll(RegExp('[\u{00A0}\u{202F}\u{2009}]'), ' ');

  test('un montant du serveur garde sa devise', () {
    expect(
      lisible(formatMontant(const socle.Money(amountMinor: 12500, currency: 'XOF'))),
      '12 500 XOF',
    );
    expect(
      lisible(formatMontant(const socle.Money(amountMinor: 12500, currency: 'XAF'))),
      '12 500 XAF',
    );
  });

  test('XOF et XAF, que « CFA » confondait, se distinguent', () {
    const lome = socle.Money(amountMinor: 4000, currency: 'XOF');
    const douala = socle.Money(amountMinor: 4000, currency: 'XAF');

    expect(lome.format(), douala.format());
    expect(formatMontant(lome), isNot(formatMontant(douala)));
  });

  test('une devise à décimales garde ses centimes', () {
    expect(formatMontant(const socle.Money(amountMinor: 1250, currency: 'EUR')), '12,50 EUR');
    expect(formatMajeur(12.5, 'EUR'), '12,50 EUR');
  });

  test('un montant négatif garde son signe', () {
    expect(lisible(formatMajeur(-1500, 'XOF')), '-1 500 XOF');
  });

  test('la règle de découpage est celle du socle', () {
    for (final montant in [0.0, 999.0, 1000.0, 1234567.0, -1500.0]) {
      expect(
        formatMajeur(montant, 'XOF'),
        socle.formatPrice(montant, currency: 'XOF', codeIso: true),
      );
    }
  });

  group('La saisie suit la devise, pas un marché écrit en dur', () {
    test('le pré-remplissage garde les décimales de la devise', () {
      expect(montantPourSaisie(1500, 'XOF'), '1500');
      expect(montantPourSaisie(1.5, 'EUR'), '1.50');
      expect(montantPourSaisie(12.5, 'GHS'), '12.50');
    });

    test('un franc sans subdivision refuse les centimes, XAF et GNF compris', () {
      for (final devise in ['XOF', 'XAF', 'GNF']) {
        expect(erreurDePrecision(1500, devise), isNull, reason: devise);
        expect(erreurDePrecision(1500.5, devise), isNotNull, reason: devise);
      }
    });

    test('une devise à deux décimales en accepte deux, pas trois', () {
      expect(erreurDePrecision(12.5, 'EUR'), isNull);
      expect(erreurDePrecision(12.505, 'EUR'), isNotNull);
    });
  });
}
