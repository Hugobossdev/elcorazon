import 'dart:convert';

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? profileImage;
  final int loyaltyPoints;
  final List<String> badges;
  final DateTime createdAt;
  final Map<String, dynamic>? preferences;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.profileImage,
    this.loyaltyPoints = 0,
    this.badges = const [],
    this.preferences,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? profileImage,
    int? loyaltyPoints,
    List<String>? badges,
    DateTime? createdAt,
    Map<String, dynamic>? preferences,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      badges: badges ?? this.badges,
      createdAt: createdAt ?? this.createdAt,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.toString(),
      'profileImage': profileImage,
      'loyaltyPoints': loyaltyPoints,
      'badges': badges.join(','),
      'createdAt': createdAt.toIso8601String(),
      'preferences': preferences,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? preferences;
    if (map['preferences'] != null) {
      if (map['preferences'] is Map) {
        preferences = Map<String, dynamic>.from(map['preferences']);
      } else if (map['preferences'] is String) {
        try {
          preferences = Map<String, dynamic>.from(
            jsonDecode(map['preferences'] as String),
          );
        } catch (e) {
          preferences = null;
        }
      }
    }

    return User(
      id: map['id'] ?? map['auth_user_id'],
      name: map['name'],
      email: map['email'],
      phone: map['phone'],
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => UserRole.client,
      ),
      profileImage: map['profile_image'],
      loyaltyPoints: map['loyalty_points'] ?? 0,
      badges: map['badges'] is List
          ? List<String>.from(map['badges'])
          : (map['badges'] as String?)
                  ?.split(',')
                  .where((b) => b.isNotEmpty)
                  .toList() ??
              [],
      createdAt: DateTime.parse(map['created_at']),
      preferences: preferences,
    );
  }
}

enum UserRole {
  client,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.client:
        return 'Client';
    }
  }

  String get emoji {
    switch (this) {
      case UserRole.client:
        return '🍔';
    }
  }
}

extension UserExtension on User {
  String get displayName => name;
}
