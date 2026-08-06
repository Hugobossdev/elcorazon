import '../network/api_client.dart';
import 'city.dart';
import 'zone_resolution.dart';

/// Accès à `/api/v1/geography/*` — voir `backend/apps/geography/views.py`.
/// Public (`permission_classes = [AllowAny]`).
class GeographyRepository {
  GeographyRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Villes desservies, toutes pages confondues (paginé côté serveur,
  /// `PAGE_SIZE=20` — un déploiement mono-pays tient largement dans une
  /// page, mais suivre `next` reste correct si ça change).
  Future<List<City>> getCities() async {
    final cities = <City>[];
    String? path = '/geography/cities/';

    while (path != null) {
      final response = await apiClient.get(path);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      cities.addAll(results.map((json) => City.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
    }

    return cities;
  }

  /// Ce point est-il desservi, et à quel barème ?
  ///
  /// C'est la question que pose l'application avant d'annoncer un frais de
  /// livraison, et la réponse ne se devine pas depuis le téléphone : le
  /// contour des zones est un `MultiPolygon` que PostGIS teste en base, et le
  /// barème vit en donnée pour qu'ouvrir un quartier ou relever un forfait se
  /// fasse depuis le back-office, sans republier trois applications.
  ///
  /// Un point hors couverture rend `isCovered == false`, pas une exception :
  /// c'est une réponse légitime à une question légitime.
  Future<ZoneResolution> resolveZone({required double lat, required double lon}) async {
    final response = await apiClient.get(
      '/geography/zones/resolve/',
      queryParameters: {'lat': lat, 'lon': lon},
    );
    return ZoneResolution.fromJson(response.data as Map<String, dynamic>);
  }
}
