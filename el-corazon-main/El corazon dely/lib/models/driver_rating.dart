class DriverRating {
  final String id;
  final String orderId;
  final String driverId;
  final String clientId;
  final int? ratingDeliveryTime;
  final int? ratingService;
  final int? ratingCondition;
  final double ratingAverage;
  final String? comment;
  final DateTime createdAt;

  DriverRating({
    required this.id,
    required this.orderId,
    required this.driverId,
    required this.clientId,
    this.ratingDeliveryTime,
    this.ratingService,
    this.ratingCondition,
    required this.ratingAverage,
    this.comment,
    required this.createdAt,
  });

  factory DriverRating.fromMap(Map<String, dynamic> map) {
    return DriverRating(
      id: map['id'],
      orderId: map['order_id'],
      driverId: map['driver_id'],
      clientId: map['client_id'],
      ratingDeliveryTime: map['rating_delivery_time'],
      ratingService: map['rating_service'],
      ratingCondition: map['rating_condition'],
      ratingAverage: (map['rating_average'] ?? 0.0).toDouble(),
      comment: map['comment'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'driver_id': driverId,
      'client_id': clientId,
      'rating_delivery_time': ratingDeliveryTime,
      'rating_service': ratingService,
      'rating_condition': ratingCondition,
      'rating_average': ratingAverage,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

