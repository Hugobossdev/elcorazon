import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/admin_role.dart';
import '../models/user.dart' as app_user;

class AdminAuthService extends ChangeNotifier {
  static final AdminAuthService _instance = AdminAuthService._internal();
  factory AdminAuthService() => _instance;
  AdminAuthService._internal();

  app_user.User? _currentAdmin;
  AdminRole? _currentRole;
  List<AdminRole> _availableRoles = [];
  bool _isAuthenticated = false;
  bool _isLoading = false;

  // Auto-logout après inactivité
  Timer? _inactivityTimer;
  DateTime? _lastActivity;
  Duration _inactivityTimeout = const Duration(minutes: 30);
  bool _autoLogoutEnabled = true;

  // Getters
  app_user.User? get currentAdmin => _currentAdmin;
  AdminRole? get currentRole => _currentRole;
  List<AdminRole> get availableRoles => _availableRoles;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  Duration get inactivityTimeout => _inactivityTimeout;
  bool get autoLogoutEnabled => _autoLogoutEnabled;

  /// Initialiser le service
  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Charger les rôles disponibles
      await _loadAvailableRoles();

      // Vérifier si un admin est déjà connecté
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        await _loadAdminProfile(currentUser.id);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing AdminAuthService: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les rôles disponibles
  Future<void> _loadAvailableRoles() async {
    try {
      // Essayer de charger les rôles depuis la base de données
      final response = await Supabase.instance.client
          .from('admin_roles')
          .select()
          .eq('is_active', true)
          .order('name');

      if (response.isNotEmpty) {
        final roles = <AdminRole>[];
        for (final data in response) {
          try {
            roles.add(AdminRole.fromMap(data));
          } catch (e) {
            debugPrint('Error parsing role data: $e, data: $data');
            // Continuer avec le prochain rôle
          }
        }
        
        // Si aucun rôle valide n'a été chargé, utiliser les rôles prédéfinis
        if (roles.isEmpty) {
          _availableRoles = [
            PredefinedAdminRoles.superAdmin,
            PredefinedAdminRoles.manager,
            PredefinedAdminRoles.operator,
          ];
        } else {
          _availableRoles = roles;
        }
      } else {
        // Fallback: utiliser les rôles prédéfinis
        _availableRoles = [
          PredefinedAdminRoles.superAdmin,
          PredefinedAdminRoles.manager,
          PredefinedAdminRoles.operator,
        ];
      }
    } catch (e) {
      debugPrint('Error loading available roles: $e');
      // Fallback: utiliser les rôles prédéfinis si la table n'existe pas
      _availableRoles = [
        PredefinedAdminRoles.superAdmin,
        PredefinedAdminRoles.manager,
        PredefinedAdminRoles.operator,
      ];
    }
  }

