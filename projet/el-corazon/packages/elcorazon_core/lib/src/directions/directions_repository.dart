import 'dart:math' as math;

import 'package:dio/dio.dart';

import 'package:elcorazon_core/src/directions/geo_point.dart';
import 'package:elcorazon_core/src/directions/route_info.dart';

/// Itinéraires et distances — API Google Directions et Distance Matrix.
///
/// Seul dépôt du socle qui ne parle pas à notre serveur : il s'adresse à
/// Google, avec la clé Maps de l'application. Il ne passe donc pas par
/// [ApiClient], qui attache un jeton de session et une URL de base qui n'ont
/// rien à faire dans une requête sortante vers un tiers.
///
/// Les deux applications qui l'utilisaient en portaient chacune une copie
/// (86 % de similarité). Elles divergeaient sur le transport : `fastfood`
/// construisait ses URL avec `Uri.https`, `dely` les concaténait à la main —
/// et n'encodait donc pas ses points de passage, ce qui casse la requête dès
/// qu'un paramètre contient un caractère réservé. C'est la première forme qui
/// est retenue ici.
class DirectionsRepository {
  /// [testAdapter] n'a qu'un usage : simuler Google dans les tests, comme le
  /// fait [ApiClient]. Ne jamais le renseigner en dehors des tests.
  DirectionsRepository({
    required this.apiKey,
    Duration timeout = const Duration(seconds: 12),
    this.cacheDuration = const Duration(minutes: 5),
    HttpClientAdapter? testAdapter,
  }) : _dio = Dio(BaseOptions(connectTimeout: timeout, receiveTimeout: timeout)) {
    if (testAdapter != null) _dio.httpClientAdapter = testAdapter;
  }

  final String apiKey;

  /// Durée de validité d'un itinéraire en cache. Au-delà, il est recalculé :
  /// le trafic a bougé, et une durée d'il y a une heure induit en erreur.
  final Duration cacheDuration;

  final Dio _dio;
  final Map<String, RouteInfo> _cacheItineraires = {};

  /// Itinéraire complet entre deux points, tracé compris.
  ///
  /// Rend `null` quand la clé API n'est pas configurée — l'écran affiche alors
  /// son tracé de repli plutôt que de casser. Toute autre anomalie lève : une
  /// erreur de quota ou une requête refusée doit se voir, pas se confondre
  /// avec « aucun itinéraire ».
  Future<RouteInfo?> getRoute({
    required GeoPoint origin,
    required GeoPoint destination,
    List<GeoPoint>? waypoints,
    String mode = 'driving',
  }) async {
    if (!_cleConfiguree) return null;

    final cle = _cleDeCache(origin, destination, waypoints, mode);
    final enCache = _cacheItineraires[cle];
    if (enCache != null) {
      if (DateTime.now().difference(enCache.timestamp) < cacheDuration) {
        return enCache;
      }
      _cacheItineraires.remove(cle);
    }

    final donnees = await _appel('/maps/api/directions/json', {
      'origin': '$origin',
      'destination': '$destination',
      'mode': mode,
      if (waypoints != null && waypoints.isNotEmpty)
        'waypoints': waypoints.join('|'),
    });

    final routes = donnees['routes'] as List<dynamic>;
    if (donnees['status'] != 'OK' || routes.isEmpty) {
      throw _erreur(donnees);
    }

    final route = routes.first as Map<String, dynamic>;
    final etape = (route['legs'] as List<dynamic>).first as Map<String, dynamic>;
    final metres = _valeur(etape['distance']);
    final trace = (route['overview_polyline'] as Map<String, dynamic>)['points'] as String;

    final itineraire = RouteInfo(
      distanceKm: metres / 1000.0,
      distanceMeters: metres,
      durationMinutes: _minutes(_valeur(etape['duration'])),
      durationInTrafficMinutes: etape['duration_in_traffic'] == null
          ? null
          : _minutes(_valeur(etape['duration_in_traffic'])),
      polylinePoints: decodePolyline(trace),
      encodedPolyline: trace,
      timestamp: DateTime.now(),
    );

    _cacheItineraires[cle] = itineraire;
    return itineraire;
  }

  /// Distance et durée seules — Distance Matrix, sans le tracé.
  ///
  /// Moins de données transportées et moins de quota consommé que [getRoute]
  /// quand l'écran n'a qu'un « à 3,4 km » à afficher.
  Future<DistanceTimeInfo?> getDistanceAndTime({
    required GeoPoint origin,
    required GeoPoint destination,
    String mode = 'driving',
  }) async {
    if (!_cleConfiguree) return null;

    final donnees = await _appel('/maps/api/distancematrix/json', {
      'origins': '$origin',
      'destinations': '$destination',
      'mode': mode,
    });

    final lignes = donnees['rows'] as List<dynamic>;
    if (donnees['status'] != 'OK' || lignes.isEmpty) throw _erreur(donnees);

    final premiere = lignes.first as Map<String, dynamic>;
    final element =
        (premiere['elements'] as List<dynamic>).first as Map<String, dynamic>;
    if (element['status'] != 'OK') {
      throw DirectionsException(
        'Impossible de calculer la distance',
        status: element['status'] as String? ?? 'UNKNOWN',
      );
    }

    final metres = _valeur(element['distance']);
    return DistanceTimeInfo(
      distanceKm: metres / 1000.0,
      distanceMeters: metres,
      durationMinutes: _minutes(_valeur(element['duration'])),
      durationInTrafficMinutes: element['duration_in_traffic'] == null
          ? null
          : _minutes(_valeur(element['duration_in_traffic'])),
    );
  }

