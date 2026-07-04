import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/customization_management_service.dart';
import '../../utils/price_formatter.dart';

class QuickCustomizationDialog extends StatefulWidget {
  final String menuItemId;
  final String category; // 'size', 'ingredient', 'sauce', 'extra'
  final CustomizationOptionModel? existingOption;

  const QuickCustomizationDialog({
    super.key,
    required this.menuItemId,
    required this.category,
    this.existingOption,
  });

  @override
  State<QuickCustomizationDialog> createState() =>
      _QuickCustomizationDialogState();
}

class _QuickCustomizationDialogState extends State<QuickCustomizationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isRequired = false;
  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingOption != null) {
      final option = widget.existingOption!;
      _nameController.text = option.name;
      _descriptionController.text = option.description ?? '';
      _priceController.text = option.priceModifier.toStringAsFixed(0);
      _isDefault = option.isDefault;
    } else {
      // Valeurs par défaut selon la catégorie
      if (widget.category == 'size') {
        _nameController.text = 'Moyen';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String _getCategoryName() {
    switch (widget.category) {
      case 'size':
        return 'Taille';
      case 'ingredient':
        return 'Ingrédient';
      case 'sauce':
        return 'Sauce';
      case 'extra':
        return 'Supplément';
      default:
        return 'Option';
    }
  }

  IconData _getCategoryIcon() {
    switch (widget.category) {
      case 'size':
        return Icons.straighten;
      case 'ingredient':
        return Icons.restaurant;
      case 'sauce':
        return Icons.water_drop;
      case 'extra':
        return Icons.add_circle;
      default:
        return Icons.tune;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingOption != null;

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 500.0);
    final dialogHeight = (screenSize.height * 0.7).clamp(400.0, 600.0);

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
                  isEditing
                      ? 'Modifier ${_getCategoryName()}'
                      : 'Nouvelle ${_getCategoryName()}',
                ),
                automaticallyImplyLeading: false,
                leading: Icon(_getCategoryIcon()),
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
                        decoration: InputDecoration(
                          labelText: 'Nom *',
                          hintText: widget.category == 'size'
                              ? 'Ex: Petit, Moyen, Grand'
                              : widget.category == 'sauce'
                              ? 'Ex: Ketchup, Mayonnaise'
                              : 'Nom de l\'option',
                          prefixIcon: Icon(_getCategoryIcon()),
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
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText: widget.category == 'size'
                              ? 'Ex: Portion standard'
                              : 'Description de l\'option',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: 'Prix supplémentaire (FCFA)',
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
                                            _priceController.text,
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
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (widget.category == 'size')
                        SwitchListTile(
                          title: const Text('Taille par défaut'),
                          subtitle: const Text(
                            'Cette taille sera sélectionnée par défaut',
                          ),
                          value: _isDefault,
                          onChanged: (value) {
                            setState(() {
                              _isDefault = value;
                            });
                          },
                        ),
                      if (widget.category != 'size')
                        SwitchListTile(
                          title: const Text('Option requise'),
                          subtitle: const Text(
                            'L\'utilisateur doit sélectionner cette option',
                          ),
                          value: _isRequired,
                          onChanged: (value) {
                            setState(() {
                              _isRequired = value;
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
                      onPressed: _isLoading ? null : _handleSubmit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Modifier' : 'Créer'),
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

    setState(() => _isLoading = true);

    final service = Provider.of<CustomizationManagementService>(
      context,
      listen: false,
    );
    final price = double.tryParse(_priceController.text) ?? 0.0;

    try {
      if (widget.existingOption != null) {
        // Modifier l'option existante
        final updated = widget.existingOption!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          priceModifier: price,
          isDefault: _isDefault,
        );

        final success = await service.updateOption(updated);
        if (!mounted) return;

        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Option modifiée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(service.error ?? 'Erreur'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Créer une nouvelle option
        final newOption = await service.createOption(
          name: _nameController.text.trim(),
          category: widget.category,
          priceModifier: price,
          isDefault: _isDefault,
          maxQuantity: widget.category == 'size' ? 1 : 1,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );

        if (!mounted) return;

        if (newOption != null) {
          // Associer automatiquement au produit
          final associationSuccess = await service.associateOptionToMenuItem(
            menuItemId: widget.menuItemId,
            optionId: newOption.id,
            isRequired: _isRequired,
            sortOrder: 0,
          );

          if (!mounted) return;

          if (associationSuccess) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Option créée et associée avec succès'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Option créée mais erreur lors de l\'association: ${service.error}',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(service.error ?? 'Erreur lors de la création'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
