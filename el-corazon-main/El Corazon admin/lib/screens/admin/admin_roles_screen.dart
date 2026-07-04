import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/dialog_helper.dart';
import '../../services/role_management_service.dart';
import '../../models/admin_role.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_widget.dart';
import '../../ui/ui.dart';

class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<AdminPermission> _selectedPermissions = [];
  bool _isCreating = false;
  AdminRole? _editingRole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RoleManagementService>().initialize();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pas d'AppBar ici car c'est un écran secondaire accessible via navigation
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Rôles Admin'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateRoleDialog,
            tooltip: 'Créer un nouveau rôle',
          ),
        ],
      ),
      body: Consumer<RoleManagementService>(
        builder: (context, roleService, child) {
          if (roleService.isLoading) {
            return const LoadingWidget(message: 'Chargement des rôles...');
          }

          final roles = roleService.roles;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: roles.length,
            itemBuilder: (context, index) {
              final role = roles[index];
              return _buildRoleCard(context, role);
            },
          );
        },
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, AdminRole role) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleRoleAction(value, role),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Modifier'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'permissions',
                      child: Row(
                        children: [
                          Icon(Icons.security, size: 20),
                          SizedBox(width: 8),
                          Text('Permissions'),
                        ],
                      ),
                    ),
                    if (role.id != 'super_admin')
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: scheme.error, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Supprimer',
                              style: TextStyle(color: scheme.error),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: role.isActive ? sem.success : sem.danger,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role.isActive ? 'Actif' : 'Inactif',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${role.permissions.length} permissions',
                  style: Theme.of(
                    context,
                  )
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: role.permissions.take(3).map((permission) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    permission.type.description,
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (role.permissions.length > 3)
              Text(
                '+${role.permissions.length - 3} autres...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                      fontStyle: FontStyle.italic,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleRoleAction(String action, AdminRole role) {
    switch (action) {
      case 'edit':
        _editRole(role);
        break;
      case 'permissions':
        _showPermissionsDialog(role);
        break;
      case 'delete':
        _deleteRole(role);
        break;
    }
  }

  void _showCreateRoleDialog() {
    _editingRole = null;
    _nameController.clear();
    _descriptionController.clear();
    _selectedPermissions.clear();

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => _buildRoleDialog(),
    );
  }

  void _editRole(AdminRole role) {
    _editingRole = role;
    _nameController.text = role.name;
    _descriptionController.text = role.description;
    _selectedPermissions = List.from(role.permissions);

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => _buildRoleDialog(),
    );
  }

  Widget _buildRoleDialog() {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(500.0, 900.0);
    final dialogHeight = (screenSize.height * 0.85).clamp(500.0, 900.0);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: dialogWidth,
          maxWidth: dialogWidth,
          minHeight: dialogHeight,
          maxHeight: dialogHeight,
        ),
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _editingRole == null
                            ? 'Créer un Rôle'
                            : 'Modifier le Rôle',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Contenu scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          label: 'Nom du rôle',
                          controller: _nameController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un nom';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'Description',
                          controller: _descriptionController,
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer une description';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildPermissionsList(),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CustomButton(
                      text: _editingRole == null ? 'Créer' : 'Modifier',
                      onPressed: _saveRole,
                      isLoading: _isCreating,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permissions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: AdminPermissionType.values.length,
            itemBuilder: (context, index) {
              final permissionType = AdminPermissionType.values[index];
              final isSelected = _selectedPermissions.any(
                (p) => p.type == permissionType,
              );

              return Container(
                constraints: const BoxConstraints(minHeight: 56),
                child: CheckboxListTile(
                  title: Text(permissionType.description),
                  subtitle: Text(_getPermissionCategory(permissionType)),
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedPermissions.add(
                          AdminPermission(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            type: permissionType,
                            resource: _getPermissionResource(permissionType),
                            action: _getPermissionAction(permissionType),
                            isGranted: true,
                          ),
                        );
                      } else {
                        _selectedPermissions.removeWhere(
                          (p) => p.type == permissionType,
                        );
                      }
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getPermissionCategory(AdminPermissionType type) {
    if (type.toString().contains('product')) return 'Gestion des produits';
    if (type.toString().contains('order')) return 'Gestion des commandes';
    if (type.toString().contains('driver')) return 'Gestion des livreurs';
    if (type.toString().contains('promotion')) return 'Gestion des promotions';
    if (type.toString().contains('analytics')) return 'Analytics';
    if (type.toString().contains('user')) return 'Gestion des utilisateurs';
    if (type.toString().contains('zone')) return 'Gestion des zones';
    if (type.toString().contains('notification')) return 'Notifications';
    if (type.toString().contains('settings')) return 'Paramètres';
    if (type.toString().contains('audit')) return 'Audit';
    return 'Autres';
  }

  String _getPermissionResource(AdminPermissionType type) {
    if (type.toString().contains('product')) return 'products';
    if (type.toString().contains('order')) return 'orders';
    if (type.toString().contains('driver')) return 'drivers';
    if (type.toString().contains('promotion')) return 'promotions';
    if (type.toString().contains('analytics')) return 'analytics';
    if (type.toString().contains('user')) return 'users';
    if (type.toString().contains('zone')) return 'zones';
    if (type.toString().contains('notification')) return 'notifications';
    if (type.toString().contains('settings')) return 'settings';
    return 'general';
  }

  String _getPermissionAction(AdminPermissionType type) {
    if (type.toString().contains('Create')) return 'create';
    if (type.toString().contains('Read')) return 'read';
    if (type.toString().contains('Update')) return 'update';
    if (type.toString().contains('Delete')) return 'delete';
    if (type.toString().contains('Send')) return 'send';
    if (type.toString().contains('Generate')) return 'generate';
    if (type.toString().contains('Assign')) return 'assign';
    return 'access';
  }

  Future<void> _saveRole() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    // Capturer les valeurs nécessaires avant le gap async
    final inverseSurfaceColor = Theme.of(context).colorScheme.inverseSurface;
    try {
      final roleService = context.read<RoleManagementService>();
      bool success;

      if (_editingRole == null) {
        final newRole = AdminRole(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text,
          description: _descriptionController.text,
          permissions: _selectedPermissions,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        success = await roleService.createRole(newRole);
      } else {
        final updatedRole = _editingRole!.copyWith(
          name: _nameController.text,
          description: _descriptionController.text,
          permissions: _selectedPermissions,
          updatedAt: DateTime.now(),
        );
        success = await roleService.updateRole(updatedRole);
      }

      if (success && mounted && context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingRole == null
                  ? 'Rôle créé avec succès'
                  : 'Rôle modifié avec succès',
            ),
            backgroundColor: inverseSurfaceColor,
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: inverseSurfaceColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _showPermissionsDialog(AdminRole role) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 700.0);
    final dialogHeight = (screenSize.height * 0.7).clamp(400.0, 700.0);

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: dialogWidth,
            maxWidth: dialogWidth,
            minHeight: dialogHeight,
            maxHeight: dialogHeight,
          ),
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Permissions - ${role.name}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Contenu scrollable
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: role.permissions.length,
                    itemBuilder: (context, index) {
                      final permission = role.permissions[index];
                      return Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: ListTile(
                          leading: Icon(
                            permission.isGranted
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: permission.isGranted
                                ? AdminColorTokens.semantic(
                                    Theme.of(context).colorScheme,
                                  ).success
                                : AdminColorTokens.semantic(
                                    Theme.of(context).colorScheme,
                                  ).danger,
                          ),
                          title: Text(permission.type.description),
                          subtitle: Text(
                            '${permission.resource} - ${permission.action}',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Fermer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteRole(AdminRole role) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le rôle'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer le rôle "${role.name}" ?',
        ),
        actions: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                // Capturer les valeurs nécessaires avant le gap async
                final inverseSurfaceColor =
                    Theme.of(context).colorScheme.inverseSurface;
                try {
                  final roleService = context.read<RoleManagementService>();
                  final success = await roleService.deleteRole(
                    role.id,
                  );

                  if (!mounted || !context.mounted) return;

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Rôle supprimé avec succès'),
                        backgroundColor: inverseSurfaceColor,
                      ),
                    );
                  }
                } catch (e) {
                  if (!mounted || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: inverseSurfaceColor,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Supprimer'),
            ),
          ),
        ],
      ),
    );
  }
}
