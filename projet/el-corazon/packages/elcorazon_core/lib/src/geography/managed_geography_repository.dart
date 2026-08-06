import '../models/money.dart';
import '../network/api_client.dart';
import 'delivery_zone.dart';
import 'managed_city.dart';

/// Géographie du back-office — `/api/v1/geography/manage/*`
/// (`backend/apps/geography/backoffice.py`), réservée au **siège**.
///
/// Séparé de [GeographyRepository], qui rend au visiteur la liste des villes
/// desservies : ici on écrit des contours et des barèmes, c'est-à-dire ce que
/// paiera chaque client de la zone. Le serveur réserve ces routes aux comptes
/// non cloisonnés — une zone n'appartient à aucun établissement, et l'accorder
/// à qui a un périmètre étroit lui donnerait le pouvoir de tarifer les autres.
class ManagedGeographyRepository {
  ManagedGeographyRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Villes, **fermées comprises**, pour la même raison que [zones].
  ///
  /// Le back-office s'en sert pour **nommer** la ville d'une zone : la zone ne
  /// porte que sa clé (`ManagedDeliveryZoneSerializer` sérialise `city` en
  /// `PrimaryKeyRelatedField`), et un écran qui doit choisir les quartiers
  /// desservis ne peut pas afficher un UUID à la place de « Lomé ».
  Future<List<ManagedCity>> cities({String? countryIsoCode, bool? isActive}) async {
    final villes = <ManagedCity>[];
    String? path = '/geography/manage/cities/';
    Map<String, dynamic>? queryParameters = {
      if (countryIsoCode != null) 'country__iso_code': countryIsoCode,
      if (isActive != null) 'is_active': isActive.toString(),
    };

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      villes.addAll(
        (body['results'] as List<dynamic>).map(
          (json) => ManagedCity.fromJson(json as Map<String, dynamic>),
        ),
      );
      path = body['next'] as String?;
      queryParameters = null;
    }

    return villes;
  }

  /// Zones, **inactives comprises** : la liste publique les filtre, celle-ci
  /// les montre — sans quoi désactiver une zone la ferait disparaître de
  /// l'écran qui sert à la rouvrir.
  Future<List<DeliveryZone>> zones({String? citySlug, bool? isActive}) async {
    final zones = <DeliveryZone>[];
    String? path = '/geography/manage/zones/';
    Map<String, dynamic>? queryParameters = {
      if (citySlug != null) 'city__slug': citySlug,
      if (isActive != null) 'is_active': isActive.toString(),
    };

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      zones.addAll(
        (body['results'] as List<dynamic>).map(
          (json) => DeliveryZone.fromJson(json as Map<String, dynamic>),
        ),
      );
      path = body['next'] as String?;
      queryParameters = null;
    }

    return zones;
  }

  /// Crée une zone.
  ///
  /// [boundary] est du GeoJSON (`Polygon` ou `MultiPolygon`) — la forme que
  /// produisent les outils de dessin cartographique.
  Future<DeliveryZone> createZone({
    required String cityId,
    required String name,
    required Map<String, dynamic> boundary,
    required Money baseFee,
    required Money feePerKm,
    Money? freeDeliveryThreshold,
    Money? minOrderAmount,
    double maxDistanceKm = 15,
    int estimatedDeliveryMinutes = 30,
  }) async {
    final response = await apiClient.post(
      '/geography/manage/zones/',
      data: {
        'city': cityId,
        'name': name,
        'boundary': boundary,
        'base_fee': baseFee.toJson(),
        'fee_per_km': feePerKm.toJson(),
        if (freeDeliveryThreshold != null)
          'free_delivery_threshold': freeDeliveryThreshold.toJson(),
        if (minOrderAmount != null) 'min_order_amount': minOrderAmount.toJson(),
        'max_distance_km': maxDistanceKm,
        'estimated_delivery_minutes': estimatedDeliveryMinutes,
      },
    );
    return DeliveryZone.fromJson(response.data as Map<String, dynamic>);
  }

  /// Modification partielle d'une zone.
  ///
  /// Un paramètre omis n'est pas transmis : le `PATCH` ne touche que ce qu'on
  /// lui donne. D'où [clearFreeDeliveryThreshold] et [clearMinOrderAmount],
  /// qui n'ont l'air redondants que jusqu'à ce qu'on veuille **retirer** un
  /// seuil : passer `null` à `freeDeliveryThreshold` se confond avec « ne pas
  /// y toucher », si bien qu'une zone qui offrait la livraison au-dessus d'un
  /// montant ne pouvait plus cesser de le faire. Ces deux drapeaux envoient un
  /// `null` explicite, que le serveur accepte (`allow_null=True`).
  Future<DeliveryZone> updateZone({
    required String zoneId,
    String? name,
    Map<String, dynamic>? boundary,
    Money? baseFee,
    Money? feePerKm,
    Money? freeDeliveryThreshold,
    Money? minOrderAmount,
    double? maxDistanceKm,
    int? estimatedDeliveryMinutes,
    bool? isActive,
    bool clearFreeDeliveryThreshold = false,
    bool clearMinOrderAmount = false,
  }) async {
    if (clearFreeDeliveryThreshold && freeDeliveryThreshold != null) {
      throw ArgumentError(
        'Un seuil de franco ne peut pas être posé et retiré dans le même appel.',
      );
    }
    if (clearMinOrderAmount && minOrderAmount != null) {
      throw ArgumentError(
        'Un minimum de commande ne peut pas être posé et retiré dans le même appel.',
      );
    }

    final response = await apiClient.patch(
      '/geography/manage/zones/$zoneId/',
      data: {
        if (name != null) 'name': name,
        if (boundary != null) 'boundary': boundary,
        if (baseFee != null) 'base_fee': baseFee.toJson(),
        if (feePerKm != null) 'fee_per_km': feePerKm.toJson(),
        if (freeDeliveryThreshold != null)
          'free_delivery_threshold': freeDeliveryThreshold.toJson()
        else if (clearFreeDeliveryThreshold) 'free_delivery_threshold': null,
        if (minOrderAmount != null)
          'min_order_amount': minOrderAmount.toJson()
        else if (clearMinOrderAmount) 'min_order_amount': null,
        if (maxDistanceKm != null) 'max_distance_km': maxDistanceKm,
        if (estimatedDeliveryMinutes != null)
          'estimated_delivery_minutes': estimatedDeliveryMinutes,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return DeliveryZone.fromJson(response.data as Map<String, dynamic>);
  }
}
