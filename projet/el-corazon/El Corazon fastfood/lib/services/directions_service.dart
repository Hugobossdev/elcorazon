import 'package:elcora_fast/config/api_config.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

export 'package:elcorazon_core/elcorazon_core.dart'
    show DirectionsException, DistanceTimeInfo, GeoPoint, RouteInfo;

/// Adaptation entre les `LatLng` de la carte et le dépôt d'itinéraires du socle.
///
/// Le calcul lui-même vit dans `DirectionsRepository` (`elcorazon_core`) depuis
/// le lot 2.3 : cette application et celle du livreur en portaient chacune une
/// copie, à 86 % identiques, dont les tracés et les caches se maintenaient
/// séparément. Il ne reste ici que la conversion des coordonnées et la lecture
/// de la clé API, qui sont propres à l'application.
///
/// Ce n'est plus un `ChangeNotifier` : l'ancien l'était sans jamais appeler
/// `notifyListeners`, et aucun arbre de providers ne l'enregistrait.
class DirectionsService {
  factory DirectionsService() => _instance;
  DirectionsService._();

  static final DirectionsService _instance = DirectionsService._();

  DirectionsRepository? _depot;

  /// La clé est relue à chaque appel, comme avant ce lot : `dotenv` peut ne pas
  /// être encore chargé quand l'écran construit le service, et une clé lue une
  /// seule fois trop tôt resterait vide pour toute la session. Le dépôt — donc
  /// son cache — n'est reconstruit que si la clé a réellement changé.
  DirectionsRepository get _depotCourant {
    final cle = ApiConfig.googleMapsApiKey;
    final existant = _depot;
    if (existant != null && existant.apiKey == cle) return existant;
    return _depot = DirectionsRepository(apiKey: cle);
  }

  /// Itinéraire complet entre deux points.
  ///
  /// Rend `null` si la clé Google n'est pas configurée — l'appelant retombe
  /// alors sur son tracé de repli, ce qu'il faisait déjà : l'ancienne version
  /// levait dans ce cas, et les deux écrans traitaient l'exception exactement
  /// comme ils traitent aujourd'hui l'absence de résultat.
  Future<RouteInfo?> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
    String mode = 'driving',
  }) {
    return _depotCourant.getRoute(
      origin: origin.enGeoPoint,
      destination: destination.enGeoPoint,
      waypoints: waypoints?.map((p) => p.enGeoPoint).toList(),
      mode: mode,
    );
  }

  /// Distance et durée seules, sans tracé.
  Future<DistanceTimeInfo?> getDistanceAndTime({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving',
  }) {
    return _depotCourant.getDistanceAndTime(
      origin: origin.enGeoPoint,
      destination: destination.enGeoPoint,
      mode: mode,
    );
  }

  /// Distance à vol d'oiseau en kilomètres — repli hors ligne.
  double calculateStraightLineDistance(LatLng point1, LatLng point2) =>
      _depotCourant.straightLineDistanceKm(point1.enGeoPoint, point2.enGeoPoint);

  /// Vide le cache des itinéraires.
  void clearCache() => _depotCourant.clearCache();
}

extension LatLngEnGeoPoint on LatLng {
  GeoPoint get enGeoPoint => GeoPoint(latitude, longitude);
}

extension GeoPointsEnLatLng on List<GeoPoint> {
  /// Tracé du socle, sous la forme qu'attend `Polyline`.
  List<LatLng> get enLatLng =>
      map((p) => LatLng(p.latitude, p.longitude)).toList();
}
