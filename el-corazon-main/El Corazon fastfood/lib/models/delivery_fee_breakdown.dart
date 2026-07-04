/// Modèle détaillé des frais de livraison avec décomposition complète
class DeliveryFeeBreakdown {
  /// Distance en kilomètres
  final double distance;

  /// Frais de base (minimum)
  final double baseFee;

  /// Frais basés sur la distance (distance × tarif/km)
  final double distanceFee;

  /// Frais de zone spécifique (si zones activées)
  final double zoneFee;

  /// Total des frais de livraison
  final double totalFee;

  /// Livraison gratuite activée
  final bool isFreeDelivery;

  /// Raison de la livraison gratuite (VIP, montant élevé, promo...)
  final String? freeDeliveryReason;

  /// L'adresse est dans une zone desservie
  final bool isInServiceableZone;

  /// Nom de la zone de livraison
  final String? zoneName;

  /// Temps estimé de livraison en minutes
  final int? estimatedDeliveryTime;

  /// Coordonnées du restaurant
  final Map<String, double>? restaurantLocation;

  /// Coordonnées de livraison
  final Map<String, double>? deliveryLocation;

  DeliveryFeeBreakdown({
    required this.distance,
    required this.baseFee,
    required this.distanceFee,
    required this.totalFee,
    this.zoneFee = 0.0,
    this.isFreeDelivery = false,
    this.freeDeliveryReason,
    this.isInServiceableZone = true,
    this.zoneName,
    this.estimatedDeliveryTime,
    this.restaurantLocation,
    this.deliveryLocation,
  });

  /// Crée une instance pour livraison gratuite
  factory DeliveryFeeBreakdown.free({
    required String reason,
    double distance = 0.0,
    int? estimatedTime,
  }) {
    return DeliveryFeeBreakdown(
      distance: distance,
      baseFee: 0.0,
      distanceFee: 0.0,
      totalFee: 0.0,
      isFreeDelivery: true,
      freeDeliveryReason: reason,
      estimatedDeliveryTime: estimatedTime,
    );
  }

  /// Crée une instance pour zone non desservie
  factory DeliveryFeeBreakdown.notServiceable({
    required double distance,
    String? zoneName,
  }) {
    return DeliveryFeeBreakdown(
      distance: distance,
      baseFee: 0.0,
      distanceFee: 0.0,
      totalFee: 0.0,
      isInServiceableZone: false,
      zoneName: zoneName,
    );
  }

  /// Copie avec modifications
  DeliveryFeeBreakdown copyWith({
    double? distance,
    double? baseFee,
    double? distanceFee,
    double? zoneFee,
    double? totalFee,
    bool? isFreeDelivery,
    String? freeDeliveryReason,
    bool? isInServiceableZone,
    String? zoneName,
    int? estimatedDeliveryTime,
    Map<String, double>? restaurantLocation,
    Map<String, double>? deliveryLocation,
  }) {
    return DeliveryFeeBreakdown(
      distance: distance ?? this.distance,
      baseFee: baseFee ?? this.baseFee,
      distanceFee: distanceFee ?? this.distanceFee,
      zoneFee: zoneFee ?? this.zoneFee,
      totalFee: totalFee ?? this.totalFee,
      isFreeDelivery: isFreeDelivery ?? this.isFreeDelivery,
      freeDeliveryReason: freeDeliveryReason ?? this.freeDeliveryReason,
      isInServiceableZone: isInServiceableZone ?? this.isInServiceableZone,
      zoneName: zoneName ?? this.zoneName,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      restaurantLocation: restaurantLocation ?? this.restaurantLocation,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
    );
  }

  /// Convertit en JSON
  Map<String, dynamic> toJson() {
    return {
      'distance': distance,
      'baseFee': baseFee,
      'distanceFee': distanceFee,
      'zoneFee': zoneFee,
      'totalFee': totalFee,
      'isFreeDelivery': isFreeDelivery,
      'freeDeliveryReason': freeDeliveryReason,
      'isInServiceableZone': isInServiceableZone,
      'zoneName': zoneName,
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'restaurantLocation': restaurantLocation,
      'deliveryLocation': deliveryLocation,
    };
  }

  /// Crée depuis JSON
  factory DeliveryFeeBreakdown.fromJson(Map<String, dynamic> json) {
    return DeliveryFeeBreakdown(
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      baseFee: (json['baseFee'] as num?)?.toDouble() ?? 0.0,
      distanceFee: (json['distanceFee'] as num?)?.toDouble() ?? 0.0,
      zoneFee: (json['zoneFee'] as num?)?.toDouble() ?? 0.0,
      totalFee: (json['totalFee'] as num?)?.toDouble() ?? 0.0,
      isFreeDelivery: json['isFreeDelivery'] as bool? ?? false,
      freeDeliveryReason: json['freeDeliveryReason'] as String?,
      isInServiceableZone: json['isInServiceableZone'] as bool? ?? true,
      zoneName: json['zoneName'] as String?,
      estimatedDeliveryTime: json['estimatedDeliveryTime'] as int?,
      restaurantLocation: json['restaurantLocation'] != null
          ? Map<String, double>.from(json['restaurantLocation'] as Map)
          : null,
      deliveryLocation: json['deliveryLocation'] != null
          ? Map<String, double>.from(json['deliveryLocation'] as Map)
          : null,
    );
  }

  @override
  String toString() {
    if (isFreeDelivery) {
      return 'DeliveryFeeBreakdown(FREE - $freeDeliveryReason)';
    }
    if (!isInServiceableZone) {
      return 'DeliveryFeeBreakdown(NOT_SERVICEABLE - ${distance.toStringAsFixed(1)} km)';
    }
    return 'DeliveryFeeBreakdown(distance: ${distance.toStringAsFixed(2)} km, '
        'total: ${totalFee.toStringAsFixed(0)} FCFA)';
  }
}
