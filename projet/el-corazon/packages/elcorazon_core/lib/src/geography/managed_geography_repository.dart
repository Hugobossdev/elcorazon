import '../models/money.dart';
import '../network/api_client.dart';
import 'delivery_zone.dart';

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
  }) async {
    final response = await apiClient.patch(
      '/geography/manage/zones/$zoneId/',
      data: {
        if (name != null) 'name': name,
        if (boundary != null) 'boundary': boundary,
        if (baseFee != null) 'base_fee': baseFee.toJson(),
        if (feePerKm != null) 'fee_per_km': feePerKm.toJson(),
        if (freeDeliveryThreshold != null)
          'free_delivery_threshold': freeDeliveryThreshold.toJson(),
        if (minOrderAmount != null) 'min_order_amount': minOrderAmount.toJson(),
        if (maxDistanceKm != null) 'max_distance_km': maxDistanceKm,
        if (estimatedDeliveryMinutes != null)
          'estimated_delivery_minutes': estimatedDeliveryMinutes,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return DeliveryZone.fromJson(response.data as Map<String, dynamic>);
  }
}
