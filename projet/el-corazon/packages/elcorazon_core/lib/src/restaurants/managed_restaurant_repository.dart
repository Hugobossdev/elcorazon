import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/restaurants/managed_restaurant.dart';

/// Établissements du périmètre — `GET /api/v1/restaurants/manage/`
/// (`backend/apps/restaurants/backoffice.py`).
///
/// La route rend **ce que le compte connecté supervise** : tout, pour un compte
/// non cloisonné ; ses seuls établissements, pour un gérant. C'est la source du
/// slug que le back-office écrivait en dur, et la raison pour laquelle il n'y a
/// pas de paramètre pour choisir : le périmètre n'est pas une préférence de
/// client, c'est une décision du serveur.
///
/// Il n'y a pas d'écriture ici. Un gérant modifie son établissement — horaires,
/// téléphone, « on arrête les commandes une heure » — mais aucun écran du
/// back-office ne le fait aujourd'hui, et un dépôt qui expose ce qu'aucun
/// appelant n'utilise est du code que personne ne vérifie.
class ManagedRestaurantRepository {
  ManagedRestaurantRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Établissements du périmètre, **inactifs compris**.
  ///
  /// Ne pas les filtrer est délibéré : c'est du back-office qu'on rouvre un
  /// établissement suspendu, et le masquer le rendrait irrécupérable depuis
  /// l'écran même qui sert à le rouvrir — le raisonnement que tiennent déjà
  /// [ManagedCategory] et les zones de livraison.
  Future<List<ManagedRestaurant>> list() async {
    final etablissements = <ManagedRestaurant>[];
    String? path = '/restaurants/manage/';

    while (path != null) {
      final response = await apiClient.get(path);
      final body = response.data as Map<String, dynamic>;
      etablissements.addAll(
        (body['results'] as List<dynamic>).map(
          (json) => ManagedRestaurant.fromJson(json as Map<String, dynamic>),
        ),
      );
      path = body['next'] as String?;
    }

    return etablissements;
  }
}
