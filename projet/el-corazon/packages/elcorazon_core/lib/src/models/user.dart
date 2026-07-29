/// Valeurs de `user_type` telles que rendues par `UserSerializer`
/// (`backend/apps/accounts/serializers.py`). Chaînes brutes plutôt qu'un enum
/// Dart : elles voyagent telles quelles depuis/vers le JSON, sans mapping à
/// entretenir.
abstract final class UserAccountType {
  static const customer = 'customer';
  static const courier = 'courier';
  static const staff = 'staff';
}

/// Utilisateur tel que rendu par `/auth/register/`, `/auth/login/`,
/// `/auth/me/` et `/auth/password/change/` — les quatre routes renvoient
/// exactement la même forme (vérifié côté serveur par
/// `test_inscription_connexion_et_me_renvoient_les_memes_cles`).
///
/// Classe écrite à la main plutôt qu'avec `freezed`/`json_serializable` :
/// aucun des deux n'est réellement utilisé dans les 3 apps aujourd'hui malgré
/// leur présence en dépendance, et ce contrat est maintenant documenté et
/// stable (ADR-009) — un générateur de code n'apporterait rien ici.
class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.userType,
    required this.isActive,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.avatar,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
    this.lastSeenAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String,
      userType: json['user_type'] as String,
      avatar: json['avatar'] as String?,
      isActive: json['is_active'] as bool,
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .map((permission) => permission.toString())
          .toList(),
      emailVerifiedAt: _parseDate(json['email_verified_at']),
      phoneVerifiedAt: _parseDate(json['phone_verified_at']),
      lastSeenAt: _parseDate(json['last_seen_at']),
      // `created_at`/`updated_at` sont garantis non nuls par le contrat
      // (ADR-009) : un champ absent ici doit faire échouer bruyamment plutôt
      // que produire un utilisateur à moitié renseigné.
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String email;
  final String? phone;
  final String fullName;
  final String userType;
  final String? avatar;
  final bool isActive;
  final List<String> permissions;
  final DateTime? emailVerifiedAt;
  final DateTime? phoneVerifiedAt;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool hasPermission(String code) => permissions.contains(code);

  static DateTime? _parseDate(Object? value) => value == null ? null : DateTime.parse(value as String);
}
