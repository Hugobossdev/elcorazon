class DriverRating {
  final String id;
  final String driverId;
  final String? clientId;
  final int ratingDeliveryTime;
  final int ratingService;
  final int ratingCondition;
  final double ratingAverage;
  final String? comment;
  final DateTime createdAt;

  DriverRating({
    required this.id,
    required this.driverId,
    this.clientId,
    required this.ratingDeliveryTime,
    required this.ratingService,
    required this.ratingCondition,
    required this.ratingAverage,
    this.comment,
    required this.createdAt,
  });

  factory DriverRating.fromMap(Map<String, dynamic> map) {
    return DriverRating(
      id: map['id'] as String,
      driverId: map['driver_id'] as String,
      clientId: map['client_id'] as String?,
      ratingDeliveryTime: map['rating_delivery_time'] as int,
      ratingService: map['rating_service'] as int,
      ratingCondition: map['rating_condition'] as int,
      ratingAverage: (map['rating_average'] as num).toDouble(),
      comment: map['comment'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
