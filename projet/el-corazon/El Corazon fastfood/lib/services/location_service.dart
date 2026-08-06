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

  Position? get currentPosition => _currentPosition;
  bool get isInitialized => _isInitialized;

  /// Initialise le service de géolocalisation
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await requestLocationPermission();
      await getCurrentLocation();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing LocationService: $e');
    }
  }

  // Demander les permissions de géolocalisation
  Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Obtenir la position actuelle
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      _currentPosition = await Geolocator.getCurrentPosition();
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      debugPrint('Erreur de géolocalisation: $e');
      return null;
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
