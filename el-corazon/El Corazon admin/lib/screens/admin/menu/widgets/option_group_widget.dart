import 'package:flutter/material.dart';
import '../../../../models/menu_models.dart';

class OptionGroupWidget extends StatefulWidget {
  final MenuOptionGroup group;
  final Function(MenuOptionGroup) onUpdate;
  final VoidCallback onDelete;

  const OptionGroupWidget({
    super.key,
    required this.group,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<OptionGroupWidget> createState() => _OptionGroupWidgetState();
}

class _OptionGroupWidgetState extends State<OptionGroupWidget> {
  late TextEditingController _nameController;
  late TextEditingController _minController;
  late TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _minController = TextEditingController(
      text: widget.group.minSelection.toString(),
    );
    _maxController = TextEditingController(
      text: widget.group.maxSelection.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _updateGroup() {
    final updatedGroup = widget.group.copyWith(
      name: _nameController.text,
      minSelection: int.tryParse(_minController.text) ?? 0,
      maxSelection: int.tryParse(_maxController.text) ?? 1,
    );
    widget.onUpdate(updatedGroup);
  }

  void _addOption() {
    final newOption = MenuOption(
      id: '', // Will be generated or handled by backend
      groupId: widget.group.id,
      name: 'Nouvelle option',
      priceModifier: 0,
    );
    final updatedOptions = List<MenuOption>.from(widget.group.options)
      ..add(newOption);
    widget.onUpdate(widget.group.copyWith(options: updatedOptions));
  }

  void _updateOption(int index, MenuOption option) {
    final updatedOptions = List<MenuOption>.from(widget.group.options);
    updatedOptions[index] = option;
    widget.onUpdate(widget.group.copyWith(options: updatedOptions));
  }

  void _deleteOption(int index) {
    final updatedOptions = List<MenuOption>.from(widget.group.options);
    updatedOptions.removeAt(index);
    widget.onUpdate(widget.group.copyWith(options: updatedOptions));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du groupe (ex: Taille, Ingrédients)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _updateGroup(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    decoration: const InputDecoration(
                      labelText: 'Min sélection',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateGroup(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    decoration: const InputDecoration(
                      labelText: 'Max sélection',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateGroup(),
                  ),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: widget.group.isRequired,
                  onChanged: (value) {
                    widget.onUpdate(widget.group.copyWith(isRequired: value));
                  },
                ),
                const Text('Obligatoire'),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Options',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final updatedOptions = List<MenuOption>.from(
                  widget.group.options,
                );
                final item = updatedOptions.removeAt(oldIndex);
                updatedOptions.insert(newIndex, item);
                widget.onUpdate(widget.group.copyWith(options: updatedOptions));
              },
              children: [
                for (int i = 0; i < widget.group.options.length; i++)
                  ListTile(
                    key: ValueKey(
                      widget.group.options[i].hashCode,
                    ), // Better key needed in real app
                    title: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: widget.group.options[i].name,
                            decoration: const InputDecoration(
                              labelText: 'Nom',
                              isDense: true,
                            ),
                            onChanged: (value) {
                              _updateOption(
                                i,
                                widget.group.options[i].copyWith(name: value),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: widget.group.options[i].priceModifier
                                .toString(),
                            decoration: const InputDecoration(
                              labelText: 'Prix (+)',
                              isDense: true,
                              suffixText: 'FCFA',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              _updateOption(
                                i,
                                widget.group.options[i].copyWith(
                                  priceModifier: double.tryParse(value) ?? 0,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _deleteOption(i),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une option'),
            ),
          ],
        ),
      ),
    );
  }
}
