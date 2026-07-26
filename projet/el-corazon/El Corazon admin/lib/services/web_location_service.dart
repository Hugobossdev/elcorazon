import 'dart:math';
import 'package:flutter/foundation.dart';

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  LocationData? _currentPosition;
  bool _isInitialized = false;

  LocationData? get currentPosition => _currentPosition;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Web-compatible location initialization
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing Location Service: $e');
    }
  }

  Future<bool> requestLocationPermission() async {
    try {
      // Web-compatible permission request
      debugPrint('Web: Location permission requested');
      return true; // Web allows location access by default
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return false;
    }
  }

  Future<LocationData?> getCurrentLocation() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      // Simulate getting location for web
      _currentPosition = LocationData(
        latitude: 12.6500, // Bamako coordinates
        longitude: -8.0000,
        accuracy: 100.0,
        timestamp: DateTime.now(),
      );
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  Future<double> calculateDistance(
      double lat1, double lon1, double lat2, double lon2) async {
    // Haversine formula for distance calculation
    const double earthRadius = 6371; // km
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double lat1Rad = _degreesToRadians(lat1);
    final double lat2Rad = _degreesToRadians(lat2);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }
}

class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });
}
