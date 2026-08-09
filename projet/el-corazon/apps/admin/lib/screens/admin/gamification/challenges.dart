import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/gamification_service.dart';
import 'package:admin/utils/dialog_helper.dart';

/// Défis — l'onglet du back-office et son formulaire.
///
/// Extrait de `gamification_management_screen.dart`, qui rassemblait quatre
/// onglets et quatre formulaires en 1 744 lignes. Les classes étaient déjà
/// nommées : c'est le fichier qui était trop long, pas les widgets. Elles
/// perdent leur `_` pour pouvoir vivre chacune chez elle.

/// Un défi est-il passé ?
///
/// La règle vivait dans le corps de la carte, et elle avait un accident :
/// faute de `end_date` elle prenait `DateTime.now()` comme date de fin, puis
/// la comparait à un second `DateTime.now()` pris quelques microsecondes plus
/// tard. Le premier étant antérieur au second, un défi **sans date de fin**
/// s'affichait expiré. Personne n'a décidé cela ; c'est une course entre deux
/// appels à l'horloge.
///
/// Un défi sans date de fin n'expire pas — c'est la seule lecture que le code
/// pouvait vouloir dire.
bool defiExpire(Map<String, dynamic> defi, {DateTime? maintenant}) {
  final fin = dateDeFinDefi(defi);
  if (fin == null) return false;

  return fin.isBefore(maintenant ?? DateTime.now());
}

/// La date de fin d'un défi, ou `null` s'il n'en a pas.
DateTime? dateDeFinDefi(Map<String, dynamic> defi) {
  final brut = defi['end_date'];
  if (brut == null) return null;

  return DateTime.tryParse(brut.toString());
}

class ChallengesTab extends StatelessWidget {
  final GamificationService gamificationService;

  const ChallengesTab({required this.gamificationService, super.key});

  @override
  Widget build(BuildContext context) {
    final challenges = gamificationService.challenges;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showChallengeForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Créer un Challenge'),
          ),
        ),
        Expanded(
          child: challenges.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun challenge',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: challenges.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final challenge = challenges[index];
                    return _buildChallengeCard(context, challenge);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(
    BuildContext context,
    Map<String, dynamic> challenge,
  ) {
    final fin = dateDeFinDefi(challenge);
    final isExpired = defiExpire(challenge);

    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.15),
          child: const Icon(Icons.flag, color: Colors.orange),
        ),
        title: Text(
          challenge['title'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(challenge['description'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text('${challenge['reward_points'] ?? 0} pts'),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(challenge['challenge_type'] ?? ''),
                  backgroundColor: Colors.purple.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(isExpired ? 'Expiré' : 'Actif'),
                  backgroundColor: (isExpired ? Colors.red : Colors.green)
                      .withValues(alpha: 0.1),
                ),
              ],
            ),
            // Sans date de fin, aucune ligne : la carte affichait « Fin: »
            // suivi de la date du jour, qui n'était celle de rien.
            if (fin != null) ...[
              const SizedBox(height: 4),
              Text(
                'Fin: ${_formatDate(fin)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
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
                        _showChallengeForm(context, challenge: challenge);
                      }
                    }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showChallengeForm(
    BuildContext context, {
    Map<String, dynamic>? challenge,
  }) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => ChallengeFormDialog(challenge: challenge),
    );
  }

}

// =====================================================
// BADGES TAB
// =====================================================

class ChallengeFormDialog extends StatefulWidget {
  final Map<String, dynamic>? challenge;

  const ChallengeFormDialog({this.challenge, super.key});

  @override
  State<ChallengeFormDialog> createState() => ChallengeFormDialogState();
}

class ChallengeFormDialogState extends State<ChallengeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _rewardPointsController = TextEditingController();
  final _rewardDiscountController = TextEditingController();

  String _challengeType = 'orders_count';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final c = widget.challenge;
    if (c != null) {
      _titleController.text = c['title'] ?? '';
      _descController.text = c['description'] ?? '';
      _targetValueController.text = (c['target_value'] ?? 0).toString();
      _rewardPointsController.text = (c['reward_points'] ?? 0).toString();
      _rewardDiscountController.text = (c['reward_discount'] ?? 0.0).toString();
      _challengeType = c['challenge_type'] ?? 'orders_count';
      _startDate = c['start_date'] != null
          ? DateTime.parse(c['start_date'].toString())
          : DateTime.now();
      _endDate = c['end_date'] != null
          ? DateTime.parse(c['end_date'].toString())
          : DateTime.now().add(const Duration(days: 7));
      _isActive = c['is_active'] ?? true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _targetValueController.dispose();
    _rewardPointsController.dispose();
    _rewardDiscountController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 750,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.challenge == null
                          ? 'Créer un Challenge'
                          : 'Modifier un Challenge',
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
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Description requise'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _challengeType,
                        decoration: const InputDecoration(
                          labelText: 'Type de challenge *',
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
                        ],
                        onChanged: (v) => setState(() => _challengeType = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _targetValueController,
                        decoration: const InputDecoration(
                          labelText: 'Valeur cible *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || int.tryParse(v) == null
                            ? 'Valeur invalide'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rewardPointsController,
                              decoration: const InputDecoration(
                                labelText: 'Points de récompense',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _rewardDiscountController,
                              decoration: const InputDecoration(
                                labelText: 'Réduction (%)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('Date de début'),
                              subtitle: Text(
                                '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: _selectStartDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ListTile(
                              title: const Text('Date de fin'),
                              subtitle: Text(
                                '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: _selectEndDate,
                            ),
                          ),
                        ],
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
                      widget.challenge == null ? 'Créer' : 'Modifier',
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
      if (widget.challenge == null) {
        service.createChallenge(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          challengeType: _challengeType,
          // Ce qui est compté. Le serveur ne sait mesurer que ce que déclare
          // `AchievementCondition` : un critère inventé ici ne compterait
          // jamais rien.
          conditionType: 'orders_count',
          targetValue: int.parse(_targetValueController.text),
          rewardPoints: int.tryParse(_rewardPointsController.text) ?? 0,
          startDate: _startDate,
          endDate: _endDate,
        );
      } else {
        service.updateChallenge(
          widget.challenge!['id'],
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          challengeType: _challengeType,
          targetValue: int.parse(_targetValueController.text),
          rewardPoints: int.tryParse(_rewardPointsController.text) ?? 0,
          startDate: _startDate,
          endDate: _endDate,
          isActive: _isActive,
        );
      }
      Navigator.pop(context);
    }
  }
}
