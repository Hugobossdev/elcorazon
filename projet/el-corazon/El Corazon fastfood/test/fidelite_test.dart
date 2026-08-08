import 'package:elcora_fast/presentation/fidelite.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Le vocabulaire du programme de fidélité.
///
/// Ces cas remplacent `models/loyalty_reward.dart` et
/// `models/loyalty_transaction.dart`, retirés avec leur adaptateur.
eccore.Reward _recompense({
  String kind = 'discount',
  int cout = 250,
  int remiseCfa = 750,
}) =>
    eccore.Reward.fromJson({
      'id': 'recompense-1',
      'name': 'Remise de bienvenue',
      'description': 'Sur votre prochaine commande',
      'kind': kind,
      'points_cost': cout,
      'discount': {'amount': '$remiseCfa', 'currency': 'XOF'},
      'validity_days': 30,
      'restaurant': null,
    });

eccore.PointsEntry _mouvement({String kind = 'bonus', int delta = 40}) =>
    eccore.PointsEntry.fromJson({
      'id': 'mouvement-1',
      'kind': kind,
      'delta': delta,
      'balance_after': 620,
      'description': 'Commande livrée',
      'order': null,
      'created_at': '2026-08-08T12:00:00Z',
    });

void main() {
  group('Les genres de récompense', () {
    test('le serveur n’en connaît que deux', () {
      // L'énumération locale en déclarait cinq : `freeItem`, `cashback` et
      // `exclusiveOffer` n'avaient aucun équivalent.
      expect(GenreRecompense.values, hasLength(2));
    });

    test('chacun a sa contrepartie', () {
      expect(_recompense(kind: 'free_delivery').genre,
          GenreRecompense.livraisonOfferte,);
      expect(_recompense().genre, GenreRecompense.remise);
    });

    test('un genre inconnu passe pour une remise', () {
      expect(_recompense(kind: 'quelque_chose_de_neuf').genre,
          GenreRecompense.remise,);
    });
  });

  group('Ce que le solde permet', () {
    test('un solde égal au coût suffit', () {
      expect(_recompense(cout: 500).estAccessibleAvec(500), isTrue);
    });

    test('un solde inférieur ne suffit pas', () {
      expect(_recompense(cout: 500).estAccessibleAvec(499), isFalse);
    });

    test('l’activité n’entre plus dans le calcul', () {
      // Le serveur filtre `is_active=True` côté requête et n'expose pas le
      // champ : toute récompense reçue est active. Le modèle local portait un
      // `isActive` qui valait toujours `true`, et l'écran affichait
      // « Bientôt disponible » dans une branche inatteignable.
      expect(_recompense(cout: 0).estAccessibleAvec(0), isTrue);
    });
  });

  group('Les mouvements de points', () {
    test('les quatre genres du serveur sont couverts', () {
      expect(_mouvement(kind: 'earned').genre, GenreMouvementPoints.gagnes);
      expect(_mouvement(kind: 'spent').genre, GenreMouvementPoints.depenses);
      expect(_mouvement(kind: 'expired').genre, GenreMouvementPoints.expires);
      expect(_mouvement(kind: 'adjusted').genre, GenreMouvementPoints.ajustes);
    });

    test('`bonus` n’existait que localement', () {
      expect(GenreMouvementPoints.values, hasLength(4));
      expect(
        GenreMouvementPoints.values.map((g) => g.versServeur),
        isNot(contains('bonus')),
      );
    });

    test('seul un gain crédite le compte', () {
      expect(GenreMouvementPoints.gagnes.crediteLeCompte, isTrue);
      expect(GenreMouvementPoints.depenses.crediteLeCompte, isFalse);
      expect(GenreMouvementPoints.expires.crediteLeCompte, isFalse);
    });
  });

  group('Le relevé', () {
    test('un crédit porte son signe, un débit garde le sien', () {
      expect(_mouvement(delta: 120).deltaAffiche, '+120');
      expect(_mouvement(kind: 'spent', delta: -500).deltaAffiche, '-500');
    });

    test('un mouvement nul ne prend pas de signe', () {
      expect(_mouvement(delta: 0).deltaAffiche, '0');
    });
  });

  group('La remise', () {
    test('passe en unité majeure pour l’affichage', () {
      // Le franc CFA n'a pas de décimales : l'unité mineure vaut la majeure.
      expect(_recompense(remiseCfa: 1000).remiseAffichee, 1000);
    });
  });
}
