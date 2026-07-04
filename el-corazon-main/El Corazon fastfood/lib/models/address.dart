import 'package:flutter/material.dart';

enum AddressType {
  home('Maison', '🏠'),
  work('Travail', '💼'),
  other('Autre', '📍');

  const AddressType(this.displayName, this.emoji);
  final String displayName;
  final String emoji;

  Color get color {
    switch (this) {
      case AddressType.home:
        return Colors.green;
      case AddressType.work:
        return Colors.blue;
      case AddressType.other:
        return Colors.orange;
    }
  }
}

class Address {
  final String id;
  final String userId;
  final String name;
  final String address;
  final String city;
  final String postalCode;
  final double? latitude;
  final double? longitude;
  final AddressType type;
  final bool isDefault;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  Address({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.type,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.isFavorite = false,
  });

  Address copyWith({
    String? id,
    String? userId,
    String? name,
    String? address,
    String? city,
    String? postalCode,
    double? latitude,
    double? longitude,
    AddressType? type,
    bool? isDefault,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Address(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'address': address,
      'city': city,
      'postal_code': postalCode,
      'latitude': latitude,
      'longitude': longitude,
      'type': type.name,
      'is_default': isDefault,
      'is_favorite': isFavorite,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      city: json['city'] as String,
      postalCode: json['postal_code'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      type: AddressType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AddressType.other,
      ),
      isDefault: json['is_default'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  String get fullAddress => '$address, $city $postalCode';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Address && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Address(id: $id, name: $name, address: $address, type: $type)';
  }
}
