/// Relevé de position d'une course — miroir de `LocationPingSerializer`
/// (`backend/apps/tracking/serializers.py`).
///
/// [recordedAt] est l'horodatage **de l'appareil**, [receivedAt] celui du
/// serveur. Les deux existent parce qu'un livreur qui traverse une zone sans
/// réseau émet en différé : les confondre dessinerait un trajet instantané au
/// moment où la rafale rattrapée arrive, et l'ETA calculé dessus serait
/// absurde.
class LocationPing {
  const LocationPing({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.receivedAt,
    this.accuracyMeters,
    this.speedMetersPerSecond,
    this.headingDegrees,
  });

  factory LocationPing.fromJson(Map<String, dynamic> json) {
    final point = json['point'] as Map<String, dynamic>;
    return LocationPing(
      id: json['id'] as String,
      latitude: (point['lat'] as num).toDouble(),
      longitude: (point['lon'] as num).toDouble(),
      accuracyMeters: (json['accuracy_m'] as num?)?.toDouble(),
      speedMetersPerSecond: (json['speed_mps'] as num?)?.toDouble(),
      headingDegrees: (json['heading_deg'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      receivedAt: DateTime.parse(json['received_at'] as String),
    );
  }

  final String id;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? speedMetersPerSecond;
  final double? headingDegrees;
  final DateTime recordedAt;
  final DateTime receivedAt;
}

/// Suivi d'une commande rendu à son client — miroir de `TrackingSerializer`.
///
/// Volontairement pauvre côté serveur : la dernière position, l'étape de la
/// course, et le livreur réduit à ce qu'on montre à la porte. Une commande
/// sans course active rend un suivi **vide plutôt qu'une erreur** — c'est
/// l'état normal des premières minutes, d'où [assignmentStatus] à vide et
/// [lastPosition] nul.
class OrderTracking {
  const OrderTracking({
    required this.orderId,
    required this.assignmentStatus,
    required this.courier,
    this.lastPosition,
    this.estimatedDeliveryAt,
  });

  factory OrderTracking.fromJson(Map<String, dynamic> json) {
    final position = json['last_position'] as Map<String, dynamic>?;
    final estimated = json['estimated_delivery_at'] as String?;
    return OrderTracking(
      orderId: json['order'] as String,
      assignmentStatus: json['assignment_status'] as String? ?? '',
      courier: Map<String, dynamic>.from(json['courier'] as Map<String, dynamic>? ?? const {}),
      lastPosition: position == null ? null : LocationPing.fromJson(position),
      estimatedDeliveryAt: estimated == null ? null : DateTime.parse(estimated),
    );
  }

  final String orderId;

  /// Vide tant qu'aucun livreur n'est affecté ; sinon voir `DeliveryStatus`.
  final String assignmentStatus;

  /// Forme de `CourierPublicSerializer`, vide tant qu'aucun livreur n'est
  /// affecté. Laissé en `Map` : le seul consommateur est l'écran de suivi
  /// client, qui en lit deux champs.
  final Map<String, dynamic> courier;
  final LocationPing? lastPosition;
  final DateTime? estimatedDeliveryAt;

  bool get hasCourier => assignmentStatus.isNotEmpty;
}
