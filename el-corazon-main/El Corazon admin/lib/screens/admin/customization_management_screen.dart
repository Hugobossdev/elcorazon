import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/customization_management_service.dart';
import '../../utils/price_formatter.dart';
import 'customization_option_form_dialog.dart';
import 'customization_association_dialog.dart';

class CustomizationManagementScreen extends StatefulWidget {
  const CustomizationManagementScreen({super.key});

  @override
  State<CustomizationManagementScreen> createState() =>
      _CustomizationManagementScreenState();
}

class _CustomizationManagementScreenState
    extends State<CustomizationManagementScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'all',
    'size',
    'ingredient',
    'sauce',
    'extra',
    'cooking',
    'shape',
    'flavor',
    'filling',
    'decoration',
    'tiers',
    'icing',
    'dietary',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _translateCategory(String category) {
    switch (category) {
      case 'all':
        return 'Toutes';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<CustomizationManagementService>(
        builder: (context, service, child) {
          if (service.isLoading && service.options.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Filtrer les options
          var filteredOptions = service.options.where((option) {
            // Filtre par catégorie
            if (_selectedCategory != 'all' &&
                option.category != _selectedCategory) {
              return false;
            }

            // Filtre par recherche
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              return option.name.toLowerCase().contains(query) ||
                  (option.description?.toLowerCase().contains(query) ?? false);
            }

            return true;
          }).toList();

          // Grouper par catégorie
          final Map<String, List<CustomizationOptionModel>> groupedOptions = {};
          for (var option in filteredOptions) {
            groupedOptions.putIfAbsent(option.category, () => []);
            groupedOptions[option.category]!.add(option);
          }

          return Column(
            children: [
              // En-tête avec recherche et filtres
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Rechercher une option...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          _searchQuery = '';
                                          _searchController.clear();
                                        });
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await showDialog(
                              context: context,
                              builder: (context) =>
                                  const CustomizationOptionFormDialog(),
                            );
                            if (result == true) {
                              await service.refresh();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Nouvelle option'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Filtres par catégorie
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _categories.map((category) {
                          final isSelected = _selectedCategory == category;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(_translateCategory(category)),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory = category;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              // Liste des options
              Expanded(
                child: filteredOptions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tune_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Aucune option trouvée'
                                  : 'Aucune option de personnalisation',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (_searchQuery.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Créez votre première option',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: groupedOptions.length,
                        itemBuilder: (context, categoryIndex) {
                          final category = groupedOptions.keys
                              .elementAt(categoryIndex);
                          final options = groupedOptions[category]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  top: categoryIndex > 0 ? 24 : 0,
                                  bottom: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getCategoryIcon(category),
                                      size: 20,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _translateCategory(category),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text('${options.length}'),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                ),
                              ),
                              ...options.map((option) => _buildOptionCard(
                                    context,
                                    option,
                                    service,
                                  )),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'size':
        return Icons.straighten;
      case 'ingredient':
        return Icons.restaurant;
      case 'sauce':
        return Icons.water_drop;
      case 'extra':
        return Icons.add_circle;
      case 'cooking':
        return Icons.local_fire_department;
      case 'shape':
        return Icons.crop_square;
      case 'flavor':
        return Icons.emoji_food_beverage;
      case 'filling':
        return Icons.layers;
      case 'decoration':
        return Icons.auto_awesome;
      case 'tiers':
        return Icons.cake;
      case 'icing':
        return Icons.icecream;
      case 'dietary':
        return Icons.eco;
      default:
        return Icons.tune;
    }
  }

  Widget _buildOptionCard(
    BuildContext context,
    CustomizationOptionModel option,
    CustomizationManagementService service,
  ) {
    final theme = Theme.of(context);

    return _OptionCardWidget(
      option: option,
      service: service,
      theme: theme,
      onEdit: () async {
        final result = await showDialog(
          context: context,
          builder: (context) => CustomizationOptionFormDialog(
            option: option,
          ),
        );
        if (result == true) {
          await service.refresh();
        }
      },
      onAssociate: () async {
        await showDialog(
          context: context,
          builder: (context) => CustomizationAssociationDialog(
            optionId: option.id,
            optionName: option.name,
          ),
        );
        await service.refresh();
      },
      onDelete: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer l\'option'),
            content: Text(
              'Êtes-vous sûr de vouloir supprimer "${option.name}" ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          final success = await service.deleteOption(option.id);
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'Option supprimée'
                      : service.error ??
                          'Erreur lors de la suppression',
                ),
                backgroundColor: success ? Colors.green : Colors.red,
              ),
            );
            if (success) {
              await service.refresh();
            }
          }
        }
      },
    );
  }
}

class _OptionCardWidget extends StatefulWidget {
  final CustomizationOptionModel option;
  final CustomizationManagementService service;
  final ThemeData theme;
  final VoidCallback onEdit;
  final VoidCallback onAssociate;
  final VoidCallback onDelete;

  const _OptionCardWidget({
    required this.option,
    required this.service,
    required this.theme,
    required this.onEdit,
    required this.onAssociate,
    required this.onDelete,
  });

  @override
  State<_OptionCardWidget> createState() => _OptionCardWidgetState();
}

class _OptionCardWidgetState extends State<_OptionCardWidget> {
  bool _isHovered = false;

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'size':
        return Icons.straighten;
      case 'ingredient':
        return Icons.restaurant;
      case 'sauce':
        return Icons.water_drop;
      case 'extra':
        return Icons.add_circle;
      case 'cooking':
        return Icons.local_fire_department;
      case 'shape':
        return Icons.crop_square;
      case 'flavor':
        return Icons.emoji_food_beverage;
      case 'filling':
        return Icons.layers;
      case 'decoration':
        return Icons.auto_awesome;
      case 'tiers':
        return Icons.cake;
      case 'icing':
        return Icons.icecream;
      case 'dietary':
        return Icons.eco;
      default:
        return Icons.tune;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: _isHovered ? 4 : 1,
        child: InkWell(
          onTap: widget.onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icône de catégorie
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(widget.option.category),
                    color: widget.theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                // Informations de l'option
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.option.name,
                              style: widget.theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (widget.option.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Par défaut',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          if (!widget.option.isActive)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Inactive',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (widget.option.description != null &&
                          widget.option.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.option.description!,
                          style: widget.theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (widget.option.priceModifier != 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.option.priceModifier > 0
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.option.priceModifier > 0
                                    ? '+${formatPrice(widget.option.priceModifier)}'
                                    : formatPrice(widget.option.priceModifier),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: widget.option.priceModifier > 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Gratuit',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          if (widget.option.maxQuantity > 1) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Max: ${widget.option.maxQuantity}',
                              style: widget.theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                          if (widget.option.allergens.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Allergènes',
                              style: widget.theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        widget.onEdit();
                        break;
                      case 'associate':
                        widget.onAssociate();
                        break;
                      case 'delete':
                        widget.onDelete();
                        break;
                    }
                  },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Modifier'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'associate',
                          child: Row(
                            children: [
                              Icon(Icons.link, size: 20),
                              SizedBox(width: 8),
                              Text('Associer à un produit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Supprimer',
                                style: TextStyle(color: Colors.red),
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
          ),
        );
  }
}
