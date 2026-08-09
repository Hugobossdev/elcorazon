import 'package:admin/utils/price_formatter.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as socle;
import 'package:flutter_test/flutter_test.dart';

/// Affichage des montants — la délégation vers le socle (lot 2.2).
///
/// Le sujet du test n'est pas la règle de formatage : elle est établie et
/// testée dans `elcorazon_core` (`money_test.dart`). Ce qui est vérifié ici,
/// c'est qu'il n'en reste **qu'une** — le back-office avait la sienne, et une
/// même commande s'affichait « 12 500 CFA » ici et « 12.500 CFA » chez le
/// client.
///
/// C'est aussi ce qui empêche la règle de se reforker : quiconque
/// réimplémenterait le formatage ici ferait rougir ces tests.
void main() {
  // Espace insécable étroite (U+202F) et non l'espace ordinaire qu'utilisait le
  // formateur remplacé : un montant ne doit pas pouvoir être coupé en fin de
  // ligne. C'est aussi ce qui a imposé d'élargir le nettoyage de l'export CSV.
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

  group('Ce que la délégation change ici', () {
    test('le séparateur de milliers est insécable', () {
      expect(PriceFormatter.format(12500), '12${nbsp}500 CFA');
      expect(PriceFormatter.format(1234567), '1${nbsp}234${nbsp}567 CFA');
    });

    test('en deçà de mille, aucun séparateur', () {
      expect(PriceFormatter.format(0), '0 CFA');
      expect(PriceFormatter.format(999), '999 CFA');
    });

    test('un montant négatif garde son signe au lieu d’être écrasé', () {
      // Le formateur remplacé rendait « 0 CFA ». Un avoir, un remboursement ou
      // un ajustement sont légitimement négatifs, et masquer le signe d'un
      // montant dans un back-office comptable est la pire des réponses.
      expect(PriceFormatter.format(-500), '-500 CFA');
      expect(PriceFormatter.format(-1500), '-1${nbsp}500 CFA');
    });

    test('NaN et l’infini ne représentent aucun montant', () {
      expect(PriceFormatter.format(double.nan), '0 CFA');
      expect(PriceFormatter.format(double.infinity), '0 CFA');
    });

    test('le franc CFA n’a pas de centime à afficher', () {
      expect(PriceFormatter.format(1250.4), '1${nbsp}250 CFA');
      expect(PriceFormatter.format(1250.6), '1${nbsp}251 CFA');
    });
  });

  group('Export CSV', () {
    test(r'le séparateur de milliers se retire par \s, pas par un espace', () {
      // `_exportOrders` nettoie le montant avant de l'écrire dans la cellule.
      // La règle est privée à l'écran ; ce qui se teste ici, c'est l'hypothèse
      // dont elle dépend — sans quoi l'espace insécable filerait au tableur.
      final montant = PriceFormatter.format(12500);
      expect(montant.replaceAll(RegExp(r'\s'), ''), '12500CFA');
      expect(montant.replaceAll(' ', ''), isNot('12500CFA'));
    });
  });
}
