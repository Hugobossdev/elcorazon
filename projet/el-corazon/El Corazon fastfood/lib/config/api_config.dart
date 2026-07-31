import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration centralisée des clés API
/// Les valeurs sont chargées depuis le fichier .env pour la sécurité
class ApiConfig {
  // Configuration PayDunya (Mode Test)
  static String get payDunyaMasterKey =>
      dotenv.env['PAYDUNYA_MASTER_KEY'] ?? '';
  static String get payDunyaPrivateKey =>
      dotenv.env['PAYDUNYA_PRIVATE_KEY'] ?? '';
  static String get payDunyaToken => dotenv.env['PAYDUNYA_TOKEN'] ?? '';
  static bool get payDunyaIsSandbox =>
      dotenv.env['PAYDUNYA_IS_SANDBOX']?.toLowerCase() == 'true';

  // Configuration PayDunya (Mode Production)
  static String get payDunyaProductionMasterKey =>
      dotenv.env['PAYDUNYA_PRODUCTION_MASTER_KEY'] ?? '';
  static String get payDunyaProductionPrivateKey =>
      dotenv.env['PAYDUNYA_PRODUCTION_PRIVATE_KEY'] ?? '';
  static String get payDunyaProductionToken =>
      dotenv.env['PAYDUNYA_PRODUCTION_TOKEN'] ?? '';

  // Configuration Google Maps
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Configuration Firebase
  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get firebaseAuthDomain =>
      dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '';
  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseStorageBucket =>
      dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';
  static String get firebaseMessagingSenderId =>
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseAppId => dotenv.env['FIREBASE_APP_ID'] ?? '';

  // Configuration Agora RTC.
  //
  // L'identifiant d'application seulement : il est public par nature. Le
  // **certificat** signe les jetons d'appel et vit côté serveur — l'embarquer
  // ici reviendrait à le distribuer dans un binaire, donc à laisser fabriquer
  // des jetons pour n'importe quel canal.
  static String get agoraAppId => dotenv.env['AGORA_APP_ID'] ?? '';

  /// Mandataire HTTP des API Google, **uniquement sur le web**.
  ///
  /// Reliquat de l'ancien backend Node : `geocoding_service`,
  /// `directions_service` et `places_service` passent par lui pour contourner
  /// CORS, et `paydunya_service` y garde un chemin de paiement client. Sur
  /// mobile, ces services appellent Google directement et ce réglage ne sert
  /// pas. Aucun équivalent Django n'existe encore — c'est le dernier lien vers
  /// un backend retiré, à traiter avec ces quatre services.
  static String get backendUrl =>
      dotenv.env['LEGACY_PROXY_URL'] ?? 'http://localhost:3000';

  // Configuration de l'environnement
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  static const bool debugMode = kDebugMode;

  /// Vérifie si toutes les clés API sont configurées
  static bool get isFullyConfigured {
    return googleMapsApiKey.isNotEmpty &&
        googleMapsApiKey != 'your-google-maps-api-key' &&
        firebaseApiKey.isNotEmpty &&
        firebaseApiKey != 'your-api-key' &&
        payDunyaMasterKey.isNotEmpty &&
        payDunyaMasterKey != 'your-paydunya-master-key';
  }

  /// Retourne les clés manquantes
  static List<String> get missingKeys {
    final List<String> missing = [];

    if (googleMapsApiKey.isEmpty ||
        googleMapsApiKey == 'your-google-maps-api-key') {
      missing.add('Google Maps API Key');
    }
    if (firebaseApiKey.isEmpty || firebaseApiKey == 'your-api-key') {
      missing.add('Firebase API Key');
    }
    if (payDunyaMasterKey.isEmpty ||
        payDunyaMasterKey == 'your-paydunya-master-key') {
      missing.add('PayDunya Master Key');
    }

    return missing;
  }

  /// Configuration Firebase pour le web
  static Map<String, String> get firebaseWebConfig => {
        'apiKey': firebaseApiKey,
        'authDomain': firebaseAuthDomain,
        'projectId': firebaseProjectId,
        'storageBucket': firebaseStorageBucket,
        'messagingSenderId': firebaseMessagingSenderId,
        'appId': firebaseAppId,
      };
}
