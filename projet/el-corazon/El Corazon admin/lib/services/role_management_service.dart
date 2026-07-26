import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_role.dart';
import '../models/user.dart' as app_user;

class RoleManagementService extends ChangeNotifier {
  static final RoleManagementService _instance =
      RoleManagementService._internal();
  factory RoleManagementService() => _instance;
  RoleManagementService._internal();

  List<AdminRole> _roles = [];
  List<app_user.User> _users = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<AdminRole> get roles => _roles;
  List<app_user.User> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialiser le service
  Future<void> initialize() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _loadRoles();
      await _loadUsers();

      _isLoading = false;
      notifyListeners();
      debugPrint('RoleManagementService: Service initialisé');
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('RoleManagementService: Erreur d\'initialisation - $e');
    }
  }

  /// Charger tous les rôles
  Future<void> _loadRoles() async {
    try {
      final response = await Supabase.instance.client
          .from('admin_roles')
          .select('*')
          .order('name');

      _roles =
          response.map<AdminRole>((data) => AdminRole.fromMap(data)).toList();

      // Ajouter les rôles par défaut s'ils n'existent pas
      await _ensureDefaultRoles();

      debugPrint('RoleManagementService: ${_roles.length} rôles chargés');
    } catch (e) {
      debugPrint('RoleManagementService: Erreur chargement rôles - $e');
      // Créer des rôles par défaut en cas d'erreur
      _createDefaultRoles();
    }
  }

  /// Charger tous les utilisateurs
  Future<void> _loadUsers() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('*')
          .order('name');

      _users = response
          .map<app_user.User>((data) => app_user.User.fromMap(data))
          .toList();
      debugPrint(
          'RoleManagementService: ${_users.length} utilisateurs chargés');
    } catch (e) {
      debugPrint('RoleManagementService: Erreur chargement utilisateurs - $e');
      _users = [];
    }
  }

  /// S'assurer que les rôles par défaut existent
  Future<void> _ensureDefaultRoles() async {
    final defaultRoles = [
      {
        'name': 'Super Admin',
        'description': 'Accès complet à toutes les fonctionnalités',
        'permissions': {
          'manage_users': true,
          'manage_roles': true,
          'manage_products': true,
          'manage_orders': true,
          'manage_drivers': true,
          'view_analytics': true,
          'manage_promotions': true,
          'manage_marketing': true,
          'manage_settings': true,
        },
        'is_default': true,
      },
      {
        'name': 'Manager',
        'description': 'Gestion des opérations quotidiennes',
        'permissions': {
          'manage_users': false,
          'manage_roles': false,
          'manage_products': true,
          'manage_orders': true,
          'manage_drivers': true,
          'view_analytics': true,
          'manage_promotions': true,
          'manage_marketing': true,
          'manage_settings': false,
        },
        'is_default': true,
      },
      {
        'name': 'Opérateur',
        'description': 'Gestion des commandes et livreurs',
        'permissions': {
          'manage_users': false,
          'manage_roles': false,
          'manage_products': false,
          'manage_orders': true,
          'manage_drivers': true,
          'view_analytics': false,
          'manage_promotions': false,
          'manage_settings': false,
        },
        'is_default': true,
      },
    ];

    for (final roleData in defaultRoles) {
      final existingRole =
          _roles.where((role) => role.name == roleData['name']).firstOrNull;
      if (existingRole == null) {
        await _createRole(AdminRole.fromMap(roleData));
      }
    }
  }

  /// Créer des rôles par défaut en cas d'erreur
  void _createDefaultRoles() {
    _roles = [
      AdminRole(
        id: '1',
        name: 'Super Admin',
        description: 'Accès complet à toutes les fonctionnalités',
        permissions: [
          const AdminPermission(
            id: 'super_admin_all',
            type: AdminPermissionType.superAdmin,
            resource: '*',
            action: '*',
            isGranted: true,
            description: 'Accès complet',
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      AdminRole(
        id: '2',
        name: 'Manager',
        description: 'Gestion des opérations quotidiennes',
        permissions: [
          const AdminPermission(
            id: 'manager_products',
            type: AdminPermissionType.productRead,
            resource: 'products',
            action: 'read',
            isGranted: true,
          ),
          const AdminPermission(
            id: 'manager_products_update',
            type: AdminPermissionType.productUpdate,
            resource: 'products',
            action: 'update',
            isGranted: true,
          ),
          const AdminPermission(
            id: 'manager_orders',
            type: AdminPermissionType.orderRead,
            resource: 'orders',
            action: 'read',
            isGranted: true,
          ),
          const AdminPermission(
            id: 'manager_orders_update',
            type: AdminPermissionType.orderUpdate,
            resource: 'orders',
            action: 'update',
            isGranted: true,
          ),
          const AdminPermission(
            id: 'manager_analytics',
            type: AdminPermissionType.analyticsRead,
            resource: 'analytics',
            action: 'read',
            isGranted: true,
          ),
          const AdminPermission(
            id: 'manager_marketing',
            type: AdminPermissionType.marketingCampaignRead,
            resource: 'marketing',
            action: 'read',
            isGranted: true,
          ),
          const AdminPermission(
            id: 'manager_marketing_create',
            type: AdminPermissionType.marketingCampaignCreate,
            resource: 'marketing',
            action: 'create',
            isGranted: true,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      AdminRole(
        id: '3',
        name: 'Opérateur',
        description: 'Gestion des commandes et livreurs',
        permissions: [
          const AdminPermission(
            id: 'operator_orders',
            type: AdminPermissionType.orderRead,
            resource: 'orders',
            action: 'read',
            isGranted: true,
          ),
          const AdminPermission(
            id: 'operator_orders_update',
            type: AdminPermissionType.orderUpdate,
            resource: 'orders',
            action: 'update',
            isGranted: true,
          ),
          const AdminPermission(
            id: 'operator_drivers',
            type: AdminPermissionType.driverRead,
            resource: 'drivers',
            action: 'read',
            isGranted: true,
          ),
          const AdminPermission(
            id: 'operator_drivers_assign',
            type: AdminPermissionType.driverAssign,
            resource: 'drivers',
            action: 'assign',
            isGranted: true,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  /// Créer un nouveau rôle (méthode privée)
  Future<void> _createRole(AdminRole role) async {
    try {
      await Supabase.instance.client.from('admin_roles').insert(role.toMap());

      _roles.add(role);
      notifyListeners();
    } catch (e) {
      debugPrint('RoleManagementService: Erreur de création de rôle - $e');
    }
  }

  /// Créer un nouveau rôle
  Future<bool> createRole(AdminRole role) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await Supabase.instance.client
          .from('admin_roles')
          .insert(role.toMap())
          .select()
          .single();

      final newRole = AdminRole.fromMap(response);
      _roles.add(newRole);

      _isLoading = false;
      notifyListeners();
      debugPrint('RoleManagementService: Rôle créé - ${role.name}');
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('RoleManagementService: Erreur création rôle - $e');
      return false;
    }
  }

  /// Mettre à jour un rôle
  Future<bool> updateRole(AdminRole role) async {
    try {
      _isLoading = true;
      notifyListeners();

      await Supabase.instance.client
          .from('admin_roles')
          .update(role.toMap())
          .eq('id', role.id);

      final index = _roles.indexWhere((r) => r.id == role.id);
      if (index != -1) {
        _roles[index] = role;
      }

      _isLoading = false;
      notifyListeners();
      debugPrint('RoleManagementService: Rôle mis à jour - ${role.name}');
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('RoleManagementService: Erreur mise à jour rôle - $e');
      return false;
    }
  }

  /// Supprimer un rôle
  Future<bool> deleteRole(String roleId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Vérifier si le rôle est utilisé
      final usersWithRole =
          _users.where((user) => user.role.name == roleId).length;
      if (usersWithRole > 0) {
        _error = 'Ce rôle est utilisé par $usersWithRole utilisateur(s)';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await Supabase.instance.client
          .from('admin_roles')
          .delete()
          .eq('id', roleId);

      _roles.removeWhere((role) => role.id == roleId);

      _isLoading = false;
      notifyListeners();
      debugPrint('RoleManagementService: Rôle supprimé - $roleId');
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('RoleManagementService: Erreur suppression rôle - $e');
      return false;
    }
  }

  /// Assigner un rôle à un utilisateur
  Future<bool> assignRoleToUser(String userId, String roleId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. Mettre à jour la table de liaison
      // D'abord supprimer les rôles existants pour cet utilisateur (si on veut un seul rôle)
      await Supabase.instance.client
          .from('user_admin_roles')
          .delete()
          .eq('user_id', userId);

      // Insérer le nouveau rôle
      await Supabase.instance.client.from('user_admin_roles').insert({
        'user_id': userId,
        'role_id': roleId,
        'is_active': true,
      });

      // 2. Mettre à jour le rôle dans la table users pour compatibilité
      // Récupérer le nom du rôle pour mettre à jour le champ texte 'role' si nécessaire
      // (ici on laisse 'admin' dans users.role, c'est géré ailleurs)
      
      // Mettre à jour la liste locale
      // ...

      _isLoading = false;
      notifyListeners();
      debugPrint(
          'RoleManagementService: Rôle assigné à l\'utilisateur $userId');
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('RoleManagementService: Erreur assignation rôle - $e');
      return false;
    }
  }

  /// Obtenir un rôle par ID
  AdminRole? getRoleById(String roleId) {
    try {
      return _roles.firstWhere((role) => role.id == roleId);
    } catch (e) {
      return null;
    }
  }

  /// Obtenir un utilisateur par ID
  app_user.User? getUserById(String userId) {
    try {
      return _users.firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }

  /// Vérifier si un utilisateur a une permission
  bool hasPermission(String userId, String permission) {
    final user = getUserById(userId);
    if (user == null) return false;

    final role = getRoleById(user.role.name);
    if (role == null) return false;

    // Vérifier si le rôle a la permission demandée
    return role.permissions
        .any((p) => p.type.toString().contains(permission) && p.isGranted);
  }

  /// Obtenir les utilisateurs avec un rôle spécifique
  List<app_user.User> getUsersByRole(String roleId) {
    return _users.where((user) => user.role.name == roleId).toList();
  }

  /// Actualiser les données
  Future<void> refresh() async {
    await initialize();
  }

  /// Effacer l'erreur
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
