import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'admin_auth_service.dart';

/// Rôles et permissions du personnel — `/administration/roles/` et
/// `/restaurants/staff/` (Phase 6).
///
/// L'ancienne implémentation portait un second système d'autorisation, parallèle
/// à celui du serveur : une table `admin_roles` dont les permissions étaient des
/// booléens nommés (`manage_marketing`, `manage_settings`) que **seule
/// l'interface consultait**. Un « Opérateur » privé du module marketing y voyait
/// l'écran disparaître, et pouvait appeler l'API marketing sans obstacle.
///
/// Ici, il n'y a plus qu'un vocabulaire — `domaine.action`, celui de l'ADR-005 —
/// et il vient du serveur :
///
/// * [registry] est le registre tel qu'il est **dans le code** du serveur.
///   Une liste tenue côté client divergerait à la première permission ajoutée,
///   et l'écran proposerait une case qui n'accorde rien ;
/// * les rôles ne sont plus semés à l'initialisation. « Créer les rôles par
///   défaut s'ils n'existent pas » depuis un poste de travail, c'était donner à
///   n'importe quelle session la faculté de recréer « Super Admin ». Les rôles
///   système sont installés par le serveur, qui refuse ensuite de les modifier ;
/// * il n'y a **pas de suppression**. Un rôle retiré à chaud priverait sans
///   préavis les comptes qui le portent, et l'effet ne se verrait qu'au
///   prochain refus. Un rôle qui ne sert plus se vide de ses permissions.
class RoleManagementService extends ChangeNotifier {
  static final RoleManagementService _instance =
      RoleManagementService._internal();
  factory RoleManagementService() => _instance;
  RoleManagementService._internal();

  eccore.AdministrationRepository get _admin =>
      eccore.AdministrationRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.AdminRole> _roles = [];
  List<eccore.PermissionEntry> _registry = [];
  List<eccore.StaffMember> _staff = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<eccore.AdminRole> get roles => _roles;
  List<eccore.PermissionEntry> get registry => _registry;
  List<eccore.StaffMember> get staff => _staff;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Registre groupé par domaine — « orders », « catalog »…
  ///
  /// Le vocabulaire `domaine.action` est fait pour ça : l'écran qui compose un
  /// rôle regroupe sans table de correspondance à entretenir.
  Map<String, List<eccore.PermissionEntry>> get registryByDomain {
    final parDomaine = <String, List<eccore.PermissionEntry>>{};
    for (final entree in _registry) {
      parDomaine.putIfAbsent(entree.domain, () => []).add(entree);
    }
    return parDomaine;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _roles = await _admin.roles();
      _registry = await _admin.permissionRegistry();
      _staff = await _admin.staff();
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Rôles : chargement impossible — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------ rôles

  Future<bool> createRole({
    required String name,
    required List<String> permissions,
    String description = '',
  }) async {
    try {
      final cree = await _admin.createRole(
        name: name,
        permissions: permissions,
        description: description,
      );
      _roles = [..._roles, cree]..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Rôles : création refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  /// Modifie un rôle. Le serveur refuse les rôles système (403) — l'écran le
  /// dit avant d'essayer, mais c'est lui qui tranche.
  Future<bool> updateRole({
    required String roleId,
    String? name,
    String? description,
    List<String>? permissions,
  }) async {
    try {
      final maj = await _admin.updateRole(
        roleId: roleId,
        name: name,
        description: description,
        permissions: permissions,
      );
      final index = _roles.indexWhere((role) => role.id == roleId);
      if (index != -1) _roles[index] = maj;
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.status == 403
          ? "Les rôles fournis à l'installation ne se modifient pas : "
                'créez-en un sur mesure et attribuez-le.'
          : e.detail;
      debugPrint('Rôles : modification refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  // -------------------------------------------------------------- personnel

  /// Remplace les rôles d'un membre du personnel.
  Future<bool> assignRoles({
    required String staffId,
    required List<String> roleIds,
  }) async {
    try {
      final maj = await _admin.assignRoles(staffId: staffId, roleIds: roleIds);
      _remplacer(maj);
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Rôles : attribution refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  /// Désactive ou réactive un compte du personnel — le serveur révoque ses
  /// jetons dans la même requête.
  Future<bool> setStaffActive({
    required String staffId,
    required bool isActive,
  }) async {
    try {
      final maj = await _admin.setStaffActive(
        staffId: staffId,
        isActive: isActive,
      );
      _remplacer(maj);
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint("Rôles : changement d'état refusé — ${e.code}");
      notifyListeners();
      return false;
    }
  }

  eccore.AdminRole? roleById(String roleId) {
    for (final role in _roles) {
      if (role.id == roleId) return role;
    }
    return null;
  }

  void _remplacer(eccore.StaffMember membre) {
    final index = _staff.indexWhere((m) => m.id == membre.id);
    if (index != -1) _staff[index] = membre;
    notifyListeners();
  }
}
