import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Statut du livreur
enum DriverStatus {
  offline('Hors ligne', Icons.person_off, Colors.grey),
  available('Disponible', Icons.delivery_dining, Colors.green),
  onDelivery('En livraison', Icons.moped, Colors.orange),
  unavailable('Indisponible', Icons.block, Colors.red);

  const DriverStatus(this.displayName, this.icon, this.color);

  final String displayName;
  final IconData icon;
  final Color color;
}

/// Modèle pour les livreurs
class Driver {
  final String id;
  final String? authUserId; // auth_user_id pour récupérer user_id depuis users
  final String? userId; // user_id de la table users (pour assignDriver)
  final String name;
  final String email;
  final String phone;
  final DriverStatus status;
  final double? latitude;
  final double? longitude;
  final String? vehicleType;
  final String? licensePlate;
  final double rating;
  final int totalDeliveries;
  final double totalEarnings;
  final DateTime createdAt;
  final DateTime? lastOnline;
  final String? profileImageUrl;
  final String? notes;
  final bool isActive;

  Driver({
    required this.id,
    this.authUserId,
    this.userId,
    required this.name,
    required this.email,
    required this.phone,
    this.status = DriverStatus.offline,
    this.latitude,
    this.longitude,
    this.vehicleType,
    this.licensePlate,
    this.rating = 0.0,
    this.totalDeliveries = 0,
    this.totalEarnings = 0.0,
    required this.createdAt,
    this.lastOnline,
    this.profileImageUrl,
    this.notes,
    this.isActive = true,
  });

  factory Driver.fromMap(Map<String, dynamic> data) {
    return Driver(
      id: data['id'] ?? '',
      authUserId: data['auth_user_id'],
      userId: data['user_id'], // Peut être fourni par la relation users
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      status: DriverStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => DriverStatus.offline,
      ),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      vehicleType: data['vehicle_type'],
      licensePlate: data['license_plate'],
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      totalDeliveries: data['total_deliveries'] ?? 0,
      totalEarnings: (data['total_earnings'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(data['created_at'] ?? DateTime.now().toIso8601String()),
      lastOnline: data['last_online'] != null ? DateTime.parse(data['last_online']) : null,
      profileImageUrl: data['profile_image_url'],
      notes: data['notes'],
      isActive: data['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'status': status.toString().split('.').last,
      'latitude': latitude,
      'longitude': longitude,
      'vehicle_type': vehicleType,
      'license_plate': licensePlate,
      'rating': rating,
      'total_deliveries': totalDeliveries,
      'total_earnings': totalEarnings,
      'created_at': createdAt.toIso8601String(),
      'last_online': lastOnline?.toIso8601String(),
      'profile_image_url': profileImageUrl,
      'notes': notes,
      'is_active': isActive,
    };
  }

  Driver copyWith({
    String? id,
    String? authUserId,
    String? userId,
    String? name,
    String? email,
    String? phone,
    DriverStatus? status,
    double? latitude,
    double? longitude,
    String? vehicleType,
    String? licensePlate,
    double? rating,
    int? totalDeliveries,
    double? totalEarnings,
    DateTime? createdAt,
    DateTime? lastOnline,
    String? profileImageUrl,
    String? notes,
    bool? isActive,
  }) {
    return Driver(
      id: id ?? this.id,
      authUserId: authUserId ?? this.authUserId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      vehicleType: vehicleType ?? this.vehicleType,
      licensePlate: licensePlate ?? this.licensePlate,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      createdAt: createdAt ?? this.createdAt,
      lastOnline: lastOnline ?? this.lastOnline,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Calcule la distance entre deux points géographiques (formule de Haversine)
  double distanceTo(double lat, double lng) {
    if (latitude == null || longitude == null) return double.infinity;
    
    const double earthRadius = 6371; // Rayon de la Terre en km
    final double lat1Rad = latitude! * math.pi / 180;
    final double lat2Rad = lat * math.pi / 180;
    final double deltaLatRad = (lat - latitude!) * math.pi / 180;
    final double deltaLngRad = (lng - longitude!) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Vérifie si le livreur est proche d'une position donnée
  bool isNearTo(double lat, double lng, {double maxDistanceKm = 5.0}) {
    return distanceTo(lat, lng) <= maxDistanceKm;
  }

  /// Calcule le temps de livraison estimé en minutes
  int estimatedDeliveryTime(double lat, double lng) {
    final distance = distanceTo(lat, lng);
    // Estimation basique : 2 minutes par km + 10 minutes de base
    return (distance * 2 + 10).round();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Driver &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.phone == phone &&
        other.status == status &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.vehicleType == vehicleType &&
        other.licensePlate == licensePlate &&
        other.rating == rating &&
        other.totalDeliveries == totalDeliveries &&
        other.totalEarnings == totalEarnings &&
        other.createdAt == createdAt &&
        other.lastOnline == lastOnline &&
        other.profileImageUrl == profileImageUrl &&
        other.notes == notes &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      email,
      phone,
      status,
      latitude,
      longitude,
      vehicleType,
      licensePlate,
      rating,
      totalDeliveries,
      totalEarnings,
      createdAt,
      lastOnline,
      profileImageUrl,
      notes,
      isActive,
    );
  }
}

/// Modèle pour les statistiques du livreur
class DriverStats {
  final String driverId;
  final int totalDeliveries;
  final double totalEarnings;
  final double averageRating;
  final int completedDeliveries;
  final int cancelledDeliveries;
  final double averageDeliveryTime; // en minutes
  final DateTime periodStart;
  final DateTime periodEnd;

  const DriverStats({
    required this.driverId,
    required this.totalDeliveries,
    required this.totalEarnings,
    required this.averageRating,
    required this.completedDeliveries,
    required this.cancelledDeliveries,
    required this.averageDeliveryTime,
    required this.periodStart,
    required this.periodEnd,
  });

  factory DriverStats.fromMap(Map<String, dynamic> data) {
    return DriverStats(
      driverId: data['driver_id'] ?? '',
      totalDeliveries: data['total_deliveries'] ?? 0,
      totalEarnings: (data['total_earnings'] as num?)?.toDouble() ?? 0.0,
      averageRating: (data['average_rating'] as num?)?.toDouble() ?? 0.0,
      completedDeliveries: data['completed_deliveries'] ?? 0,
      cancelledDeliveries: data['cancelled_deliveries'] ?? 0,
      averageDeliveryTime: (data['average_delivery_time'] as num?)?.toDouble() ?? 0.0,
      periodStart: DateTime.parse(data['period_start'] ?? DateTime.now().toIso8601String()),
      periodEnd: DateTime.parse(data['period_end'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driver_id': driverId,
      'total_deliveries': totalDeliveries,
      'total_earnings': totalEarnings,
      'average_rating': averageRating,
      'completed_deliveries': completedDeliveries,
      'cancelled_deliveries': cancelledDeliveries,
      'average_delivery_time': averageDeliveryTime,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DriverStats &&
        other.driverId == driverId &&
        other.totalDeliveries == totalDeliveries &&
        other.totalEarnings == totalEarnings &&
        other.averageRating == averageRating &&
        other.completedDeliveries == completedDeliveries &&
        other.cancelledDeliveries == cancelledDeliveries &&
        other.averageDeliveryTime == averageDeliveryTime &&
        other.periodStart == periodStart &&
        other.periodEnd == periodEnd;
  }

  @override
  int get hashCode {
    return Object.hash(
      driverId,
      totalDeliveries,
      totalEarnings,
      averageRating,
      completedDeliveries,
      cancelledDeliveries,
      averageDeliveryTime,
      periodStart,
      periodEnd,
    );
  }
}