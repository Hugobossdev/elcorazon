import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/menu_models.dart';
import '../../models/category.dart';
import '../../services/menu_service.dart';
import '../../services/category_management_service.dart';
import '../../widgets/custom_button.dart';
import 'option_groups_editor.dart'; // Import du nouveau widget

class MenuItemFormDialog extends StatefulWidget {
  final MenuItem? menuItem;
  final VoidCallback? onSaved;

  const MenuItemFormDialog({
    super.key,
    this.menuItem,
    this.onSaved,
  });

  @override
  State<MenuItemFormDialog> createState() => _MenuItemFormDialogState();
}

class _MenuItemFormDialogState extends State<MenuItemFormDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _imageUrlController;

  String? _selectedCategoryId;
  bool _isAvailable = true;
  bool _isPopular = false;
  bool _isVegetarian = false;
  bool _isVegan = false;
  bool _isUploadingImage = false;
  List<MenuOptionGroup> _optionGroups = [];

  late TabController _tabController;

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
      setState(() {
        _isUploadingImage = true;
      });

      try {
        if (!mounted || !context.mounted) return;
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

        if (imageUrl != null && mounted) {
          setState(() {
            _imageUrlController.text = imageUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploadée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final item = widget.menuItem;
    _nameController = TextEditingController(text: item?.name);
    _descriptionController = TextEditingController(text: item?.description);
    _priceController = TextEditingController(text: item?.basePrice.toString());
    _imageUrlController = TextEditingController(text: item?.imageUrl);

    _selectedCategoryId = item?.categoryId;
    _isAvailable = item?.isAvailable ?? true;
    _isPopular = item?.isPopular ?? false;
    _isVegetarian = item?.isVegetarian ?? false;
    _isVegan = item?.isVegan ?? false;
    _optionGroups = item?.optionGroups ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryService = Provider.of<CategoryManagementService>(context);
    final categories = categoryService.categories;

    // Si aucune catégorie n'est sélectionnée et qu'il en existe, sélectionner la première par défaut
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 600,
        height: 700,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header avec Tabs
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.menuItem == null
                          ? 'Nouvel Article'
                          : 'Modifier l\'Article',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: const [
                      Tab(text: 'Informations', icon: Icon(Icons.info_outline)),
                      Tab(
                          text: 'Options & Variantes',
                          icon: Icon(Icons.list_alt)),
                    ],
                  ),
                ],
              ),
            ),

            // Contenu
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGeneralInfoTab(categories),
                    _buildOptionsTab(),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 16),
                  CustomButton(
                    text: 'Enregistrer',
                    onPressed: _saveMenuItem,
                    icon: Icons.save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralInfoTab(List<Category> categories) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Preview
              InkWell(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  margin: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    image: _imageUrlController.text.isNotEmpty &&
                            !_isUploadingImage
                        ? DecorationImage(
                            image: NetworkImage(_imageUrlController.text),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _isUploadingImage
                      ? const Center(child: CircularProgressIndicator())
                      : (_imageUrlController.text.isEmpty
                          ? const Icon(Icons.add_photo_alternate,
                              size: 40, color: Colors.grey)
                          : null),
                ),
              ),
              // Champs principaux
              Expanded(
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
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        border: OutlineInputBorder(),
                      ),
                      items: categories
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCategoryId = value),
                      validator: (value) => value == null ? 'Requis' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Prix (FCFA)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Requis';
                    if (double.tryParse(value!) == null) return 'Invalide';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'URL de l\'image',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              hintText: 'Ingrédients, allergènes, etc.',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          const Text('Attributs',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 16,
            children: [
              FilterChip(
                label: const Text('Disponible'),
                selected: _isAvailable,
                onSelected: (val) => setState(() => _isAvailable = val),
                avatar: Icon(
                    _isAvailable ? Icons.check_circle : Icons.circle_outlined,
                    size: 18),
              ),
              FilterChip(
                label: const Text('Populaire'),
                selected: _isPopular,
                onSelected: (val) => setState(() => _isPopular = val),
                avatar: const Icon(Icons.star, size: 18, color: Colors.orange),
              ),
              FilterChip(
                label: const Text('Végétarien'),
                selected: _isVegetarian,
                onSelected: (val) => setState(() => _isVegetarian = val),
                avatar: const Icon(Icons.grass, size: 18, color: Colors.green),
              ),
              FilterChip(
                label: const Text('Vegan'),
                selected: _isVegan,
                onSelected: (val) => setState(() => _isVegan = val),
                avatar: const Icon(Icons.eco, size: 18, color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: OptionGroupsEditor(
        menuItemId: widget.menuItem?.id ?? '',
        initialGroups: _optionGroups,
        onChanged: (groups) {
          setState(() {
            _optionGroups = groups;
          });
        },
      ),
    );
  }

  /// Synchronise les optionGroups et leurs options avec la base de données
  /// Cette méthode gère la création, la mise à jour et la suppression
  Future<void> _syncOptionGroups(MenuService menuService, String menuItemId) async {
    try {
      // Récupérer les groupes existants depuis la base de données
      final existingItem = await menuService.getMenuItem(menuItemId);
      final existingGroups = existingItem?.optionGroups ?? [];
      
      // Créer des maps pour faciliter la recherche
      final existingGroupMap = {
        for (var group in existingGroups) group.id: group
      };
      final newGroupMap = {
        for (var group in _optionGroups.where((g) => g.id.isNotEmpty)) group.id: group
      };
      
      // Identifier les groupes à supprimer (existent en DB mais plus dans la nouvelle liste)
      final groupsToDelete = existingGroups
          .where((existing) => !newGroupMap.containsKey(existing.id))
          .toList();
      
      // Supprimer les groupes qui ne sont plus nécessaires (cascade supprime aussi les options)
      for (var groupToDelete in groupsToDelete) {
        await menuService.deleteOptionGroup(groupToDelete.id);
      }
      
      // Traiter chaque groupe de la nouvelle liste
      for (var newGroup in _optionGroups) {
        // Vérifier si le groupe existe déjà dans la base de données
        final isExistingGroup = existingGroupMap.containsKey(newGroup.id);
        
        if (!isExistingGroup) {
          // Nouveau groupe : créer le groupe et ses options
          // Ne pas inclure l'ID temporaire lors de la création
          final groupToCreate = MenuOptionGroup(
            id: '', // Laisser la DB générer l'ID
            menuItemId: menuItemId,
            name: newGroup.name,
            description: newGroup.description,
            minSelection: newGroup.minSelection,
            maxSelection: newGroup.maxSelection,
            isRequired: newGroup.isRequired,
            sortOrder: newGroup.sortOrder,
          );
          final createdGroup = await menuService.createOptionGroup(groupToCreate);
          
          if (createdGroup != null && newGroup.options.isNotEmpty) {
            for (var option in newGroup.options) {
              // Créer toutes les options comme nouvelles (ignorer les IDs temporaires)
              final optionToCreate = MenuOption(
                id: '', // Laisser la DB générer l'ID
                groupId: createdGroup.id,
                name: option.name,
                description: option.description,
                priceModifier: option.priceModifier,
                isAvailable: option.isAvailable,
                sortOrder: option.sortOrder,
              );
              await menuService.createOption(optionToCreate);
            }
          }
        } else {
          // Groupe existant : mettre à jour le groupe
          final groupToUpdate = newGroup.copyWith(menuItemId: menuItemId);
          await menuService.updateOptionGroup(groupToUpdate);
          
          // Synchroniser les options du groupe
          final existingGroup = existingGroupMap[newGroup.id];
          if (existingGroup != null) {
            final existingOptions = existingGroup.options;
            final existingOptionMap = {
              for (var opt in existingOptions) opt.id: opt
            };
            final newOptionMap = {
              for (var opt in newGroup.options) opt.id: opt
            };
            
            // Supprimer les options qui ne sont plus dans la nouvelle liste
            final optionsToDelete = existingOptions
                .where((existing) => !newOptionMap.containsKey(existing.id))
                .toList();
            
            for (var optionToDelete in optionsToDelete) {
              await menuService.deleteOption(optionToDelete.id);
            }
            
            // Créer ou mettre à jour les options
            for (var newOption in newGroup.options) {
              if (!existingOptionMap.containsKey(newOption.id)) {
                // Nouvelle option : créer (ignorer l'ID temporaire)
                final optionToCreate = MenuOption(
                  id: '', // Laisser la DB générer l'ID
                  groupId: newGroup.id,
                  name: newOption.name,
                  description: newOption.description,
                  priceModifier: newOption.priceModifier,
                  isAvailable: newOption.isAvailable,
                  sortOrder: newOption.sortOrder,
                );
                await menuService.createOption(optionToCreate);
              } else {
                // Option existante : mettre à jour
                await menuService.updateOption(newOption.copyWith(groupId: newGroup.id));
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la synchronisation des optionGroups: $e');
      // Ne pas faire échouer la sauvegarde complète si la sync échoue
      // L'utilisateur pourra réessayer ou gérer manuellement
    }
  }

  Future<void> _saveMenuItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) return;

    try {
      final menuService = Provider.of<MenuService>(context, listen: false);

      // Créer l'objet MenuItem de base
      final newItem = MenuItem(
        id: widget.menuItem?.id ?? '',
        categoryId: _selectedCategoryId!,
        name: _nameController.text,
        description: _descriptionController.text,
        basePrice: double.parse(_priceController.text),
        imageUrl: _imageUrlController.text,
        isAvailable: _isAvailable,
        isPopular: _isPopular,
        isVegetarian: _isVegetarian,
        isVegan: _isVegan,
        optionGroups: _optionGroups, // Les optionGroups sont sauvegardés séparément dans _saveMenuItem
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool success;
      if (widget.menuItem == null) {
        final createdItem = await menuService.createMenuItem(newItem);
        success = createdItem != null;
        // Sauvegarder les optionGroups séparément car Supabase ne gère pas les nested writes complexes
        if (success && _optionGroups.isNotEmpty) {
          for (var group in _optionGroups) {
            // Créer le groupe sans l'ID temporaire (laisser la DB générer l'ID)
            final groupToCreate = MenuOptionGroup(
              id: '', // Laisser la DB générer l'ID
              menuItemId: createdItem.id,
              name: group.name,
              description: group.description,
              minSelection: group.minSelection,
              maxSelection: group.maxSelection,
              isRequired: group.isRequired,
              sortOrder: group.sortOrder,
            );
            final createdGroup = await menuService.createOptionGroup(groupToCreate);
            if (createdGroup != null && group.options.isNotEmpty) {
              for (var option in group.options) {
                // Créer l'option sans l'ID temporaire (laisser la DB générer l'ID)
                final optionToCreate = MenuOption(
                  id: '', // Laisser la DB générer l'ID
                  groupId: createdGroup.id,
                  name: option.name,
                  description: option.description,
                  priceModifier: option.priceModifier,
                  isAvailable: option.isAvailable,
                  sortOrder: option.sortOrder,
                );
                await menuService.createOption(optionToCreate);
              }
            }
          }
        }
      } else {
        success = await menuService.updateMenuItem(newItem);
        // Synchroniser les optionGroups séparément car Supabase ne gère pas les nested writes complexes
        if (success) {
          await _syncOptionGroups(menuService, newItem.id);
        }
      }

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          widget.onSaved?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Article enregistré'),
                backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erreur lors de l\'enregistrement'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving item: $e');
    }
  }
}
