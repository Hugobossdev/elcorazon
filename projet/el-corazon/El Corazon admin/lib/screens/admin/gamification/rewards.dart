import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/gamification_service.dart';
import 'package:admin/utils/dialog_helper.dart';

/// Récompenses — l'onglet du back-office et son formulaire.
///
/// Extrait de `gamification_management_screen.dart`, qui rassemblait quatre
/// onglets et quatre formulaires en 1 744 lignes. Les classes étaient déjà
/// nommées : c'est le fichier qui était trop long, pas les widgets. Elles
/// perdent leur `_` pour pouvoir vivre chacune chez elle.

class RewardsTab extends StatelessWidget {
  final GamificationService gamificationService;

  const RewardsTab({required this.gamificationService, super.key});

  @override
  Widget build(BuildContext context) {
    final rewards = gamificationService.loyaltyRewards;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showRewardForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Créer une Récompense'),
          ),
        ),
        Expanded(
          child: rewards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.card_giftcard,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune récompense',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rewards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final reward = rewards[index];
                    return _buildRewardCard(context, reward);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRewardCard(BuildContext context, Map<String, dynamic> reward) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.15),
          child: const Icon(Icons.card_giftcard, color: Colors.green),
        ),
        title: Text(
          reward['title'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reward['description'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text('${reward['cost'] ?? 0} pts'),
                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(reward['reward_type'] ?? ''),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(
                    reward['is_active'] == true ? 'Actif' : 'Inactif',
                  ),
                  backgroundColor:
                      (reward['is_active'] == true ? Colors.green : Colors.grey)
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
                        _showRewardForm(context, reward: reward);
                      }
                    }),
              ),
              PopupMenuItem(
                child: Text(
                  reward['is_active'] == true ? 'Désactiver' : 'Activer',
                ),
                onTap: () {
                  gamificationService.updateLoyaltyReward(
                    reward['id'],
                    isActive: !((reward['is_active'] as bool?) ?? true),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRewardForm(BuildContext context, {Map<String, dynamic>? reward}) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => RewardFormDialog(reward: reward),
    );
  }

}

// =====================================================
// FORM DIALOGS
// =====================================================

class RewardFormDialog extends StatefulWidget {
  final Map<String, dynamic>? reward;

  const RewardFormDialog({this.reward, super.key});

  @override
  State<RewardFormDialog> createState() => RewardFormDialogState();
}

class RewardFormDialogState extends State<RewardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _costController = TextEditingController();
  final _valueController = TextEditingController();

  String _rewardType = 'discount';
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final r = widget.reward;
    if (r != null) {
      _titleController.text = r['title'] ?? '';
      _descController.text = r['description'] ?? '';
      _costController.text = (r['cost'] ?? 0).toString();
      _valueController.text = (r['discount'] ?? 0.0).toString();
      _rewardType = r['kind'] ?? 'discount';
      _isActive = r['is_active'] ?? true;
    } else {
      _costController.text = '0';
      _valueController.text = '0';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _costController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 650,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.reward == null
                          ? 'Créer une Récompense'
                          : 'Modifier une Récompense',
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
                              controller: _costController,
                              decoration: const InputDecoration(
                                labelText: 'Coût (points) *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  v == null || int.tryParse(v) == null
                                  ? 'Coût invalide'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _rewardType,
                              decoration: const InputDecoration(
                                labelText: 'Type de récompense *',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'discount',
                                  child: Text('Remise sur une commande'),
                                ),
                                DropdownMenuItem(
                                  value: 'free_delivery',
                                  child: Text('Livraison offerte'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _rewardType = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_rewardType == 'discount')
                        TextFormField(
                          controller: _valueController,
                          decoration: const InputDecoration(
                            labelText: 'Montant de la remise (FCFA) *',
                            helperText:
                                'Un montant, pas un pourcentage : le serveur '
                                'le manie comme une somme.',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final montant = double.tryParse(v ?? '');
                            if (montant == null || montant <= 0) {
                              return 'Une remise doit porter un montant';
                            }
                            return null;
                          },
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
                    child: Text(widget.reward == null ? 'Créer' : 'Modifier'),
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
      // Le serveur ne connaît que deux natures de récompense — une remise, ou
      // la livraison offerte. « Points » n'en était pas une : offrir des points
      // contre des points ne fait que déplacer un solde, et « article offert »
      // n'a jamais eu de champ pour désigner l'article.
      final montant = _rewardType == 'discount'
          ? double.tryParse(_valueController.text)
          : null;

      if (widget.reward == null) {
        service.createLoyaltyReward(
          name: _titleController.text.trim(),
          description: _descController.text.trim(),
          kind: _rewardType,
          pointsCost: int.parse(_costController.text),
          discount: montant,
        );
      } else {
        service.updateLoyaltyReward(
          widget.reward!['id'],
          name: _titleController.text.trim(),
          description: _descController.text.trim(),
          kind: _rewardType,
          pointsCost: int.parse(_costController.text),
          discount: montant,
          isActive: _isActive,
        );
      }
      Navigator.pop(context);
    }
  }
}
