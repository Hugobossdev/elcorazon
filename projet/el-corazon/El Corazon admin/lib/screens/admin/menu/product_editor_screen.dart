import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/menu_models.dart';
import '../../../services/menu_service.dart';
import 'widgets/option_group_widget.dart';

class ProductEditorScreen extends StatefulWidget {
  final String categoryId;
  final MenuItem? menuItem;

  const ProductEditorScreen({
    super.key,
    required this.categoryId,
    this.menuItem,
  });

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _imageUrlController;

  bool _isPopular = false;
  bool _isVegetarian = false;
  bool _isVegan = false;
  bool _isAvailable = true;

  List<MenuOptionGroup> _optionGroups = [];
  bool _isLoading = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final item = widget.menuItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _priceController = TextEditingController(
      text: item?.basePrice.toString() ?? '0',
    );
    _imageUrlController = TextEditingController(text: item?.imageUrl ?? '');

    if (item != null) {
      _isPopular = item.isPopular;
      _isVegetarian = item.isVegetarian;
      _isVegan = item.isVegan;
      _isAvailable = item.isAvailable;
      _optionGroups = List.from(item.optionGroups);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final menuService = Provider.of<MenuService>(context, listen: false);

      final newItem = MenuItem(
        id: widget.menuItem?.id ?? '',
        categoryId: widget.categoryId,
        name: _nameController.text,
        description: _descriptionController.text,
        basePrice: double.tryParse(_priceController.text) ?? 0,
        imageUrl:
            _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
        isPopular: _isPopular,
        isVegetarian: _isVegetarian,
        isVegan: _isVegan,
        isAvailable: _isAvailable,
        createdAt: widget.menuItem?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        optionGroups: _optionGroups,
      );

      if (widget.menuItem == null) {
        // Create
        final createdItem = await menuService.createMenuItem(newItem);
        if (createdItem != null) {
          // Save option groups
          for (var group in _optionGroups) {
            final groupWithItemId = group.copyWith(menuItemId: createdItem.id);
            final createdGroup = await menuService.createOptionGroup(
              groupWithItemId,
            );
            if (createdGroup != null) {
              for (var option in group.options) {
                final optionWithGroupId = option.copyWith(
                  groupId: createdGroup.id,
                );
                await menuService.createOption(optionWithGroupId);
              }
            }
          }
        }
      } else {
        // Update
        await menuService.updateMenuItem(newItem);

        // Handle groups update (simplified: delete all and recreate for now, or smart update)
        // For this MVP, we'll assume the user manages groups carefully.
        // A proper implementation would diff the groups.
        // Given the complexity, let's just save the item properties for now and handle groups if they are new.
        // Ideally, we should have specific API endpoints for syncing options.

        // NOTE: This is a simplified approach. In a real app, you'd want to handle IDs properly to avoid recreating everything.
        // For now, we will just update the main item properties.
        // Updating nested relations via Supabase directly is tricky without a stored procedure or multiple calls.

        // Let's try to update groups that have IDs, create those that don't.
        for (var group in _optionGroups) {
          if (group.id.isEmpty) {
            final groupWithItemId = group.copyWith(menuItemId: newItem.id);
            final createdGroup = await menuService.createOptionGroup(
              groupWithItemId,
            );
            if (createdGroup != null) {
              for (var option in group.options) {
                final optionWithGroupId = option.copyWith(
                  groupId: createdGroup.id,
                );
                await menuService.createOption(optionWithGroupId);
              }
            }
          } else {
            await menuService.updateOptionGroup(group);
            // Handle options within group
            for (var option in group.options) {
              if (option.id.isEmpty) {
                final optionWithGroupId = option.copyWith(groupId: group.id);
                await menuService.createOption(optionWithGroupId);
              } else {
                await menuService.updateOption(option);
              }
            }
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    // Demander à l'utilisateur de choisir la source
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Caméra'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 85, // Compression pour réduire la taille
      maxWidth: 1920, // Limiter la résolution
      maxHeight: 1920,
    );

    if (image != null) {
      if (!mounted) return;
      
      setState(() {
        _isUploadingImage = true;
      });

      try {
        if (!mounted) return;
        final menuService = Provider.of<MenuService>(context, listen: false);
        final productName =
            _nameController.text.isNotEmpty ? _nameController.text : 'product';

        // Passer l'ancienne URL si on modifie un produit existant
        final oldImageUrl = widget.menuItem?.imageUrl;

        final imageUrl = await menuService.uploadProductImage(
          image,
          productName,
          oldImageUrl: oldImageUrl,
        );

        if (imageUrl != null && mounted && context.mounted) {
          setState(() {
            _imageUrlController.text = imageUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploadée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted && context.mounted) {
          final error = menuService.error ?? 'Erreur inconnue';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur upload: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploadingImage = false;
          });
        }
      }
    }
  }

  void _addOptionGroup() {
    setState(() {
      _optionGroups.add(
        MenuOptionGroup(
          id: '', // Empty ID indicates new
          menuItemId: widget.menuItem?.id ?? '',
          name: 'Nouveau groupe',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.menuItem == null ? 'Nouveau Produit' : 'Modifier Produit',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Basic Info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nom du produit',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Requis' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
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
                                    controller: _priceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Prix de base',
                                      suffixText: 'CFA',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Requis'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Section Image avec upload
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Aperçu de l'image
                                InkWell(
                                  onTap: _isUploadingImage ? null : _pickImage,
                                  child: Container(
                                    width: 150,
                                    height: 150,
                                    margin: const EdgeInsets.only(right: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 2,
                                      ),
                                      image: _imageUrlController
                                                  .text.isNotEmpty &&
                                              !_isUploadingImage
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                _imageUrlController.text,
                                              ),
                                              fit: BoxFit.cover,
                                              onError: (exception, stackTrace) {
                                                // En cas d'erreur de chargement de l'image
                                              },
                                            )
                                          : null,
                                    ),
                                    child: _isUploadingImage
                                        ? const Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                CircularProgressIndicator(),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Upload...',
                                                  style:
                                                      TextStyle(fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          )
                                        : _imageUrlController.text.isEmpty
                                            ? const Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.add_photo_alternate,
                                                    size: 48,
                                                    color: Colors.grey,
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'Ajouter\nune image',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Stack(
                                                children: [
                                                  // Bouton pour changer l'image
                                                  Positioned(
                                                    top: 4,
                                                    right: 4,
                                                    child: Container(
                                                      decoration: const BoxDecoration(
                                                        color: Colors.black54,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons.edit,
                                                          color: Colors.white,
                                                          size: 20,
                                                        ),
                                                        onPressed: _pickImage,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                  ),
                                ),
                                // Champ URL et bouton
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: _imageUrlController,
                                        decoration: InputDecoration(
                                          labelText: 'URL de l\'image',
                                          border: const OutlineInputBorder(),
                                          suffixIcon: _imageUrlController
                                                  .text.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.clear),
                                                  onPressed: () {
                                                    setState(() {
                                                      _imageUrlController
                                                          .clear();
                                                    });
                                                  },
                                                )
                                              : null,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: _isUploadingImage
                                                ? null
                                                : _pickImage,
                                            icon: const Icon(Icons.upload),
                                            label: const Text('Uploader'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(context)
                                                  .primaryColor,
                                            ),
                                          ),
                                          if (_imageUrlController
                                              .text.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                setState(() {
                                                  _imageUrlController.clear();
                                                });
                                              },
                                              icon: const Icon(Icons.delete),
                                              label: const Text('Supprimer'),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Formats acceptés: JPG, PNG, WebP\nTaille max: 5MB',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Flags
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Disponible'),
                            value: _isAvailable,
                            onChanged: (v) => setState(() => _isAvailable = v),
                          ),
                          SwitchListTile(
                            title: const Text('Populaire'),
                            value: _isPopular,
                            onChanged: (v) => setState(() => _isPopular = v),
                          ),
                          SwitchListTile(
                            title: const Text('Végétarien'),
                            value: _isVegetarian,
                            onChanged: (v) => setState(() => _isVegetarian = v),
                          ),
                          SwitchListTile(
                            title: const Text('Vegan'),
                            value: _isVegan,
                            onChanged: (v) => setState(() => _isVegan = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Customizations
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Personnalisations',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        ElevatedButton.icon(
                          onPressed: _addOptionGroup,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter un groupe'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_optionGroups.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Aucune option de personnalisation'),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _optionGroups.length,
                        itemBuilder: (context, index) {
                          return OptionGroupWidget(
                            group: _optionGroups[index],
                            onUpdate: (updatedGroup) {
                              setState(() {
                                _optionGroups[index] = updatedGroup;
                              });
                            },
                            onDelete: () {
                              setState(() {
                                _optionGroups.removeAt(index);
                              });
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
