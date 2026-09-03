import 'package:admin/presentation/filtres_supervision.dart';
import 'package:admin/presentation/statut_commande.dart';
import 'package:admin/presentation/tri_commandes.dart';
import 'package:flutter_test/flutter_test.dart';

/// La sélection qui part au serveur.
///
/// Ces règles décidaient auparavant de ce qu'on gardait d'une liste déjà
/// chargée : se tromper coûtait un affichage. Elles décident maintenant du
/// contenu d'une **requête**, et une erreur y coûte une page fausse — ou une
/// requête relancée à chaque frappe.
void main() {
  group('Ce qui déclenche une nouvelle requête', () {
    test('changer de statut en déclenche une', () {
      const a = FiltresCommandes();
      const b = FiltresCommandes(statut: StatutCommande.prete);

      expect(a.memeRequeteQue(b), isFalse);
    });

    test('changer la recherche en déclenche une', () {
      const a = FiltresCommandes();
      const b = FiltresCommandes(recherche: 'Kodjo');

      expect(a.memeRequeteQue(b), isFalse);
    });

    test('changer la période en déclenche une', () {
      const a = FiltresCommandes();
      const b = FiltresCommandes(fenetre: FenetreCommandes.aujourdHui);

      expect(a.memeRequeteQue(b), isFalse);
    });

    test('changer la taille de page en déclenche une', () {
      const a = FiltresCommandes();
      const b = FiltresCommandes(taillePage: 50);

      expect(a.memeRequeteQue(b), isFalse);
    });

    test('changer le tri n’en déclenche PAS', () {
      // Le tri ne part pas au serveur : il porte sur la page reçue. Le compter
      // ici relancerait une requête identique à chaque clic sur une colonne.
      const a = FiltresCommandes();
      const b = FiltresCommandes(tri: TriCommandes.totalDecroissant);

      expect(a.memeRequeteQue(b), isTrue);
    });

    test('les espaces de bordure d’une recherche ne comptent pas', () {
      // Sinon appuyer sur la barre d'espace après un terme relance la même
      // recherche.
      const a = FiltresCommandes(recherche: 'Kodjo');
      const b = FiltresCommandes(recherche: '  Kodjo  ');

      expect(a.memeRequeteQue(b), isTrue);
    });
  });

  group('Les bornes de période', () {
    final maintenant = DateTime(2026, 8, 8, 15, 30);

    test('« aujourd’hui » part de minuit, pas de l’heure qu’il est', () {
      // Partir de « il y a 24 h » écarterait les commandes du matin même.
      expect(
        FenetreCommandes.aujourdHui.depuis(maintenant),
        DateTime(2026, 8, 8),
      );
    });

    test('« 7 derniers jours » recule de sept jours', () {
      expect(
        FenetreCommandes.septJours.depuis(maintenant),
        maintenant.subtract(const Duration(days: 7)),
      );
    });

    test('« tout l’historique » n’a pas de borne', () {
      // `null` et non une date lointaine : une borne inventée écarterait
      // silencieusement les commandes plus anciennes.
      expect(FenetreCommandes.toutes.depuis(maintenant), isNull);
    });
  });

  group('Les filtres actifs', () {
    test('une sélection d’ouverture n’en compte aucun', () {
      expect(const FiltresCommandes().actifs, isFalse);
      expect(const FiltresCommandes().nombreActifs, 0);
    });

    test('le tri ne compte pas comme un filtre', () {
      // Il ne restreint rien : proposer « effacer les filtres » pour un tri
      // ferait chercher une restriction qui n'existe pas.
      const filtres = FiltresCommandes(tri: TriCommandes.totalDecroissant);

      expect(filtres.actifs, isFalse);
    });

    test('chaque terme posé est compté une fois', () {
      const filtres = FiltresCommandes(
        statut: StatutCommande.prete,
        recherche: 'Ama',
        fenetre: FenetreCommandes.aujourdHui,
        restaurantSlug: 'el-corazon-lome',
      );

      expect(filtres.nombreActifs, 4);
    });

    test('une recherche d’espaces seuls ne compte pas', () {
      expect(const FiltresCommandes(recherche: '   ').actifs, isFalse);
    });
  });

  group('copyWith', () {
    test('efface le statut sur demande explicite', () {
      // `copyWith(statut: null)` ne peut pas signifier « efface » — c'est la
      // valeur par défaut de tout paramètre optionnel. D'où le drapeau.
      const filtres = FiltresCommandes(statut: StatutCommande.prete);

      expect(filtres.copyWith().statut, StatutCommande.prete);
      expect(filtres.copyWith(effacerStatut: true).statut, isNull);
    });

    test('efface l’établissement sur demande explicite', () {
      const filtres = FiltresCommandes(restaurantSlug: 'el-corazon-lome');

      expect(filtres.copyWith(effacerRestaurant: true).restaurantSlug, isNull);
    });

    test('conserve ce qu’on ne touche pas', () {
      const filtres = FiltresCommandes(
        statut: StatutCommande.enAttente,
        recherche: 'Ama',
        taillePage: 50,
      );

      final maj = filtres.copyWith(fenetre: FenetreCommandes.toutes);

      expect(maj.statut, StatutCommande.enAttente);
      expect(maj.recherche, 'Ama');
      expect(maj.taillePage, 50);
    });
  });
}
