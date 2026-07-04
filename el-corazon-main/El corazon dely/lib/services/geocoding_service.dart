import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class GeocodingService extends ChangeNotifier {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  // Cache pour éviter les appels répétés
  final Map<String, LatLng> _addressCache = {};

  /// Convertit une adresse en coordonnées latitude/longitude
  Future<LatLng?> geocodeAddress(String address) async {
    try {
      // Vérifier le cache d'abord
      if (_addressCache.containsKey(address)) {
        return _addressCache[address];
      }

      // Utiliser l'API de géocodage de Google
      final String apiKey = ApiConfig.googleMapsApiKey;
      if (apiKey.isEmpty || apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
        throw Exception('Clé API Google Maps non configurée');
      }
      final String encodedAddress = Uri.encodeComponent(address);
      final String url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final latLng = LatLng(
            location['lat'].toDouble(),
            location['lng'].toDouble(),
          );

          // Mettre en cache le résultat
          _addressCache[address] = latLng;

          debugPrint(
              'GeocodingService: Adresse géocodée - $address -> $latLng');
          return latLng;
        } else {
          debugPrint(
              'GeocodingService: Erreur de géocodage - ${data['status']}');
          return null;
        }
      } else {
        debugPrint('GeocodingService: Erreur HTTP - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('GeocodingService: Erreur de géocodage - $e');
      return null;
    }
  }

  /// Convertit des coordonnées en adresse (géocodage inverse)
  Future<String?> reverseGeocode(LatLng coordinates) async {
    try {
      final String apiKey = ApiConfig.googleMapsApiKey;
      if (apiKey.isEmpty || apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
        throw Exception('Clé API Google Maps non configurée');
      }
      final String url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${coordinates.latitude},${coordinates.longitude}&key=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final address = data['results'][0]['formatted_address'];
          debugPrint(
              'GeocodingService: Coordonnées inversées - $coordinates -> $address');
          return address;
        } else {
          debugPrint(
              'GeocodingService: Erreur de géocodage inverse - ${data['status']}');
          return null;
        }
      } else {
        debugPrint('GeocodingService: Erreur HTTP - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('GeocodingService: Erreur de géocodage inverse - $e');
      return null;
    }
  }

  /// Calcule la distance entre deux points en kilomètres
  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Rayon de la Terre en km

    final double lat1Rad = point1.latitude * (3.14159265359 / 180);
    final double lat2Rad = point2.latitude * (3.14159265359 / 180);
    final double deltaLatRad =
        (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    final double deltaLngRad =
        (point2.longitude - point1.longitude) * (3.14159265359 / 180);

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  /// Calcule le temps de trajet estimé en minutes
  Future<int?> calculateTravelTime(LatLng origin, LatLng destination) async {
    try {
      final String apiKey = ApiConfig.googleMapsApiKey;
      if (apiKey.isEmpty || apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
        throw Exception('Clé API Google Maps non configurée');
      }
      final String url =
          'https://maps.googleapis.com/maps/api/distancematrix/json?'
          'origins=${origin.latitude},${origin.longitude}&'
          'destinations=${destination.latitude},${destination.longitude}&'
          'mode=driving&key=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['rows'].isNotEmpty) {
          final duration = data['rows'][0]['elements'][0]['duration']
              ['value']; // en secondes
          final minutes = (duration / 60).round();
          debugPrint(
              'GeocodingService: Temps de trajet calculé - $minutes minutes');
          return minutes;
        } else {
          debugPrint(
              'GeocodingService: Erreur de calcul de temps - ${data['status']}');
          return null;
        }
      } else {
        debugPrint('GeocodingService: Erreur HTTP - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('GeocodingService: Erreur de calcul de temps - $e');
      return null;
    }
  }

  /// Obtient les directions entre deux points
  /// Retourne une liste de points LatLng (classe locale)
  Future<List<LatLng>?> getDirections(LatLng origin, LatLng destination) async {
    try {
      final String apiKey = ApiConfig.googleMapsApiKey;
      if (apiKey.isEmpty || apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
        throw Exception('Clé API Google Maps non configurée');
      }
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'key=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'];
          final List<LatLng> points = [];

          for (var leg in legs) {
            final steps = leg['steps'];
            for (var step in steps) {
              final startLocation = step['start_location'];
              points.add(LatLng(
                startLocation['lat'].toDouble(),
                startLocation['lng'].toDouble(),
              ));
            }
          }

          // Ajouter le point final
          final endLocation = legs.last['end_location'];
          points.add(LatLng(
            endLocation['lat'].toDouble(),
            endLocation['lng'].toDouble(),
          ));

          debugPrint(
              'GeocodingService: Directions obtenues - ${points.length} points');
          return points;
        } else {
          debugPrint(
              'GeocodingService: Erreur de directions - ${data['status']}');
          return null;
        }
      } else {
        debugPrint('GeocodingService: Erreur HTTP - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('GeocodingService: Erreur de directions - $e');
      return null;
    }
  }

  /// Vide le cache de géocodage
  void clearCache() {
    _addressCache.clear();
    debugPrint('GeocodingService: Cache vidé');
  }
}

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LatLng &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}
