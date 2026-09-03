import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/restaurants/restaurant_option.dart';

/// Les établissements ouverts au public — `GET /api/v1/restaurants/`.
///
/// Route **publique** (`AllowAny` côté serveur, `RestaurantViewSet`) : elle
/// s'appelle sans session, ce qui est nécessaire ici puisque son unique
/// appelant aujourd'hui est le formulaire de candidature d'un livreur qui n'a
/// pas encore de compte.
///
/// À ne pas confondre avec [ManagedRestaurantRepository], qui rend le périmètre
/// d'un compte du personnel — inactifs compris — et exige un jeton. Les deux
/// listes ne contiennent pas la même chose et ne s'utilisent pas au même
/// endroit : celle-ci ne montre que ce qui est ouvert, et c'est exactement ce
/// à quoi un candidat peut se rattacher.
class RestaurantDirectoryRepository {
  RestaurantDirectoryRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Les établissements actifs, page après page.
  ///
  /// La pagination est suivie jusqu'au bout : la liste se compte en dizaines,
  /// elle alimente un sélecteur, et une deuxième page oubliée rendrait
  /// invisible — donc inchoisissable — une partie des établissements.
  Future<List<RestaurantOption>> list() async {
    final options = <RestaurantOption>[];
    String? path = '/restaurants/';

    while (path != null) {
      final response = await apiClient.get(path);
      final body = response.data as Map<String, dynamic>;
      options.addAll(
        (body['results'] as List<dynamic>).map(
          (json) => RestaurantOption.fromJson(json as Map<String, dynamic>),
        ),
      );
      path = body['next'] as String?;
    }

    return options;
  }
}
