import 'package:elcora_fast/config/api_config.dart';

/// Configuration PayDunya
///
/// Ce fichier contient la configuration pour l'intégration PayDunya.
/// Les clés API sont centralisées dans ApiConfig.
class PayDunyaConfig {
  // Mode Sandbox (test) par défaut
  static bool get isSandbox => ApiConfig.payDunyaIsSandbox;

  // Clés API PayDunya - Sandbox (Test)
  // Les clés sont récupérées depuis ApiConfig
  static String get sandboxMasterKey => ApiConfig.payDunyaMasterKey;
  static String get sandboxPrivateKey => ApiConfig.payDunyaPrivateKey;
  static String get sandboxToken => ApiConfig.payDunyaToken;

  // Clés API PayDunya - Production
  // Les clés sont récupérées depuis ApiConfig (qui lit depuis .env)
  // ⚠️ IMPORTANT: Ne commitez JAMAIS le fichier .env dans le repository
  static String get productionMasterKey =>
      ApiConfig.payDunyaProductionMasterKey;
  static String get productionPrivateKey =>
      ApiConfig.payDunyaProductionPrivateKey;
  static String get productionToken => ApiConfig.payDunyaProductionToken;

  // Informations du magasin
  static const String storeName = 'El Corazón - FastFoodGo';
  static const String storeTagline = 'Votre repas à la vitesse de votre faim';
  static const String storePostalAddress = 'Abidjan, Côte d\'Ivoire';
  static const String storePhone = '+225 XX XX XX XX';
  static const String storeWebsiteUrl = 'https://fastfoodgo.ci';
  static const String storeLogoUrl = 'https://fastfoodgo.ci/logo.png';

  // URLs de callback
  static const String cancelUrl = 'https://fastfoodgo.ci/payment/cancel';
  static const String returnUrl = 'https://fastfoodgo.ci/payment/success';
  static const String webhookUrl = 'https://fastfoodgo.ci/webhook/paydunya';

  // Méthodes de paiement supportées
  static const List<String> supportedPaymentMethods = [
    'mobile_money', // MTN, Orange Money, Moov Money
    'card', // Carte bancaire
    'wallet', // Portefeuille PayDunya
  ];

  // Opérateurs Mobile Money supportés
  static const List<String> supportedMobileMoneyOperators = [
    'mtn', // MTN Mobile Money
    'orange', // Orange Money
    'moov', // Moov Money
  ];

  /// Récupère la clé master selon l'environnement
  static String get masterKey =>
      isSandbox ? sandboxMasterKey : productionMasterKey;

  /// Récupère la clé privée selon l'environnement
  static String get privateKey =>
      isSandbox ? sandboxPrivateKey : productionPrivateKey;

  /// Récupère le token selon l'environnement
  static String get token => isSandbox ? sandboxToken : productionToken;

  /// Vérifie si la configuration est valide
  static bool get isValid {
    if (isSandbox) {
      // En mode sandbox, on accepte les clés de test
      return sandboxMasterKey.isNotEmpty &&
          sandboxPrivateKey.isNotEmpty &&
          sandboxToken.isNotEmpty;
    } else {
      // En mode production, on vérifie que les clés ne sont pas les valeurs par défaut
      return productionMasterKey.isNotEmpty &&
          productionMasterKey != 'your-production-master-key' &&
          productionPrivateKey.isNotEmpty &&
          productionPrivateKey != 'your-production-private-key' &&
          productionToken.isNotEmpty &&
          productionToken != 'your-production-token';
    }
  }
}
