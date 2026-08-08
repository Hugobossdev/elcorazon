import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/gamification_service.dart';
import 'package:admin/utils/dialog_helper.dart';

/// Badges — l'onglet du back-office et son formulaire.
///
/// Extrait de `gamification_management_screen.dart`, qui rassemblait quatre
/// onglets et quatre formulaires en 1 744 lignes. Les classes étaient déjà
/// nommées : c'est le fichier qui était trop long, pas les widgets. Elles
/// perdent leur `_` pour pouvoir vivre chacune chez elle.

class BadgesTab extends StatelessWidget {
  final GamificationService gamificationService;

  const BadgesTab({required this.gamificationService, super.key});

  @override
  Widget build(BuildContext context) {
    final badges = gamificationService.badges;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showBadgeForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Créer un Badge'),
          ),
        ),
        Expanded(
          child: badges.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun badge',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: badges.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final badge = badges[index];
                    return _buildBadgeCard(context, badge);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(BuildContext context, Map<String, dynamic> badge) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.withValues(alpha: 0.15),
          child: Text(
            badge['icon'] ?? '🏅',
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          badge['title'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(badge['description'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text('${badge['points_required'] ?? 0} pts requis'),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(badge['is_active'] == true ? 'Actif' : 'Inactif'),
                  backgroundColor:
                      (badge['is_active'] == true ? Colors.green : Colors.grey)
                          .withValues(alpha: 0.1),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Modifier'),
                onTap: () =>
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted) {
                        _showBadgeForm(context, badge: badge);
                      }
                    }),
              ),
              PopupMenuItem(
                child: Text(
                  badge['is_active'] == true ? 'Désactiver' : 'Activer',
                ),
                onTap: () {
                  gamificationService.updateBadge(
                    badge['id'],
                    isActive: !((badge['is_active'] as bool?) ?? true),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBadgeForm(BuildContext context, {Map<String, dynamic>? badge}) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => BadgeFormDialog(badge: badge),
    );
  }

}

// =====================================================
// REWARDS TAB
// =====================================================

class BadgeFormDialog extends StatefulWidget {
  final Map<String, dynamic>? badge;

  const BadgeFormDialog({this.badge, super.key});

  @override
  State<BadgeFormDialog> createState() => BadgeFormDialogState();
}

class BadgeFormDialogState extends State<BadgeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _iconController = TextEditingController();
  final _pointsRequiredController = TextEditingController();

  String _criteria = 'points';
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final b = widget.badge;
    if (b != null) {
      _titleController.text = b['title'] ?? '';
      _descController.text = b['description'] ?? '';
      _iconController.text = b['icon'] ?? '🏅';
      _pointsRequiredController.text = (b['points_required'] ?? 0).toString();
      _criteria = b['criteria'] ?? 'points';
      _isActive = b['is_active'] ?? true;
    } else {
      _iconController.text = '🏅';
      _pointsRequiredController.text = '0';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _iconController.dispose();
    _pointsRequiredController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 600,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.badge == null
                          ? 'Créer un Badge'
                          : 'Modifier un Badge',
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
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titre *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Titre requis' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _iconController,
                              decoration: const InputDecoration(
                                labelText: 'Icône (emoji) *',
                                border: OutlineInputBorder(),
                                hintText: '🏅',
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Icône requise'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _pointsRequiredController,
                              decoration: const InputDecoration(
                                labelText: 'Points requis *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  v == null || int.tryParse(v) == null
                                  ? 'Points invalides'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _criteria,
                        decoration: const InputDecoration(
                          labelText: 'Critère *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'points',
                            child: Text('Points'),
                          ),
                          DropdownMenuItem(
                            value: 'orders',
                            child: Text('Commandes'),
                          ),
                          DropdownMenuItem(
                            value: 'spending',
                            child: Text('Dépenses'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _criteria = v!),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Actif'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(widget.badge == null ? 'Créer' : 'Modifier'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final service = context.read<GamificationService>();
      if (widget.badge == null) {
        service.createBadge(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          icon: _iconController.text.trim(),
          pointsRequired: int.parse(_pointsRequiredController.text),
        );
      } else {
        service.updateBadge(
          widget.badge!['id'],
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          icon: _iconController.text.trim(),
          pointsRequired: int.parse(_pointsRequiredController.text),
          isActive: _isActive,
        );
      }
      Navigator.pop(context);
    }
  }
}
