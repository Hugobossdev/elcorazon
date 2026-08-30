import 'package:elcora_fast/presentation/reprise_de_commande.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Remettre une commande passée au panier.
///
/// ## Ce que ces cas tiennent
///
/// Un article **retiré de la carte** ne peut pas être recommandé : le panier
/// serveur ne connaît que le catalogue du jour, et une ligne inventée
/// disparaît à la synchronisation suivante — sans que personne ne le dise.
///
/// L'écran d'historique collectait déjà la liste de ces articles et ne la
/// montrait **jamais** : on recommandait cinq plats, deux avaient quitté la
/// carte, et le message annonçait « 3 articles ajoutés » sans un mot des deux
/// autres. Le client s'en apercevait au règlement, ou pas du tout.
///
/// Ces cas épinglent le retour de la méthode partagée — c'est lui qui permet à
/// l'écran de le dire.
void main() {
  eccore.MenuItem article({
    required String id,
    required String nom,
    bool disponible = true,
  }) {
    return eccore.MenuItem(
      id: id,
      restaurantSlug: 'el-corazon-lome',
      categorySlug: 'grillades',
      categoryName: 'Grillades',
      name: nom,
      slug: id,
      description: '',
      image: null,
      price: const eccore.Money(amountMinor: 250000, currency: 'XOF'),
      preparationMinutes: 20,
      allergens: const [],
      dietaryTags: const [],
      isAvailable: disponible,
      isPopular: false,
      vipExclusive: false,
      ratingAverage: 0,
      ratingCount: 0,
      sortOrder: 0,
    );
  }

  LigneAReprendre ligne(String id, String nom, {int quantite = 1}) {
    return (
      menuItemId: id,
      nom: nom,
      quantite: quantite,
      options: const <String, String>{},
    );
  }

  /// Le résultat sous la forme que l'écran consomme : combien d'articles, et
  /// lesquels sont perdus.
  ({int ajoutes, List<String> indisponibles}) reprise(
    List<LigneAReprendre> lignes,
    List<eccore.MenuItem> catalogue,
  ) {
    final tri = trierLaReprise(lignes, catalogue);
    return (
      ajoutes: tri.retenues.fold(0, (n, r) => n + r.ligne.quantite),
      indisponibles: tri.indisponibles,
    );
  }

  test('une commande dont tout est encore à la carte passe entière', () {
    final resultat = reprise(
      [ligne('a', 'Poulet yassa', quantite: 2), ligne('b', 'Attiéké')],
      [article(id: 'a', nom: 'Poulet yassa'), article(id: 'b', nom: 'Attiéké')],
    );

    expect(resultat.ajoutes, 3);
    expect(resultat.indisponibles, isEmpty);
  });

  test('un article absent du catalogue est nommé, pas ajouté', () {
    // Le cas qui passait sous silence : l'article n'existe plus, la ligne est
    // écartée — et son nom remonte pour que l'écran puisse le dire.
    final resultat = reprise(
      [ligne('a', 'Poulet yassa'), ligne('disparu', 'Brochettes du chef')],
      [article(id: 'a', nom: 'Poulet yassa')],
    );

    expect(resultat.ajoutes, 1);
    expect(resultat.indisponibles, ['Brochettes du chef']);
  });

  test('un article encore au catalogue mais indisponible est écarté aussi', () {
    // `is_available = false` : la cuisine ne le sert plus aujourd'hui. Le
    // serveur refuserait la ligne ; autant l'écarter et le dire.
    final resultat = reprise(
      [ligne('a', 'Poulet yassa')],
      [article(id: 'a', nom: 'Poulet yassa', disponible: false)],
    );

    expect(resultat.ajoutes, 0);
    expect(resultat.indisponibles, ['Poulet yassa']);
  });

  test('la quantité de chaque ligne est reprise, pas seulement le nombre', () {
    final resultat = reprise(
      [ligne('a', 'Poulet yassa', quantite: 4)],
      [article(id: 'a', nom: 'Poulet yassa')],
    );

    expect(resultat.ajoutes, 4);
  });

  test('une commande entièrement hors carte n’ajoute rien et nomme tout', () {
    final resultat = reprise(
      [ligne('x', 'Plat retiré'), ligne('y', 'Autre plat retiré')],
      const [],
    );

    expect(resultat.ajoutes, 0);
    expect(resultat.indisponibles, ['Plat retiré', 'Autre plat retiré']);
  });

  test('une commande vide ne produit ni ajout ni reproche', () {
    final resultat = reprise(const [], const []);

    expect(resultat.ajoutes, 0);
    expect(resultat.indisponibles, isEmpty);
  });
}
