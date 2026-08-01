/// Compte client vu du guichet — miroir de `CustomerSerializer`.
///
/// Distinct de [User], et pas par recopie : c'est un dossier **en lecture
/// seule**, sans permissions ni jetons, dont le seul geste d'exploitation est
/// le blocage. Le nom, l'adresse et le téléphone appartiennent au client et se
/// modifient depuis son application ; les rendre modifiables ici ouvrirait un
/// chemin de reprise de compte par « mot de passe oublié ».
class Customer {
  const Customer({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.avatar,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
    this.lastSeenAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String,
      avatar: json['avatar'] as String?,
      isActive: json['is_active'] as bool,
      emailVerifiedAt: _date(json['email_verified_at']),
      phoneVerifiedAt: _date(json['phone_verified_at']),
      lastSeenAt: _date(json['last_seen_at']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String email;
  final String? phone;
  final String fullName;
  final String? avatar;

  /// Faux = compte bloqué. Le serveur a révoqué ses jetons dans la même
  /// requête, sans quoi il aurait continué de commander jusqu'à leur
  /// expiration.
  final bool isActive;
  final DateTime? emailVerifiedAt;
  final DateTime? phoneVerifiedAt;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEmailVerified => emailVerifiedAt != null;
  bool get isPhoneVerified => phoneVerifiedAt != null;

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}

/// Compte du personnel — miroir de `StaffSerializer`.
///
/// [permissions] est l'**union** de celles de ses rôles, calculée par le
/// serveur. La recomposer côté client à partir de [roleIds] dériverait le jour
/// où un rôle change sans que l'écran ait rechargé la liste des rôles.
class StaffMember {
  const StaffMember({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    required this.roleIds,
    required this.restaurantSlugs,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.lastSeenAt,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String,
      isActive: json['is_active'] as bool,
      roleIds: (json['roles'] as List<dynamic>? ?? const [])
          .map((role) => role.toString())
          .toList(),
      restaurantSlugs: (json['restaurants'] as List<dynamic>? ?? const [])
          .map((slug) => slug.toString())
          .toList(),
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .map((permission) => permission.toString())
          .toList(),
      lastSeenAt: json['last_seen_at'] == null
          ? null
          : DateTime.parse(json['last_seen_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String email;
  final String? phone;
  final String fullName;
  final bool isActive;
  final List<String> roleIds;
  final List<String> restaurantSlugs;
  final List<String> permissions;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool hasPermission(String code) => permissions.contains(code);
}
