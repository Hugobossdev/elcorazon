import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/restaurants/restaurant.dart';

/// Les établissements ouverts au public — `GET /api/v1/restaurants/`.
///
/// Route **publique** (`AllowAny` côté serveur, `RestaurantViewSet`) : elle
/// s'appelle sans session, ce qui est nécessaire pour ses deux appelants — le
/// formulaire de candidature d'un livreur qui n'a pas encore de compte, et
/// l'application cliente qui montre les restaurants avant l'inscription.
///
/// Le serveur n'y rend que les établissements **en service** (`status`
/// `active`), et la cascade va jusqu'au pays : fermer un marché en retire les
/// villes, les zones et les restaurants d'un seul geste.
///
/// À ne pas confondre avec `ManagedRestaurantRepository`, qui rend le périmètre
/// d'un compte du personnel — brouillons et suspendus compris — et exige un
/// jeton. Les deux listes ne contiennent pas la même chose.
class RestaurantDirectoryRepository {
  RestaurantDirectoryRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Les établissements en service, page après page.
  ///
  /// La pagination est suivie jusqu'au bout : la liste se compte en dizaines,
  /// elle alimente un sélecteur, et une deuxième page oubliée rendrait
  /// invisible — donc inchoisissable — une partie des établissements.
  ///
  /// [latitude] et [longitude] font trier par proximité **côté serveur**, sur
  /// l'ellipsoïde et servi par l'index GiST. Les deux vont ensemble : une
  /// latitude seule ne situe rien, et le serveur refuse la requête. Sans elles,
  /// le tri est alphabétique et `distanceMeters` reste nul.
  Future<List<Restaurant>> list({double? latitude, double? longitude}) async {
    if ((latitude == null) != (longitude == null)) {
      throw ArgumentError(
        'Une latitude seule ne situe rien : les deux coordonnées se fournissent '
        'ensemble, ou aucune.',
      );
    }

    final etablissements = <Restaurant>[];
    String? path = '/restaurants/';
    Map<String, dynamic>? parametres = latitude == null
        ? null
        : {'lat': latitude, 'lon': longitude};

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: parametres);
      final body = response.data as Map<String, dynamic>;
      etablissements.addAll(
        (body['results'] as List<dynamic>).map(
          (json) => Restaurant.fromJson(json as Map<String, dynamic>),
        ),
      );
      path = body['next'] as String?;
      // Les paramètres voyagent déjà dans l'URL de `next` : les repasser
      // dupliquerait `lat` et `lon` dans la chaîne de requête.
      parametres = null;
    }

    return etablissements;
  }

  /// Fiche d'un établissement, horaires compris (`RestaurantDetailSerializer`).
  ///
  /// La liste ne porte pas les plages d'ouverture : les charger pour chaque
  /// élément multiplierait la réponse par sept, pour une donnée que seule la
  /// fiche affiche.
  Future<Restaurant> get(String slug) async {
    final response = await apiClient.get('/restaurants/$slug/');
    return Restaurant.fromJson(response.data as Map<String, dynamic>);
  }
}
