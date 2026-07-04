class User {
  final String id;
  final String authUserId; // Supabase Auth user ID
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? profileImage;
  final String? profileImageUrl;
  final int loyaltyPoints;
  final List<String> badges;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isOnline; // For delivery staff
  final bool isActive; // Client active status
  final UserPreferences? preferences;
  final UserStats? stats;

  User({
    required this.id,
    required this.authUserId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImage,
    this.profileImageUrl,
    this.loyaltyPoints = 0,
    this.badges = const [],
    required this.createdAt,
    this.lastLoginAt,
    this.isOnline = false,
    this.isActive = true,
    this.preferences,
    this.stats,
  });

  User copyWith({
    String? id,
    String? authUserId,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? profileImage,
    String? profileImageUrl,
    int? loyaltyPoints,
    List<String>? badges,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isOnline,
    bool? isActive,
    UserPreferences? preferences,
    UserStats? stats,
  }) {
    return User(
      id: id ?? this.id,
      authUserId: authUserId ?? this.authUserId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      badges: badges ?? this.badges,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isOnline: isOnline ?? this.isOnline,
      isActive: isActive ?? this.isActive,
      preferences: preferences ?? this.preferences,
      stats: stats ?? this.stats,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'auth_user_id': authUserId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.toString(),
      'profileImage': profileImage,
      'profile_image_url': profileImageUrl,
      'loyaltyPoints': loyaltyPoints,
      'badges': badges.join(','),
      'createdAt': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'isOnline': isOnline ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'preferences': preferences?.toMap(),
      'stats': stats?.toMap(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    // Valider les champs requis
    final id = map['id']?.toString() ?? '';
    final authUserId = map['auth_user_id']?.toString() ?? id;
    final name = map['name']?.toString() ?? '';
    final email = map['email']?.toString() ?? '';
    final phone = map['phone']?.toString() ?? '';
    
    if (id.isEmpty || authUserId.isEmpty || name.isEmpty || email.isEmpty || phone.isEmpty) {
      throw Exception('Missing required fields in User.fromMap: id=$id, authUserId=$authUserId, name=$name, email=$email, phone=$phone');
    }

    // Parser le rôle
    UserRole role;
    try {
      final roleString = map['role']?.toString().toLowerCase() ?? 'client';
      role = UserRole.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == roleString,
        orElse: () => UserRole.client,
      );
    } catch (e) {
      role = UserRole.client;
    }

    // Parser la date de création
    DateTime createdAt;
    try {
      if (map['created_at'] != null) {
        if (map['created_at'] is DateTime) {
          createdAt = map['created_at'] as DateTime;
        } else {
          createdAt = DateTime.parse(map['created_at'].toString());
        }
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      createdAt = DateTime.now();
    }

    // Parser last_login_at
    DateTime? lastLoginAt;
    if (map['last_login_at'] != null) {
      try {
        if (map['last_login_at'] is DateTime) {
          lastLoginAt = map['last_login_at'] as DateTime;
        } else {
          lastLoginAt = DateTime.parse(map['last_login_at'].toString());
        }
      } catch (e) {
        lastLoginAt = null;
      }
    }

    // Parser les badges
    List<String> badges = [];
    if (map['badges'] != null) {
      if (map['badges'] is List) {
        badges = List<String>.from(
          (map['badges'] as List).map((b) => b.toString())
        );
      } else if (map['badges'] is String) {
        badges = (map['badges'] as String)
            .split(',')
            .where((b) => b.trim().isNotEmpty)
            .map((b) => b.trim())
            .toList();
      }
    }

    // Parser les préférences
    UserPreferences? preferences;
    if (map['preferences'] != null) {
      try {
        if (map['preferences'] is Map) {
          preferences = UserPreferences.fromMap(
              Map<String, dynamic>.from(map['preferences']));
        }
      } catch (e) {
        preferences = null;
      }
    }

    // Parser les stats
    UserStats? stats;
    if (map['stats'] != null) {
      try {
        if (map['stats'] is Map) {
          stats = UserStats.fromMap(Map<String, dynamic>.from(map['stats']));
        }
      } catch (e) {
        stats = null;
      }
    }

    return User(
      id: id,
      authUserId: authUserId,
      name: name,
      email: email,
      phone: phone,
      role: role,
      profileImage: map['profile_image']?.toString(),
      profileImageUrl: map['profile_image_url']?.toString(),
      loyaltyPoints: (map['loyalty_points'] as num?)?.toInt() ?? 0,
      badges: badges,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      isOnline: map['is_online'] == true || map['is_online'] == 1,
      isActive: map['is_active'] != null
          ? (map['is_active'] == true || map['is_active'] == 1)
          : true, // Par défaut, actif si non spécifié
      preferences: preferences,
      stats: stats,
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

class UserPreferences {
  final bool notifications;
  final bool darkMode;
  final String language;

  UserPreferences({
    required this.notifications,
    required this.darkMode,
    required this.language,
  });

  Map<String, dynamic> toMap() {
    return {
      'notifications': notifications,
      'dark_mode': darkMode,
      'language': language,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      notifications: map['notifications'] == true || map['notifications'] == 1,
      darkMode: map['dark_mode'] == true || map['dark_mode'] == 1,
      language: map['language']?.toString() ?? 'fr',
    );
  }
}

class UserStats {
  final int totalOrders;
  final int completedOrders;
  final double totalSpent;
  final int loyaltyPoints;
  final int level;

  UserStats({
    required this.totalOrders,
    required this.completedOrders,
    required this.totalSpent,
    required this.loyaltyPoints,
    required this.level,
  });

  Map<String, dynamic> toMap() {
    return {
      'total_orders': totalOrders,
      'completed_orders': completedOrders,
      'total_spent': totalSpent,
      'loyalty_points': loyaltyPoints,
      'level': level,
    };
  }

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      totalOrders: map['total_orders'] ?? 0,
      completedOrders: map['completed_orders'] ?? 0,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0.0,
      loyaltyPoints: map['loyalty_points'] ?? 0,
      level: map['level'] ?? 1,
    );
  }
}
