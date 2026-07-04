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
  final bool isOnline; // For delivery staff

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImage,
    this.loyaltyPoints = 0,
    this.badges = const [],
    required this.createdAt,
    this.isOnline = false,
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
    bool? isOnline,
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
      isOnline: isOnline ?? this.isOnline,
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
      'isOnline': isOnline ? 1 : 0,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
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
      isOnline: map['is_online'] ?? false,
    );
  }
}

enum UserRole {
  client,
  admin,
  delivery,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.client:
        return 'Client';
      case UserRole.admin:
        return 'Restaurant Admin';
      case UserRole.delivery:
        return 'Delivery Staff';
    }
  }

  String get emoji {
    switch (this) {
      case UserRole.client:
        return '🍔';
      case UserRole.admin:
        return '👨‍💼';
      case UserRole.delivery:
        return '🛵';
    }
  }
}

extension UserExtension on User {
  String get displayName => name;
}
