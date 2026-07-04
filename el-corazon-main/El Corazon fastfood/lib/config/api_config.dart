import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration centralisée des clés API
/// Les valeurs sont chargées depuis le fichier .env pour la sécurité
class ApiConfig {
  // Configuration Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

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

  // Configuration Agora RTC
  static String get agoraAppId => dotenv.env['AGORA_APP_ID'] ?? '';

  // Configuration Backend (Node.js/Express)
  static String get backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  // Configuration de l'environnement
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  static const bool debugMode = kDebugMode;

  /// Vérifie si toutes les clés API sont configurées
  static bool get isFullyConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        googleMapsApiKey.isNotEmpty &&
        googleMapsApiKey != 'your-google-maps-api-key' &&
        firebaseApiKey.isNotEmpty &&
        firebaseApiKey != 'your-api-key' &&
        payDunyaMasterKey.isNotEmpty &&
        payDunyaMasterKey != 'your-paydunya-master-key';
  }

  /// Vérifie si les services essentiels sont configurés
  static bool get isEssentialConfigured {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }

  /// Retourne les clés manquantes
  static List<String> get missingKeys {
    final List<String> missing = [];

    if (supabaseUrl.isEmpty) {
      missing.add('Supabase URL');
    }
    if (supabaseAnonKey.isEmpty) {
      missing.add('Supabase Anon Key');
    }
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
