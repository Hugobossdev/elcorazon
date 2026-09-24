import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin/services/customization_management_service.dart';
import 'package:admin/utils/price_formatter.dart';

class CustomizationOptionFormDialog extends StatefulWidget {
  final CustomizationOptionModel? option;
  final String? preselectedCategory;

  const CustomizationOptionFormDialog({
    super.key,
    this.option,
    this.preselectedCategory,
  });

  @override
  State<CustomizationOptionFormDialog> createState() =>
      _CustomizationOptionFormDialogState();
}

class _CustomizationOptionFormDialogState
    extends State<CustomizationOptionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceModifierController = TextEditingController();

  /// Groupe suggéré (`group_name`) : texte libre côté serveur, pas une liste.
  final _groupeController = TextEditingController();
  bool _isDefault = false;
  bool _isActive = true;


  @override
  void initState() {
    super.initState();
    // Initialiser la catégorie : option existante > catégorie présélectionnée > défaut
    _groupeController.text = widget.option?.category ?? widget.preselectedCategory ?? '';

    if (widget.option != null) {
      final option = widget.option!;
      _nameController.text = option.name;
      _priceModifierController.text = montantPourSaisie(option.priceModifier, option.devise);
      _isDefault = option.isDefault;
      _isActive = option.isActive;
    }
    // Écouter les changements de prix pour mettre à jour l'aperçu
    _priceModifierController.addListener(() {
      if (!mounted) return;
      // Reporter setState après le build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    });
  }

  /// La devise du modèle, ou celle de l'établissement où il sera créé.
  String get _devise =>
      widget.option?.devise ??
      context.read<CustomizationManagementService>().deviseDeCreation;

  /// Le supplément saisi, en unité majeure — virgule acceptée.
  double? get _prixSaisi =>
      double.tryParse(_priceModifierController.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _nameController.dispose();
    _groupeController.dispose();
    _priceModifierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.option != null;

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 600.0);
    final dialogHeight = (screenSize.height * 0.8).clamp(500.0, 800.0);

    return Dialog(
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        constraints: BoxConstraints(
          minWidth: dialogWidth,
          maxWidth: dialogWidth,
          minHeight: dialogHeight,
          maxHeight: dialogHeight,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AppBar(
                title: Text(
                  isEditing ? 'Modifier l\'option' : 'Nouvelle option',
                ),
                automaticallyImplyLeading: false,
                actions: [
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom *',
                          hintText: 'Ex: Petit, Moyen, Grand',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le nom est requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _groupeController,
                        decoration: const InputDecoration(
                          labelText: 'Groupe suggéré',
                          hintText: 'Cuisson, Suppléments, Sauces…',
                          helperText: 'Vide : l’option sera rangée dans « Options » '
                              'lorsqu’on l’appliquera à un article.',
                        ),
                        maxLength: 80,
                      ),
                      // Les groupes que la bibliothèque emploie déjà, en un
                      // geste : deux orthographes du même groupe feraient
                      // deux groupes chez le client.
                      Builder(builder: (context) {
                        final groupes = context
                            .read<CustomizationManagementService>()
                            .groupes;
                        if (groupes.isEmpty) return const SizedBox.shrink();
                        return Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final groupe in groupes)
                              ActionChip(
                                label: Text(groupe),
                                onPressed: () =>
                                    setState(() => _groupeController.text = groupe),
                              ),
                          ],
                        );
                      },),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _priceModifierController,
                              decoration: InputDecoration(
                                labelText: 'Prix supplémentaire',
                                hintText: '0',
                                suffixText: _devise,
                                helperText: 'Prix ajouté au prix de base',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return null;
                                final price = _prixSaisi;
                                if (price == null) return 'Prix invalide';
                                return erreurDePrecision(price, _devise);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Aperçu',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Builder(
                                    builder: (context) {
                                      final price = _prixSaisi ?? 0.0;
                                      final devise = _devise;
                                      return Text(
                                        price > 0
                                            ? '+${formatMajeur(price, devise)}'
                                            : price < 0
                                            ? formatMajeur(price, devise)
                                            : 'Gratuit',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: price > 0
                                              ? Colors.green.shade700
                                              : price < 0
                                              ? Colors.red.shade700
                                              : Colors.grey.shade700,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        title: const Text('Option par défaut'),
                        subtitle: const Text(
                          'Présélectionnée dans son groupe une fois appliquée '
                          'à un article',
                        ),
                        value: _isDefault,
                        onChanged: (value) {
                          setState(() {
                            _isDefault = value;
                          });
                        },
                      ),
                      if (isEditing)
                        SwitchListTile(
                          title: const Text('Active'),
                          subtitle: const Text('L\'option est disponible'),
                          value: _isActive,
                          onChanged: (value) {
                            setState(() {
                              _isActive = value;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _handleSubmit,
                      child: Text(isEditing ? 'Modifier' : 'Créer'),
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

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final service = Provider.of<CustomizationManagementService>(
      context,
      listen: false,
    );

    final priceModifier = _prixSaisi ?? 0.0;

    if (widget.option == null) {
      // Créer
      final newOption = await service.createOption(
        name: _nameController.text.trim(),
        category: _groupeController.text.trim(),
        priceModifier: priceModifier,
        isDefault: _isDefault,
      );

      if (!mounted) return;

      Navigator.pop(context);
      if (newOption != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Option créée avec succès')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(service.error ?? 'Erreur lors de la création'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Modifier
      final updatedOption = widget.option!.copyWith(
        name: _nameController.text.trim(),
        category: _groupeController.text.trim(),
        priceModifier: priceModifier,
        isDefault: _isDefault,
        isActive: _isActive,
      );

      final success = await service.updateOption(updatedOption);

      if (!mounted) return;

      Navigator.pop(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Option modifiée avec succès')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(service.error ?? 'Erreur lors de la modification'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
