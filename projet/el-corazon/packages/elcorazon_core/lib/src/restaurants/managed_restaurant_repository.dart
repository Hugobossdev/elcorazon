import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/restaurants/managed_restaurant.dart';
import 'package:elcorazon_core/src/restaurants/restaurant_lifecycle.dart';

/// Établissements du périmètre — `GET /api/v1/restaurants/manage/`
/// (`backend/apps/restaurants/backoffice.py`).
///
/// La route rend **ce que le compte connecté supervise** : tout, pour un compte
/// non cloisonné ; ses seuls établissements, pour un gérant. C'est la source du
/// slug que le back-office écrivait en dur, et la raison pour laquelle il n'y a
/// pas de paramètre pour choisir : le périmètre n'est pas une préférence de
/// client, c'est une décision du serveur.
///
/// Les écritures ont été ajoutées avec l'écran de provisionnement : ouvrir un
/// établissement, corriger sa fiche, le faire avancer dans son cycle de vie.
/// Elles n'existaient pas — le serveur les acceptait depuis l'origine, aucun
/// appelant ne s'en servait, et ouvrir un second restaurant passait donc par
/// `django-admin`.
///
/// [updateStatus] est une route à part et non un champ de [update] : publier un
/// établissement et corriger son numéro de téléphone ne sont pas le même geste.
/// Le serveur y fait passer la machine à états **et** la vérification de
/// complétude, si bien qu'une mise en service sur un établissement sans carte
/// est refusée en 409 avec la liste de ce qui manque.
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

  /// Ouvre un établissement — **en brouillon**.
  ///
  /// Le serveur ne prend pas de statut à la création : toute fiche naît en
  /// brouillon et se publie par [updateStatus]. C'est ce qui empêche un
  /// restaurant d'apparaître dans l'application cliente à l'instant où l'on
  /// valide un formulaire, sans carte ni horaires — le comportement qu'avait
  /// `is_active`, vrai par défaut.
  ///
  /// La [zoneId] emporte la ville, donc le pays, donc la devise et le fuseau :
  /// il n'y a pas de champ pour eux, et c'est ce qui rend impossible un
  /// établissement dont le pays contredirait la ville.
  Future<ManagedRestaurant> create({
    required String name,
    required String slug,
    required String zoneId,
    required String address,
    required double latitude,
    required double longitude,
    required String phone,
    String description = '',
    String? email,
    int defaultPreparationMinutes = 20,
  }) async {
    final response = await apiClient.post(
      '/restaurants/manage/',
      data: {
        'name': name,
        'slug': slug,
        'zone': zoneId,
        'address': address,
        'location': {'lat': latitude, 'lon': longitude},
        'phone': phone,
        'description': description,
        if (email != null && email.isNotEmpty) 'email': email,
        'default_preparation_minutes': defaultPreparationMinutes,
      },
    );
    return ManagedRestaurant.fromJson(response.data as Map<String, dynamic>);
  }

  /// Modification partielle — un paramètre omis n'est pas transmis.
  ///
  /// Ni `status` ni `isActive` n'y figurent : le premier passe par
  /// [updateStatus], le second est calculé par le serveur à partir du premier.
  /// Les exposer ici offrirait deux leviers de publication, dont l'un serait
  /// silencieusement sans effet.
  ///
  /// [acceptsOrders], en revanche, est bien un champ de fiche : c'est le
  /// drapeau du coup de feu, qu'un gérant bascule dix fois par semaine sans
  /// que l'établissement cesse d'exister.
  Future<ManagedRestaurant> update({
    required String slug,
    String? name,
    String? description,
    String? zoneId,
    String? address,
    double? latitude,
    double? longitude,
    String? phone,
    String? email,
    bool? acceptsOrders,
    int? defaultPreparationMinutes,
  }) async {
    if ((latitude == null) != (longitude == null)) {
      throw ArgumentError(
        'Une latitude seule ne situe rien : les deux coordonnées se fournissent ensemble.',
      );
    }

    final response = await apiClient.patch(
      '/restaurants/manage/$slug/',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (zoneId != null) 'zone': zoneId,
        if (address != null) 'address': address,
        if (latitude != null && longitude != null)
          'location': {'lat': latitude, 'lon': longitude},
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (acceptsOrders != null) 'accepts_orders': acceptsOrders,
        if (defaultPreparationMinutes != null)
          'default_preparation_minutes': defaultPreparationMinutes,
      },
    );
    return ManagedRestaurant.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fait avancer l'établissement dans son cycle de vie.
  ///
  /// Les transitions refusées et les établissements incomplets sortent tous
  /// deux en 409, mais sous deux codes distincts — `illegal_transition` et
  /// `incomplete_configuration` — parce qu'ils appellent deux gestes
  /// différents : choisir une autre cible, ou aller remplir ce qui manque. Le
  /// second porte la liste dans le membre `missing` du corps d'erreur, que
  /// [ApiException.details] rend disponible.
  Future<ManagedRestaurant> updateStatus({
    required String slug,
    required RestaurantLifecycle status,
  }) async {
    final response = await apiClient.post(
      '/restaurants/manage/$slug/status/',
      data: {'status': status.code},
    );
    return ManagedRestaurant.fromJson(response.data as Map<String, dynamic>);
  }
}
