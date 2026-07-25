import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isTrackingDelivery = false;
  String _deliveryStatus = 'En préparation';
  double _deliveryProgress = 0.0;
  List<LatLng> _deliveryRoute = [];

  Position? get currentPosition => _currentPosition;
  bool get isTrackingDelivery => _isTrackingDelivery;
  String get deliveryStatus => _deliveryStatus;
  double get deliveryProgress => _deliveryProgress;
  List<LatLng> get deliveryRoute => _deliveryRoute;

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

  // Démarrer le suivi de livraison
  void startDeliveryTracking(String orderId) {
    _isTrackingDelivery = true;
    _deliveryStatus = 'Commande confirmée';
    _deliveryProgress = 0.1;

    // Simuler les étapes de livraison
    _simulateDeliveryProgress();
    notifyListeners();
  }

  // Simuler le progrès de la livraison
  void _simulateDeliveryProgress() async {
    // Étape 1: En préparation
    await Future.delayed(const Duration(seconds: 5));
    _deliveryStatus = 'En préparation';
    _deliveryProgress = 0.3;
    notifyListeners();

    // Étape 2: Prêt pour livraison
    await Future.delayed(const Duration(seconds: 10));
    _deliveryStatus = 'Prêt pour livraison';
    _deliveryProgress = 0.5;
    notifyListeners();

    // Étape 3: En route
    await Future.delayed(const Duration(seconds: 5));
    _deliveryStatus = 'En route vers vous';
    _deliveryProgress = 0.7;
    notifyListeners();

    // Étape 4: Proche
    await Future.delayed(const Duration(seconds: 15));
    _deliveryStatus = 'Très proche';
    _deliveryProgress = 0.9;
    notifyListeners();

    // Étape 5: Livré
    await Future.delayed(const Duration(seconds: 5));
    _deliveryStatus = 'Livré avec succès!';
    _deliveryProgress = 1.0;
    _isTrackingDelivery = false;
    notifyListeners();
  }

  // Calculer la distance entre deux points
  double calculateDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  // Simuler la route de livraison
  void generateDeliveryRoute(LatLng restaurant, LatLng destination) {
    _deliveryRoute = [
      restaurant,
      LatLng(restaurant.latitude + 0.001, restaurant.longitude + 0.0005),
      LatLng(restaurant.latitude + 0.002, restaurant.longitude + 0.001),
      LatLng(destination.latitude - 0.001, destination.longitude - 0.0005),
      destination,
    ];
    notifyListeners();
  }

  // Arrêter le suivi
  void stopTracking() {
    _isTrackingDelivery = false;
    _deliveryProgress = 0.0;
    _deliveryStatus = 'En préparation';
    _deliveryRoute.clear();
    notifyListeners();
  }

  // Trouver les restaurants à proximité
  List<Map<String, dynamic>> getNearbyRestaurants(Position userLocation) {
    // Simulation de restaurants proches
    return [
      {
        'name': 'El Corazón - Centre Ville',
        'distance': 0.8,
        'position': LatLng(
            userLocation.latitude + 0.005, userLocation.longitude + 0.003),
        'rating': 4.8,
        'deliveryTime': '15-20 min'
      },
      {
        'name': 'El Corazón - Zone Industrielle',
        'distance': 1.2,
        'position': LatLng(
            userLocation.latitude - 0.008, userLocation.longitude + 0.006),
        'rating': 4.6,
        'deliveryTime': '20-25 min'
      },
      {
        'name': 'El Corazón - Quartier Résidentiel',
        'distance': 2.1,
        'position': LatLng(
            userLocation.latitude + 0.012, userLocation.longitude - 0.009),
        'rating': 4.7,
        'deliveryTime': '25-30 min'
      },
    ];
  }
}
