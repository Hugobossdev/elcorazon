import 'package:elcora_fast/screens/client/social_feed_screen.dart';
import 'package:elcora_fast/services/social_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Groupes — `/social/groups/`.
///
/// Le backend de ce domaine existait depuis la Phase 4, testé et documenté,
/// mais aucune application ne l'appelait. Cet écran est la moitié qui manquait.
///
/// Le **code d'invitation est généré par le serveur** et affiché ici : le
/// laisser choisir à l'auteur du groupe permettrait de deviner celui d'un
/// autre, et un groupe privé cesserait de l'être.
class SocialGroupsScreen extends StatefulWidget {
  const SocialGroupsScreen({super.key});

  @override
  State<SocialGroupsScreen> createState() => _SocialGroupsScreenState();
}

class _SocialGroupsScreenState extends State<SocialGroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SocialService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes groupes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Rejoindre avec un code',
            onPressed: _rejoindre,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creer,
        icon: const Icon(Icons.add),
        label: const Text('Créer'),
      ),
      body: Consumer<SocialService>(
        builder: (context, service, child) {
          if (service.isLoading && service.groups.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.error != null && service.groups.isEmpty) {
            return _Message(
              icone: Icons.cloud_off_outlined,
              texte: service.error!,
              action: service.refreshGroups,
            );
          }

          if (service.groups.isEmpty) {
            return _Message(
              icone: Icons.groups_outlined,
              texte: 'Aucun groupe pour le moment.\n'
                  'Créez-en un, ou rejoignez celui d’un proche avec son code.',
              action: service.refreshGroups,
            );
          }

          return RefreshIndicator(
            onRefresh: service.refreshGroups,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: service.groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _carte(service, service.groups[index], scheme),
            ),
          );
        },
      ),
    );
  }

  Widget _carte(
    SocialService service,
    eccore.SocialGroup groupe,
    ColorScheme scheme,
  ) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(_icone(groupe.kind), color: scheme.onPrimaryContainer),
        ),
        title: Text(
          groupe.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${_libelle(groupe.kind)} · '
              '${groupe.memberCount}/${groupe.maxMembers} membres',
            ),
            if (groupe.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(groupe.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => switch (action) {
            'code' => _partagerCode(groupe),
            'quitter' => _quitter(service, groupe),
            _ => null,
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'code', child: Text('Code d’invitation')),
            PopupMenuItem(value: 'quitter', child: Text('Quitter le groupe')),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SocialFeedScreen(group: groupe),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- actions

  Future<void> _creer() async {
    final nom = TextEditingController();
    final description = TextEditingController();
    var nature = eccore.GroupKind.friends;
    var prive = true;
    final formKey = GlobalKey<FormState>();

    final valide = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouveau groupe'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nom,
                    decoration: const InputDecoration(labelText: 'Nom *'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Le nom est requis'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: nature,
                    decoration: const InputDecoration(labelText: 'Nature'),
                    items: [
                      for (final valeur in eccore.GroupKind.values)
                        DropdownMenuItem(
                          value: valeur,
                          child: Text(_libelle(valeur)),
                        ),
                    ],
                    onChanged: (v) => setDialogState(() {
                      if (v != null) nature = v;
                    }),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Groupe privé'),
                    subtitle: const Text('On n’y entre qu’avec le code'),
                    value: prive,
                    onChanged: (v) => setDialogState(() => prive = v),
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
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );

    if (valide != true || !mounted) return;

    final service = context.read<SocialService>();
    final messager = ScaffoldMessenger.of(context);
    final groupe = await service.createGroup(
      name: nom.text.trim(),
      kind: nature,
      description: description.text.trim(),
      isPrivate: prive,
    );

    nom.dispose();
    description.dispose();

    if (!mounted) return;
    messager.showSnackBar(
      SnackBar(
        content: Text(
          groupe != null
              ? 'Groupe créé — code d’invitation : ${groupe.inviteCode}'
              : service.error ?? 'Création refusée',
        ),
      ),
    );
  }

  Future<void> _rejoindre() async {
    final code = TextEditingController();

    final valide = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejoindre un groupe'),
        content: TextField(
          controller: code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Code d’invitation',
            hintText: 'Ex. A1B2C3',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );

    if (valide != true || !mounted) return;

    final service = context.read<SocialService>();
    final messager = ScaffoldMessenger.of(context);
    final ok = await service.joinGroup(code.text);
    code.dispose();

    if (!mounted) return;
    messager.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Groupe rejoint' : service.error ?? 'Code refusé'),
      ),
    );
  }

  Future<void> _partagerCode(eccore.SocialGroup groupe) async {
    await Clipboard.setData(ClipboardData(text: groupe.inviteCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Code copié : ${groupe.inviteCode}')),
    );
  }

  Future<void> _quitter(
    SocialService service,
    eccore.SocialGroup groupe,
  ) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quitter ${groupe.name} ?'),
        content: const Text(
          'Vous ne verrez plus les publications de ce groupe. Le rejoindre à '
          'nouveau demandera son code d’invitation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirme != true || !mounted) return;

    final messager = ScaffoldMessenger.of(context);
    final ok = await service.leaveGroup(groupe.id);

    if (!mounted) return;
    messager.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Groupe quitté' : service.error ?? 'Sortie refusée'),
      ),
    );
  }

  // -------------------------------------------------------------- libellés

  static String _libelle(String nature) => switch (nature) {
    eccore.GroupKind.family => 'Famille',
    eccore.GroupKind.friends => 'Amis',
    eccore.GroupKind.work => 'Travail',
    eccore.GroupKind.neighborhood => 'Quartier',
    eccore.GroupKind.custom => 'Personnalisé',
    _ => nature,
  };

  static IconData _icone(String nature) => switch (nature) {
    eccore.GroupKind.family => Icons.family_restroom,
    eccore.GroupKind.friends => Icons.people_outline,
    eccore.GroupKind.work => Icons.work_outline,
    eccore.GroupKind.neighborhood => Icons.location_city_outlined,
    _ => Icons.groups_outlined,
  };
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icone,
    required this.texte,
    required this.action,
  });

  final IconData icone;
  final String texte;
  final Future<void> Function() action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56, color: scheme.outline),
            const SizedBox(height: 14),
            Text(texte, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => action(),
              child: const Text('Recharger'),
            ),
          ],
        ),
      ),
    );
  }
}
