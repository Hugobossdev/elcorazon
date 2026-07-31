import 'package:flutter/foundation.dart';

/// Configuration centralisée des clés API pour l'application livreur.
class ApiConfig {
  // Configuration Google Maps
  static const String googleMapsApiKey =
      'AIzaSyCtSGHbgwiNKhblSK7NpU7aVUvuxz-w-tM';

  // Configuration Agora
  static const String agoraAppId = 'YOUR_AGORA_APP_ID';

  // Configuration PayDunya
  static const String payDunyaMasterKey = 'YOUR_PAYDUNYA_MASTER_KEY';
  static const String payDunyaPrivateKey = 'YOUR_PAYDUNYA_PRIVATE_KEY';
  static const String payDunyaToken = 'YOUR_PAYDUNYA_TOKEN';

  // Configuration de l'environnement
  static const String environment = 'development';
  static const bool debugMode = kDebugMode;

  /// Vérifie si toutes les clés API sont configurées
  static bool get isFullyConfigured {
    return googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY' &&
        googleMapsApiKey.isNotEmpty &&
        agoraAppId != 'YOUR_AGORA_APP_ID' &&
        payDunyaMasterKey != 'YOUR_PAYDUNYA_MASTER_KEY';
  }
}
