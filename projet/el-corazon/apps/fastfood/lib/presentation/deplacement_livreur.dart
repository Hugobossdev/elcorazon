/// Comment le repère du livreur passe d'une position à la suivante.
///
/// ## Pourquoi ce n'est pas simplement `setState(position)`
///
/// Le livreur émet une position toutes les dix secondes environ. Reposer le
/// repère à chaque message le fait **sauter** d'une centaine de mètres, dix
/// fois par minute : la carte donne l'impression d'un suivi cassé alors que
/// tout fonctionne, et le client ne peut pas lire la direction que prend son
/// livreur — il ne voit qu'un point qui clignote d'un endroit à l'autre.
///
/// Glisser entre les deux positions rend le trajet lisible sans rien inventer :
/// le point intermédiaire n'est pas une position relevée et ne prétend pas
/// l'être, c'est une **interpolation d'affichage**. Elle ne sert donc qu'au
/// repère — jamais aux distances, à la vitesse moyenne ou à l'alerte de
/// proximité, qui continuent de porter sur les relevés réels.
///
/// Extrait de l'écran de suivi pour être testable : les trois règles qui
/// suivent — le seuil de saut, la borne de durée, le calcul du point — se
/// vérifient sans monter une carte Google.
library;

import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';


/// Au-delà de cette distance, on **repose** le repère au lieu de le faire
/// glisser.
///
/// Un tel écart ne vient jamais d'un déplacement observé pendant l'intervalle
/// d'émission : c'est un premier relevé, une reprise après un tunnel, ou un
/// point aberrant. Animer sur trois kilomètres montrerait un livreur traverser
/// la ville en ligne droite à travers les immeubles, ce qui est plus faux que
/// le saut qu'on voulait éviter.
const double sautAuDelaDeMetres = 2000;

/// En deçà, le déplacement ne se voit pas à l'écran : l'animer coûte des
/// images pour rien.
const double glissementEnDecaDeMetres = 3;

/// Durée du glissement, bornée.
///
/// Calée sur la cadence d'émission pour que le repère arrive à peu près quand
/// le relevé suivant se présente : plus court, il attend, immobile, l'essentiel
/// de l'intervalle — ce qu'on cherchait justement à éviter ; plus long, il
/// traîne derrière la position réelle et le retard s'accumule.
///
/// [cadence] est l'intervalle d'émission attendu ([TrackingSettings.emissionInterval]
/// côté livreur). La borne haute la ramène sous la seconde et demie : au-delà,
/// un client qui regarde la carte voit un point qui rampe.
Duration dureeDeGlissement(double distanceMetres, {required Duration cadence}) {
  if (distanceMetres <= glissementEnDecaDeMetres ||
      distanceMetres >= sautAuDelaDeMetres) {
    return Duration.zero;
  }

  // Proportionnelle à la distance, sur la part de la cadence qu'un déplacement
  // ordinaire couvre. Un livreur en ville parcourt de l'ordre de 80 m entre
  // deux relevés ; c'est cette échelle qui donne la fraction.
  final fraction = (distanceMetres / 80).clamp(0.0, 1.0);
  final millisecondes =
      (cadence.inMilliseconds * 0.15 * (0.4 + 0.6 * fraction)).round();

  return Duration(
    milliseconds: millisecondes.clamp(250, 1500),
  );
}

/// Le point à afficher, à l'avancement [t] entre [depart] et [arrivee].
///
/// [t] est borné à `[0, 1]` : une animation qui déborde — ce qui arrive au
/// dernier tic d'une courbe élastique — projetterait le repère au-delà de la
/// position relevée, donc devant un livreur qui n'y est pas.
///
/// Interpolation linéaire en degrés, et non sur la grande orbe. Sur les
/// quelques centaines de mètres qui séparent deux relevés, l'écart entre les
/// deux est de l'ordre du centimètre — invisible à tout niveau de zoom, pour un
/// calcul dix fois plus court.
LatLng pointIntermediaire(LatLng depart, LatLng arrivee, double t) {
  final avancement = t.clamp(0.0, 1.0);
  return LatLng(
    depart.latitude + (arrivee.latitude - depart.latitude) * avancement,
    depart.longitude + (arrivee.longitude - depart.longitude) * avancement,
  );
}

/// Cap, en degrés, du segment [depart] → [arrivee]. `null` si les deux points
/// se confondent — un livreur immobile n'a pas de direction, et faire pivoter
/// son repère vers un cap calculé sur du bruit GPS le ferait tourner sur
/// place.
double? capDuSegment(LatLng depart, LatLng arrivee) {
  final dLat = arrivee.latitude - depart.latitude;
  final dLon = arrivee.longitude - depart.longitude;
  if (dLat.abs() < 1e-7 && dLon.abs() < 1e-7) return null;

  // Les longitudes se resserrent avec la latitude : sans ce facteur, un
  // déplacement plein est vers l'est se lirait « nord-est » près de l'équateur
  // et « est-sud-est » plus haut.
  final radians = math.atan2(
    dLon * math.cos(depart.latitude * math.pi / 180),
    dLat,
  );
  return (radians * 180 / math.pi + 360) % 360;
}
