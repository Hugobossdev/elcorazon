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

/// Le livreur, tel que le client qui attend son repas peut le voir.
///
/// Miroir de `TrackingCourierSerializer`. Il n'est rendu qu'à partir de
/// l'**acceptation** — un livreur qui n'a pas accepté peut encore refuser — et
/// son [telephone] n'est rempli que tant que la course est engagée : passé la
/// livraison, il n'y a plus personne à joindre pour cette course.
class TrackingCourier {
  const TrackingCourier({
    required this.id,
    required this.fullName,
    this.avatar,
    this.vehicleType = '',
    this.ratingAverage = '',
    this.ratingCount = 0,
    this.telephone = '',
  });

  factory TrackingCourier.fromJson(Map<String, dynamic> json) => TrackingCourier(
    id: json['id']?.toString() ?? '',
    fullName: json['full_name'] as String? ?? '',
    avatar: json['avatar'] as String?,
    vehicleType: json['vehicle_type'] as String? ?? '',
    ratingAverage: json['rating_average']?.toString() ?? '',
    ratingCount: json['rating_count'] as int? ?? 0,
    telephone: json['phone'] as String? ?? '',
  );

  final String id;
  final String fullName;
  final String? avatar;
  final String vehicleType;
  final String ratingAverage;
  final int ratingCount;

  /// Vide une fois la course terminée — voir la documentation de la classe.
  final String telephone;

  /// Y a-t-il quelqu'un à appeler maintenant ?
  bool get joignable => telephone.isNotEmpty;

  /// Le nom à afficher, jamais vide — un livreur sans nom reste « Livreur ».
  String get nomAffiche => fullName.isEmpty ? 'Livreur' : fullName;
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
    this.courier,
    this.lastPosition,
    this.estimatedDeliveryAt,
  });

  factory OrderTracking.fromJson(Map<String, dynamic> json) {
    final position = json['last_position'] as Map<String, dynamic>?;
    final estimated = json['estimated_delivery_at'] as String?;
    final courier = json['courier'] as Map<String, dynamic>?;
    return OrderTracking(
      orderId: json['order'] as String,
      assignmentStatus: json['assignment_status'] as String? ?? '',
      // Une `Map` vide vaut « aucun livreur » : c'est ce que rendait le serveur
      // avant que le champ ne devienne nul, et un client à jour doit rester
      // lisible devant l'un comme devant l'autre.
      courier: courier == null || courier.isEmpty ? null : TrackingCourier.fromJson(courier),
      lastPosition: position == null ? null : LocationPing.fromJson(position),
      estimatedDeliveryAt: estimated == null ? null : DateTime.parse(estimated),
    );
  }

  final String orderId;

  /// Vide tant qu'aucun livreur n'est affecté ; sinon voir `DeliveryStatus`.
  final String assignmentStatus;

  /// Le livreur, **ou `null`** tant que personne n'a accepté la course.
  ///
  /// C'était une `Map` non nullable, et l'écran de suivi ne pouvait rien en
  /// déduire : il gardait donc ses boutons « Message » et « Appeler » sur un
  /// identifiant de livreur porté par la commande — que le serveur n'a jamais
  /// rendu. Les deux boutons étaient grisés en permanence, et la notation du
  /// livreur ne s'affichait jamais.
  final TrackingCourier? courier;
  final LocationPing? lastPosition;
  final DateTime? estimatedDeliveryAt;

  /// Quelqu'un porte-t-il cette commande, **et le client peut-il le voir** ?
  ///
  /// Porte désormais sur le livreur rendu, et non sur l'étape de la course :
  /// une course seulement proposée a bien une étape, mais aucun livreur à
  /// montrer — c'est précisément ce que le serveur refuse de nommer.
  bool get hasCourier => courier != null;
}
