/// Configuration centralisée pour le système de livraison
class DeliveryConfig {
  /// Frais de base minimum (FCFA)
  static const double baseFee = 500.0;

  /// Prix par kilomètre (FCFA/km)
  static const double pricePerKm = 200.0;

  /// Distance maximale de livraison (km)
  static const double maxDeliveryDistance = 25.0;

  /// Seuil de commande pour livraison gratuite (FCFA)
  static const double freeDeliveryThreshold = 10000.0;

  /// Frais maximum de livraison (FCFA)
  static const double maxFee = 5000.0;

  /// Vitesse moyenne de livraison (km/h)
  static const int averageSpeedKmH = 30;

  /// Temps de préparation de base (minutes)
  static const int basePreparationTime = 15;

  /// Utiliser le système de zones de livraison
  /// Si false, utilise uniquement le calcul par distance
  static const bool useDeliveryZones = false;

  /// Forcer la validation stricte des zones
  /// Si true, refuse les commandes hors zone
  /// Si false, affiche un avertissement mais permet la commande
  static const bool strictZoneEnforcement = false;

  /// Arrondir les frais à la dizaine supérieure
  static const bool roundToNearestTen = true;

  /// Afficher la décomposition détaillée des frais
  static const bool showDetailedBreakdown = true;

  /// Activer le cache des calculs de frais
  static const bool enableFeeCache = true;

  /// Durée du cache (minutes)
  static const int feeCacheDuration = 5;

  /// Calculer automatiquement les frais au changement d'adresse
  static const bool autoCalculateOnAddressChange = true;

  /// Afficher l'estimation de temps sur la carte
  static const bool showTimeEstimateOnMap = true;

  /// Afficher les zones de livraison sur la carte
  static const bool showZonesOnMap = false;

  /// Rayon de recherche pour les zones (km)
  /// Utilisé pour optimiser la recherche de zones
  static const double zoneSearchRadius = 30.0;

  /// Messages personnalisés
  static const String freeDeliveryVipMessage =
      'Livraison gratuite (Client VIP)';
  static const String freeDeliveryAmountMessage =
      'Livraison gratuite (commande ≥ 10000 FCFA)';
  static const String notServiceableMessage =
      'Désolé, nous ne livrons pas encore dans cette zone.';
  static const String maxDistanceExceededMessage =
      'Distance trop importante (max 25 km)';

  DeliveryConfig._();
}
