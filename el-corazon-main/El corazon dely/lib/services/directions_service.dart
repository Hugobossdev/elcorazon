import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/api_config.dart';

/// Service de gestion des directions et calculs de distance/temps avec Google Directions API
class DirectionsService extends ChangeNotifier {
  static final DirectionsService _instance = DirectionsService._internal();
  factory DirectionsService() => _instance;
  DirectionsService._internal();

  // Cache pour éviter les appels répétés
  final Map<String, RouteInfo> _routeCache = {};

  /// Obtient les informations complètes d'un itinéraire (distance, temps, polyline)
  /// 
  /// [origin] : Point de départ
  /// [destination] : Point d'arrivée
  /// [waypoints] : Points intermédiaires (optionnel)
  /// [mode] : Mode de transport (driving, walking, bicycling, transit)
  /// 
  /// Retourne un objet RouteInfo avec distance, durée et polyline
  Future<RouteInfo?> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
    String mode = 'driving',
  }) async {
    try {
      // Créer une clé de cache
      final cacheKey = _generateCacheKey(origin, destination, waypoints, mode);
      
      // Vérifier le cache
      if (_routeCache.containsKey(cacheKey)) {
        final cached = _routeCache[cacheKey]!;
        // Utiliser le cache si moins de 5 minutes
        if (DateTime.now().difference(cached.timestamp).inMinutes < 5) {
          debugPrint('✅ DirectionsService: Route récupérée du cache');
          return cached;
        } else {
          _routeCache.remove(cacheKey);
        }
      }

      // Construire l'URL de l'API
      final apiKey = ApiConfig.googleMapsApiKey;
      if (apiKey.isEmpty || apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
        throw Exception('Clé API Google Maps non configurée');
      }

      String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=$mode&'
          'key=$apiKey';

      // Ajouter les waypoints si fournis
      if (waypoints != null && waypoints.isNotEmpty) {
        final waypointsStr = waypoints
            .map((wp) => '${wp.latitude},${wp.longitude}')
            .join('|');
        url += '&waypoints=$waypointsStr';
      }

      debugPrint('🔄 DirectionsService: Requête à Google Directions API...');

      // Faire la requête
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: La requête a pris trop de temps');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Extraire la distance (en mètres)
          final distanceValue = leg['distance']['value'] as int;
          final distanceKm = distanceValue / 1000.0;

          // Extraire la durée (en secondes)
          final durationValue = leg['duration']['value'] as int;
          final durationMinutes = (durationValue / 60).round();

          // Extraire la durée dans le trafic si disponible
          int? durationInTrafficMinutes;
          if (leg['duration_in_traffic'] != null) {
            final durationInTrafficValue = leg['duration_in_traffic']['value'] as int;
            durationInTrafficMinutes = (durationInTrafficValue / 60).round();
          }

          // Extraire le polyline encodé
          final overviewPolyline = route['overview_polyline']['points'] as String;

          // Décoder le polyline en liste de points LatLng
          final polylinePoints = _decodePolyline(overviewPolyline);

          // Créer l'objet RouteInfo
          final routeInfo = RouteInfo(
            distanceKm: distanceKm,
            distanceMeters: distanceValue,
            durationMinutes: durationMinutes,
            durationInTrafficMinutes: durationInTrafficMinutes,
            polylinePoints: polylinePoints,
            encodedPolyline: overviewPolyline,
            timestamp: DateTime.now(),
          );

          // Mettre en cache
          _routeCache[cacheKey] = routeInfo;

          debugPrint('✅ DirectionsService: Route calculée - ${distanceKm.toStringAsFixed(2)} km, $durationMinutes min');
          
          return routeInfo;
        } else {
          final status = data['status'] as String;
          final errorMessage = data['error_message'] as String? ?? 'Erreur inconnue';
          debugPrint('❌ DirectionsService: Erreur API - $status: $errorMessage');
          
          // Gérer les erreurs spécifiques
          if (status == 'ZERO_RESULTS') {
            throw Exception('Aucun itinéraire trouvé entre ces points');
          } else if (status == 'NOT_FOUND') {
            throw Exception('Point de départ ou d\'arrivée introuvable');
          } else if (status == 'OVER_QUERY_LIMIT') {
            throw Exception('Quota API dépassé. Veuillez réessayer plus tard');
          } else if (status == 'REQUEST_DENIED') {
            throw Exception('Requête refusée. Vérifiez votre clé API');
          } else if (status == 'INVALID_REQUEST') {
            throw Exception('Requête invalide: $errorMessage');
          } else {
            throw Exception('Erreur API: $status - $errorMessage');
          }
        }
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ DirectionsService: Erreur calcul route - $e');
      rethrow;
    }
  }

  /// Calcule uniquement la distance et le temps entre deux points
  /// Plus rapide que getRoute car utilise Distance Matrix API
  Future<DistanceTimeInfo?> getDistanceAndTime({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving',
  }) async {
    try {
      final apiKey = ApiConfig.googleMapsApiKey;
      if (apiKey.isEmpty || apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
        throw Exception('Clé API Google Maps non configurée');
      }

      final url = 'https://maps.googleapis.com/maps/api/distancematrix/json?'
          'origins=${origin.latitude},${origin.longitude}&'
          'destinations=${destination.latitude},${destination.longitude}&'
          'mode=$mode&'
          'key=$apiKey';

      debugPrint('🔄 DirectionsService: Requête à Google Distance Matrix API...');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['rows'].isNotEmpty) {
          final element = data['rows'][0]['elements'][0];
          
          if (element['status'] == 'OK') {
            final distanceValue = element['distance']['value'] as int;
            final distanceKm = distanceValue / 1000.0;
            
            final durationValue = element['duration']['value'] as int;
            final durationMinutes = (durationValue / 60).round();

            // Durée dans le trafic si disponible
            int? durationInTrafficMinutes;
            if (element['duration_in_traffic'] != null) {
              final durationInTrafficValue = element['duration_in_traffic']['value'] as int;
              durationInTrafficMinutes = (durationInTrafficValue / 60).round();
            }

            debugPrint('✅ DirectionsService: Distance/Temps calculés - ${distanceKm.toStringAsFixed(2)} km, $durationMinutes min');

            return DistanceTimeInfo(
              distanceKm: distanceKm,
              distanceMeters: distanceValue,
              durationMinutes: durationMinutes,
              durationInTrafficMinutes: durationInTrafficMinutes,
            );
          } else {
            throw Exception('Impossible de calculer la distance: ${element['status']}');
          }
        } else {
          throw Exception('Erreur API: ${data['status']}');
        }
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ DirectionsService: Erreur calcul distance/temps - $e');
      rethrow;
    }
  }

  /// Décode un polyline encodé en liste de points LatLng
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  /// Génère une clé de cache unique
  String _generateCacheKey(LatLng origin, LatLng destination, List<LatLng>? waypoints, String mode) {
    final waypointsStr = waypoints?.map((wp) => '${wp.latitude},${wp.longitude}').join('|') ?? '';
    return '${origin.latitude},${origin.longitude}_${destination.latitude},${destination.longitude}_${waypointsStr}_$mode';
  }

  /// Vide le cache
  void clearCache() {
    _routeCache.clear();
    debugPrint('✅ DirectionsService: Cache vidé');
  }

  /// Calcule la distance en ligne droite (Haversine) comme fallback
  double calculateStraightLineDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371.0; // Rayon de la Terre en km

    final double lat1Rad = point1.latitude * (3.14159265359 / 180);
    final double lat2Rad = point2.latitude * (3.14159265359 / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (3.14159265359 / 180);

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }
}

