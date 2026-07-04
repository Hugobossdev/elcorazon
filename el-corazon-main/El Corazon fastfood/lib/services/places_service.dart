import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:elcora_fast/config/api_config.dart';

class PlaceSuggestion {
  final String placeId;
  final String description;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
  });
}

class PlaceDetails {
  final String placeId;
  final String formattedAddress;
  final LatLng location;

  const PlaceDetails({
    required this.placeId,
    required this.formattedAddress,
    required this.location,
  });
}

/// Service Google Places (Autocomplete + Details)
///
/// - Pas de package externe: on appelle directement l'API HTTP.
/// - Nécessite `GOOGLE_MAPS_API_KEY` dans `.env`.
class PlacesService {
  static final PlacesService _instance = PlacesService._internal();
  factory PlacesService() => _instance;
  PlacesService._internal();

  /// Autocomplete (suggestions)
  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    String? language,
    String? countryCode, // ex: "ci"
    LatLng? locationBias,
    int? radiusMeters,
  }) async {
    final apiKey = ApiConfig.googleMapsApiKey;
    if (apiKey.isEmpty) return const [];

    final trimmed = input.trim();
    if (trimmed.length < 3) return const [];

    final params = <String, String>{
      'input': trimmed,
      'key': apiKey,
    };

    if (language != null && language.isNotEmpty) {
      params['language'] = language;
    }
    if (countryCode != null && countryCode.isNotEmpty) {
      params['components'] = 'country:$countryCode';
    }
    if (locationBias != null) {
      params['location'] = '${locationBias.latitude},${locationBias.longitude}';
      if (radiusMeters != null && radiusMeters > 0) {
        params['radius'] = radiusMeters.toString();
      }
    }

    // ⚠️ Web: CORS bloquera maps.googleapis.com. On passe par un proxy backend.
    final uri = kIsWeb
        ? Uri.parse('${ApiConfig.backendUrl}/api/google/places/autocomplete')
            .replace(queryParameters: params)
        : Uri.https(
            'maps.googleapis.com',
            '/maps/api/place/autocomplete/json',
            params,
          );

    final resp = await http.get(uri);
    if (resp.statusCode != 200) return const [];

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final status = data['status']?.toString() ?? '';
    if (status != 'OK') {
      // ZERO_RESULTS est courant
      debugPrint('PlacesService.autocomplete status=$status');
      return const [];
    }

    final preds = (data['predictions'] as List<dynamic>? ?? const []);
    return preds
        .map((p) => p as Map<String, dynamic>)
        .map(
          (p) => PlaceSuggestion(
            placeId: p['place_id']?.toString() ?? '',
            description: p['description']?.toString() ?? '',
          ),
        )
        .where((p) => p.placeId.isNotEmpty && p.description.isNotEmpty)
        .toList();
  }

  /// Détails (pour récupérer lat/lng + adresse formatée)
  Future<PlaceDetails?> getDetails(
    String placeId, {
    String? language,
  }) async {
    final apiKey = ApiConfig.googleMapsApiKey;
    if (apiKey.isEmpty) return null;
    if (placeId.isEmpty) return null;

    final params = <String, String>{
      'place_id': placeId,
      'fields': 'place_id,formatted_address,geometry/location',
      'key': apiKey,
    };
    if (language != null && language.isNotEmpty) {
      params['language'] = language;
    }

    final uri = kIsWeb
        ? Uri.parse('${ApiConfig.backendUrl}/api/google/places/details')
            .replace(queryParameters: params)
        : Uri.https(
            'maps.googleapis.com',
            '/maps/api/place/details/json',
            params,
          );

    final resp = await http.get(uri);
    if (resp.statusCode != 200) return null;

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final status = data['status']?.toString() ?? '';
    if (status != 'OK') {
      debugPrint('PlacesService.getDetails status=$status');
      return null;
    }

    final result = data['result'] as Map<String, dynamic>?;
    if (result == null) return null;

    final formatted = result['formatted_address']?.toString() ?? '';
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final loc = geometry?['location'] as Map<String, dynamic>?;
    final lat = (loc?['lat'] as num?)?.toDouble();
    final lng = (loc?['lng'] as num?)?.toDouble();
    if (lat == null || lng == null || formatted.isEmpty) return null;

    return PlaceDetails(
      placeId: placeId,
      formattedAddress: formatted,
      location: LatLng(lat, lng),
    );
  }
}


