import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as socle;
import 'package:flutter_test/flutter_test.dart';

/// Affichage des montants — la délégation vers le socle (lot 2.2).
///
/// Le sujet du test n'est pas la règle de formatage : elle est établie et
/// testée dans `elcorazon_core` (`money_test.dart`). Ce qui est vérifié ici,
/// c'est qu'il n'en reste **qu'une** — l'application avait la sienne, qui
/// rendait « 12.500 CFA » là où le back-office rendait « 12 500 CFA », et une
/// même commande s'affichait donc de deux façons selon l'écran qui la montrait.
///
/// C'est aussi ce qui empêche la règle de se reforker : quiconque
/// réimplémenterait le formatage ici ferait rougir ces tests.
void main() {
  // Espace insécable étroite (U+202F), pas une espace ordinaire ni un point :
  // un montant ne doit pas pouvoir être coupé en fin de ligne.
  const nbsp = ' ';

  group('Délégation au socle', () {
    test('le rendu est celui du socle, montant pour montant', () {
      for (final montant in [
        0.0,
        999.0,
        1000.0,
        12500.0,
        1234567.0,
        -1500.0,
        1250.4,
      ]) {
        expect(PriceFormatter.format(montant), socle.formatPrice(montant));
        expect(formatPrice(montant), socle.formatPrice(montant));
      }
    });

    test('un Money du socle rend la même chose que son unité majeure', () {
      // Le lot 3 remplacera ces `double` par des `Money` : les deux chemins
      // doivent déjà converger, sans quoi la migration changerait l'affichage.
      const montant = socle.Money(amountMinor: 12500, currency: 'XOF');
      expect(PriceFormatter.format(montant.toMajorUnits()), montant.format());
    });
  });

  group('Ce que la délégation corrige', () {
    test('les milliers sont séparés par une espace, non par un point', () {
      // Rendait « 12.500 CFA » avant le lot 2.2.
      expect(PriceFormatter.format(12500), '12${nbsp}500 CFA');
      expect(PriceFormatter.format(1234567), '1${nbsp}234${nbsp}567 CFA');
    });

    test('en deçà de mille, aucun séparateur', () {
      expect(PriceFormatter.format(0), '0 CFA');
      expect(PriceFormatter.format(999), '999 CFA');
    });

    test('un montant négatif garde son signe', () {
      // Rendait « -.500 CFA » avant le lot 2.2 : le signe tombait dans le
      // découpage par groupes de trois.
      expect(PriceFormatter.format(-500), '-500 CFA');
      expect(PriceFormatter.format(-1500), '-1${nbsp}500 CFA');
    });

    test('NaN et l’infini ne représentent aucun montant', () {
      // Rendaient « NaN CFA » et « Infinity CFA » avant le lot 2.2.
      expect(PriceFormatter.format(double.nan), '0 CFA');
      expect(PriceFormatter.format(double.infinity), '0 CFA');
    });

    test('le franc CFA n’a pas de centime à afficher', () {
      expect(PriceFormatter.format(1250.4), '1${nbsp}250 CFA');
      expect(PriceFormatter.format(1250.6), '1${nbsp}251 CFA');
    });
  });
}
