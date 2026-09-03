/// Une page de résultats, telle que la rend `StandardPagination`
/// (`backend/common/pagination.py`).
///
/// Pourquoi ce type existe
/// -----------------------
///
/// Les dépôts du socle suivent `next` **jusqu'au bout** et rendent une liste
/// complète. C'est le bon choix pour ce qui est borné par nature — les zones de
/// livraison d'une ville, les créneaux d'un livreur, les rôles — et le mauvais
/// pour ce qui grandit sans limite : à dix mille commandes, l'écran de
/// supervision télécharge cinq cents pages avant d'afficher la première ligne.
///
/// Ce type ne remplace pas ces méthodes, il les complète : un appelant qui veut
/// la page suivante la demande, un appelant qui veut tout continue de tout
/// obtenir. Les deux coexistent parce que les deux besoins existent.
///
/// [next] est l'**URL complète** rendue par le serveur, et non un numéro de
/// page : la reconstruire à partir d'un compteur obligerait à recopier les
/// filtres de la requête d'origine, et la première divergence donnerait une
/// page suivante qui ne suit pas la précédente.
class Page<T> {
  const Page({
    required this.results,
    required this.count,
    this.next,
    this.previous,
  });

  /// Depuis le corps d'une réponse paginée. [lire] convertit une ligne.
  factory Page.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) lire,
  ) {
    return Page<T>(
      results: (json['results'] as List<dynamic>)
          .map((ligne) => lire(ligne as Map<String, dynamic>))
          .toList(),
      // `count` est le total **de la requête filtrée**, pas de la table : c'est
      // ce qu'un écran affiche à côté de « page 2 sur 17 ».
      count: json['count'] as int? ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
    );
  }

  final List<T> results;
  final int count;

  /// URL complète de la page suivante, ou `null` sur la dernière.
  final String? next;

  /// URL complète de la page précédente, ou `null` sur la première.
  final String? previous;

  bool get hasNext => next != null;
  bool get hasPrevious => previous != null;
  bool get isEmpty => results.isEmpty;
}
