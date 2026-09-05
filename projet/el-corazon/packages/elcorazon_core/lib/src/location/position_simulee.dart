import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:elcorazon_core/src/diagnostics/journal.dart';
import 'package:elcorazon_core/src/directions/geo_point.dart';
import 'package:elcorazon_core/src/navigation/geo_calcul.dart';

/// Position simulée — **mode debug uniquement**.
///
/// ## Le problème qu'elle résout
///
/// Le développement se fait depuis Abidjan ; l'établissement est à Lomé, à
/// 600 km. Tout ce qui dépend de la position réelle de l'appareil devient donc
/// invérifiable : la couverture d'une adresse, la distance au restaurant, le
/// franchissement d'une zone, l'arrivée du livreur, l'estimation d'un délai.
/// Le seul contournement disponible — le simulateur de position du système —
/// n'existe ni sur un appareil Android physique sans mode développeur, ni de
/// façon scriptable, et il ne rejoue pas un trajet.
///
/// ## Ce qu'elle ne change pas
///
/// **Rien, en production.** [activer] est sans effet hors `kDebugMode`, et
/// [estActive] y répond toujours `false` : le compilateur en déduit que les
/// branches de simulation sont mortes et les retire du binaire. Il n'y a donc
/// pas de chemin par lequel une position inventée atteindrait un client — ce
/// qui compte, puisqu'une position fausse en production enverrait un livreur à
/// la mauvaise adresse ou facturerait la mauvaise distance.
///
/// Elle ne remplace pas non plus le calcul de distance ni la résolution de
/// zone : ceux-ci restent au serveur (PostGIS). Elle ne fait qu'une chose —
/// répondre à « où est l'appareil ? » — et c'est précisément la question que le
/// développement à distance ne peut pas poser autrement.
///
/// ## Déplacement
///
/// [suivre] rejoue un trajet point par point, ce qui permet de vérifier ce
/// qu'aucune position fixe ne montre : l'entrée dans une zone, la sortie d'une
/// autre, l'approche du client, la mise à jour d'un délai estimé. Le flux est
/// le même que celui d'un capteur réel — les écrans ne savent pas d'où il
/// vient.
class PositionSimulee {
  PositionSimulee._();

  static final PositionSimulee _instance = PositionSimulee._();

  factory PositionSimulee() => _instance;

  GeoPoint? _point;
  Timer? _parcours;
  final StreamController<GeoPoint> _flux = StreamController<GeoPoint>.broadcast();

  /// Le trajet rejoué, déjà interpolé, et où l'on en est.
  ///
  /// Conservés en champs — et non capturés dans la fermeture de la minuterie —
  /// pour que [interrompre] puisse arrêter le temps sans perdre la place, et
  /// [reprendre] repartir du même point. Une simulation qu'on ne peut que
  /// relancer depuis le début oblige à refaire dix minutes de trajet pour
  /// revoir la dernière annonce.
  List<GeoPoint> _pas = const [];
  int _index = 0;
  Duration _cadence = const Duration(seconds: 2);

  /// Vitesse par défaut d'un trajet rejoué, en km/h. Celle d'une moto de
  /// livraison en ville — assez lente pour qu'on voie les transitions passer.
  static const double vitesseParDefautKmH = 25;

  /// La simulation est-elle en cours ?
  ///
  /// Toujours `false` hors debug, **quoi qu'on ait appelé**. C'est cette
  /// constante qui permet au compilateur d'éliminer les branches de simulation
  /// du binaire de production.
  bool get estActive => kDebugMode && _point != null;

  /// Position simulée courante, ou `null`.
  GeoPoint? get point => estActive ? _point : null;

  /// Flux des positions simulées, pour les écrans qui écoutent un capteur.
  Stream<GeoPoint> get flux => _flux.stream;

  /// Fixe la position de l'appareil.
  ///
  /// Sans effet hors debug : l'appel est conservé pour que le code appelant
  /// n'ait pas à se garder lui-même, et il ne fait rien.
  void activer(double latitude, double longitude) {
    if (!kDebugMode) return;
    _arreterLeParcours();
    _poser(GeoPoint(latitude, longitude));
    Journal.trace('PositionSimulee : fixée à $latitude, $longitude');
  }

  /// Rend la main au capteur réel.
  void desactiver() {
    _arreterLeParcours();
    _point = null;
    _pas = const [];
    _index = 0;
    Journal.trace('PositionSimulee : désactivée, retour au capteur');
  }

  /// Rejoue un trajet, point par point, à [vitesseKmH].
  ///
  /// Les points sont **interpolés** entre les sommets fournis : un itinéraire
  /// rendu par le serveur n'a qu'une poignée de sommets, et sauter de l'un à
  /// l'autre ferait franchir une zone entière entre deux relevés — exactement
  /// le cas qu'on cherche à observer.
  ///
  /// Un trajet déjà en cours est remplacé. Le trajet s'arrête de lui-même au
  /// dernier point, où la position reste fixée : c'est ce qu'on veut pour
  /// vérifier une arrivée.
  void suivre(
    List<GeoPoint> trajet, {
    double vitesseKmH = vitesseParDefautKmH,
    Duration cadence = const Duration(seconds: 2),
  }) {
    if (!kDebugMode) return;
    if (trajet.length < 2) {
      if (trajet.length == 1) activer(trajet.first.latitude, trajet.first.longitude);
      return;
    }

    _arreterLeParcours();

    _pas = _interpoler(trajet, vitesseKmH: vitesseKmH, cadence: cadence);
    _cadence = cadence;
    _index = 0;
    _poser(_pas.first);
    _demarrerLaMinuterie();

    Journal.trace('PositionSimulee : trajet de ${_pas.length} points à $vitesseKmH km/h');
  }

