import 'package:flutter/foundation.dart';

/// Configuration centralisée des clés API
class ApiConfig {
  // Configuration Supabase
  static const String supabaseUrl = 'https://fuvgfvonpivubkrvnsdt.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ1dmdmdm9ucGl2dWJrcnZuc2R0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI2OTM0MDUsImV4cCI6MjA3ODI2OTQwNX0.32onFnZ4vMQxkdh_oUS1oHsGUFX4SXhrb_388qnuS58';

  // Configuration PayDunya (Mode Test)
  static const String payDunyaMasterKey =
      'wWr8BTxk-bSdK-uV9n-W45D-YZeArRLqmBqW';
  static const String payDunyaPrivateKey =
      'test_private_QaNmxsVwnkbTZAea83vPXu5VvN1';
  static const String payDunyaToken = 'hiLPQQUFSy8NnAeLekrZ';
  static const bool payDunyaIsSandbox = true;

  // Configuration Google Maps
  static const String googleMapsApiKey =
      'AIzaSyCtSGHbgwiNKhblSK7NpU7aVUvuxz-w-tM';

  // Configuration Firebase
  static const String firebaseApiKey = 'your-api-key';
  static const String firebaseAuthDomain = 'your-project.firebaseapp.com';
  static const String firebaseProjectId = 'your-project-id';
  static const String firebaseStorageBucket = 'your-project.appspot.com';
  static const String firebaseMessagingSenderId = '123456789';
  static const String firebaseAppId = 'your-app-id';

  // Configuration Agora RTC
  static const String agoraAppId = 'YOUR_AGORA_APP_ID'; // TODO: Ajouter votre App ID Agora

  // Configuration Backend (Node.js/Express)
  static const String backendUrl =
      'http://localhost:3000'; // Change to your backend URL

  // Configuration de l'environnement
  static const String environment = 'development';
  static const bool debugMode = kDebugMode;

  /// Vérifie si toutes les clés API sont configurées
  static bool get isFullyConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY' &&
        firebaseApiKey != 'your-api-key' &&
        payDunyaMasterKey != 'your_master_key';
  }

  /// Vérifie si les services essentiels sont configurés
  static bool get isEssentialConfigured {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }

  /// Retourne les clés manquantes
  static List<String> get missingKeys {
    final List<String> missing = [];

    if (googleMapsApiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
      missing.add('Google Maps API Key');
    }

    if (firebaseApiKey == 'your-api-key') {
      missing.add('Firebase API Key');
    }

    if (payDunyaMasterKey == 'your_master_key') {
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
