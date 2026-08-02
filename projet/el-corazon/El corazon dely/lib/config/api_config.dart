import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration des clés API de l'application livreur.
///
/// Elles sont lues depuis `.env`, comme dans les deux autres applications. La
/// clé Google Maps se trouvait auparavant **en dur dans ce fichier** : elle
/// partait donc dans l'historique Git en plus du binaire, et changer de clé
/// demandait un déploiement.
///
/// Ces valeurs restent publiques par construction — une clé Maps côté client
/// part dans l'APK et dans le HTML servi. Ce qui les protège n'est pas leur
/// discrétion mais leur **restriction** côté console (empreinte d'application,
/// référent, quotas) : voir `docs/security/google_maps.md`.
///
/// Aucune clé de prestataire de paiement ici. L'encaissement est une affaire de
/// serveur, et le livreur ne fait que constater ce qu'il doit percevoir.
class ApiConfig {
  /// Cartes et navigation.
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  /// Identifiant d'application Agora — public par nature.
  ///
  /// Le **certificat** signe les jetons d'appel et reste côté serveur : le
  /// placer ici reviendrait à laisser fabriquer des jetons pour n'importe quel
  /// canal.
  static String get agoraAppId => dotenv.env['AGORA_APP_ID'] ?? '';

  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  static const bool debugMode = kDebugMode;

  /// Les clés nécessaires au fonctionnement sont-elles renseignées ?
  static bool get isFullyConfigured =>
      googleMapsApiKey.isNotEmpty && agoraAppId.isNotEmpty;

  /// Ce qui manque, pour un message de diagnostic lisible au démarrage.
  static List<String> get missingKeys => [
    if (googleMapsApiKey.isEmpty) 'GOOGLE_MAPS_API_KEY',
    if (agoraAppId.isEmpty) 'AGORA_APP_ID',
  ];
}
