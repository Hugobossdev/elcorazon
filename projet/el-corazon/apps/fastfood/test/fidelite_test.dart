import 'package:elcora_fast/presentation/fidelite.dart';
import 'package:elcora_fast/presentation/profil_utilisateur.dart';
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

  group('Les paliers de fidelite', () {
    // Les seuils vivent cote client faute de route serveur (BR-006). Tant
    // qu'ils y vivent, ils doivent au moins etre coherents entre le profil et
    // l'ecran des recompenses — c'est ce que ces cas tiennent.

    test('un compte neuf part au palier de base', () {
      expect(PalierFidelite.pour(0), PalierFidelite.standard);
    });

    test('le seuil est atteint des qu’il est egale', () {
      expect(PalierFidelite.pour(200), PalierFidelite.fidele);
      expect(PalierFidelite.pour(500), PalierFidelite.vip);
    });

    test('un point de moins ne suffit pas', () {
      expect(PalierFidelite.pour(199), PalierFidelite.standard);
      expect(PalierFidelite.pour(499), PalierFidelite.fidele);
    });

    test('le sommet n’a pas de suivant', () {
      expect(PalierFidelite.vip.suivant, isNull);
      expect(PalierFidelite.standard.suivant, PalierFidelite.fidele);
    });

    test('l’avancement compte ce qui manque, pas ce qui est acquis', () {
      final avancement = avancementDeFidelite(150);
      expect(avancement.palier, PalierFidelite.standard);
      expect(avancement.suivant, PalierFidelite.fidele);
      expect(avancement.pointsManquants, 50);
      expect(avancement.progression, closeTo(0.75, 0.001));
    });

    test('la progression se mesure entre deux seuils, pas depuis zero', () {
      // 350 points : a mi-chemin entre 200 (Fidele) et 500 (VIP). Mesuree
      // depuis zero, la barre afficherait 70 % — et un client a 30 points du
      // palier verrait une barre presque pleine bien trop tot.
      final avancement = avancementDeFidelite(350);
      expect(avancement.palier, PalierFidelite.fidele);
      expect(avancement.progression, closeTo(0.5, 0.001));
    });

    test('au sommet la barre est pleine et rien ne manque', () {
      final avancement = avancementDeFidelite(900);
      expect(avancement.palier, PalierFidelite.vip);
      expect(avancement.suivant, isNull);
      expect(avancement.pointsManquants, 0);
      expect(avancement.progression, 1);
    });

    test('le libelle du profil est celui du palier', () {
      expect(palierDeFidelite(0), PalierFidelite.standard.libelle);
      expect(palierDeFidelite(250), PalierFidelite.fidele.libelle);
      expect(palierDeFidelite(800), PalierFidelite.vip.libelle);
    });
  });
}
