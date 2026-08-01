/// Rôle du personnel — miroir de `RoleSerializer`.
///
/// Un rôle n'est **qu'un groupement de permissions**. Le serveur ne teste
/// jamais son nom (ADR-005) : renommer « Manager » ne change aucun droit, et
/// créer « Responsable de nuit » avec trois permissions ne demande aucun
/// déploiement.
class AdminRole {
  const AdminRole({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
    required this.isSystem,
    required this.createdAt,
  });

  factory AdminRole.fromJson(Map<String, dynamic> json) {
    return AdminRole(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .map((permission) => permission.toString())
          .toList(),
      isSystem: json['is_system'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String name;
  final String description;
  final List<String> permissions;

  /// Fourni à l'installation : ni modifiable ni supprimable. Retirer
  /// « Super Admin » d'une instance en production enfermerait tout le monde
  /// dehors — le serveur refuse, l'écran doit le dire avant.
  final bool isSystem;
  final DateTime createdAt;
}

/// Une entrée du registre des permissions, tel qu'il est **dans le code du
/// serveur** — miroir de `PermissionSerializer`.
///
/// Lu et non recopié : une liste de codes tenue côté client diverge à la
/// première permission ajoutée, et l'écran propose alors une case qui
/// n'accorde rien, ou tait un droit qui existe.
class PermissionEntry {
  const PermissionEntry({required this.code, required this.description});

  factory PermissionEntry.fromJson(Map<String, dynamic> json) {
    return PermissionEntry(
      code: json['code'] as String,
      description: json['description'] as String? ?? '',
    );
  }

  final String code;
  final String description;

  /// Partie avant le point — « orders », « catalog ». Les écrans groupent par
  /// domaine ; le vocabulaire `domaine.action` est justement fait pour ça.
  String get domain => code.split('.').first;
}
