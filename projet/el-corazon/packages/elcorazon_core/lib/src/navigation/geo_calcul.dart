import 'dart:math' as math;

import 'package:elcorazon_core/src/directions/geo_point.dart';

/// Les quatre calculs géométriques dont la navigation a besoin, et rien de plus.
///
/// ## Pourquoi ils sont réunis ici
///
/// La formule de haversine était écrite **trois fois** dans le dépôt avant
/// cette tranche : dans `DirectionsRepository` (en kilomètres, avec `asin`),
/// dans `PositionSimulee` (en mètres, avec `atan2`), et une troisième fois à
/// la main dans l'écran de suivi du livreur, avec son propre
/// `_degreesToRadians` et sa constante π recopiée. Trois copies justes, mais
/// trois copies : le jour où l'une se corrige, les deux autres ne le savent
/// pas.
///
/// Les deux autres calculs — le cap et la distance à un segment — n'existaient
/// nulle part, et ce sont eux qui décident de tout ce qu'une navigation fait
/// d'utile : orienter le repère du livreur, et savoir s'il a quitté
/// l'itinéraire.
///
/// Aucune dépendance de plateforme. `Geolocator.distanceBetween` ferait le
/// premier calcul, mais il exige un greffon monté : un test qui vérifie une
/// sortie d'itinéraire ne pourrait alors pas s'exécuter sans appareil, ce qui
/// est exactement la situation qu'on veut éviter.
abstract final class GeoCalcul {
  static const double _rayonTerrestreMetres = 6371000.0;

  static double _radians(double degres) => degres * math.pi / 180;

  static double _degres(double radians) => radians * 180 / math.pi;

  /// Distance entre deux points, en mètres, par la formule de haversine.
  static double distanceMetres(GeoPoint a, GeoPoint b) {
    final dLat = _radians(b.latitude - a.latitude);
    final dLon = _radians(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(a.latitude)) *
            math.cos(_radians(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * _rayonTerrestreMetres * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  /// Cap de [depart] vers [arrivee], en degrés depuis le nord, dans `[0, 360[`.
  ///
  /// C'est ce qui oriente le repère du livreur et fait tourner la carte dans
  /// son sens de marche. Le cap **rendu par le capteur** est préféré quand il
  /// existe ; celui-ci sert quand il manque — un GPS immobile ne rend pas de
  /// cap, et un trajet rejoué n'en rend aucun.
  static double capDegres(GeoPoint depart, GeoPoint arrivee) {
    final lat1 = _radians(depart.latitude);
    final lat2 = _radians(arrivee.latitude);
    final dLon = _radians(arrivee.longitude - depart.longitude);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    return (_degres(math.atan2(y, x)) + 360) % 360;
  }

  /// Écart angulaire le plus court entre deux caps, dans `[0, 180]`.
  ///
  /// Sans lui, passer de 359° à 1° se lit comme un demi-tour de 358 degrés, et
  /// la carte pivote violemment sur un livreur qui roule tout droit vers le
  /// nord.
  static double ecartDeCap(double a, double b) {
    final brut = (a - b).abs() % 360;
    return brut > 180 ? 360 - brut : brut;
  }

  /// Distance de [point] au segment `[a, b]`, en mètres, et le point du segment
  /// qui en est le plus proche.
  ///
  /// La projection se fait dans un plan local : à l'échelle d'un segment
  /// d'itinéraire — quelques dizaines à quelques centaines de mètres — la
  /// courbure de la Terre est négligeable, et la traiter coûterait un calcul
  /// sphérique par segment à chaque relevé de position. La longitude est
  /// corrigée par le cosinus de la latitude, sans quoi un degré de longitude
  /// compterait autant qu'un degré de latitude et l'écart serait faux d'un
  /// facteur qui dépend de la latitude — à Lomé, près de deux.
  static ProjectionSurSegment projeterSurSegment(
    GeoPoint point,
    GeoPoint a,
    GeoPoint b,
  ) {
    final cosLat = math.cos(_radians(point.latitude));

    double x(GeoPoint p) => p.longitude * cosLat;
    double y(GeoPoint p) => p.latitude;

    final ax = x(a);
    final ay = y(a);
    final dx = x(b) - ax;
    final dy = y(b) - ay;

    // Segment dégénéré : les deux extrémités confondues. Google en produit,
    // sur un point de passage répété.
    final longueurCarree = dx * dx + dy * dy;
    if (longueurCarree == 0) {
      return ProjectionSurSegment(
        point: a,
        distanceMetres: distanceMetres(point, a),
        fraction: 0,
      );
    }

    // Borné à [0, 1] : au-delà, le pied de la perpendiculaire tombe hors du
    // segment, et c'est alors l'extrémité qui est le point le plus proche.
    final fraction =
        (((x(point) - ax) * dx + (y(point) - ay) * dy) / longueurCarree)
            .clamp(0.0, 1.0);

    final projete = GeoPoint(ay + dy * fraction, (ax + dx * fraction) / cosLat);
    return ProjectionSurSegment(
      point: projete,
      distanceMetres: distanceMetres(point, projete),
      fraction: fraction,
    );
  }

  /// Longueur cumulée d'un tracé, en mètres.
  static double longueurTrace(List<GeoPoint> trace) {
    var total = 0.0;
    for (var i = 0; i < trace.length - 1; i++) {
      total += distanceMetres(trace[i], trace[i + 1]);
    }
    return total;
  }
}

/// Le point d'un segment le plus proche d'une position, et ce qui l'en sépare.
class ProjectionSurSegment {
  const ProjectionSurSegment({
    required this.point,
    required this.distanceMetres,
    required this.fraction,
  });

  /// Le point du segment le plus proche de la position.
  final GeoPoint point;

  /// Ce qui sépare la position du segment, en mètres.
  final double distanceMetres;

  /// Où le point projeté tombe sur le segment : 0 à son début, 1 à sa fin.
  final double fraction;
}
