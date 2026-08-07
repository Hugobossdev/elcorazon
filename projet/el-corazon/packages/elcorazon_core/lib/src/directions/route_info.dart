import 'package:elcorazon_core/src/directions/geo_point.dart';

/// Durée et distance d'un trajet, telles qu'un écran les montre.
///
/// Mise en facteur de [RouteInfo] et [DistanceTimeInfo], qui portaient la même
/// paire de formateurs recopiée — deux fois par application, quatre fois en
/// tout avant le lot 2.3.
mixin TrajetMesure {
  double get distanceKm;
  int get distanceMeters;
  int get durationMinutes;

  /// Renseignée par Google quand le trafic est connu sur l'itinéraire.
  int? get durationInTrafficMinutes;

  /// La durée à afficher : celle du trafic si le service l'a fournie.
  int get effectiveDurationMinutes =>
      durationInTrafficMinutes ?? durationMinutes;

  /// « 850m » en deçà du kilomètre, « 3.4 km » au-delà.
  ///
  /// Le seuil est sur [distanceKm] et l'affichage court sur [distanceMeters] :
  /// écrire « 0.8 km » pour une rue à traverser se lit moins bien que « 800m ».
  String get formattedDistance =>
      distanceKm < 1 ? '${distanceMeters}m' : '${distanceKm.toStringAsFixed(1)} km';

  /// « 45min » en deçà de l'heure, « 1h 15min » au-delà.
  String get formattedDuration {
    if (effectiveDurationMinutes < 60) return '${effectiveDurationMinutes}min';
    final heures = effectiveDurationMinutes ~/ 60;
    final minutes = effectiveDurationMinutes % 60;
    return '${heures}h ${minutes}min';
  }
}

/// Itinéraire complet — mesures et tracé.
class RouteInfo with TrajetMesure {
  RouteInfo({
    required this.distanceKm,
    required this.distanceMeters,
    required this.durationMinutes,
    required this.polylinePoints,
    required this.encodedPolyline,
    required this.timestamp,
    this.durationInTrafficMinutes,
  });

  @override
  final double distanceKm;
  @override
  final int distanceMeters;
  @override
  final int durationMinutes;
  @override
  final int? durationInTrafficMinutes;

  /// Tracé décodé, prêt à être posé sur une carte.
  final List<GeoPoint> polylinePoints;

  /// Le même tracé sous sa forme compressée Google, conservé tel quel : c'est
  /// ce qui se stocke ou se retransmet sans réencoder.
  final String encodedPolyline;

  /// Moment du calcul — c'est lui qui date l'entrée en cache.
  final DateTime timestamp;
}

/// Mesures seules, sans tracé — réponse de l'API Distance Matrix.
class DistanceTimeInfo with TrajetMesure {
  DistanceTimeInfo({
    required this.distanceKm,
    required this.distanceMeters,
    required this.durationMinutes,
    this.durationInTrafficMinutes,
  });

  @override
  final double distanceKm;
  @override
  final int distanceMeters;
  @override
  final int durationMinutes;
  @override
  final int? durationInTrafficMinutes;
}
