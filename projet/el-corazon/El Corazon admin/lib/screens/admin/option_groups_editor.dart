import 'package:flutter/material.dart';
import '../../models/menu_models.dart';
import '../../utils/dialog_helper.dart';
import '../../widgets/custom_button.dart';

class OptionGroupsEditor extends StatefulWidget {
  final String menuItemId;
  final List<MenuOptionGroup> initialGroups;
  final Function(List<MenuOptionGroup>) onChanged;

  const OptionGroupsEditor({
    super.key,
    required this.menuItemId,
    required this.initialGroups,
    required this.onChanged,
  });

  @override
  State<OptionGroupsEditor> createState() => _OptionGroupsEditorState();
}

class _OptionGroupsEditorState extends State<OptionGroupsEditor> {
  late List<MenuOptionGroup> _groups;

  @override
  void initState() {
    super.initState();
    _groups = List.from(widget.initialGroups);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Options & Variantes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _addGroup,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Ajouter un groupe'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_groups.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Center(
              child: Text(
                'Aucune option configurée (ex: Taille, Sauce, Suppléments)',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _groups.length,
            itemBuilder: (context, index) {
              final group = _groups[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${group.isRequired ? "Obligatoire" : "Facultatif"} • ${group.minSelection}-${group.maxSelection} choix',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editGroup(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 20, color: Colors.red),
                        onPressed: () => _deleteGroup(index),
                      ),
                      const Icon(Icons.expand_more),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Choix disponibles:',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          ...group.options.asMap().entries.map((entry) {
                            final optIndex = entry.key;
                            final option = entry.value;
                            return ListTile(
                              dense: true,
                              title: Text(option.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (option.priceModifier > 0)
                                    Text(
                                      '+${option.priceModifier.toStringAsFixed(0)} FCFA',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 16),
                                    onPressed: () =>
                                        _editOption(index, optIndex),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        size: 16, color: Colors.red),
                                    onPressed: () =>
                                        _deleteOption(index, optIndex),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          CustomButton(
                            text: 'Ajouter un choix',
                            onPressed: () => _addOption(index),
                            icon: Icons.add,
                            variant: ButtonVariant.outlined,
                            height: 36,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  void _addGroup() {
    final nameController = TextEditingController();
    final minController = TextEditingController(text: '0');
    final maxController = TextEditingController(text: '1');
    bool isRequired = false;

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nouveau Groupe d\'Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: 'Nom (ex: Taille, Sauce)'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minController,
                      decoration: const InputDecoration(labelText: 'Min'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: maxController,
                      decoration: const InputDecoration(labelText: 'Max'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Obligatoire'),
                value: isRequired,
                onChanged: (val) => setState(() => isRequired = val),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;
                setState(() {
                  _groups.add(MenuOptionGroup(
                    id: DateTime.now()
                        .millisecondsSinceEpoch
                        .toString(), // Temp ID
                    menuItemId: widget.menuItemId,
                    name: nameController.text,
                    minSelection: int.parse(minController.text),
                    maxSelection: int.parse(maxController.text),
                    isRequired: isRequired,
                  ));
                });
                widget.onChanged(_groups);
                Navigator.pop(context);
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  void _editGroup(int index) {
    final group = _groups[index];
    final nameController = TextEditingController(text: group.name);
    final minController =
        TextEditingController(text: group.minSelection.toString());
    final maxController =
        TextEditingController(text: group.maxSelection.toString());
    bool isRequired = group.isRequired;

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier le Groupe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minController,
                      decoration: const InputDecoration(labelText: 'Min'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: maxController,
                      decoration: const InputDecoration(labelText: 'Max'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Obligatoire'),
                value: isRequired,
                onChanged: (val) => setState(() => isRequired = val),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                this.setState(() {
                  _groups[index] = group.copyWith(
                    name: nameController.text,
                    minSelection: int.parse(minController.text),
                    maxSelection: int.parse(maxController.text),
                    isRequired: isRequired,
                  );
                });
                widget.onChanged(_groups);
                Navigator.pop(context);
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteGroup(int index) {
    setState(() {
      _groups.removeAt(index);
    });
    widget.onChanged(_groups);
  }

  void _addOption(int groupIndex) {
    final nameController = TextEditingController();
    final priceController = TextEditingController(text: '0');

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau Choix'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration:
                  const InputDecoration(labelText: 'Nom (ex: Grande, Ketchup)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                  labelText: 'Prix Supplémentaire (FCFA)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              setState(() {
                final group = _groups[groupIndex];
                final newOptions = List<MenuOption>.from(group.options)
                  ..add(MenuOption(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    groupId: group.id,
                    name: nameController.text,
                    priceModifier: double.parse(priceController.text),
                  ));
                _groups[groupIndex] = group.copyWith(options: newOptions);
              });
              widget.onChanged(_groups);
              Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _editOption(int groupIndex, int optionIndex) {
    final group = _groups[groupIndex];
    final option = group.options[optionIndex];
    final nameController = TextEditingController(text: option.name);
    final priceController =
        TextEditingController(text: option.priceModifier.toString());

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le Choix'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                  labelText: 'Prix Supplémentaire (FCFA)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              setState(() {
                final newOptions = List<MenuOption>.from(group.options);
                newOptions[optionIndex] = option.copyWith(
                  name: nameController.text,
                  priceModifier: double.parse(priceController.text),
                );
                _groups[groupIndex] = group.copyWith(options: newOptions);
              });
              widget.onChanged(_groups);
              Navigator.pop(context);
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _deleteOption(int groupIndex, int optionIndex) {
    setState(() {
      final group = _groups[groupIndex];
      final newOptions = List<MenuOption>.from(group.options)
        ..removeAt(optionIndex);
      _groups[groupIndex] = group.copyWith(options: newOptions);
    });
    widget.onChanged(_groups);
  }
}



