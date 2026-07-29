import 'package:flutter/foundation.dart';

/// Configuration centralisée des clés API pour l'application Deliver
///
/// L'URL et la clé Supabase ne vivent plus ici : ce fichier en portait une
/// copie codée en dur, distincte de celle lue depuis `.env` par
/// `supabase/supabase_config.dart` (la seule réellement utilisée à
/// l'initialisation) — deux sources de vérité pour la même valeur, dont
/// celle-ci n'avait plus aucun appelant.
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
