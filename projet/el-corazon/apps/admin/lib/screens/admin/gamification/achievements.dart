import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/gamification_service.dart';
import 'package:admin/utils/dialog_helper.dart';

/// Succès — l'onglet du back-office et son formulaire.
///
/// Extrait de `gamification_management_screen.dart`, qui rassemblait quatre
/// onglets et quatre formulaires en 1 744 lignes. Les classes étaient déjà
/// nommées : c'est le fichier qui était trop long, pas les widgets. Elles
/// perdent leur `_` pour pouvoir vivre chacune chez elle.

class AchievementsTab extends StatelessWidget {
  final GamificationService gamificationService;

  const AchievementsTab({required this.gamificationService, super.key});

  @override
  Widget build(BuildContext context) {
    final achievements = gamificationService.achievements;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAchievementForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Créer un Achievement'),
          ),
        ),
        Expanded(
          child: achievements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun achievement',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: achievements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final achievement = achievements[index];
                    return _buildAchievementCard(context, achievement);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(
    BuildContext context,
    Map<String, dynamic> achievement,
  ) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.amber.withValues(alpha: 0.15),
          child: Text(
            achievement['icon'] ?? '🏆',
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          achievement['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(achievement['description'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text('${achievement['points_reward'] ?? 0} pts'),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(achievement['condition_type'] ?? ''),
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(
                    achievement['is_active'] == true ? 'Actif' : 'Inactif',
                  ),
                  backgroundColor:
                      (achievement['is_active'] == true
                              ? Colors.green
                              : Colors.grey)
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
                        _showAchievementForm(context, achievement: achievement);
                      }
                    }),
              ),
              PopupMenuItem(
                child: Text(
                  achievement['is_active'] == true ? 'Désactiver' : 'Activer',
                ),
                onTap: () {
                  gamificationService.updateAchievement(
                    achievement['id'],
                    isActive: !((achievement['is_active'] as bool?) ?? true),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAchievementForm(
    BuildContext context, {
    Map<String, dynamic>? achievement,
  }) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AchievementFormDialog(achievement: achievement),
    );
  }

}

// =====================================================
// CHALLENGES TAB
// =====================================================

class AchievementFormDialog extends StatefulWidget {
  final Map<String, dynamic>? achievement;

  const AchievementFormDialog({this.achievement, super.key});

  @override
  State<AchievementFormDialog> createState() => AchievementFormDialogState();
}

class AchievementFormDialogState extends State<AchievementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _iconController = TextEditingController();
  final _pointsController = TextEditingController();
  final _conditionValueController = TextEditingController();
  final _badgeRewardController = TextEditingController();

  String _conditionType = 'orders_count';
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final a = widget.achievement;
    if (a != null) {
      _nameController.text = a['name'] ?? '';
      _descController.text = a['description'] ?? '';
      _iconController.text = a['icon'] ?? '🏆';
      _pointsController.text = (a['points_reward'] ?? 0).toString();
      _conditionValueController.text = (a['condition_value'] ?? 0).toString();
      _badgeRewardController.text = a['badge_reward'] ?? '';
      _conditionType = a['condition_type'] ?? 'orders_count';
      _isActive = a['is_active'] ?? true;
    } else {
      _iconController.text = '🏆';
      _pointsController.text = '0';
      _conditionValueController.text = '1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _iconController.dispose();
    _pointsController.dispose();
    _conditionValueController.dispose();
    _badgeRewardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 700,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.achievement == null
                          ? 'Créer un Achievement'
                          : 'Modifier un Achievement',
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
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Nom requis' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Description requise'
                            : null,
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
                                hintText: '🏆',
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Icône requise'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _pointsController,
                              decoration: const InputDecoration(
                                labelText: 'Points de récompense *',
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
                        initialValue: _conditionType,
                        decoration: const InputDecoration(
                          labelText: 'Type de condition *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'orders_count',
                            child: Text('Nombre de commandes'),
                          ),
                          DropdownMenuItem(
                            value: 'total_spent',
                            child: Text('Total dépensé'),
                          ),
                          DropdownMenuItem(
                            value: 'streak_days',
                            child: Text('Jours consécutifs'),
                          ),
                          DropdownMenuItem(
                            value: 'category_orders',
                            child: Text('Commandes par catégorie'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _conditionType = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _conditionValueController,
                        decoration: const InputDecoration(
                          labelText: 'Valeur de condition *',
                          border: OutlineInputBorder(),
                          hintText: 'Ex: 10 pour 10 commandes',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || int.tryParse(v) == null
                            ? 'Valeur invalide'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _badgeRewardController,
                        decoration: const InputDecoration(
                          labelText: 'Badge de récompense (optionnel)',
                          border: OutlineInputBorder(),
                          hintText: 'ID du badge',
                        ),
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
                    child: Text(
                      widget.achievement == null ? 'Créer' : 'Modifier',
                    ),
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
      if (widget.achievement == null) {
        service.createAchievement(
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          icon: _iconController.text.trim(),
          pointsReward: int.parse(_pointsController.text),
          conditionType: _conditionType,
          conditionValue: int.parse(_conditionValueController.text),
        );
      } else {
        service.updateAchievement(
          widget.achievement!['id'],
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          icon: _iconController.text.trim(),
          pointsReward: int.parse(_pointsController.text),
          conditionType: _conditionType,
          conditionValue: int.parse(_conditionValueController.text),
          isActive: _isActive,
        );
      }
      Navigator.pop(context);
    }
  }
}
