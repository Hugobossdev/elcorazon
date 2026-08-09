import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration centralisée des clés API
/// Les valeurs sont chargées depuis le fichier .env pour la sécurité
class ApiConfig {
  // Aucune clé de prestataire de paiement ici, ni test ni production.
  //
  // L'encaissement est une affaire de serveur : l'application ouvre une
  // demande (`POST /payments/{commande}/initiate/`), reçoit une adresse de
  // règlement, et lit ensuite l'état que le webhook signé a écrit. Elle ne
  // décide jamais qu'un paiement a abouti, et n'a donc aucune raison de
  // détenir de quoi encaisser.

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

  // Configuration de l'environnement
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  static const bool debugMode = kDebugMode;

  /// Vérifie si toutes les clés API sont configurées
  static bool get isFullyConfigured {
    // Les clés de paiement ne figurent plus ici : l'encaissement passe par le
    // serveur, qui détient les siennes. Une application n'a pas à savoir si
    // elles sont configurées — elle appelle `/payments/{id}/initiate/` et lit
    // la réponse.
    return googleMapsApiKey.isNotEmpty &&
        googleMapsApiKey != 'your-google-maps-api-key' &&
        firebaseApiKey.isNotEmpty &&
        firebaseApiKey != 'your-api-key';
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
