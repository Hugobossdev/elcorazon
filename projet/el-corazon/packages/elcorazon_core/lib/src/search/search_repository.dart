import '../network/api_client.dart';

/// Familles de résultats — valeurs de `SearchHit.kind` côté serveur.
abstract final class SearchKind {
  static const order = 'order';
  static const customer = 'customer';
  static const courier = 'courier';
  static const menuItem = 'menu_item';
}

/// Un résultat de recherche, sous une forme identique quelle que soit sa
/// famille — miroir de `SearchHitSerializer`.
///
/// [title] et [subtitle] sont composés **par le serveur** : c'est lui qui sait
/// ce qui identifie une commande (sa référence) ou un livreur (son nom et son
/// véhicule). Quatre mises en forme recopiées dans l'écran divergeraient à la
/// première évolution du modèle.
class SearchHit {
  const SearchHit({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
  });

  factory SearchHit.fromJson(Map<String, dynamic> json) {
    return SearchHit(
      kind: json['kind'] as String,
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
    );
  }

  final String kind;
  final String id;
  final String title;
  final String subtitle;
}

/// Recherche transverse du back-office — `/api/v1/search/`
/// (`backend/apps/search/services.py`), réservée au personnel.
///
/// Un seul appel remplace les quatre requêtes que l'écran lançait lui-même sur
/// quatre tables. Ce n'est pas qu'un regroupement : le serveur applique pour
/// chaque famille sa permission (`orders.read`, `customers.read`,
/// `couriers.read`, `catalog.read`) **et** le cloisonnement par établissement.
/// L'implémentation précédente n'appliquait ni l'une ni l'autre — un opérateur
/// de Kara y trouvait les commandes de Lomé.
///
/// Une famille dont le compte n'a pas le droit est **absente** de la réponse,
/// et non rendue vide : « rien trouvé » et « vous n'y avez pas accès » ne se
/// corrigent pas de la même façon.
class SearchRepository {
  SearchRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Cherche [query] dans toutes les familles autorisées.
  ///
  /// Le serveur refuse (400) une requête de moins de trois caractères : deux
  /// ramèneraient une part notable de chaque table sans rien désigner.
  Future<List<SearchHit>> search(String query, {int limit = 5}) async {
    final response = await apiClient.get(
      '/search/',
      queryParameters: {'q': query, 'limit': limit},
    );
    return (response.data as List<dynamic>)
        .map((json) => SearchHit.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