  /// Charger le profil admin
  Future<void> _loadAdminProfile(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('auth_user_id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint('Error loading admin profile: User not found');
        _currentAdmin = null;
        _currentRole = null;
        _isAuthenticated = false;
        return;
      }

      try {
        // Vérifier les champs requis
        final id = response['id']?.toString() ?? response['auth_user_id']?.toString();
        final name = response['name']?.toString();
        final email = response['email']?.toString();
        final phone = response['phone']?.toString();
        
        if (id == null || id.isEmpty || 
            name == null || name.isEmpty || 
            email == null || email.isEmpty || 
            phone == null || phone.isEmpty) {
          debugPrint('Error loading admin profile: Missing required fields');
          debugPrint('  id: $id, name: $name, email: $email, phone: $phone');
          _currentAdmin = null;
          _currentRole = null;
          _isAuthenticated = false;
          return;
        }
        
        _currentAdmin = app_user.User.fromMap(response);
      } catch (userError) {
        debugPrint('Error parsing user data: $userError');
        debugPrint('Response data: $response');
        _currentAdmin = null;
        _currentRole = null;
        _isAuthenticated = false;
        return;
      }

      // Charger le rôle admin
      if (_currentAdmin?.role == app_user.UserRole.admin) {
        try {
          // Essayer de charger le rôle depuis user_admin_roles
          final userRoleResponse = await Supabase.instance.client
              .from('user_admin_roles')
              .select('*, admin_roles(*)')
              .eq('user_id', userId)
              .eq('is_active', true)
              .maybeSingle();

          // Gérer le cas où admin_roles peut être un Map, une List, ou null
          dynamic adminRolesData = userRoleResponse?['admin_roles'];
          Map<String, dynamic>? adminRoleMap;
          
          if (adminRolesData != null) {
            if (adminRolesData is Map<String, dynamic>) {
              adminRoleMap = adminRolesData;
            } else if (adminRolesData is List && adminRolesData.isNotEmpty) {
              // Si c'est une liste, prendre le premier élément
              final firstRole = adminRolesData.first;
              if (firstRole is Map<String, dynamic>) {
                adminRoleMap = firstRole;
              }
            }
          }
          
          if (adminRoleMap != null) {
            try {
              _currentRole = AdminRole.fromMap(adminRoleMap);
            } catch (roleParseError) {
              debugPrint('Error parsing admin role: $roleParseError');
              _currentRole = PredefinedAdminRoles.superAdmin;
            }
          } else {
            // Si aucun rôle n'est assigné, utiliser le rôle Super Admin par défaut
            try {
              final defaultRoleResponse = await Supabase.instance.client
                  .from('admin_roles')
                  .select()
                  .eq('name', 'Super Administrateur')
                  .maybeSingle();
              
              if (defaultRoleResponse != null && 
                  defaultRoleResponse['id'] != null) {
                try {
                  _currentRole = AdminRole.fromMap(defaultRoleResponse);
                  // Assigner le rôle par défaut à l'utilisateur
                  final roleId = defaultRoleResponse['id']?.toString();
                  if (roleId != null && roleId.isNotEmpty && _currentAdmin != null) {
                    await _assignDefaultRole(_currentAdmin!.id, roleId);
                  }
                } catch (defaultRoleError) {
                  debugPrint('Error parsing default role: $defaultRoleError');
                  _currentRole = PredefinedAdminRoles.superAdmin;
                }
              } else {
                // Fallback: utiliser les rôles prédéfinis
                _currentRole = PredefinedAdminRoles.superAdmin;
              }
            } catch (defaultRoleFetchError) {
              debugPrint('Error fetching default role: $defaultRoleFetchError');
              // Fallback: utiliser les rôles prédéfinis
              _currentRole = PredefinedAdminRoles.superAdmin;
            }
          }
          _isAuthenticated = true;
        } catch (roleError) {
          debugPrint('Error loading admin role: $roleError');
          // Fallback: utiliser les rôles prédéfinis si la table n'existe pas
          _currentRole = PredefinedAdminRoles.superAdmin;
          _isAuthenticated = true;
        }
      } else {
        // L'utilisateur n'est pas un admin
        _isAuthenticated = false;
        _currentRole = null;
      }
    } catch (e) {
      debugPrint('Error loading admin profile: $e');
      _currentAdmin = null;
      _currentRole = null;
      _isAuthenticated = false;
    }
  }

  /// Assigner le rôle par défaut à un utilisateur
  Future<void> _assignDefaultRole(String userId, String roleId) async {
    try {
      // Vérifier si le rôle est déjà assigné
      final existing = await Supabase.instance.client
          .from('user_admin_roles')
          .select()
          .eq('user_id', userId)
          .eq('role_id', roleId)
          .maybeSingle();
      
      if (existing == null) {
        // Insérer seulement si n'existe pas
        await Supabase.instance.client.from('user_admin_roles').insert({
          'user_id': userId,
          'role_id': roleId,
          'is_active': true,
        });
      }
    } catch (e) {
      debugPrint('Error assigning default role: $e');
      // Ignorer l'erreur si la table n'existe pas encore
    }
  }

  /// Connexion admin
  Future<bool> loginAdmin(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userId = response.user?.id;
      if (userId != null) {
        await _loadAdminProfile(userId);

        if (_isAuthenticated) {
          // Sauvegarder les préférences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('admin_email', email);
          await prefs.setBool('admin_remember', true);
          
          // Initialiser le timer d'inactivité
          _startInactivityTimer();
        }
      } else {
        debugPrint('Login failed: user is null');
        _isAuthenticated = false;
      }

      _isLoading = false;
      notifyListeners();
      return _isAuthenticated;
    } catch (e) {
      debugPrint('Error logging in admin: $e');
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  /// Déconnexion admin
  Future<void> logoutAdmin() async {
    try {
      _isLoading = true;
      notifyListeners();

      await Supabase.instance.client.auth.signOut();

      // Nettoyer les préférences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('admin_email');
      await prefs.remove('admin_remember');

      _currentAdmin = null;
      _currentRole = null;
      _isAuthenticated = false;

      // Arrêter le timer d'inactivité
      _stopInactivityTimer();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error logging out admin: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Vérifier les permissions
  bool hasPermission(AdminPermissionType permission) {
    if (_currentRole == null) return false;
    return _currentRole!.hasPermission(permission);
  }

  /// Vérifier l'accès à une ressource
  bool canAccess(String resource) {
    if (_currentRole == null) return false;
    return _currentRole!.canAccess(resource);
  }

  /// Créer un nouveau rôle admin
  Future<bool> createAdminRole(AdminRole role) async {
    try {
      _isLoading = true;
      notifyListeners();

      await Supabase.instance.client.from('admin_roles').insert(role.toMap());

      await _loadAvailableRoles();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error creating admin role: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Mettre à jour un rôle admin
  Future<bool> updateAdminRole(AdminRole role) async {
    try {
      _isLoading = true;
      notifyListeners();

      await Supabase.instance.client
          .from('admin_roles')
          .update(role.toMap())
          .eq('id', role.id);

      await _loadAvailableRoles();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating admin role: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Supprimer un rôle admin
  Future<bool> deleteAdminRole(String roleId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await Supabase.instance.client
          .from('admin_roles')
          .delete()
          .eq('id', roleId);

      await _loadAvailableRoles();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting admin role: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Assigner un rôle à un utilisateur
  Future<bool> assignRoleToUser(String userId, String roleId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await Supabase.instance.client.from('user_admin_roles').insert({
        'user_id': userId,
        'role_id': roleId,
        'assigned_at': DateTime.now().toIso8601String(),
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error assigning role to user: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Récupérer les utilisateurs avec leurs rôles
  Future<List<Map<String, dynamic>>> getUsersWithRoles() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('*, user_admin_roles(*, admin_roles(*))')
          .eq('role', 'admin');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting users with roles: $e');
      return [];
    }
  }

  /// Récupérer un utilisateur par ID
  Future<app_user.User?> getUserById(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint('User not found: $userId');
        return null;
      }

      try {
        return app_user.User.fromMap(response);
      } catch (parseError) {
        debugPrint('Error parsing user data: $parseError');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  /// Vérifier si l'email est déjà utilisé
  Future<bool> isEmailAvailable(String email) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      return response == null;
    } catch (e) {
      debugPrint('Error checking email availability: $e');
      return false;
    }
  }

  /// Créer un nouvel utilisateur admin
  Future<bool> createAdminUser({
    required String email,
    required String password,
    required String name,
    required String roleId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Créer l'utilisateur dans Supabase Auth
      final authResponse = await Supabase.instance.client.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: password,
          emailConfirm: true,
        ),
      );

      final userId = authResponse.user?.id;
      if (userId != null) {
        // Créer le profil utilisateur
        await Supabase.instance.client.from('users').insert({
          'id': userId,
          'auth_user_id': userId,
          'email': email,
          'name': name,
          'role': 'admin',
          'created_at': DateTime.now().toIso8601String(),
        });

        // Assigner le rôle
        // Note: Ici userId est à la fois l'ID auth et l'ID public car on l'a forcé
        await assignRoleToUser(userId, roleId);
      } else {
        debugPrint('Error creating admin user: auth user is null');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error creating admin user: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Mettre à jour le profil admin
  Future<bool> updateAdminProfile({
    required String name,
    String? phone,
    String? address,
  }) async {
    try {
      final currentAdminId = _currentAdmin?.id;
      if (currentAdminId == null) {
        debugPrint('Cannot update admin profile: no current admin');
        return false;
      }

      _isLoading = true;
      notifyListeners();

      await Supabase.instance.client.from('users').update({
        'name': name,
        'phone': phone,
        'address': address,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', currentAdminId);

      // Recharger le profil using auth user ID
      if (_currentAdmin != null) {
        await _loadAdminProfile(_currentAdmin!.authUserId);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating admin profile: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Changer le mot de passe
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      _isLoading = true;
      notifyListeners();

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error changing password: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Récupérer les préférences sauvegardées
  Future<Map<String, dynamic>?> getSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('admin_email');
      final remember = prefs.getBool('admin_remember') ?? false;

      if (email != null && remember) {
        return {'email': email, 'remember': remember};
      }
      return null;
    } catch (e) {
      debugPrint('Error getting saved preferences: $e');
      return null;
    }
  }

  /// Enregistrer une activité utilisateur (pour éviter la déconnexion automatique)
  void recordActivity() {
    if (!_isAuthenticated || !_autoLogoutEnabled) return;

    _lastActivity = DateTime.now();
    _resetInactivityTimer();
  }

  /// Configurer le timeout d'inactivité
  void setInactivityTimeout(Duration timeout) {
    _inactivityTimeout = timeout;
    _resetInactivityTimer();
  }

  /// Activer/désactiver la déconnexion automatique
  void setAutoLogoutEnabled(bool enabled) {
    _autoLogoutEnabled = enabled;
    if (enabled && _isAuthenticated) {
      _startInactivityTimer();
    } else {
      _stopInactivityTimer();
    }
    notifyListeners();
  }

  /// Démarrer le timer d'inactivité
  void _startInactivityTimer() {
    if (!_autoLogoutEnabled) return;

    _lastActivity = DateTime.now();
    _resetInactivityTimer();
  }

  /// Réinitialiser le timer d'inactivité
  void _resetInactivityTimer() {
    _stopInactivityTimer();

    if (!_isAuthenticated || !_autoLogoutEnabled) return;

    _inactivityTimer = Timer(_inactivityTimeout, () {
      debugPrint('AdminAuthService: Déconnexion automatique après inactivité');
      logoutAdmin();
    });
  }

  /// Arrêter le timer d'inactivité
  void _stopInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _lastActivity = null;
  }

  /// Vérifier si l'utilisateur est toujours actif
  bool isStillActive() {
    if (!_isAuthenticated || !_autoLogoutEnabled) return true;
    if (_lastActivity == null) return false;

    final elapsed = DateTime.now().difference(_lastActivity!);
    return elapsed < _inactivityTimeout;
  }

  @override
  void dispose() {
    _stopInactivityTimer();
    super.dispose();
  }
}
