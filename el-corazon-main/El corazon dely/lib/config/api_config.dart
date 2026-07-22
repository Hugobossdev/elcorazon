import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration centralisée des clés API pour l'application Deliver
/// Les valeurs sont chargées depuis le fichier .env pour la sécurité
class ApiConfig {
  // Configuration Supabase (déplacée vers supabase_config.dart qui utilise dotenv)
  // Ces getters sont conservés pour compatibilité descendante mais
  // SupabaseConfig est l'authorité unique pour Supabase.
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Configuration Google Maps
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Configuration Agora
  static String get agoraAppId => dotenv.env['AGORA_APP_ID'] ?? '';

  // Configuration PayDunya
  static String get payDunyaMasterKey =>
      dotenv.env['PAYDUNYA_MASTER_KEY'] ?? '';
  static String get payDunyaPrivateKey =>
      dotenv.env['PAYDUNYA_PRIVATE_KEY'] ?? '';
  static String get payDunyaToken => dotenv.env['PAYDUNYA_TOKEN'] ?? '';
  static bool get payDunyaIsSandbox =>
      dotenv.env['PAYDUNYA_IS_SANDBOX']?.toLowerCase() == 'true';

  // Configuration Backend (Laravel API)
  static String get backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';

  // Configuration de l'environnement
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  static const bool debugMode = kDebugMode;

  /// Vérifie si toutes les clés API sont configurées
  static bool get isFullyConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        googleMapsApiKey.isNotEmpty &&
        googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY' &&
        agoraAppId.isNotEmpty &&
        agoraAppId != 'YOUR_AGORA_APP_ID' &&
        payDunyaMasterKey.isNotEmpty &&
        payDunyaMasterKey != 'YOUR_PAYDUNYA_MASTER_KEY';
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
        googleMapsApiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
      missing.add('Google Maps API Key');
    }
    if (agoraAppId.isEmpty || agoraAppId == 'YOUR_AGORA_APP_ID') {
      missing.add('Agora App ID');
    }
    if (payDunyaMasterKey.isEmpty ||
        payDunyaMasterKey == 'YOUR_PAYDUNYA_MASTER_KEY') {
      missing.add('PayDunya Master Key');
    }

    return missing;
  }
}
