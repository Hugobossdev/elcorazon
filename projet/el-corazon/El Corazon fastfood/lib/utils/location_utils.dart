import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

/// Utilitaires pour la gestion de la localisation GPS
class LocationUtils {
  /// Vérifie et demande les permissions de localisation
  /// Retourne true si les permissions sont accordées
  static Future<bool> checkLocationPermissions() async {
    try {
      // Vérifier si le service de localisation est activé
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('LocationUtils: Service de localisation désactivé');
        return false;
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // Demander la permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('LocationUtils: Permission de localisation refusée');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
          'LocationUtils: Permission de localisation refusée définitivement',
        );
        return false;
      }

      debugPrint('LocationUtils: Permissions OK');
      return true;
    } catch (e) {
      debugPrint('LocationUtils: Erreur vérification permissions - $e');
      return false;
    }
  }

  /// Obtient la position GPS actuelle
  /// Retourne null en cas d'erreur ou de permission refusée
  static Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await checkLocationPermissions();
      if (!hasPermission) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      debugPrint(
        'LocationUtils: Position obtenue - lat: ${position.latitude}, lng: ${position.longitude}',
      );
      return position;
    } catch (e) {
      debugPrint('LocationUtils: Erreur obtention position - $e');
      return null;
    }
  }

  /// Vérifie si le service de localisation est activé sur l'appareil
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('LocationUtils: Erreur vérification service - $e');
      return false;
    }
  }

  /// Ouvre les paramètres de localisation de l'appareil
  /// (L'utilisateur devra activer manuellement)
  static Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
      debugPrint('LocationUtils: Ouverture des paramètres de localisation');
    } catch (e) {
      debugPrint('LocationUtils: Erreur ouverture paramètres - $e');
    }
  }

  /// Vérifie la précision de la localisation
  /// Retourne true si la précision est suffisante (< 50m)
  static bool isAccuracySufficient(
    Position position, {
    double maxAccuracy = 50.0,
  }) {
    return position.accuracy <= maxAccuracy;
  }

  /// Calcule la distance entre deux positions en mètres
  static double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Obtient un message d'erreur convivial basé sur le statut de la permission
  static String getPermissionErrorMessage(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.denied:
        return 'Permission de localisation refusée. Veuillez autoriser l\'accès à votre position.';
      case LocationPermission.deniedForever:
        return 'Permission de localisation refusée définitivement. Veuillez activer la localisation dans les paramètres.';
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return 'Permission accordée';
      case LocationPermission.unableToDetermine:
        return 'Impossible de déterminer les permissions de localisation.';
    }
  }

  /// Obtient la permission actuelle sans la demander
  static Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  /// Stream de positions pour suivi en temps réel
  /// Utile pour afficher la position actuelle en continu
  static Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // Mise à jour tous les 10 mètres
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
