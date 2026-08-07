import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:elcora_dely/config/api_config.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

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
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? const [];

        if (data['status'] == 'OK' && results.isNotEmpty) {
          final premier = results.first as Map<String, dynamic>;
          final geometry = premier['geometry'] as Map<String, dynamic>;
          final location = geometry['location'] as Map<String, dynamic>;
          final latLng = LatLng(
            (location['lat'] as num).toDouble(),
            (location['lng'] as num).toDouble(),
          );

          // Mettre en cache le résultat
          _addressCache[address] = latLng;

          Journal.trace(
              'GeocodingService: Adresse géocodée - $address -> $latLng');
          return latLng;
        } else {
          Journal.trace(
              'GeocodingService: Erreur de géocodage - ${data['status']}');
          return null;
        }
      } else {
        Journal.trace('GeocodingService: Erreur HTTP - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      Journal.trace('GeocodingService: Erreur de géocodage - $e');
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
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? const [];

        if (data['status'] == 'OK' && results.isNotEmpty) {
          final address =
              (results.first as Map<String, dynamic>)['formatted_address']
                  as String?;
          Journal.trace(
              'GeocodingService: Coordonnées inversées - $coordinates -> $address');
          return address;
        } else {
          Journal.trace(
              'GeocodingService: Erreur de géocodage inverse - ${data['status']}');
          return null;
        }
      } else {
        Journal.trace('GeocodingService: Erreur HTTP - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      Journal.trace('GeocodingService: Erreur de géocodage inverse - $e');
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
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rows = data['rows'] as List<dynamic>? ?? const [];

        if (data['status'] == 'OK' && rows.isNotEmpty) {
          final premiere = rows.first as Map<String, dynamic>;
          final element = (premiere['elements'] as List<dynamic>).first
              as Map<String, dynamic>;
          final duration = (element['duration'] as Map<String, dynamic>)['value']
              as num; // en secondes
          final minutes = (duration / 60).round();
          Journal.trace(
              'GeocodingService: Temps de trajet calculé - $minutes minutes');
          return minutes;
        } else {
          Journal.trace(
              'GeocodingService: Erreur de calcul de temps - ${data['status']}');
          return null;
        }
      } else {
        Journal.trace('GeocodingService: Erreur HTTP - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      Journal.trace('GeocodingService: Erreur de calcul de temps - $e');
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
        final data = json.decode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>? ?? const [];

        if (data['status'] == 'OK' && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final legs = route['legs'] as List<dynamic>;
          final points = <LatLng>[];

          LatLng point(Map<String, dynamic> coordonnees) => LatLng(
                (coordonnees['lat'] as num).toDouble(),
                (coordonnees['lng'] as num).toDouble(),
              );

          for (final leg in legs) {
            final steps = (leg as Map<String, dynamic>)['steps'] as List<dynamic>;
            for (final step in steps) {
              final depart = (step as Map<String, dynamic>)['start_location']
                  as Map<String, dynamic>;
              points.add(point(depart));
            }
          }

          // Ajouter le point final
          final arrivee = (legs.last as Map<String, dynamic>)['end_location']
              as Map<String, dynamic>;
          points.add(point(arrivee));

          Journal.trace(
              'GeocodingService: Directions obtenues - ${points.length} points');
          return points;
        } else {
          Journal.trace(
              'GeocodingService: Erreur de directions - ${data['status']}');
          return null;
        }
      } else {
        Journal.trace('GeocodingService: Erreur HTTP - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      Journal.trace('GeocodingService: Erreur de directions - $e');
      return null;
    }
  }

  /// Vide le cache de géocodage
  void clearCache() {
    _addressCache.clear();
    Journal.trace('GeocodingService: Cache vidé');
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
