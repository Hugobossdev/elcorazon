import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class CategoryFormDialog extends StatefulWidget {
  final Category? category;
  final Function(
    String name,
    String displayName,
    String emoji,
    String? description,
    int sortOrder,
  )
  onSubmit;

  const CategoryFormDialog({super.key, this.category, required this.onSubmit});

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emojiController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sortOrderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _displayNameController.text = widget.category!.name;
      _emojiController.text = '🍽️';
      _descriptionController.text = widget.category!.description ?? '';
      _sortOrderController.text = widget.category!.displayOrder.toString();
    } else {
      _emojiController.text = '🍽️';
      _sortOrderController.text = '1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _emojiController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 600.0);
    final dialogHeight = (screenSize.height * 0.7).clamp(500.0, 700.0);

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
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.category == null
                          ? 'Ajouter une catégorie'
                          : 'Modifier la catégorie',
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Contenu scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextField(
                        label: 'Nom (identifiant) *',
                        controller: _nameController,
                        hint: 'Ex: burgers, pizzas',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le nom est requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Nom d\'affichage *',
                        controller: _displayNameController,
                        hint: 'Ex: Burgers, Pizzas',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le nom d\'affichage est requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Emoji *',
                        controller: _emojiController,
                        hint: 'Ex: 🍔, 🍕',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'L\'emoji est requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Description',
                        controller: _descriptionController,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Ordre d\'affichage',
                        controller: _sortOrderController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'L\'ordre est requis';
                          }
                          final order = int.tryParse(value);
                          if (order == null || order < 1) {
                            return 'L\'ordre doit être un nombre positif';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CustomButton(
                    text: widget.category == null ? 'Créer' : 'Modifier',
                    onPressed: _submitForm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final displayName = _displayNameController.text.trim();
      final emoji = _emojiController.text.trim();
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final sortOrder = int.parse(_sortOrderController.text);

      widget.onSubmit(name, displayName, emoji, description, sortOrder);
      Navigator.of(context).pop();
    }
  }
}
