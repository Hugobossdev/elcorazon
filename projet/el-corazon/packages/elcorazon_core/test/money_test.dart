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
}
