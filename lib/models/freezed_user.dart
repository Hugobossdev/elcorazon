// import 'package:freezed_annotation/freezed_annotation.dart'; // TODO: Décommenter après génération
import 'package:elcora_fast/models/user.dart' as user_models;

// TODO: Générer les fichiers avec: flutter pub run build_runner build --delete-conflicting-outputs
// part 'freezed_user.freezed.dart';
// part 'freezed_user.g.dart';

/// Exemple de modèle User avec Freezed
///
/// Pour générer le code, exécutez :
/// ```bash
/// flutter pub run build_runner build --delete-conflicting-outputs
/// ```
// TODO: Décommenter après génération des fichiers
// @freezed
class FreezedUser /* with _$FreezedUser */ {
  final String id;
  final String name;
  final String email;
  final String phone;
  final user_models.UserRole role;
  final String? profileImage;
  final int loyaltyPoints;
  final List<String> badges;
  final DateTime createdAt;
  final bool isOnline;

  const FreezedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.profileImage,
    this.loyaltyPoints = 0,
    this.badges = const [],
    this.isOnline = false,
  }); // = _FreezedUser;

  // TODO: Décommenter après génération
  // factory FreezedUser.fromJson(Map<String, dynamic> json) =>
  //     _$FreezedUserFromJson(json);

  /// Factory pour créer depuis un Map (compatibilité avec l'ancien code)
  factory FreezedUser.fromMap(Map<String, dynamic> map) {
    // Parser le rôle
    user_models.UserRole role = user_models.UserRole.client;
    if (map['role'] != null) {
      final roleString = map['role'].toString().toLowerCase();
      switch (roleString) {
        case 'delivery':
        case 'delivery_staff':
          role = user_models.UserRole.delivery;
          break;
        case 'client':
        default:
          role = user_models.UserRole.client;
          break;
      }
    }

    // Parser les badges
    List<String> badges = [];
    if (map['badges'] != null) {
      if (map['badges'] is String) {
        badges = (map['badges'] as String)
            .split(',')
            .where((b) => b.trim().isNotEmpty)
            .map((b) => b.trim())
            .toList();
      } else if (map['badges'] is List) {
        badges = (map['badges'] as List).map((b) => b.toString()).toList();
      }
    }

    // Parser la date
    DateTime createdAt = DateTime.now();
    if (map['created_at'] != null || map['createdAt'] != null) {
      try {
        final dateString =
            map['created_at']?.toString() ?? map['createdAt']?.toString() ?? '';
        if (dateString.isNotEmpty) {
          createdAt = DateTime.parse(dateString);
        }
      } catch (e) {
        // Erreur de parsing, utiliser la date actuelle
      }
    }

    return FreezedUser(
      id: map['id']?.toString() ?? map['auth_user_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      role: role,
      profileImage:
          map['profile_image']?.toString() ?? map['profileImage']?.toString(),
      loyaltyPoints: (map['loyalty_points'] is num)
          ? (map['loyalty_points'] as num).toInt()
          : (map['loyaltyPoints'] is num)
              ? (map['loyaltyPoints'] as num).toInt()
              : 0,
      badges: badges,
      createdAt: createdAt,
      isOnline: map['is_online'] == 1 ||
          map['is_online'] == true ||
          map['isOnline'] == true,
    );
  }

  /// Méthode pour convertir en Map (compatibilité avec l'ancien code)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.toString().split('.').last,
      'profileImage': profileImage,
      'loyaltyPoints': loyaltyPoints,
      'badges': badges.join(','),
      'createdAt': createdAt.toIso8601String(),
      'isOnline': isOnline ? 1 : 0,
    };
  }
}
