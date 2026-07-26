// import 'package:flutter/material.dart'; // Non utilisé
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Modèle pour les rôles administrateur
class AdminRole {
  final String id;
  final String name;
  final String description;
  final List<AdminPermission> permissions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminRole({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminRole.fromMap(Map<String, dynamic> map) {
    // Gérer les permissions qui peuvent être stockées en JSONB
    List<AdminPermission> permissionsList = [];
    
    try {
      if (map['permissions'] != null) {
        if (map['permissions'] is List) {
          final permList = map['permissions'] as List;
          
          // Vérifier si les éléments sont des strings simples ou des Maps
          if (permList.isNotEmpty) {
            if (permList.first is String) {
              // Cas simple: permissions stockées comme ["all"], ["orders", "menu"]
              permissionsList = permList.map((p) {
                final permString = p.toString();
                return AdminPermission(
                  id: permString,
                  type: _getPermissionTypeFromString(permString),
                  resource: permString,
                  action: 'access',
                  isGranted: true,
                  description: permString,
                );
              }).toList();
            } else if (permList.first is Map) {
              // Cas complexe: permissions stockées comme objets
              permissionsList = permList
                  .map((p) => AdminPermission.fromMap(
                      p is Map<String, dynamic> ? p : Map<String, dynamic>.from(p)))
                  .toList();
            }
          }
        } else if (map['permissions'] is String) {
          // Si c'est une chaîne JSON, la parser
          try {
            final decoded = jsonDecode(map['permissions']) as List;
            if (decoded.isNotEmpty && decoded.first is String) {
              // Strings simples
              permissionsList = decoded.map((p) {
                final permString = p.toString();
                return AdminPermission(
                  id: permString,
                  type: _getPermissionTypeFromString(permString),
                  resource: permString,
                  action: 'access',
                  isGranted: true,
                  description: permString,
                );
              }).toList();
            } else {
              // Objects complexes
              permissionsList = decoded
                  .cast<Map<String, dynamic>>()
                  .map((p) => AdminPermission.fromMap(p))
                  .toList();
            }
          } catch (e) {
            debugPrint('Error parsing permissions JSON: $e');
            permissionsList = [];
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing role data: $e, data: $map');
      permissionsList = [];
    }
    
    // Gérer l'ID - doit être non null
    final id = map['id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('AdminRole.fromMap: id is required but was null or empty');
    }
    
    // Gérer le nom - doit être non null
    final name = map['name']?.toString();
    if (name == null || name.isEmpty) {
      throw Exception('AdminRole.fromMap: name is required but was null or empty');
    }
    
    // Gérer les dates avec gestion d'erreur robuste
    DateTime parseDateTime(dynamic dateValue, DateTime defaultValue) {
      if (dateValue == null) return defaultValue;
      
      try {
        if (dateValue is DateTime) {
          return dateValue;
        } else if (dateValue is String) {
          return DateTime.parse(dateValue);
        } else {
          // Essayer de convertir en string puis parser
          return DateTime.parse(dateValue.toString());
        }
      } catch (e) {
        debugPrint('Error parsing date: $e, value: $dateValue');
        return defaultValue;
      }
    }
    
    // Gérer les booléens avec gestion d'erreur robuste
    bool parseBoolean(dynamic boolValue, bool defaultValue) {
      if (boolValue == null) return defaultValue;
      
      if (boolValue is bool) {
        return boolValue;
      } else if (boolValue is String) {
        return boolValue.toLowerCase() == 'true' || boolValue == '1';
      } else if (boolValue is int) {
        return boolValue != 0;
      } else {
        return defaultValue;
      }
    }
    
    final now = DateTime.now();
    
    return AdminRole(
      id: id,
      name: name,
      description: map['description']?.toString() ?? '',
      permissions: permissionsList,
      isActive: parseBoolean(map['is_active'], true),
      createdAt: parseDateTime(map['created_at'], now),
      updatedAt: parseDateTime(map['updated_at'], now),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'permissions': permissions.map((p) => p.toMap()).toList(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AdminRole copyWith({
    String? id,
    String? name,
    String? description,
    List<AdminPermission>? permissions,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminRole(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool hasPermission(AdminPermissionType permission) {
    return permissions.any((p) => p.type == permission && p.isGranted);
  }

  bool canAccess(String resource) {
    return permissions.any((p) => p.resource == resource && p.isGranted);
  }

  /// Convertit une string de permission en AdminPermissionType
  static AdminPermissionType _getPermissionTypeFromString(String permString) {
    // Mapping simple des permissions string vers les types
    final permLower = permString.toLowerCase();
    
    if (permLower == 'all' || permLower == 'superadmin') {
      return AdminPermissionType.superAdmin;
    }
    
    // Mapping basé sur les ressources courantes
    switch (permLower) {
      case 'orders':
        return AdminPermissionType.orderRead;
      case 'menu':
      case 'products':
        return AdminPermissionType.productRead;
      case 'deliveries':
      case 'drivers':
        return AdminPermissionType.driverRead;
      case 'users':
        return AdminPermissionType.userRead;
      case 'reports':
        return AdminPermissionType.reportsGenerate;
      case 'analytics':
        return AdminPermissionType.analyticsRead;
      case 'promotions':
        return AdminPermissionType.promotionRead;
      case 'marketing':
      case 'campaigns':
        return AdminPermissionType.marketingCampaignRead;
      case 'settings':
        return AdminPermissionType.settingsRead;
      default:
        return AdminPermissionType.productRead;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminRole &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, description, isActive, createdAt, updatedAt);
  }
}

/// Modèle pour les permissions administrateur
class AdminPermission {
  final String id;
  final AdminPermissionType type;
  final String resource;
  final String action;
  final bool isGranted;
  final String? description;

  const AdminPermission({
    required this.id,
    required this.type,
    required this.resource,
    required this.action,
    this.isGranted = true,
    this.description,
  });

  factory AdminPermission.fromMap(Map<String, dynamic> map) {
    // Gérer le type de permission
    AdminPermissionType permissionType = AdminPermissionType.productRead;
    
    if (map['type'] != null) {
      final typeString = map['type'].toString();
      try {
        // Essayer de trouver le type correspondant
        permissionType = AdminPermissionType.values.firstWhere(
          (e) => e.toString().split('.').last == typeString ||
                e.name == typeString ||
                e.toString() == typeString,
          orElse: () => AdminPermissionType.productRead,
        );
      } catch (e) {
        permissionType = AdminPermissionType.productRead;
      }
    }
    
    return AdminPermission(
      id: map['id']?.toString() ?? '',
      type: permissionType,
      resource: map['resource']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      isGranted: map['is_granted'] ?? true,
      description: map['description']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name, // Use simple name instead of toString()
      'resource': resource,
      'action': action,
      'is_granted': isGranted,
      'description': description,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminPermission &&
        other.id == id &&
        other.type == type &&
        other.resource == resource &&
        other.action == action &&
        other.isGranted == isGranted &&
        other.description == description;
  }

  @override
  int get hashCode {
    return Object.hash(id, type, resource, action, isGranted, description);
  }
}

/// Types de permissions
enum AdminPermissionType {
  // Gestion des produits
  productCreate('Créer des produits'),
  productRead('Lire les produits'),
  productUpdate('Modifier les produits'),
  productDelete('Supprimer les produits'),

  // Gestion des commandes
  orderRead('Lire les commandes'),
  orderUpdate('Modifier les commandes'),
  orderCancel('Annuler les commandes'),
  orderRefund('Rembourser les commandes'),

  // Gestion des livreurs
  driverCreate('Créer des livreurs'),
  driverRead('Lire les livreurs'),
  driverUpdate('Modifier les livreurs'),
  driverDelete('Supprimer les livreurs'),
  driverAssign('Assigner des livraisons'),

  // Gestion des promotions
  promotionCreate('Créer des promotions'),
  promotionRead('Lire les promotions'),
  promotionUpdate('Modifier les promotions'),
  promotionDelete('Supprimer les promotions'),

  // Analytics et rapports
  analyticsRead('Lire les analytics'),
  reportsGenerate('Générer des rapports'),

  // Gestion des utilisateurs
  userRead('Lire les utilisateurs'),
  userUpdate('Modifier les utilisateurs'),
  userDelete('Supprimer les utilisateurs'),

  // Gestion des zones
  zoneCreate('Créer des zones'),
  zoneRead('Lire les zones'),
  zoneUpdate('Modifier les zones'),
  zoneDelete('Supprimer les zones'),

  // Notifications
  notificationSend('Envoyer des notifications'),
  notificationRead('Lire les notifications'),

  // Paramètres
  settingsRead('Lire les paramètres'),
  settingsUpdate('Modifier les paramètres'),

  // Audit et logs
  auditRead('Lire les logs d\'audit'),

  // Marketing
  marketingCampaignCreate('Créer des campagnes'),
  marketingCampaignRead('Lire les campagnes'),
  marketingCampaignUpdate('Modifier les campagnes'),
  marketingCampaignDelete('Supprimer les campagnes'),

  // Super admin
  superAdmin('Accès super administrateur');

  const AdminPermissionType(this.description);

  final String description;
}

/// Rôles prédéfinis
class PredefinedAdminRoles {
  static AdminRole get superAdmin => AdminRole(
        id: 'super_admin',
        name: 'Super Administrateur',
        description: 'Accès complet au système',
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
      );

  static AdminRole get manager => AdminRole(
        id: 'manager',
        name: 'Manager',
        description: 'Gestion des opérations quotidiennes',
        permissions: [
          // Produits
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
          // Commandes
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
          // Analytics
          const AdminPermission(
            id: 'manager_analytics',
            type: AdminPermissionType.analyticsRead,
            resource: 'analytics',
            action: 'read',
            isGranted: true,
          ),
          // Rapports
          const AdminPermission(
            id: 'manager_reports',
            type: AdminPermissionType.reportsGenerate,
            resource: 'reports',
            action: 'generate',
            isGranted: true,
          ),
          // Marketing
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
          const AdminPermission(
            id: 'manager_marketing_update',
            type: AdminPermissionType.marketingCampaignUpdate,
            resource: 'marketing',
            action: 'update',
            isGranted: true,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  static AdminRole get operator => AdminRole(
        id: 'operator',
        name: 'Opérateur',
        description: 'Gestion des commandes et livreurs',
        permissions: [
          // Commandes
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
          // Livreurs
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
      );
}
