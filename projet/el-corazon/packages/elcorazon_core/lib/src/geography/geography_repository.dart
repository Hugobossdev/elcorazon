import '../network/api_client.dart';
import 'city.dart';

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
}
