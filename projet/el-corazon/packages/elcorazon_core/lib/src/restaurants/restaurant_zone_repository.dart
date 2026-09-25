import 'package:elcorazon_core/src/geography/delivery_zone.dart';
import 'package:elcorazon_core/src/geography/zone_shape.dart';
import 'package:elcorazon_core/src/models/money.dart';
import 'package:elcorazon_core/src/network/api_client.dart';

/// Zones **propres à une cuisine** — `/restaurants/manage/zones/`.
///
/// Aucune application ne les lisait : la route existait, cloisonnée et
/// journalisée, sans un seul écran pour s'en servir. Le gérant ne pouvait donc
/// pas dire jusqu'où *sa* cuisine livre.
///
/// Le serveur tient tout : le périmètre (une cuisine ne voit ni ne touche les
/// zones d'une autre — 404), la forme (contour refusé s'il se croise, sort du
/// globe ou couvre plus de 5 000 km²), le journal, et le refus de supprimer
/// une zone qui porte encore la cuisine (409, avec le nom à rattacher
/// ailleurs).
class RestaurantZoneRepository {
  RestaurantZoneRepository({required this.apiClient});

  final ApiClient apiClient;

  static const _chemin = '/restaurants/manage/zones/';

  /// Les zones d'une cuisine, toutes pages lues — un sélecteur qui oublie la
  /// deuxième page rend une zone invisible, donc inmodifiable.
  Future<List<DeliveryZone>> zonesDe(String restaurantSlug) async {
    final zones = <DeliveryZone>[];
    String? suivante = _chemin;
    Map<String, dynamic>? parametres = {'restaurant__slug': restaurantSlug, 'page_size': 100};

    while (suivante != null) {
      final reponse = await apiClient.get(suivante, queryParameters: parametres);
      final corps = reponse.data as Map<String, dynamic>;
      zones.addAll(
        (corps['results'] as List<dynamic>)
            .map((json) => DeliveryZone.fromJson(json as Map<String, dynamic>)),
      );
      suivante = corps['next'] as String?;
      parametres = null;
    }
    return zones;
  }

  Future<DeliveryZone> creer({
    required String restaurantSlug,
    required String cityId,
    required String nom,
    required FormeDeZone forme,
    required Money forfait,
    required Money parKm,
    required double distanceMaxKm,
    required int dureeEstimeeMinutes,
  }) async {
    final reponse = await apiClient.post(
      _chemin,
      data: {
        'restaurant': restaurantSlug,
        'city': cityId,
        'name': nom,
        ...forme.versJson(),
        'base_fee': forfait.toJson(),
        'fee_per_km': parKm.toJson(),
        'max_distance_km': distanceMaxKm.toString(),
        'estimated_delivery_minutes': dureeEstimeeMinutes,
      },
    );
    return DeliveryZone.fromJson(reponse.data as Map<String, dynamic>);
  }

  /// `PATCH` : seul ce qu'on donne est envoyé. Une forme omise garde le
  /// contour existant — corriger un tarif n'oblige pas à redessiner.
  Future<DeliveryZone> modifier(
    String zoneId, {
    String? nom,
    FormeDeZone? forme,
    Money? forfait,
    Money? parKm,
    double? distanceMaxKm,
    int? dureeEstimeeMinutes,
    bool? active,
  }) async {
    final reponse = await apiClient.patch(
      '$_chemin$zoneId/',
      data: {
        if (nom != null) 'name': nom,
        if (forme != null) ...forme.versJson(),
        if (forfait != null) 'base_fee': forfait.toJson(),
        if (parKm != null) 'fee_per_km': parKm.toJson(),
        if (distanceMaxKm != null) 'max_distance_km': distanceMaxKm.toString(),
        if (dureeEstimeeMinutes != null) 'estimated_delivery_minutes': dureeEstimeeMinutes,
        if (active != null) 'is_active': active,
      },
    );
    return DeliveryZone.fromJson(reponse.data as Map<String, dynamic>);
  }

  /// Supprime la zone. Un 409 dit qu'une cuisine y est encore posée : son
  /// `detail` nomme la cuisine à rattacher ailleurs, et c'est lui qu'on montre.
  Future<void> supprimer(String zoneId) async {
    await apiClient.delete('$_chemin$zoneId/');
  }
}
