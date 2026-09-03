import 'package:elcorazon_core/elcorazon_core.dart'
    show Journal, LocationAvailability, LocationRemede;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Position de l'appareil : permission et relevé ponctuel, rien d'autre.
///
/// Ce service portait aussi un **faux suivi de livraison** — une minuterie qui
/// faisait avancer une course de « en préparation » à « livré avec succès » en
/// quarante secondes sans rien demander à personne, un itinéraire fabriqué en
/// ajoutant des millièmes de degré au point de départ, et une liste de
/// restaurants inventés autour de l'utilisateur.
///
/// L'émission réelle vit dans `RealtimeTrackingService` : un flux de position
/// ouvert **le temps d'une course** (invariant L3 — un relevé appartient à une
/// course, pas à un livreur), et diffusé au client par
/// `ws/orders/{id}/tracking/`. Ce service-ci ne sert qu'aux relevés ponctuels
/// et à la question « peut-on relever ? », posée par l'écran des réglages.
///
/// [disponibilite] rend la **cause** plutôt qu'un booléen : GPS coupé,
/// permission à redemander, refus définitif et capteur muet appellent quatre
/// gestes différents, et l'écran des réglages les redécouvrait en réinterrogeant
/// `Geolocator` de son côté. La cause et la phrase à afficher viennent
/// désormais du socle, partagées avec l'application cliente.
class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  LocationAvailability _derniereDisponibilite =
      LocationAvailability.positionIndisponible;

  Position? get currentPosition => _currentPosition;

  /// Ce qui empêchait le dernier relevé, ou [LocationAvailability.disponible].
  LocationAvailability get derniereDisponibilite => _derniereDisponibilite;

  /// Interroge le système : peut-on relever la position, et sinon pourquoi ?
  ///
  /// L'ordre des tests compte. Sur un téléphone dont la localisation est
  /// coupée, la permission peut être accordée depuis des mois : tester la
  /// permission d'abord annoncerait « tout va bien » et le relevé échouerait
  /// ensuite sans explication.
  Future<LocationAvailability> disponibilite() async {
    LocationAvailability retenir(LocationAvailability etat) {
      if (_derniereDisponibilite != etat) {
        _derniereDisponibilite = etat;
        notifyListeners();
      }
      return etat;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return retenir(LocationAvailability.serviceDesactive);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return retenir(
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          LocationAvailability.disponible,
        LocationPermission.deniedForever =>
          LocationAvailability.permissionRefuseeDefinitivement,
        _ => LocationAvailability.permissionRefusee,
      },
    );
  }

  /// Conservé pour les appelants qui n'ont qu'un oui/non à traiter.
  Future<bool> requestLocationPermission() async =>
      (await disponibilite()).estDisponible;

  /// Position actuelle, ou `null` — la cause est alors dans
  /// [derniereDisponibilite].
  Future<Position?> getCurrentLocation() async {
    final etat = await disponibilite();
    if (!etat.estDisponible) return null;

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
        // Sans borne, l'appel reste suspendu tant que le capteur n'a pas fixé —
        // dans un parking souterrain, indéfiniment.
      ).timeout(const Duration(seconds: 15));
      _derniereDisponibilite = LocationAvailability.disponible;
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      Journal.trace('Erreur de géolocalisation: $e');
      _derniereDisponibilite = LocationAvailability.positionIndisponible;
      notifyListeners();
      return null;
    }
  }

  /// Applique le geste que [LocationAvailability.remede] désigne.
  Future<bool> appliquerRemede(LocationRemede remede) async {
    switch (remede) {
      case LocationRemede.ouvrirReglagesDeLocalisation:
        return Geolocator.openLocationSettings();
      case LocationRemede.ouvrirLaFicheDeLApplication:
        return Geolocator.openAppSettings();
      case LocationRemede.redemanderLaPermission:
        await Geolocator.requestPermission();
        return true;
      case LocationRemede.aucun:
      case LocationRemede.patienter:
        return false;
    }
  }

  /// Distance en mètres entre deux points, sur l'ellipsoïde.
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
