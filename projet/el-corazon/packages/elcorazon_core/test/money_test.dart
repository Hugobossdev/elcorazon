import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Montants — ADR-007.
///
/// Un montant voyage en **unité mineure**, et son exposant dépend de la
/// devise : le franc CFA n'a pas de décimale, l'euro en a deux. Les deux
/// conversions testées ici sont les seules que les applications ont le droit
/// de faire — afficher une saisie, et transformer une saisie en unité mineure
/// avant de l'envoyer. Tout le reste (additions, remises, frais) se calcule
/// côté serveur.
void main() {
  group('Vers l’unité majeure (affichage)', () {
    test('le franc CFA n’a pas de décimale', () {
      const montant = Money(amountMinor: 1250, currency: 'XOF');
      expect(montant.toMajorUnits(), 1250);
    });

    test('l’euro en a deux', () {
      const montant = Money(amountMinor: 1250, currency: 'EUR');
      expect(montant.toMajorUnits(), 12.50);
    });

    test('une devise inconnue est traitée sans décimale plutôt qu’en erreur', () {
      // Mieux vaut un affichage exact au franc près qu'un écran vide : le
      // serveur reste seul juge de l'exposant, il ne fait que ne pas figurer
      // dans la table locale.
      const montant = Money(amountMinor: 700, currency: 'ZZZ');
      expect(montant.toMajorUnits(), 700);
    });
  });

  group('Depuis une saisie du back-office', () {
    test('un montant en francs CFA passe tel quel', () {
      final montant = Money.fromMajorUnits(12000, 'XOF');
      expect(montant.amountMinor, 12000);
      expect(montant.currency, 'XOF');
    });

    test('un montant en euros est converti en centimes', () {
      expect(Money.fromMajorUnits(12.50, 'EUR').amountMinor, 1250);
    });

    test('l’arrondi ne perd pas le centime que le flottant écorne', () {
      // 12.50 × 100 vaut 1249,999… en virgule flottante : une troncature
      // rendrait 1249, soit un centime perdu à chaque enregistrement.
      expect(Money.fromMajorUnits(12.50, 'EUR').amountMinor, 1250);
      expect(Money.fromMajorUnits(8.20, 'EUR').amountMinor, 820);
      expect(Money.fromMajorUnits(0.29, 'EUR').amountMinor, 29);
    });

    test('l’aller-retour rend la saisie', () {
      for (final saisie in [0.0, 1.0, 999.99, 12345.67]) {
        expect(Money.fromMajorUnits(saisie, 'EUR').toMajorUnits(), saisie);
      }
    });

    test('le format d’envoi est celui qu’attend le serveur', () {
      expect(
        Money.fromMajorUnits(12000, 'XOF').toJson(),
        {'amount': '12000', 'currency': 'XOF'},
      );
    });
  });

  group('Affichage', () {
    // Espace insécable étroite (U+202F), pas une espace ordinaire : un montant
    // ne doit pas pouvoir être coupé en fin de ligne.
    const nbsp = ' ';

    test('les milliers sont séparés', () {
      expect(formatPrice(1000), '1${nbsp}000 CFA');
      expect(formatPrice(12500), '12${nbsp}500 CFA');
      expect(formatPrice(150000), '150${nbsp}000 CFA');
      expect(formatPrice(1234567), '1${nbsp}234${nbsp}567 CFA');
    });

    test('en deçà de mille, aucun séparateur', () {
      expect(formatPrice(0), '0 CFA');
      expect(formatPrice(999), '999 CFA');
    });

    test('le franc CFA s’affiche « CFA » et non « XOF »', () {
      expect(formatPrice(500), '500 CFA');
      expect(formatPrice(500, currency: 'XAF'), '500 CFA');
    });

    test('une devise sans symbole connu garde son code', () {
      expect(formatPrice(500, currency: 'NGN'), '500,00 NGN');
    });

    test('les décimales suivent la devise, pas l’appelant', () {
      // Le franc CFA n'a pas de centime : en afficher laisserait croire à une
      // précision qui n'existe pas.
      expect(formatPrice(1250.4), '1${nbsp}250 CFA');
      expect(formatPrice(12.50, currency: 'EUR'), '12,50 EUR');
      expect(formatPrice(1234.5, currency: 'EUR'), '1${nbsp}234,50 EUR');
    });

    test('l’arrondi se fait sur l’unité mineure, avant le découpage', () {
      // `12.505 €` doit devenir « 12,51 » : arrondir d'abord, découper ensuite.
      // Découper d'abord rendrait « 12,50 ».
      expect(formatPrice(12.505, currency: 'EUR'), '12,51 EUR');
      expect(formatPrice(999.999, currency: 'EUR'), '1${nbsp}000,00 EUR');
    });

    test('un montant négatif garde son signe', () {
      // Les trois formateurs remplacés l'écrasaient à « 0 CFA » ou rendaient
      // « -.500 CFA ». Un avoir est légitimement négatif ; masquer le signe
      // d'un montant est la dernière chose qu'une interface doive faire.
      expect(formatPrice(-1500), '-1${nbsp}500 CFA');
      expect(formatPrice(-500), '-500 CFA');
      expect(formatPrice(-12.50, currency: 'EUR'), '-12,50 EUR');
    });

    test('NaN et l’infini ne représentent aucun montant', () {
      expect(formatPrice(double.nan), '0 CFA');
      expect(formatPrice(double.infinity), '0 CFA');
      expect(formatPrice(double.negativeInfinity), '0 CFA');
    });

    test('Money.format part de l’unité mineure', () {
      expect(const Money(amountMinor: 12500, currency: 'XOF').format(), '12${nbsp}500 CFA');
      expect(const Money(amountMinor: 1250, currency: 'EUR').format(), '12,50 EUR');
      expect(const Money(amountMinor: -1250, currency: 'EUR').format(), '-12,50 EUR');
    });
  });
}
