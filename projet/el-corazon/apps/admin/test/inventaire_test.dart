import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/presentation/inventaire.dart';
import 'package:admin/screens/inventaire/ingredients_screen.dart';
import 'package:admin/screens/inventaire/recettes_screen.dart';

/// Ce que les écrans d'inventaire disent et décident, sans widget.
///
/// Aucune de ces fonctions n'applique une règle du serveur : elles disent ce
/// qu'il a fait. Ce que ces cas verrouillent, c'est qu'elles le disent juste —
/// qu'une perte en attente ne s'annonce pas comme écrite, et qu'un bouton de
/// validation ne s'offre pas à qui l'a déclarée.

eccore.AdjustmentRequest _demande({
  String status = 'pending',
  String requestedBy = 'u-1',
  eccore.Money? valeur = const eccore.Money(amountMinor: 8000, currency: 'XOF'),
}) {
  return eccore.AdjustmentRequest(
    id: 'dem-1',
    stockLineId: 'stock-1',
    restaurantSlug: 'el-corazon-lome',
    ingredientName: 'Bœuf',
    kind: 'waste',
    quantity: const eccore.Quantity(amount: '-2000', unit: 'g', dimension: 'mass'),
    reason: 'Froid rompu',
    status: status,
    estimatedValue: valeur,
    requestedById: requestedBy,
    createdAt: DateTime(2026, 9, 13),
  );
}

void main() {
  group('Issue d’une déclaration', () {
    test('une perte en attente ne s’annonce pas comme écrite', () {
      final message = issueDeDeclaration(
        eccore.Declaration(request: _demande()),
        quoi: 'Perte',
      );

      expect(message, startsWith('Perte en attente de validation'));
      expect(message, contains('8'));
      expect(message, isNot(contains('enregistrée')));
    });

    test('un coût inconnu se dit comme la raison de l’attente', () {
      final message = issueDeDeclaration(
        eccore.Declaration(request: _demande(valeur: null)),
        quoi: 'Perte',
      );

      expect(message, contains('coût de cet ingrédient est encore inconnu'));
    });

    test('une perte écrite dit sa quantité', () {
      final mouvement = eccore.StockMovement(
        id: 'mvt-1',
        stockLineId: 'stock-1',
        ingredientName: 'Bœuf',
        kind: 'waste',
        quantity: const eccore.Quantity(amount: '-500', unit: 'g', dimension: 'mass'),
        createdAt: DateTime(2026, 9, 13),
      );

      expect(
        issueDeDeclaration(eccore.Declaration(movement: mouvement), quoi: 'Perte'),
        'Perte enregistrée (-500 g).',
      );
    });
  });

  group('Le quatre-yeux, annoncé', () {
    test('le déclarant ne se voit pas proposer de trancher', () {
      final droit = peutTrancher(demande: _demande(), compteId: 'u-1', aLaPermission: true);

      expect(droit.autorise, isFalse);
      expect(droit.raison, contains('une autre personne'));
    });

    test('sans la permission, pas de bouton non plus', () {
      final droit = peutTrancher(demande: _demande(), compteId: 'u-2', aLaPermission: false);

      expect(droit.autorise, isFalse);
      expect(droit.raison, contains('inventory.approve'));
    });

    test('une autre personne munie de la permission tranche', () {
      expect(
        peutTrancher(demande: _demande(), compteId: 'u-2', aLaPermission: true).autorise,
        isTrue,
      );
    });

    test('une demande déjà tranchée ne se retranche pas', () {
      final droit = peutTrancher(
        demande: _demande(status: 'approved'),
        compteId: 'u-2',
        aLaPermission: true,
      );

      expect(droit.autorise, isFalse);
      expect(droit.raison, 'Demande déjà validée.');
    });
  });

  group('Prix du lot', () {
    test('un prix en francs se lit en unités mineures, espaces admises', () {
      final prix = prixDuLot('12 000', devise: 'XOF');

      expect((prix?.amountMinor, prix?.currency), (12000, 'XOF'));
    });

    test('un champ vide veut dire « pas de prix »', () {
      expect(prixDuLot('  ', devise: 'XOF'), isNull);
    });

    test('des centimes sur une devise sans centimes sont refusés, pas arrondis', () {
      expect(() => prixDuLot('12000,50', devise: 'XOF'), throwsFormatException);
    });

    test('une devise à deux décimales se lit sans flottant', () {
      expect(prixDuLot('12,5', devise: 'EUR')?.amountMinor, 1250);
      expect(prixDuLot('0,05', devise: 'EUR')?.amountMinor, 5);
      expect(() => prixDuLot('1,234', devise: 'EUR'), throwsFormatException);
    });
  });

  group('Libellés', () {
    test('les mouvements, dimensions, unités et statuts se lisent en français', () {
      expect(libelleMouvement('receipt'), 'Réception');
      expect(libelleMouvement('adjustment'), 'Correction');
      expect(libelleMouvement('inconnu'), 'inconnu');
      expect(libelleDimension('volume'), 'Volume');
      expect(libelleUnite('unit'), 'unité(s)');
      expect(libelleUnite('kg'), 'kg');
      expect(libelleStatutDemande('rejected'), 'Refusée');
    });

    test('le coût se dit par son unité, ou se dit inconnu', () {
      expect(libelleCout(null, 'kg'), 'Coût inconnu');
      expect(
        libelleCout(const eccore.Money(amountMinor: 4000, currency: 'XOF'), 'unit'),
        endsWith('/ unité'),
      );
    });

    test('on reçoit en kilogrammes, on retire en grammes', () {
      expect(unitesDeSaisie('mass'), ['g', 'kg']);
      expect(unitesDeSaisie('mass', pourUneLivraison: true), ['kg', 'g']);
      expect(unitesDeSaisie('inconnue'), ['unit']);
    });
  });

  group('Recettes et référentiel', () {
    test('un plat sans recette dit qu’il ne consomme rien', () {
      expect(resumeDeRecette(null), contains('ne consomme rien'));
    });

    test('les recettes s’indexent par leur cible, plat ou option', () {
      const surPlat = eccore.Recipe(
        id: 'r-1',
        targetName: 'Burger',
        restaurantSlug: 'lome',
        lines: [
          eccore.RecipeLine(
            ingredientId: 'i-1',
            ingredientName: 'Oignon',
            quantity: eccore.Quantity(amount: '20', unit: 'g'),
          ),
        ],
        menuItemId: 'item-1',
      );
      const surOption = eccore.Recipe(
        id: 'r-2',
        targetName: 'Sans oignon',
        restaurantSlug: 'lome',
        lines: [],
        optionId: 'opt-1',
      );

      final index = indexerParCible([surPlat, surOption]);

      expect(index.keys, unorderedEquals(['item-1', 'opt-1']));
      expect(resumeDeRecette(index['item-1']), '1 ingrédient');
    });

    test('le slug d’un ingrédient se déduit de son nom', () {
      expect(slugDIngredient('Piment frais d’Afrique'), 'piment-frais-d-afrique');
      expect(slugDIngredient('  Crème fraîche  '), 'creme-fraiche');
      expect(slugDIngredient('Bœuf haché'), 'boeuf-hache');
      expect(slugDIngredient('!!!'), '');
    });

    test('une clé de tentative est stable pour elle-même et différente d’une autre', () {
      final premiere = CleDeTentative();
      final seconde = CleDeTentative();

      expect(premiere.valeur, hasLength(32));
      expect(premiere.valeur, premiere.valeur);
      expect(premiere.valeur, isNot(seconde.valeur));
      expect(CleDeTentative.avec('connue').valeur, 'connue');
    });
  });
}
