import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Position de l'appareil : permission et relevé, rien d'autre.
///
/// Ce service portait aussi un **faux suivi de livraison** — une minuterie qui
/// faisait avancer une course de « en préparation » à « livré avec succès » en
/// quarante secondes sans rien demander à personne, un itinéraire fabriqué en
/// ajoutant des millièmes de degré au point de départ, et une liste de
/// restaurants inventés autour de l'utilisateur.
///
/// L'émission réelle vit dans `RealtimeTrackingService` : un relevé toutes les
/// dix secondes, déposé sur la course en cours (invariant L3 — un relevé
/// appartient à une course, pas à un livreur), et diffusé au client par
/// `ws/orders/{id}/tracking/`.
class LocationService extends ChangeNotifier {
  Position? _currentPosition;

  Position? get currentPosition => _currentPosition;

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

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
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
