import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:admin/presentation/regimes_article.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/services/menu_service.dart';
import 'package:admin/services/category_management_service.dart';
import 'package:admin/widgets/custom_button.dart';
import 'package:admin/screens/admin/option_groups_editor.dart'; // Import du nouveau widget
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

class MenuItemFormDialog extends StatefulWidget {
  final eccore.ManagedMenuItem? menuItem;
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
  List<eccore.OptionGroup> _optionGroups = [];

  /// Photo choisie pour un article **qui n'existe pas encore** — envoyée juste
  /// après sa création, faute d'identifiant à qui l'attacher avant.
  XFile? _pendingImage;
  Uint8List? _pendingImageBytes;

  late TabController _tabController;

  /// Vignette du cadre de photo.
  ///
  /// La photo en attente prime sur l'URL enregistrée : c'est le dernier choix
  /// de l'exploitant, et il doit se voir avant même d'avoir été envoyé —
  /// depuis les octets en mémoire, un fichier pas encore parti n'ayant pas
  /// d'adresse.
  DecorationImage? _apercu() {
    if (_isUploadingImage) return null;

    final octets = _pendingImageBytes;
    if (octets != null) {
      return DecorationImage(image: MemoryImage(octets), fit: BoxFit.cover);
    }

    if (_imageUrlController.text.isEmpty) return null;
    return DecorationImage(
      image: NetworkImage(_imageUrlController.text),
      fit: BoxFit.cover,
    );
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
      final existant = widget.menuItem?.id;

      // Article pas encore créé : la photo attend son identifiant. Voir
      // `_saveMenuItem`, qui l'envoie une fois la création aboutie.
      if (existant == null || existant.isEmpty) {
        final octets = await image.readAsBytes();
        if (!mounted) return;

        setState(() {
          _pendingImage = image;
          _pendingImageBytes = octets;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Photo retenue — elle sera envoyée à l’enregistrement du produit',
            ),
          ),
        );
        return;
      }

      setState(() {
        _isUploadingImage = true;
      });