/// Informations complètes sur un itinéraire
class RouteInfo {
  final double distanceKm;
  final int distanceMeters;
  final int durationMinutes;
  final int? durationInTrafficMinutes;
  final List<LatLng> polylinePoints;
  final String encodedPolyline;
  final DateTime timestamp;

  RouteInfo({
    required this.distanceKm,
    required this.distanceMeters,
    required this.durationMinutes,
    this.durationInTrafficMinutes,
    required this.polylinePoints,
    required this.encodedPolyline,
    required this.timestamp,
  });

  /// Durée à utiliser (avec trafic si disponible, sinon durée normale)
  int get effectiveDurationMinutes => durationInTrafficMinutes ?? durationMinutes;

  /// Formatage de la distance
  String get formattedDistance {
    if (distanceKm < 1) {
      return '${distanceMeters}m';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
  }

  /// Formatage de la durée
  String get formattedDuration {
    if (effectiveDurationMinutes < 60) {
      return '${effectiveDurationMinutes}min';
    } else {
      final hours = effectiveDurationMinutes ~/ 60;
      final minutes = effectiveDurationMinutes % 60;
      return '${hours}h ${minutes}min';
    }
  }
}

/// Informations de distance et temps (sans polyline)
class DistanceTimeInfo {
  final double distanceKm;
  final int distanceMeters;
  final int durationMinutes;
  final int? durationInTrafficMinutes;

  DistanceTimeInfo({
    required this.distanceKm,
    required this.distanceMeters,
    required this.durationMinutes,
    this.durationInTrafficMinutes,
  });

  int get effectiveDurationMinutes => durationInTrafficMinutes ?? durationMinutes;

  String get formattedDistance {
    if (distanceKm < 1) {
      return '${distanceMeters}m';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
  }

  String get formattedDuration {
    if (effectiveDurationMinutes < 60) {
      return '${effectiveDurationMinutes}min';
    } else {
      final hours = effectiveDurationMinutes ~/ 60;
      final minutes = effectiveDurationMinutes % 60;
      return '${hours}h ${minutes}min';
    }
  }
}

