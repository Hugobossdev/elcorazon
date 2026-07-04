import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:elcora_fast/models/user.dart';

part 'freezed_user.freezed.dart';
part 'freezed_user.g.dart';

/// Exemple de modèle User avec Freezed
///
/// Pour générer le code, exécutez :
/// ```bash
/// flutter pub run build_runner build --delete-conflicting-outputs
/// ```
@freezed
class FreezedUser with _$FreezedUser {
  const FreezedUser._();

  const factory FreezedUser({
    required String id,
    required String name,
    required String email,
    required String phone,
    required UserRole role,
    required DateTime createdAt,
    String? profileImage,
    @Default(0) int loyaltyPoints,
    @Default([]) List<String> badges,
  }) = _FreezedUser;

  factory FreezedUser.fromJson(Map<String, dynamic> json) =>
      _$FreezedUserFromJson(json);

  /// Factory pour créer depuis un Map (compatibilité avec l'ancien code)
  factory FreezedUser.fromMap(Map<String, dynamic> map) {
    // Parser le rôle (uniquement client maintenant)
    const UserRole role = UserRole.client;

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
    };
  }
}