      try {
        if (!mounted || !context.mounted) return;
        final menuService = Provider.of<MenuService>(context, listen: false);

        final imageUrl = await menuService.uploadProductImage(
          menuItemId: existant,
          image: image,
        );

        if (imageUrl != null && mounted) {
          setState(() {
            _imageUrlController.text = imageUrl;
            _pendingImage = null;
            _pendingImageBytes = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image enregistrée'),
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
    _priceController = TextEditingController(text: item?.price.toMajorUnits().toStringAsFixed(0));
    _imageUrlController = TextEditingController(text: item?.image);

    _selectedCategoryId = item?.categoryId;
    _isAvailable = item?.isAvailable ?? true;
    _isPopular = item?.isPopular ?? false;
    _isVegetarian = item?.estVegetarien ?? false;
    _isVegan = item?.estVegan ?? false;
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
                          fontWeight: FontWeight.bold,),
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
                          icon: Icon(Icons.list_alt),),
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

  Widget _buildGeneralInfoTab(List<eccore.ManagedCategory> categories) {
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
                    image: _apercu(),
                  ),
                  child: _isUploadingImage
                      ? const Center(child: CircularProgressIndicator())
                      : (_apercu() == null
                          ? const Icon(Icons.add_photo_alternate,
                              size: 40, color: Colors.grey,)
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
                              ),)
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
              style: TextStyle(fontWeight: FontWeight.bold),),
          Wrap(
            spacing: 16,
            children: [
              FilterChip(
                label: const Text('Disponible'),
                selected: _isAvailable,
                onSelected: (val) => setState(() => _isAvailable = val),
                avatar: Icon(
                    _isAvailable ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,),
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
        for (final group in existingGroups) group.id: group,
      };
      final newGroupMap = {
        for (final group in _optionGroups.where((g) => g.id.isNotEmpty)) group.id: group,
      };
      
      // Identifier les groupes à supprimer (existent en DB mais plus dans la nouvelle liste)
      final groupsToDelete = existingGroups
          .where((existing) => !newGroupMap.containsKey(existing.id))
          .toList();
      
      // Supprimer les groupes qui ne sont plus nécessaires (cascade supprime aussi les options)
      for (final groupToDelete in groupsToDelete) {
        await menuService.deleteOptionGroup(groupToDelete.id);
      }
      
      // Traiter chaque groupe de la nouvelle liste
      for (final newGroup in _optionGroups) {
        // Vérifier si le groupe existe déjà dans la base de données
        final isExistingGroup = existingGroupMap.containsKey(newGroup.id);
        
        if (!isExistingGroup) {
          // Nouveau groupe : créer le groupe et ses options
          // Ne pas inclure l'ID temporaire lors de la création
          final createdGroup = await menuService.createOptionGroup(
            menuItemId: menuItemId,
            name: newGroup.name,
            minSelect: newGroup.minSelect,
            maxSelect: newGroup.maxSelect,
            sortOrder: newGroup.sortOrder,
          );
          
          if (createdGroup != null && newGroup.options.isNotEmpty) {
            for (final option in newGroup.options) {
              // Créer toutes les options comme nouvelles (ignorer les IDs temporaires)
              await menuService.createOption(
                groupId: createdGroup.id,
                name: option.name,
                priceModifier: option.priceDelta.toMajorUnits(),
                isAvailable: option.isAvailable,
                sortOrder: option.sortOrder,
              );
            }
          }
        } else {
          // Groupe existant : mettre à jour le groupe
          await menuService.updateOptionGroup(
            groupId: newGroup.id,
            name: newGroup.name,
            minSelect: newGroup.minSelect,
            maxSelect: newGroup.maxSelect,
            sortOrder: newGroup.sortOrder,
          );
          
          // Synchroniser les options du groupe
          final existingGroup = existingGroupMap[newGroup.id];
          if (existingGroup != null) {
            final existingOptions = existingGroup.options;
            final existingOptionMap = {
              for (final opt in existingOptions) opt.id: opt,
            };
            final newOptionMap = {
              for (final opt in newGroup.options) opt.id: opt,
            };
            
            // Supprimer les options qui ne sont plus dans la nouvelle liste
            final optionsToDelete = existingOptions
                .where((existing) => !newOptionMap.containsKey(existing.id))
                .toList();
            
            for (final optionToDelete in optionsToDelete) {
              await menuService.deleteOption(optionToDelete.id);
            }
            
            // Créer ou mettre à jour les options
            for (final newOption in newGroup.options) {
              if (!existingOptionMap.containsKey(newOption.id)) {
                // Nouvelle option : créer (ignorer l'ID temporaire)
                await menuService.createOption(
                  groupId: newGroup.id,
                  name: newOption.name,
                  priceModifier: newOption.priceDelta.toMajorUnits(),
                  isAvailable: newOption.isAvailable,
                  sortOrder: newOption.sortOrder,
                );
              } else {
                // Option existante : mettre à jour
                await menuService.updateOption(
                  optionId: newOption.id,
                  name: newOption.name,
                  priceModifier: newOption.priceDelta.toMajorUnits(),
                  isAvailable: newOption.isAvailable,
                  sortOrder: newOption.sortOrder,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      Journal.trace('Erreur lors de la synchronisation des optionGroups: $e');
      // Ne pas faire échouer la sauvegarde complète si la sync échoue
      // L'utilisateur pourra réessayer ou gérer manuellement
    }
  }

  Future<void> _saveMenuItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) return;

    try {
      final menuService = Provider.of<MenuService>(context, listen: false);

      // Les régimes partent entiers : la liste est ouverte côté serveur, et
      // n'y renvoyer que les deux cases de cet écran effacerait les autres.
      final regimes = Regimes.regimesAvec(
        widget.menuItem?.dietaryTags ?? const [],
        vegetarien: _isVegetarian,
        vegan: _isVegan,
      );

      bool success;
      if (widget.menuItem == null) {
        final createdItem = await menuService.createMenuItem(
          categoryId: _selectedCategoryId!,
          name: _nameController.text,
          basePrice: double.parse(_priceController.text),
          dietaryTags: regimes,
          description: _descriptionController.text,
          isAvailable: _isAvailable,
          isPopular: _isPopular,
        );
        success = createdItem != null;

        // La photo choisie avant que l'article existe : c'est maintenant
        // qu'elle trouve un article à qui s'attacher. Un échec ne défait pas la
        // création — l'article est enregistré, il lui manque son image.
        final enAttente = _pendingImage;
        if (success && enAttente != null) {
          await menuService.uploadProductImage(
            menuItemId: createdItem.id,
            image: enAttente,
          );
        }

        // Les groupes d'options s'écrivent après l'article : ils lui
        // appartiennent, et le contrat ne les accepte pas imbriqués.
        if (success && _optionGroups.isNotEmpty) {
          for (final group in _optionGroups) {
            final createdGroup = await menuService.createOptionGroup(
              menuItemId: createdItem.id,
              name: group.name,
              minSelect: group.minSelect,
              maxSelect: group.maxSelect,
              sortOrder: group.sortOrder,
            );
            if (createdGroup != null) {
              for (final option in group.options) {
                await menuService.createOption(
                  groupId: createdGroup.id,
                  name: option.name,
                  priceModifier: option.priceDelta.toMajorUnits(),
                  isAvailable: option.isAvailable,
                  sortOrder: option.sortOrder,
                );
              }
            }
          }
        }
      } else {
        final existant = widget.menuItem!;
        success = await menuService.updateMenuItem(
          menuItemId: existant.id,
          categoryId: _selectedCategoryId!,
          name: _nameController.text,
          basePrice: double.parse(_priceController.text),
          dietaryTags: regimes,
          description: _descriptionController.text,
          isAvailable: _isAvailable,
          isPopular: _isPopular,
          sortOrder: existant.sortOrder,
        );
        if (success) {
          await _syncOptionGroups(menuService, existant.id);
        }
      }

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          widget.onSaved?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Article enregistré'),
                backgroundColor: Colors.green,),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erreur lors de l\'enregistrement'),
                backgroundColor: Colors.red,),
          );
        }
      }
    } catch (e) {
      Journal.trace('Error saving item: $e');
    }
  }
}
