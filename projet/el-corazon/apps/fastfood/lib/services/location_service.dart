import 'package:elcorazon_core/elcorazon_core.dart'
    show Journal, LocationAvailability, LocationRemede;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Position de l'appareil : permission et relevé, rien d'autre.
///
/// Ce service portait aussi un **faux suivi de livraison** : `startDeliveryTracking`
/// déclenchait une minuterie qui faisait passer la commande de « en préparation »
/// à « livré avec succès » en quarante secondes, sans jamais interroger
/// personne. Un client dont le repas n'était pas parti voyait donc son écran
/// annoncer la livraison. Il fabriquait aussi un itinéraire (quatre points
/// obtenus en ajoutant des millièmes de degré au départ) et une liste de
/// « restaurants à proximité » entièrement inventée, positionnée autour de
/// l'utilisateur.
///
/// Le vrai suivi existe : `RealtimeTrackingService` écoute
/// `ws/orders/{id}/tracking/`, où le livreur publie sa position et le serveur
/// diffuse les changements de statut. C'est la seule source d'avancement d'une
/// livraison.
///
/// ## Pourquoi le résultat n'est plus un `bool`
///
/// [requestLocationPermission] rendait `false` pour quatre situations qui
/// n'appellent pas le même geste — GPS éteint, permission à redemander, refus
/// définitif, capteur muet. Les écrans devaient donc les redistinguer
/// eux-mêmes, et le faisaient mal : le sélecteur de point sur la carte
/// rappelait `Geolocator.isLocationServiceEnabled()` **après coup** pour
/// deviner lequel des quatre cas venait de se produire, la feuille d'adresse ne
/// le devinait pas du tout et affichait « Autorisez la localisation » à un
/// client dont la permission était accordée mais le GPS coupé. [disponibilite]
/// rend le cas, une bonne fois, et [LocationAvailability.consigne] la phrase à
/// afficher.
class LocationService extends ChangeNotifier {
  /// Instance unique, comme les autres services de l'application.
  ///
  /// Chaque `LocationService()` construisait auparavant un objet neuf, dont
  /// `currentPosition` valait `null` tant que personne n'avait relevé la
  /// position *sur cette instance-là*. Le tri des adresses par distance, qui
  /// en construisait une à la volée, retombait donc systématiquement sur une
  /// position absente : l'option existait dans le menu et ne triait rien.
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  bool _isInitialized = false;
  LocationAvailability _derniereDisponibilite =
      LocationAvailability.positionIndisponible;

  Position? get currentPosition => _currentPosition;
  bool get isInitialized => _isInitialized;

  /// Ce qui empêchait le dernier relevé, ou [LocationAvailability.disponible].
  ///
  /// Reflète la dernière tentative, pas l'état courant du téléphone : un
  /// client qui rallume son GPS ne change rien ici tant qu'on ne redemande
  /// pas. C'est [disponibilite] qui interroge le système.
  LocationAvailability get derniereDisponibilite => _derniereDisponibilite;

  /// Initialise le service de géolocalisation
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await getCurrentLocation();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      Journal.trace('Error initializing LocationService: $e');
    }
  }

  /// Interroge le système : peut-on relever la position, et sinon pourquoi ?
  ///
  /// Demande la permission quand elle n'a jamais été posée — c'est le seul
  /// moment où le système accepte de la poser, et le faire ici évite que
  /// chaque appelant s'en souvienne. Ne la redemande **pas** après un refus
  /// définitif : le système ne réafficherait rien, et l'appelant croirait à
  /// tort avoir tenté quelque chose.
  Future<LocationAvailability> disponibilite() async {
    LocationAvailability retenir(LocationAvailability etat) {
      if (_derniereDisponibilite != etat) {
        _derniereDisponibilite = etat;
        notifyListeners();
      }
      return etat;
    }

    // L'ordre compte : sur un téléphone dont la localisation est coupée, la
    // permission peut être accordée depuis longtemps. Tester la permission
    // d'abord annoncerait « tout va bien » et le relevé échouerait ensuite
    // sans explication.
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
  ///
  /// Préférer [disponibilite] partout où un message est affiché : c'est le
  /// `false` de cette méthode-ci qui obligeait les écrans à re-deviner la
  /// cause.
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
        // sous un toit ou en sous-sol, indéfiniment. L'écran affichait alors un
        // indicateur d'attente que rien ne venait jamais arrêter.
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
  ///
  /// Rend `true` quand un écran système a été ouvert ou une demande posée —
  /// l'appelant sait alors qu'il doit relire [disponibilite] au retour.
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
