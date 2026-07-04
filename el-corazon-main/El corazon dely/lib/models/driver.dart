class Driver {
  final String id;
  final String userId;
  final String? profilePhotoUrl;
  final String? licenseNumber;
  final String? idNumber;
  final String? vehicleType;
  final String? vehicleNumber;
  final String? licensePhotoUrl;
  final String? idCardPhotoUrl;
  final String? vehiclePhotoUrl;
  final String verificationStatus;
  final String? verificationNotes;
  final int totalDeliveries;
  final int completedDeliveries;
  final double rating;
  final int totalRatings;
  final bool isAvailable;
  final double? currentLocationLatitude;
  final double? currentLocationLongitude;
  final DateTime? lastLocationUpdate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Driver({
    required this.id,
    required this.userId,
    this.profilePhotoUrl,
    this.licenseNumber,
    this.idNumber,
    this.vehicleType,
    this.vehicleNumber,
    this.licensePhotoUrl,
    this.idCardPhotoUrl,
    this.vehiclePhotoUrl,
    this.verificationStatus = 'pending',
    this.verificationNotes,
    this.totalDeliveries = 0,
    this.completedDeliveries = 0,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.isAvailable = true,
    this.currentLocationLatitude,
    this.currentLocationLongitude,
    this.lastLocationUpdate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      id: map['id'],
      userId: map['user_id'],
      profilePhotoUrl: map['profile_photo_url'],
      licenseNumber: map['license_number'],
      idNumber: map['id_number'],
      vehicleType: map['vehicle_type'],
      vehicleNumber: map['vehicle_number'],
      licensePhotoUrl: map['license_photo_url'],
      idCardPhotoUrl: map['id_card_photo_url'],
      vehiclePhotoUrl: map['vehicle_photo_url'],
      verificationStatus: map['verification_status'] ?? 'pending',
      verificationNotes: map['verification_notes'],
      totalDeliveries: map['total_deliveries'] ?? 0,
      completedDeliveries: map['completed_deliveries'] ?? 0,
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalRatings: map['total_ratings'] ?? 0,
      isAvailable: map['is_available'] ?? true,
      currentLocationLatitude: map['current_location_latitude']?.toDouble(),
      currentLocationLongitude: map['current_location_longitude']?.toDouble(),
      lastLocationUpdate: map['last_location_update'] != null
          ? DateTime.parse(map['last_location_update'])
          : null,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'profile_photo_url': profilePhotoUrl,
      'license_number': licenseNumber,
      'id_number': idNumber,
      'vehicle_type': vehicleType,
      'vehicle_number': vehicleNumber,
      'license_photo_url': licensePhotoUrl,
      'id_card_photo_url': idCardPhotoUrl,
      'vehicle_photo_url': vehiclePhotoUrl,
      'verification_status': verificationStatus,
      'verification_notes': verificationNotes,
      'total_deliveries': totalDeliveries,
      'completed_deliveries': completedDeliveries,
      'rating': rating,
      'total_ratings': totalRatings,
      'is_available': isAvailable,
      'current_location_latitude': currentLocationLatitude,
      'current_location_longitude': currentLocationLongitude,
      'last_location_update': lastLocationUpdate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Driver copyWith({
    String? id,
    String? userId,
    String? profilePhotoUrl,
    String? licenseNumber,
    String? idNumber,
    String? vehicleType,
    String? vehicleNumber,
    String? licensePhotoUrl,
    String? idCardPhotoUrl,
    String? vehiclePhotoUrl,
    String? verificationStatus,
    String? verificationNotes,
    int? totalDeliveries,
    int? completedDeliveries,
    double? rating,
    int? totalRatings,
    bool? isAvailable,
    double? currentLocationLatitude,
    double? currentLocationLongitude,
    DateTime? lastLocationUpdate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Driver(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      idNumber: idNumber ?? this.idNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      licensePhotoUrl: licensePhotoUrl ?? this.licensePhotoUrl,
      idCardPhotoUrl: idCardPhotoUrl ?? this.idCardPhotoUrl,
      vehiclePhotoUrl: vehiclePhotoUrl ?? this.vehiclePhotoUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationNotes: verificationNotes ?? this.verificationNotes,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      completedDeliveries: completedDeliveries ?? this.completedDeliveries,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLocationLatitude: currentLocationLatitude ?? this.currentLocationLatitude,
      currentLocationLongitude: currentLocationLongitude ?? this.currentLocationLongitude,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

