import 'package:flutter/material.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/widgets/custom_button.dart';

class OptionGroupsEditor extends StatefulWidget {
  final String menuItemId;
  final List<eccore.OptionGroup> initialGroups;
  final Function(List<eccore.OptionGroup>) onChanged;

  const OptionGroupsEditor({
    required this.menuItemId, required this.initialGroups, required this.onChanged, super.key,
  });

  @override
  State<OptionGroupsEditor> createState() => _OptionGroupsEditorState();
}

class _OptionGroupsEditorState extends State<OptionGroupsEditor> {
  late List<eccore.OptionGroup> _groups;

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
                    '${group.isRequired ? "Obligatoire" : "Facultatif"} • ${group.minSelect}-${group.maxSelect} choix',
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
                            size: 20, color: Colors.red,),
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
                              style: TextStyle(fontWeight: FontWeight.w500),),
                          const SizedBox(height: 8),
                          ...group.options.asMap().entries.map((entry) {
                            final optIndex = entry.key;
                            final option = entry.value;
                            return ListTile(
                              dense: true,
                              title: Text(option.name),
                              // L'indisponibilité se lit dans la liste : sans
                              // elle, il fallait ouvrir chaque option pour
                              // savoir laquelle était éteinte.
                              subtitle: option.isAvailable
                                  ? null
                                  : const Text(
                                      'Indisponible',
                                      style: TextStyle(color: Colors.orange),
                                    ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (option.priceDelta.amountMinor > 0)
                                    Text(
                                      '+${option.priceDelta.format()}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 16),
                                    onPressed: () =>
                                        _editOption(index, optIndex),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        size: 16, color: Colors.red,),
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
                child: const Text('Annuler'),),
            FilledButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;
                setState(() {
                  _groups.add(eccore.OptionGroup(
                    // Provisoire : le serveur attribue l'identifiant définitif
                    // à l'enregistrement.
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    // Un champ vidé levait une `FormatException` qui refermait
                    // l'écran sans créer le groupe. Les bornes retombent sur
                    // « exactement un choix », la forme la plus courante et
                    // celle que le serveur accepte toujours.
                    minSelect: _borneSaisie(minController.text, defaut: 0),
                    maxSelect: _borneSaisie(maxController.text, defaut: 1),
                    isRequired: isRequired,
                    sortOrder: _groups.length,
                    options: const [],
                  ),);
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
        TextEditingController(text: group.minSelect.toString());
    final maxController =
        TextEditingController(text: group.maxSelect.toString());
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
                child: const Text('Annuler'),),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                this.setState(() {
                  _groups[index] = group.copyWith(
                    name: nameController.text.trim(),
                    // Les bornes existantes servent de repli : une saisie
                    // effacée ne doit pas redéfinir le groupe, et `int.parse`
                    // levait ici la même `FormatException` qu'à la création.
                    minSelect: _borneSaisie(
                      minController.text,
                      defaut: group.minSelect,
                    ),
                    maxSelect: _borneSaisie(
                      maxController.text,
                      defaut: group.maxSelect,
                    ),
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
                  labelText: 'Prix Supplémentaire (FCFA)',),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              // Les francs CFA n'ont pas de décimale : l'unité mineure est le
              // franc. La saisie est relue avant d'entrer dans `setState` —
              // `double.parse` à nu y levait une `FormatException` sur un champ
              // vidé, et l'écran se refermait sans rien enregistrer.
              final prix = _prixSaisi(priceController.text);
              if (prix == null) return;

              setState(() {
                final group = _groups[groupIndex];
                final newOptions = List<eccore.Option>.from(group.options)
                  ..add(eccore.Option(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    priceDelta: eccore.Money(
                      amountMinor: prix,
                      currency: 'XOF',
                    ),
                    isDefault: false,
                    isAvailable: true,
                    sortOrder: group.options.length,
                  ),);
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
    // `Money.toString()` rend « 1000 XOF » : le champ se pré-remplissait donc
    // avec une chaîne que sa propre relecture (`double.parse`) refusait, et
    // « Sauvegarder » levait une `FormatException` — modifier le prix d'une
    // option était impossible sans vider le champ à la main.
    final priceController = TextEditingController(
      text: _saisiePrix(option.priceDelta),
    );
    bool isAvailable = option.isAvailable;

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                    labelText: 'Prix Supplémentaire (FCFA)',),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              // La disponibilité se pilote depuis ici : elle était figée à
              // « vrai » à la création et jamais rendue modifiable, si bien
              // qu'une rupture de fromage obligeait à supprimer l'option — et
              // à la ressaisir le lendemain. L'éteindre la laisse visible au
              // client, marquée « Indisponible » et non sélectionnable.
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponible'),
                subtitle: Text(
                  isAvailable
                      ? 'Proposée aux clients'
                      : 'Affichée mais non commandable',
                ),
                value: isAvailable,
                onChanged: (val) => setDialogState(() => isAvailable = val),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                final prix = _prixSaisi(priceController.text);
                if (prix == null) return;

                setState(() {
                  final newOptions = List<eccore.Option>.from(group.options);
                  newOptions[optionIndex] = option.copyWith(
                    name: nameController.text.trim(),
                    priceDelta: eccore.Money(
                      amountMinor: prix,
                      currency: 'XOF',
                    ),
                    isAvailable: isAvailable,
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
      ),
    );
  }

  /// Ce qu'on inscrit dans le champ « prix » pour un montant existant.
  ///
  /// Les francs CFA n'ont pas de décimale : l'unité mineure **est** le franc,
  /// et le champ se relit donc tel quel.
  static String _saisiePrix(eccore.Money montant) => '${montant.amountMinor}';

  /// Le montant saisi, en unités mineures — `null` si la saisie n'en est pas un.
  ///
  /// Les dialogues appelaient `double.parse` à nu : un champ vide, un espace ou
  /// une virgule décimale levaient une `FormatException` qui remontait jusqu'au
  /// gestionnaire d'appui, fermant l'écran sans rien enregistrer et sans dire
  /// pourquoi. Rendre `null` laisse le bouton sans effet, ce qui est le
  /// comportement déjà retenu pour un nom vide.
  static int? _prixSaisi(String saisie) {
    final normalise = saisie.trim().replaceAll(',', '.');
    if (normalise.isEmpty) return null;
    final valeur = double.tryParse(normalise);
    return valeur?.round();
  }

  /// Une borne de groupe saisie, ou [defaut] si la saisie n'en est pas une.
  static int _borneSaisie(String saisie, {required int defaut}) {
    final valeur = int.tryParse(saisie.trim());
    if (valeur == null || valeur < 0) return defaut;
    return valeur;
  }

  void _deleteOption(int groupIndex, int optionIndex) {
    setState(() {
      final group = _groups[groupIndex];
      final newOptions = List<eccore.Option>.from(group.options)
        ..removeAt(optionIndex);
      _groups[groupIndex] = group.copyWith(options: newOptions);
    });
    widget.onChanged(_groups);
  }
}