  /// Distance à vol d'oiseau, en kilomètres (formule de haversine).
  ///
  /// Recours quand Google est injoignable : elle sous-estime toujours un
  /// trajet réel, mais elle ne consomme ni réseau ni quota.
  double straightLineDistanceKm(GeoPoint a, GeoPoint b) {
    const rayonTerrestreKm = 6371.0;
    double radians(double degres) => degres * math.pi / 180;

    final dLat = radians(b.latitude - a.latitude);
    final dLng = radians(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radians(a.latitude)) *
            math.cos(radians(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    return rayonTerrestreKm * 2 * math.asin(math.sqrt(h));
  }

  /// Décode un tracé au format « encoded polyline » de Google.
  ///
  /// Publique et non privée parce que c'est la seule logique de ce dépôt qui
  /// se teste sans réseau, et la seule dont une erreur se verrait à l'écran
  /// sous forme d'un trait qui part de travers.
  List<GeoPoint> decodePolyline(String encoded) {
    final points = <GeoPoint>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    int prochainDelta() {
      var decalage = 0;
      var resultat = 0;
      int octet;
      do {
        octet = encoded.codeUnitAt(index++) - 63;
        resultat |= (octet & 0x1F) << decalage;
        decalage += 5;
      } while (octet >= 0x20);
      // Bit de poids faible à 1 = valeur négative, en complément à un.
      return (resultat & 1) != 0 ? ~(resultat >> 1) : resultat >> 1;
    }

    while (index < encoded.length) {
      lat += prochainDelta();
      lng += prochainDelta();
      points.add(GeoPoint(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  /// Vide le cache des itinéraires.
  void clearCache() => _cacheItineraires.clear();

  bool get _cleConfiguree =>
      apiKey.isNotEmpty &&
      apiKey != 'YOUR_GOOGLE_MAPS_API_KEY' &&
      apiKey != 'your-google-maps-api-key';

  Future<Map<String, dynamic>> _appel(
    String chemin,
    Map<String, String> parametres,
  ) async {
    // `Uri.https` encode les paramètres. La copie de `dely` concaténait la
    // chaîne à la main : un point de passage suffisait à produire une URL
    // invalide.
    final uri = Uri.https('maps.googleapis.com', chemin, {
      ...parametres,
      'key': apiKey,
    });
    final reponse = await _dio.getUri<Map<String, dynamic>>(uri);
    return reponse.data ?? const {};
  }

  static int _valeur(Object? mesure) =>
      ((mesure! as Map<String, dynamic>)['value'] as num).toInt();

  static int _minutes(int secondes) => (secondes / 60).round();

  static DirectionsException _erreur(Map<String, dynamic> donnees) {
    final status = donnees['status'] as String? ?? 'UNKNOWN';
    return DirectionsException(
      _messages[status] ?? donnees['error_message'] as String? ?? 'Erreur inconnue',
      status: status,
    );
  }

  static const _messages = {
    'ZERO_RESULTS': 'Aucun itinéraire trouvé entre ces points',
    'NOT_FOUND': 'Point de départ ou d’arrivée introuvable',
    'OVER_QUERY_LIMIT': 'Quota API dépassé. Veuillez réessayer plus tard',
    'REQUEST_DENIED': 'Requête refusée. Vérifiez votre clé API',
  };

  String _cleDeCache(
    GeoPoint origin,
    GeoPoint destination,
    List<GeoPoint>? waypoints,
    String mode,
  ) =>
      // Accolades obligatoires : `$origin_` se lirait comme un identifiant.
      '${origin}_${destination}_${waypoints?.join('|') ?? ''}_$mode';
}

/// Refus de Google, avec son code — `ZERO_RESULTS`, `OVER_QUERY_LIMIT`…
///
/// Une exception typée plutôt qu'un `Exception(String)` : l'appelant qui veut
/// distinguer « aucun itinéraire » (normal) d'un quota dépassé (à signaler)
/// n'a pas à lire un message pour le savoir.
class DirectionsException implements Exception {
  const DirectionsException(this.message, {required this.status});

  final String message;
  final String status;

  @override
  String toString() => 'DirectionsException($status): $message';
}
