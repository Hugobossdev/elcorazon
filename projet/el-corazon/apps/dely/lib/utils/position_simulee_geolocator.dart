import 'package:elcorazon_core/elcorazon_core.dart' show GeoCalcul, GeoPoint, PositionSimulee;
import 'package:geolocator/geolocator.dart';

/// Passerelle entre la simulation du socle et le type `Position` de Geolocator.
///
/// `PositionSimulee` vit dans `elcorazon_core`, qui n'embarque pas Geolocator :
/// le socle sert l'API, la session et le temps réel, et lui faire dépendre d'un
/// greffon de plateforme rendrait ses tests inexécutables sans appareil. La
/// conversion se fait donc ici, à la frontière — comme celle de `GeoPoint` vers
/// `LatLng` dans les écrans de carte.
///
/// **Mode debug uniquement.** `PositionSimulee.point` répond toujours `null`
/// hors `kDebugMode`, si bien que [positionSimuleeOuNull] rend `null` et que
/// [fluxDePositions] retombe sur le capteur réel. Aucun chemin ne mène d'une
/// position inventée à un client.

/// La simulation tourne-t-elle ?
///
/// Toujours faux hors debug. Exposé parce que deux décisions en dépendent
/// ailleurs : ne pas exiger de permission de localisation pour un trajet
/// rejoué, et afficher au développeur d'où vient le point qu'il regarde.
bool get simulationDePositionActive => PositionSimulee().estActive;

/// Position simulée, à la forme qu'attendent les écrans, ou `null`.
///
/// Les champs que la simulation n'a pas de sens à inventer sont annoncés
/// neutres plutôt que tirés au hasard : une précision de zone (`accuracy: 0`)
/// dit « on sait exactement où », ce qui est le cas d'un point qu'on a posé
/// soi-même. Aucun de ces champs n'est lu ailleurs qu'à l'affichage.
Position? positionSimuleeOuNull() {
  final point = PositionSimulee().point;
  if (point == null) return null;
  return _versPosition(point);
}

/// Le flux de positions à écouter : celui du simulateur s'il tourne, sinon
/// celui du capteur.
///
/// Le choix se fait **à l'abonnement** et non à chaque relevé : basculer en
/// cours de course laisserait deux sources émettre en alternance, et le suivi
/// sauterait entre deux villes. Pour changer de source, on arrête et on relance
/// le suivi — ce que fait `RealtimeTrackingService.relancerLeFluxDePosition`.
///
/// ## Cap et vitesse
///
/// Ils sont **calculés à partir des points successifs**, et non annoncés nuls.
/// Un trajet rejoué doit exercer le même code qu'une course réelle : c'est
/// l'orientation du repère, la rotation de la carte et le lissage du cap à
/// l'arrêt qui en dépendent, et les laisser à zéro reviendrait à ne jamais les
/// vérifier avant d'être sur la route. La vitesse se déduit de la distance
/// parcourue entre deux émissions et du temps écoulé — c'est exactement ce que
/// fait un récepteur GPS.
Stream<Position> fluxDePositions(LocationSettings reglages) {
  final simulation = PositionSimulee();
  if (!simulation.estActive) {
    return Geolocator.getPositionStream(locationSettings: reglages);
  }

  return _flux(simulation);
}

Stream<Position> _flux(PositionSimulee simulation) async* {
  GeoPoint? precedent;
  DateTime? precedentA;

  Position tracer(GeoPoint point) {
    final maintenant = DateTime.now();
    var cap = 0.0;
    var vitesse = 0.0;

    final avant = precedent;
    final avantA = precedentA;
    if (avant != null && avantA != null) {
      final metres = GeoCalcul.distanceMetres(avant, point);
      final secondes = maintenant.difference(avantA).inMilliseconds / 1000;
      // Deux points confondus ne définissent pas de cap : le conserver à zéro
      // ferait pointer le repère au nord à chaque arrêt. Le cap précédent est
      // gardé par le moteur de navigation, qui refuse déjà de tourner en
      // dessous d'un mètre par seconde.
      if (metres > 0.5) cap = GeoCalcul.capDegres(avant, point);
      if (secondes > 0) vitesse = metres / secondes;
    }

    precedent = point;
    precedentA = maintenant;
    return _versPosition(point, cap: cap, vitesse: vitesse, horodatage: maintenant);
  }

  // Le point courant d'abord : un trajet rejoué n'émet qu'à sa cadence, et
  // l'écran resterait vide pendant les premières secondes.
  final courant = simulation.point;
  if (courant != null) yield tracer(courant);

  await for (final point in simulation.flux) {
    yield tracer(point);
  }
}

Position _versPosition(
  GeoPoint point, {
  double cap = 0,
  double vitesse = 0,
  DateTime? horodatage,
}) {
  return Position(
    latitude: point.latitude,
    longitude: point.longitude,
    timestamp: horodatage ?? DateTime.now(),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: cap,
    headingAccuracy: 0,
    speed: vitesse,
    speedAccuracy: 0,
  );
}
