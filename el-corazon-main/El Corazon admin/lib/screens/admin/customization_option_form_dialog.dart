import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/customization_management_service.dart';
import '../../utils/price_formatter.dart';

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
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _priceModifierController = TextEditingController();
  final _maxQuantityController = TextEditingController();
  final _allergensController = TextEditingController();

  late String _selectedCategory;
  bool _isDefault = false;
  bool _isActive = true;

  // Catégories principales en premier
  final List<String> _mainCategories = [
    'size', // Taille
    'ingredient', // Ingrédient
    'sauce', // Sauces
    'extra', // Suppléments
  ];

  final List<String> _otherCategories = [
    'cooking',
    'shape',
    'flavor',
    'filling',
    'decoration',
    'tiers',
    'icing',
    'dietary',
  ];

  List<String> get _categories => [..._mainCategories, ..._otherCategories];

  @override
  void initState() {
    super.initState();
    // Initialiser la catégorie : option existante > catégorie présélectionnée > défaut
    _selectedCategory =
        widget.option?.category ?? widget.preselectedCategory ?? 'extra';

    if (widget.option != null) {
      final option = widget.option!;
      _nameController.text = option.name;
      _descriptionController.text = option.description ?? '';
      _imageUrlController.text = option.imageUrl ?? '';
      _priceModifierController.text = option.priceModifier.toStringAsFixed(0);
      _maxQuantityController.text = option.maxQuantity.toString();
      _allergensController.text = option.allergens.join(', ');
      _selectedCategory = option.category;
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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _priceModifierController.dispose();
    _maxQuantityController.dispose();
    _allergensController.dispose();
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
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie *',
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(_translateCategory(category)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Description de l\'option',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _priceModifierController,
                              decoration: const InputDecoration(
                                labelText: 'Prix supplémentaire',
                                hintText: '0',
                                prefixText: 'FCFA ',
                                helperText: 'Prix ajouté au prix de base',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final price = double.tryParse(value);
                                  if (price == null) {
                                    return 'Prix invalide';
                                  }
                                }
                                return null;
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
                                      final price =
                                          double.tryParse(
                                            _priceModifierController.text,
                                          ) ??
                                          0.0;
                                      return Text(
                                        price > 0
                                            ? '+${formatPrice(price)}'
                                            : price < 0
                                            ? formatPrice(price)
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
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _maxQuantityController,
                              decoration: const InputDecoration(
                                labelText: 'Quantité max',
                                hintText: '1',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '1';
                                }
                                final qty = int.tryParse(value);
                                if (qty == null || qty < 1) {
                                  return 'Minimum 1';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL de l\'image',
                          hintText: 'https://...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _allergensController,
                        decoration: const InputDecoration(
                          labelText: 'Allergènes',
                          hintText:
                              'Séparés par des virgules (ex: gluten, lactose)',
                          helperText:
                              'Liste des allergènes séparés par des virgules',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Option par défaut'),
                        subtitle: const Text('Sélectionnée automatiquement'),
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
                  mainAxisSize: MainAxisSize.max,
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

    final allergens = _allergensController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final priceModifier = double.tryParse(_priceModifierController.text) ?? 0.0;
    final maxQuantity = int.tryParse(_maxQuantityController.text) ?? 1;

    if (widget.option == null) {
      // Créer
      final newOption = await service.createOption(
        name: _nameController.text.trim(),
        category: _selectedCategory,
        priceModifier: priceModifier,
        isDefault: _isDefault,
        maxQuantity: maxQuantity,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        allergens: allergens,
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
        category: _selectedCategory,
        priceModifier: priceModifier,
        isDefault: _isDefault,
        maxQuantity: maxQuantity,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        allergens: allergens,
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

  String _translateCategory(String category) {
    switch (category) {
      case 'size':
        return 'Taille';
      case 'cooking':
        return 'Cuisson';
      case 'ingredient':
        return 'Ingrédient';
      case 'sauce':
        return 'Sauces';
      case 'extra':
        return 'Suppléments';
      case 'shape':
        return 'Forme';
      case 'flavor':
        return 'Saveur';
      case 'filling':
        return 'Garniture';
      case 'decoration':
        return 'Décoration';
      case 'tiers':
        return 'Étages';
      case 'icing':
        return 'Glaçage';
      case 'dietary':
        return 'Préférence alimentaire';
      default:
        return category;
    }
  }
}
