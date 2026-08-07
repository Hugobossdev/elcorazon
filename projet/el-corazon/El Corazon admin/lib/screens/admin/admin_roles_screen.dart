import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/role_management_service.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/widgets/loading_widget.dart';

/// Rôles & permissions — composés à partir du **registre du serveur**.
///
/// L'écran précédent cochait des booléens d'une table locale
/// (`manage_marketing`, `manage_settings`) qui n'existaient que là : le serveur
/// ne les lisait pas, et un rôle privé d'un module voyait seulement l'onglet
/// disparaître. Ici, chaque case correspond à une permission que le serveur
/// exige réellement (`orders.refund`, `catalog.write`…), et la liste vient de
/// lui — elle ne se recopie plus.
///
/// Deux gestes ont disparu, parce que le serveur les refuse et qu'il a raison :
/// modifier un rôle système (retirer « Super Admin » enfermerait tout le monde
/// dehors) et supprimer un rôle (les comptes qui le portent perdraient leurs
/// droits sans préavis).
class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RoleManagementService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rôles & permissions'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<RoleManagementService>().refresh(),
            tooltip: 'Recharger',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _ouvrirFormulaire(null),
            tooltip: 'Créer un rôle',
          ),
        ],
      ),
      body: Consumer<RoleManagementService>(
        builder: (context, service, child) {
          if (service.isLoading && service.roles.isEmpty) {
            return const LoadingWidget(message: 'Chargement des rôles...');
          }

          if (service.error != null && service.roles.isEmpty) {
            return _Message(
              icone: Icons.lock_outline,
              texte: service.error!,
              action: service.refresh,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final role in service.roles) _carteRole(role, service),
              const SizedBox(height: 24),
              _sectionPersonnel(service),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------- les rôles

  Widget _carteRole(eccore.AdminRole role, RoleManagementService service) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          role.isSystem ? Icons.shield : Icons.badge_outlined,
          color: role.isSystem ? scheme.tertiary : scheme.primary,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                role.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (role.isSystem) ...[
              const SizedBox(width: 8),
              Chip(
                label: const Text('Système'),
                visualDensity: VisualDensity.compact,
                backgroundColor: scheme.tertiaryContainer,
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          role.description.isEmpty
              ? '${role.permissions.length} permissions'
              : '${role.description} · ${role.permissions.length} permissions',
        ),
        trailing: role.isSystem
            ? Tooltip(
                message:
                    "Rôle fourni à l'installation : il ne se modifie pas.\n"
                    'Créez-en un sur mesure et attribuez-le.',
                child: Icon(Icons.lock_outline, color: scheme.outline),
              )
            : IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _ouvrirFormulaire(role),
                tooltip: 'Modifier',
              ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: role.permissions.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Aucune permission : ce rôle n'accorde rien.",
                      style: TextStyle(color: scheme.outline),
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final code in role.permissions)
                        Tooltip(
                          // Le libellé vient du registre du serveur : l'écran
                          // ne le devine pas à partir du code.
                          message: _libelle(service, code) ?? code,
                          child: Chip(
                            label: Text(
                              code,
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String? _libelle(RoleManagementService service, String code) {
    for (final entree in service.registry) {
      if (entree.code == code) return entree.description;
    }
    return null;
  }

  // ------------------------------------------------------------- personnel

  Widget _sectionPersonnel(RoleManagementService service) {
    if (service.staff.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Personnel',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final membre in service.staff)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  membre.fullName.isEmpty
                      ? '?'
                      : membre.fullName.characters.first.toUpperCase(),
                ),
              ),
              title: Text(membre.fullName),
              subtitle: Text(
                membre.roleIds.isEmpty
                    ? 'Aucun rôle · ${membre.email}'
                    : '${membre.roleIds.map((id) => service.roleById(id)?.name ?? '—').join(', ')} · ${membre.email}',
              ),
              trailing: Switch(
                value: membre.isActive,
                onChanged: (actif) => _basculerCompte(service, membre, actif),
              ),
              onTap: () => _attribuerRoles(service, membre),
            ),
          ),
      ],
    );
  }

  Future<void> _basculerCompte(
    RoleManagementService service,
    eccore.StaffMember membre,
    bool actif,
  ) async {
    final messager = ScaffoldMessenger.of(context);
    final ok = await service.setStaffActive(
      staffId: membre.id,
      isActive: actif,
    );

    if (!mounted) return;
    messager.showSnackBar(
      SnackBar(
        content: Text(
          ok
              // La révocation est faite par le serveur dans la même requête :
              // sans elle, un compte fermé travaillerait jusqu'à l'expiration
              // de son jeton d'accès.
              ? (actif
                    ? '${membre.fullName} peut de nouveau se connecter'
                    : '${membre.fullName} est désactivé, ses sessions sont fermées')
              : service.error ?? 'Opération refusée',
        ),
      ),
    );
  }

  Future<void> _attribuerRoles(
    RoleManagementService service,
    eccore.StaffMember membre,
  ) async {
    final selection = {...membre.roleIds};

    final valide = await DialogHelper.showSafeDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Rôles de ${membre.fullName}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final role in service.roles)
                    CheckboxListTile(
                      dense: true,
                      title: Text(role.name),
                      subtitle: Text('${role.permissions.length} permissions'),
                      value: selection.contains(role.id),
                      onChanged: (coche) => setDialogState(() {
                        if (coche ?? false) {
                          selection.add(role.id);
                        } else {
                          selection.remove(role.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (valide != true || !mounted) return;

    final messager = ScaffoldMessenger.of(context);
    final ok = await service.assignRoles(
      staffId: membre.id,
      roleIds: selection.toList(),
    );

    if (!mounted) return;
    messager.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Rôles mis à jour' : service.error ?? 'Attribution refusée',
        ),
      ),
    );
  }

  // ------------------------------------------------------------ formulaire

  Future<void> _ouvrirFormulaire(eccore.AdminRole? role) async {
    final service = context.read<RoleManagementService>();
    final nom = TextEditingController(text: role?.name ?? '');
    final description = TextEditingController(text: role?.description ?? '');
    final selection = {...?role?.permissions};
    final formKey = GlobalKey<FormState>();

    final valide = await DialogHelper.showSafeDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(role == null ? 'Nouveau rôle' : 'Modifier ${role.name}'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nom,
                      decoration: const InputDecoration(
                        labelText: 'Nom du rôle *',
                        hintText: 'Ex. Responsable de nuit',
                      ),
                      validator: (valeur) =>
                          (valeur == null || valeur.trim().isEmpty)
                          ? 'Le nom est requis'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Permissions',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Registre du serveur — chaque case correspond à un droit '
                      'que l’API exige réellement.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    for (final entree in service.registryByDomain.entries)
                      _blocDomaine(entree, selection, setDialogState),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              child: Text(role == null ? 'Créer' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (valide != true || !mounted) return;

    final messager = ScaffoldMessenger.of(context);
    final permissions = selection.toList()..sort();
    final ok = role == null
        ? await service.createRole(
            name: nom.text.trim(),
            description: description.text.trim(),
            permissions: permissions,
          )
        : await service.updateRole(
            roleId: role.id,
            name: nom.text.trim(),
            description: description.text.trim(),
            permissions: permissions,
          );

    nom.dispose();
    description.dispose();

    if (!mounted) return;
    messager.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (role == null ? 'Rôle créé' : 'Rôle mis à jour')
              : service.error ?? 'Opération refusée',
        ),
      ),
    );
  }

  Widget _blocDomaine(
    MapEntry<String, List<eccore.PermissionEntry>> domaine,
    Set<String> selection,
    void Function(void Function()) setDialogState,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            domaine.key,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          for (final entree in domaine.value)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(entree.description),
              subtitle: Text(
                entree.code,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              value: selection.contains(entree.code),
              onChanged: (coche) => setDialogState(() {
                if (coche ?? false) {
                  selection.add(entree.code);
                } else {
                  selection.remove(entree.code);
                }
              }),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icone,
    required this.texte,
    required this.action,
  });

  final IconData icone;
  final String texte;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(texte, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: action, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