  /// Suspend le trajet là où il en est. La position reste celle du dernier pas.
  ///
  /// Sert à observer un état intermédiaire — l'instant où une instruction est
  /// prononcée, l'entrée dans le rayon d'arrivée — sans courir après.
  void interrompre() {
    if (!kDebugMode) return;
    _arreterLeParcours();
    Journal.trace('PositionSimulee : trajet interrompu au pas $_index');
  }

  /// Repart du pas où [interrompre] avait laissé le trajet.
  void reprendre() {
    if (!kDebugMode) return;
    if (_parcours != null || _pas.isEmpty || _index >= _pas.length - 1) return;
    _demarrerLaMinuterie();
    Journal.trace('PositionSimulee : trajet repris au pas $_index');
  }

  /// Ramène le trajet à son point de départ, sans le relancer.
  ///
  /// La position est reposée sur le premier pas : c'est l'état d'avant le
  /// départ, celui depuis lequel on rejoue une séquence qu'on vient de rater.
  void reinitialiser() {
    if (!kDebugMode) return;
    _arreterLeParcours();
    if (_pas.isEmpty) return;
    _index = 0;
    _poser(_pas.first);
    Journal.trace('PositionSimulee : trajet remis au départ');
  }

  /// Où en est le trajet, entre 0 et 1. Vaut 0 quand aucun trajet n'est chargé.
  double get avancement =>
      _pas.length < 2 ? 0 : (_index / (_pas.length - 1)).clamp(0.0, 1.0);

  /// Un trajet est-il chargé, en cours ou en pause ?
  bool get aUnTrajet => kDebugMode && _pas.length >= 2;

  /// Le trajet est-il en cours de lecture ?
  bool get enDeplacement => _parcours != null;

  void _demarrerLaMinuterie() {
    _parcours = Timer.periodic(_cadence, (minuterie) {
      _index++;
      if (_index >= _pas.length) {
        // Arrêt au dernier point, sans effacer la position : le trajet fini,
        // le livreur simulé reste chez le client, ce qui est l'état qu'on veut
        // observer.
        _index = _pas.length - 1;
        minuterie.cancel();
        _parcours = null;
        Journal.trace('PositionSimulee : trajet terminé');
        return;
      }
      _poser(_pas[_index]);
    });
  }

  void _poser(GeoPoint nouveau) {
    _point = nouveau;
    if (!_flux.isClosed) _flux.add(nouveau);
  }

  void _arreterLeParcours() {
    _parcours?.cancel();
    _parcours = null;
  }

  /// Découpe un itinéraire en points régulièrement espacés dans le **temps**.
  ///
  /// L'espacement se calcule en distance parcourue par tic, et non en fraction
  /// de segment : deux segments de longueurs très différentes seraient sinon
  /// parcourus dans la même durée, et le livreur simulé ferait 200 mètres en
  /// dix secondes puis 4 kilomètres dans les dix suivantes.
  @visibleForTesting
  static List<GeoPoint> interpoler(
    List<GeoPoint> trajet, {
    double vitesseKmH = vitesseParDefautKmH,
    Duration cadence = const Duration(seconds: 2),
  }) =>
      _interpoler(trajet, vitesseKmH: vitesseKmH, cadence: cadence);

  static List<GeoPoint> _interpoler(
    List<GeoPoint> trajet, {
    required double vitesseKmH,
    required Duration cadence,
  }) {
    if (trajet.length < 2) return List.of(trajet);

    final metresParTic = vitesseKmH * 1000 / 3600 * (cadence.inMilliseconds / 1000);
    if (metresParTic <= 0) return List.of(trajet);

    // Le premier point n'est **pas** ajouté ici : la première itération de la
    // boucle le produit elle-même, à `fraction = 0`. L'ajouter en plus le
    // dupliquait, ce qui insérait un écart nul en tête — le trajet démarrait
    // donc par un tic immobile, et le test de régularité du pas le voyait.
    final points = <GeoPoint>[];
    var reste = 0.0;

    for (var i = 0; i < trajet.length - 1; i++) {
      final depart = trajet[i];
      final arrivee = trajet[i + 1];
      final longueur = distanceMetres(depart, arrivee);
      if (longueur == 0) continue;

      // `reste` reporte d'un segment au suivant la fraction de tic non
      // consommée : sans lui, chaque sommet réinitialiserait la cadence et le
      // trajet ralentirait à chaque virage.
      var parcouru = reste;
      while (parcouru < longueur) {
        final fraction = parcouru / longueur;
        points.add(
          GeoPoint(
            depart.latitude + (arrivee.latitude - depart.latitude) * fraction,
            depart.longitude + (arrivee.longitude - depart.longitude) * fraction,
          ),
        );
        parcouru += metresParTic;
      }
      reste = parcouru - longueur;
    }

    points.add(trajet.last);
    return points;
  }

  /// Distance entre deux points, en mètres, par la formule de haversine.
  ///
  /// Calculée ici plutôt qu'appelée sur `Geolocator` : ce module doit rester
  /// utilisable dans un test qui ne monte aucun greffon de plateforme, et la
  /// simulation est justement ce qu'on veut vérifier sans appareil.
  @visibleForTesting
  static double distanceMetres(GeoPoint a, GeoPoint b) =>
      GeoCalcul.distanceMetres(a, b);

  /// Ferme le flux — pour les tests, qui construisent et jettent.
  @visibleForTesting
  void fermer() {
    _arreterLeParcours();
    _point = null;
    _pas = const [];
    _index = 0;
  }
}
