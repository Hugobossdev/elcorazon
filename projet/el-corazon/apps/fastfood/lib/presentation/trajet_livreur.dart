import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Ce qu'on sait du trajet d'un livreur d'après les positions relevées.
class StatistiquesTrajet {
  const StatistiquesTrajet({
    required this.distanceParcourue,
    required this.vitesseMoyenne,
  });

  /// En kilomètres, somme des sauts entre positions successives.
  final double distanceParcourue;

  /// En km/h, ou `null` si aucune vitesse plausible n'a pu être retenue.
  ///
  /// `null` et zéro ne disent pas la même chose : le premier veut dire qu'on
  /// ne sait pas, le second que le livreur ne bouge pas.
  final double? vitesseMoyenne;
}

/// Distance et vitesse moyenne d'un trajet, d'après [historique].
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Ce calcul était une méthode privée de `delivery_tracking_screen.dart` qui
/// écrivait directement dans l'état du widget. Rien ne pouvait l'interroger,
/// alors qu'il porte trois règles qui méritent de l'être : l'ordre de
/// l'historique, le rejet des valeurs aberrantes et la double source de
/// vitesse.
///
/// [historique] va **du plus récent au plus ancien** — l'écran empile ses
/// relevés par `insert(0, …)`. L'écart de temps entre l'élément `i` et
/// l'élément `i+1` est donc positif, et c'est ce qui fait marcher le calcul.
///
/// [distanceEntre] est passée plutôt qu'importée : le calcul de distance vit
/// dans un service, et l'y appeler enfermerait de nouveau cette fonction.
///
/// Deux sources de vitesse coexistent et sont **toutes deux** retenues quand
/// elles existent : celle déduite de la distance et du temps, et celle que le
/// GPS rapporte dans `speed` (en m/s). Les valeurs hors de `]0, 100[` km/h
/// sont écartées comme aberrantes.
StatistiquesTrajet statistiquesDuTrajet(
  List<Map<String, dynamic>> historique, {
  required double Function(LatLng, LatLng) distanceEntre,
}) {
  if (historique.length < 2) {
    return const StatistiquesTrajet(distanceParcourue: 0, vitesseMoyenne: null);
  }

  var distanceTotale = 0.0;
  final vitesses = <double>[];

  for (var i = 0; i < historique.length - 1; i++) {
    final recent = historique[i];
    final precedent = historique[i + 1];

    final distance = distanceEntre(
      _position(recent),
      _position(precedent),
    );
    distanceTotale += distance;

    final secondes = (recent['timestamp'] as DateTime)
        .difference(precedent['timestamp'] as DateTime)
        .inSeconds;
    if (secondes > 0) {
      _retenirSiPlausible(vitesses, distance / (secondes / 3600));
    }

    final gps = recent['speed'] as double?;
    if (gps != null) {
      _retenirSiPlausible(vitesses, gps * 3.6);
    }
  }

  return StatistiquesTrajet(
    distanceParcourue: distanceTotale,
    vitesseMoyenne: vitesses.isEmpty
        ? null
        : vitesses.reduce((a, b) => a + b) / vitesses.length,
  );
}

LatLng _position(Map<String, dynamic> releve) => LatLng(
      releve['latitude'] as double,
      releve['longitude'] as double,
    );

void _retenirSiPlausible(List<double> vitesses, double kmh) {
  if (kmh > 0 && kmh < 100) vitesses.add(kmh);
}

/// La distance, en kilomètres, sous laquelle on prévient le client que son
/// livreur arrive.
///
/// 500 mètres. Le chiffre était écrit au milieu du corps d'un widget, sous la
/// forme `distance < 0.5` commentée « moins de 500 mètres ».
const double seuilDAlerteDeProximite = 0.5;

/// Le livreur est-il assez près pour qu'on prévienne le client ?
bool livreurToutProche(double distanceKm) =>
    distanceKm < seuilDAlerteDeProximite;

/// Le temps de trajet estimé, à défaut de réponse du service d'itinéraire.
///
/// Deux minutes par kilomètre, soit 30 km/h — l'allure d'un deux-roues en
/// ville. C'est un **repli** : l'écran demande d'abord une vraie durée au
/// service, et ne retombe ici que s'il n'en obtient pas.
///
/// Le résultat est arrondi à la minute, donc une distance inférieure à 250
/// mètres donne « 0 min ». C'est le comportement actuel.
int minutesEstimeesPourKm(double distanceKm) => (distanceKm * 2).round();
