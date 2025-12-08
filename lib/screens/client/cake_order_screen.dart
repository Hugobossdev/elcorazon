import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/customization_service.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/database_service.dart';
import 'package:elcora_fast/services/offline_sync_service.dart';
import 'package:elcora_fast/widgets/custom_button.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/theme.dart';

enum CakeDeliveryMethod { delivery, pickup }

/// Écran dédié aux commandes de gâteaux : catalogue prêt-à-commander
/// et configurateur complet pour les créations sur-mesure.
class CakeOrderScreen extends StatefulWidget {
  const CakeOrderScreen({super.key});

  @override
  State<CakeOrderScreen> createState() => _CakeOrderScreenState();
}

class _CakeOrderScreenState extends State<CakeOrderScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late String _customizationId;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  DateTime? _customDeliveryDate;
  TimeOfDay? _customDeliveryTime;
  bool _isSubmitting = false;
  CakeDeliveryMethod _deliveryMethod = CakeDeliveryMethod.delivery;

  final Map<String, int> _categorySelectionLimits = const {
    'filling': 2,
    'decoration': 3,
  };

  // Data loaded from Supabase
  List<MenuItem> _readyCakes = [];
  MenuItem? _customCakeItem;
  String? _dessertsCategoryId;
  bool _isLoading = true;
  String? _error;

  static const Set<String> _singleChoiceCategories = {
    'shape',
    'size',
    'flavor',
    'tiers',
    'icing',
    'dietary',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _customizationId = _generateCustomizationId();

    // Charger les données depuis Supabase
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCakesFromDatabase();
      await _initializeCustomization();
    });
  }

  Future<void> _loadCakesFromDatabase() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      final databaseService = appService.databaseService;

      // Charger les catégories pour trouver l'ID de la catégorie desserts
      final categories = await databaseService.getMenuCategories();
      final dessertsCategory = categories.firstWhere(
        (cat) =>
            cat['name']?.toString().toLowerCase() == 'desserts' ||
            cat['display_name']?.toString().toLowerCase().contains('dessert') ==
                true,
        orElse: () => categories.firstWhere(
          (cat) =>
              cat['name']?.toString().toLowerCase().contains('dessert') == true,
          orElse: () => {},
        ),
      );

      _dessertsCategoryId = dessertsCategory['id'] as String?;

      if (_dessertsCategoryId == null) {
        // Si aucune catégorie desserts n'est trouvée, utiliser tous les items disponibles
        debugPrint(
            '⚠️ Catégorie desserts non trouvée, chargement de tous les items',);
      }

      // Charger les gâteaux depuis la base de données
      final menuData = await databaseService.getMenuItems(
        categoryId: _dessertsCategoryId,
      );

      _readyCakes = menuData
          .map((data) => MenuItem.fromMap(data))
          .where((item) => item.isAvailable)
          .toList();

      // Créer ou charger le gâteau personnalisé
      await _loadOrCreateCustomCakeItem(databaseService);

      setState(() {
        _isLoading = false;
      });

      debugPrint('✅ Loaded ${_readyCakes.length} ready cakes from database');
    } catch (e) {
      debugPrint('❌ Error loading cakes from database: $e');
      setState(() {
        _error = 'Erreur lors du chargement des gâteaux: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOrCreateCustomCakeItem(
      DatabaseService databaseService,) async {
    try {
      // Chercher un item "Gâteau personnalisé" dans la base de données
      final menuData = await databaseService.getMenuItems();
      final customCake = menuData
          .map((data) => MenuItem.fromMap(data))
          .where((item) =>
              item.name.toLowerCase().contains('personnalisé') ||
              item.name.toLowerCase().contains('custom'),)
          .firstOrNull;

      if (customCake != null) {
        _customCakeItem = customCake;
        debugPrint('✅ Found custom cake item in database: ${customCake.id}');
        return;
      }

      // Si aucun n'existe, essayer de créer l'item dans la base de données
      if (_dessertsCategoryId != null && _dessertsCategoryId!.isNotEmpty) {
        try {
          const customCakeId = 'cake-custom-personnalise';
          final customCakeData = {
            'id': customCakeId,
            'name': 'Gâteau personnalisé',
            'description':
                'Composez votre gâteau idéal : forme, taille, saveur et décor. Créez une pièce unique sur-mesure pour toutes vos occasions spéciales.',
            'price': 20000.0,
            'category_id': _dessertsCategoryId,
            'image_url':
                'https://images.unsplash.com/photo-1542281286-9e0a16bb7366?auto=format&fit=crop&w=600&q=80',
            'is_popular': true,
            'is_available': true,
            'preparation_time': 90,
            'sort_order': 999,
            'is_vegetarian': false,
            'is_vegan': false,
          };

          await databaseService.createMenuItem(customCakeData);
          debugPrint('✅ Created custom cake item in database');

          // Recharger l'item depuis la base de données
          final createdItemData =
              await databaseService.getMenuItemById(customCakeId);
          if (createdItemData != null) {
            _customCakeItem = MenuItem.fromMap(createdItemData);
            return;
          }
        } catch (createError) {
          debugPrint(
              '⚠️ Could not create custom cake item in database: $createError',);
          // Continue avec l'item par défaut en mémoire
        }
      }

      // Créer un item par défaut si la création en DB a échoué ou si pas de catégorie
      _customCakeItem = MenuItem(
        id: 'cake-custom-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Gâteau personnalisé',
        description:
            'Composez votre gâteau idéal : forme, taille, saveur et décor.',
        price: 20000,
        categoryId: _dessertsCategoryId ?? '',
        imageUrl:
            'https://images.unsplash.com/photo-1542281286-9e0a16bb7366?auto=format&fit=crop&w=600&q=80',
        isPopular: true,
        preparationTime: 90,
      );
      debugPrint('⚠️ Custom cake item not found, using default in-memory item');
    } catch (e) {
      debugPrint('❌ Error loading custom cake item: $e');
      // Fallback vers un item par défaut
      _customCakeItem = MenuItem(
        id: 'cake-custom-default',
        name: 'Gâteau personnalisé',
        description:
            'Composez votre gâteau idéal : forme, taille, saveur et décor.',
        price: 20000,
        categoryId: _dessertsCategoryId ?? '',
        imageUrl:
            'https://images.unsplash.com/photo-1542281286-9e0a16bb7366?auto=format&fit=crop&w=600&q=80',
        isPopular: true,
        preparationTime: 90,
      );
    }
  }

  Future<void> _initializeCustomization() async {
    if (_customCakeItem == null) {
      debugPrint(
          '⚠️ _customCakeItem est null, impossible d\'initialiser la personnalisation',);
      return;
    }

    try {
      final customizationService =
          Provider.of<CustomizationService>(context, listen: false);

      // S'assurer que le service est initialisé
      if (!customizationService.isInitialized) {
        debugPrint('🔄 Initialisation du service de personnalisation...');
        await customizationService.initialize();
      }

      debugPrint(
          '🎂 Démarrage de la personnalisation pour: ${_customCakeItem!.name} (${_customCakeItem!.id})',);

      await customizationService.startCustomization(
        _customizationId,
        _customCakeItem!.id,
        _customCakeItem!.name,
      );

      debugPrint('✅ Personnalisation initialisée avec succès');

      // Forcer un rebuild pour afficher les options
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint(
          '❌ Erreur lors de l\'initialisation de la personnalisation: $e',);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des options: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    final customizationService =
        Provider.of<CustomizationService>(context, listen: false);
    customizationService.clearCustomization(_customizationId);
    _messageController.dispose();
    _contactController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commander un gâteau'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.cake_outlined), text: 'Catalogue'),
            Tab(icon: Icon(Icons.build), text: 'Personnaliser'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReadyMadeTab(theme),
          _buildCustomizationTab(theme),
        ],
      ),
    );
  }

  Widget _buildReadyMadeTab(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCakesFromDatabase,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_readyCakes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cake_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun gâteau disponible pour le moment',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _readyCakes.length,
      itemBuilder: (context, index) {
        final cake = _readyCakes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cake.imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    cake.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.cake,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cake.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cake.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          PriceFormatter.format(cake.price),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.add_shopping_cart_outlined),
                          label: const Text('Commander'),
                          onPressed: () => _handleReadyCakeOrder(cake),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomizationTab(ThemeData theme) {
    if (_isLoading || _customCakeItem == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              _isLoading
                  ? 'Chargement des gâteaux...'
                  : 'Gâteau personnalisé non disponible',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Consumer<CustomizationService>(
      builder: (context, service, child) {
        final optionsByCategory = service.getOptionsByCategory(
          _customCakeItem!.id,
          fallbackName: _customCakeItem!.name,
        );
        final customization = service.getCurrentCustomization(_customizationId);

        if (optionsByCategory.isEmpty || customization == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  'Chargement des options de personnalisation...',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        final priceModifier = service.calculatePriceModifier(_customizationId);
        final finalPrice = _customCakeItem!.price + priceModifier;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomizationSummary(theme, priceModifier, finalPrice),
              const SizedBox(height: 16),
              ...optionsByCategory.entries.map((entry) {
                final category = entry.key;
                final options = entry.value;
                final selectedIds =
                    customization.selections[category] ?? <String>[];
                final isSingleChoice =
                    _singleChoiceCategories.contains(category);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildCategorySection(
                    theme,
                    category: category,
                    options: options,
                    selectedIds: selectedIds,
                    singleChoice: isSingleChoice,
                    service: service,
                  ),
                );
              }),
              const SizedBox(height: 12),
              _buildMessageField(theme, service),
              const SizedBox(height: 12),
              _buildDeliverySelectors(theme),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Ajouter au panier',
                icon: Icons.check_circle_outline,
                onPressed: _isSubmitting || _customCakeItem == null
                    ? null
                    : () => _confirmCustomCakeOrder(service),
                isLoading: _isSubmitting,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomizationSummary(
    ThemeData theme,
    double priceModifier,
    double finalPrice,
  ) {
    if (_customCakeItem == null) {
      return const SizedBox.shrink();
    }

    final customizationService =
        Provider.of<CustomizationService>(context, listen: false);
    final current =
        customizationService.getCurrentCustomization(_customizationId);
    final optionsByCategory = customizationService.getOptionsByCategory(
      _customCakeItem!.id,
      fallbackName: _customCakeItem!.name,
    );
    final optionLookup = <String, CustomizationOption>{};
    for (final entry in optionsByCategory.entries) {
      for (final option in entry.value) {
        optionLookup[option.id] = option;
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image du gâteau
          if (_customCakeItem!.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  Image.network(
                    _customCakeItem!.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.cake,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Badge "Personnalisé"
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.palette,
                            size: 16,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Sur mesure',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _customCakeItem!.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Base: ${PriceFormatter.format(_customCakeItem!.price)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (priceModifier > 0)
                          Text(
                            'Options: +${PriceFormatter.format(priceModifier)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        PriceFormatter.format(finalPrice),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (current != null)
                  ...current.selections.entries.expand((entry) {
                    final translated =
                        customizationService.translateCategory(entry.key);
                    final options = entry.value
                        .map((id) => optionLookup[id])
                        .whereType<CustomizationOption>()
                        .map((opt) =>
                            '${opt.name}${opt.priceModifier == 0 ? '' : ' (+${PriceFormatter.format(opt.priceModifier)})'}',)
                        .toList();
                    if (options.isEmpty) return const Iterable<Widget>.empty();
                    return [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '$translated :',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                options.join(', '),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  }),
                const SizedBox(height: 12),
                if (current != null && current.selections.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Votre sélection:',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...current.selections.entries.expand((entry) {
                          final translated =
                              customizationService.translateCategory(entry.key);
                          final options = entry.value
                              .map((id) => optionLookup[id])
                              .whereType<CustomizationOption>()
                              .map((opt) =>
                                  '${opt.name}${opt.priceModifier == 0 ? '' : ' (+${PriceFormatter.format(opt.priceModifier)})'}',)
                              .toList();
                          if (options.isEmpty) {
                            return const Iterable<Widget>.empty();
                          }
                          return [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '$translated :',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      options.join(', '),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ];
                        }),
                      ],
                    ),
                  ),
                if (current?.specialInstructions?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.message,
                          size: 16,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            current!.specialInstructions!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    ThemeData theme, {
    required String category,
    required List<CustomizationOption> options,
    required List<String> selectedIds,
    required bool singleChoice,
    required CustomizationService service,
  }) {
    final title = service.translateCategory(category);
    final maxSelections = _categorySelectionLimits[category];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedIds.contains(option.id);
            final priceSuffix = option.priceModifier == 0
                ? ''
                : ' (${option.priceModifier > 0 ? '+' : ''}${PriceFormatter.format(option.priceModifier)})';

            if (singleChoice) {
              return ChoiceChip(
                label: Text('${option.name}$priceSuffix'),
                selected: isSelected,
                selectedColor: theme.colorScheme.primaryContainer,
                checkmarkColor: theme.colorScheme.onPrimaryContainer,
                labelStyle: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  if (!selected) return;
                  _handleSingleSelection(
                      service, category, option.id, selectedIds,);
                },
              );
            }

            return FilterChip(
              label: Text('${option.name}$priceSuffix'),
              selected: isSelected,
              selectedColor: theme.colorScheme.secondaryContainer,
              checkmarkColor: theme.colorScheme.onSecondaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) {
                if (selected &&
                    maxSelections != null &&
                    selectedIds.length >= maxSelections) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Vous pouvez choisir au maximum $maxSelections option(s) pour $title.',),
                      backgroundColor: theme.colorScheme.errorContainer,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                _handleMultiSelection(service, category, option.id, selected);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMessageField(ThemeData theme, CustomizationService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Message sur le gâteau (optionnel)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _messageController,
          maxLength: 60,
          decoration: const InputDecoration(
            hintText: 'Ex: Joyeux anniversaire Jade !',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) =>
              service.updateSpecialInstructions(_customizationId, value.trim()),
        ),
      ],
    );
  }

  Widget _buildDeliverySelectors(ThemeData theme) {
    String dateLabel = 'Sélectionner une date de livraison';
    if (_customDeliveryDate != null) {
      dateLabel = _formatDate(_customDeliveryDate!);
    }

    String timeLabel = 'Sélectionner une heure de livraison';
    if (_customDeliveryTime != null && context.mounted) {
      timeLabel = _customDeliveryTime!.format(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Planification & retrait',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<CakeDeliveryMethod>(
                value: CakeDeliveryMethod.delivery,
                groupValue: _deliveryMethod,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _deliveryMethod = value;
                  });
                },
                title: const Text('Livraison'),
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<CakeDeliveryMethod>(
                value: CakeDeliveryMethod.pickup,
                groupValue: _deliveryMethod,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _deliveryMethod = value;
                  });
                },
                title: const Text('Retrait en boutique'),
                dense: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _contactController,
          decoration: const InputDecoration(
            labelText: 'Contact (téléphone ou email)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.event_outlined),
              label: Text(dateLabel),
              onPressed: _pickCustomDeliveryDate,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule_outlined),
              label: Text(timeLabel),
              onPressed:
                  _customDeliveryDate == null ? null : _pickCustomDeliveryTime,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleReadyCakeOrder(MenuItem cake) async {
    final deliverySlot = await _pickDeliverySlot(context);
    if (deliverySlot == null || !context.mounted) return;

    final cartService = Provider.of<CartService>(context, listen: false);
    final offlineSyncService =
        Provider.of<OfflineSyncService>(context, listen: false);

    try {
      cartService.addItem(
        cake,
        customizations: {
          'Livraison':
              '${deliverySlot['dateDisplay']} à ${deliverySlot['timeDisplay']}',
          'Date ISO': deliverySlot['dateIso'],
          'Heure': deliverySlot['timeDisplay'],
          'Type': 'Gâteau prêt',
        },
      );

      if (!mounted) return;

      final isOnline = offlineSyncService.isOnline;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${cake.name} ajouté au panier !',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (!isOnline)
                      Text(
                        'Sauvegardé hors ligne - synchronisation automatique',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showError('Erreur lors de l\'ajout au panier: ${e.toString()}');
      }
      debugPrint('❌ Error adding ready cake to cart: $e');
    }
  }

  Future<void> _confirmCustomCakeOrder(CustomizationService service) async {
    if (_customCakeItem == null) {
      _showError('Gâteau personnalisé non disponible. Veuillez réessayer.');
      return;
    }

    // Vérifier que la personnalisation existe
    final customization = service.getCurrentCustomization(_customizationId);
    if (customization == null) {
      _showError(
          'Erreur: Personnalisation introuvable. Veuillez réinitialiser.',);
      // Réinitialiser la personnalisation
      await _initializeCustomization();
      return;
    }

    // Validation des options de personnalisation requises pour les gâteaux
    final validation =
        service.validateCustomization(_customizationId, _customCakeItem!.name);
    if (validation['isValid'] != true) {
      final errors = (validation['errors'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      
      // Vérifier les options requises pour les gâteaux
      final requiredCategories = ['shape', 'size', 'flavor', 'tiers', 'icing', 'dietary'];
      final missingRequired = <String>[];
      
      for (final category in requiredCategories) {
        final selections = customization.selections[category] ?? [];
        if (selections.isEmpty) {
          final categoryName = service.translateCategory(category);
          missingRequired.add(categoryName);
        }
      }
      
      if (missingRequired.isNotEmpty) {
        _showError(
          'Veuillez sélectionner les options requises : ${missingRequired.join(', ')}',
        );
        setState(() => _isSubmitting = false);
        return;
      }
      
      // Pour les autres erreurs, afficher un avertissement
      if (errors.isNotEmpty) {
        debugPrint('⚠️ Avertissements de validation: ${errors.join('\n')}');
      }
    }

    // Validation de la date et heure
    if (_customDeliveryDate == null || _customDeliveryTime == null) {
      _showError(
          'Veuillez sélectionner la date et l\'heure de livraison/retrait.',);
      setState(() => _isSubmitting = false);
      return;
    }

    // Validation de la date (minimum 24h à l'avance pour les gâteaux personnalisés)
    final selectedDateTime = DateTime(
      _customDeliveryDate!.year,
      _customDeliveryDate!.month,
      _customDeliveryDate!.day,
      _customDeliveryTime!.hour,
      _customDeliveryTime!.minute,
    );
    final now = DateTime.now();
    final difference = selectedDateTime.difference(now);

    if (difference.isNegative) {
      _showError('La date et l\'heure sélectionnées sont dans le passé.');
      setState(() => _isSubmitting = false);
      return;
    }

    if (difference.inHours < 24) {
      final hoursNeeded = 24 - difference.inHours;
      _showError(
          'Pour un gâteau personnalisé, veuillez commander au moins 24 heures à l\'avance. Il reste ${hoursNeeded} heure(s) avant la date sélectionnée.',);
      setState(() => _isSubmitting = false);
      return;
    }

    // Validation du contact si livraison
    if (_deliveryMethod == CakeDeliveryMethod.delivery &&
        (_contactController.text.trim().isEmpty)) {
      _showError(
          'Veuillez fournir un numéro de téléphone ou un email pour la livraison.',);
      return;
    }

    setState(() => _isSubmitting = true);

    final optionLookup = <String, CustomizationOption>{};
    final optionsByCategory = service.getOptionsByCategory(
      _customCakeItem!.id,
      fallbackName: _customCakeItem!.name,
    );
    for (final entry in optionsByCategory.entries) {
      for (final option in entry.value) {
        optionLookup[option.id] = option;
      }
    }

    final finishedCustomization = service.finishCustomization(_customizationId);
    if (finishedCustomization == null) {
      setState(() => _isSubmitting = false);
      _showError('Impossible de finaliser la personnalisation.');
      return;
    }

    final totalPrice =
        _customCakeItem!.price + finishedCustomization.totalPriceModifier;

    final customizationsMap = <String, dynamic>{
      'Type': 'Gâteau personnalisé',
    };

    finishedCustomization.selections.forEach((category, optionIds) {
      final labels = optionIds
          .map((id) => optionLookup[id]?.name ?? id)
          .toList(growable: false);
      final translatedCategory = service.translateCategory(category);
      customizationsMap[translatedCategory] = labels.join(', ');
    });

    if (finishedCustomization.specialInstructions?.isNotEmpty == true) {
      customizationsMap['Message'] = finishedCustomization.specialInstructions;
    }

    final deliveryDateIso = DateTime(
      _customDeliveryDate!.year,
      _customDeliveryDate!.month,
      _customDeliveryDate!.day,
      _customDeliveryTime!.hour,
      _customDeliveryTime!.minute,
    );

    customizationsMap['Mode'] = _deliveryMethod == CakeDeliveryMethod.delivery
        ? 'Livraison'
        : 'Retrait en boutique';
    customizationsMap['Livraison'] =
        '${_formatDate(_customDeliveryDate!)} à ${_customDeliveryTime!.format(context)}';
    customizationsMap['Date ISO'] = deliveryDateIso.toIso8601String();
    if (_contactController.text.trim().isNotEmpty) {
      customizationsMap['Contact'] = _contactController.text.trim();
    }
    if (customization.totalPriceModifier != 0) {
      customizationsMap['Supplément'] =
          PriceFormatter.format(customization.totalPriceModifier);
    }

    final cartService = Provider.of<CartService>(context, listen: false);
    final offlineSyncService =
        Provider.of<OfflineSyncService>(context, listen: false);

    try {
      cartService.addItem(
        _customCakeItem!.copyWith(price: totalPrice),
        customizations: customizationsMap,
      );

      if (!mounted) return;

      // Afficher un message selon le statut de connexion
      final isOnline = offlineSyncService.isOnline;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Gâteau personnalisé ajouté au panier !',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (!isOnline)
                      Text(
                        'Sauvegardé hors ligne - synchronisation automatique',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Réinitialiser pour une prochaine personnalisation
      await _resetCustomization(service);
      setState(() => _isSubmitting = false);
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Erreur lors de l\'ajout au panier: ${e.toString()}');
      debugPrint('❌ Error adding custom cake to cart: $e');
    }
  }

  Future<void> _resetCustomization(CustomizationService service) async {
    // Nettoyer la personnalisation précédente
    service.clearCustomization(_customizationId);
    
    // Générer un nouvel ID de personnalisation
    _customizationId = _generateCustomizationId();
    
    // Réinitialiser les champs
    _messageController.clear();
    _contactController.clear();
    _customDeliveryDate = null;
    _customDeliveryTime = null;
    _deliveryMethod = CakeDeliveryMethod.delivery;
    
    // Réinitialiser la personnalisation
    if (_customCakeItem != null) {
      await _initializeCustomization();
    }
    
    // Forcer un rebuild
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickCustomDeliveryDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );

    if (date != null) {
      setState(() {
        _customDeliveryDate = date;
        _customDeliveryTime = null; // reset time when date changes
      });
    }
  }

  Future<void> _pickCustomDeliveryTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (time != null) {
      setState(() => _customDeliveryTime = time);
    }
  }

  void _handleSingleSelection(
    CustomizationService service,
    String category,
    String optionId,
    List<String> currentlySelected,
  ) {
    // Désélectionner les autres options de la même catégorie
    for (final selectedId in currentlySelected) {
      if (selectedId != optionId) {
        service.updateSelection(
          _customizationId,
          category,
          selectedId,
          false,
        );
      }
    }

    // Sélectionner la nouvelle option
    service.updateSelection(
      _customizationId,
      category,
      optionId,
      true,
    );

    // Feedback visuel
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  void _handleMultiSelection(
    CustomizationService service,
    String category,
    String optionId,
    bool isSelected,
  ) {
    service.updateSelection(
      _customizationId,
      category,
      optionId,
      isSelected,
    );

    // Feedback visuel pour les sélections multiples
    if (mounted && isSelected) {
      final customization = service.getCurrentCustomization(_customizationId);
      final selectedCount = (customization?.selections[category] ?? []).length;
      final maxSelections = _categorySelectionLimits[category];
      
      if (maxSelections != null && selectedCount >= maxSelections) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Maximum atteint pour ${service.translateCategory(category)} ($maxSelections sélection(s))',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<Map<String, String>?> _pickDeliverySlot(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );

    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (time == null) return null;

    final dateIso = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    return {
      'dateIso': dateIso.toIso8601String(),
      'dateDisplay': _formatDate(date),
      'timeDisplay': time.format(context),
    };
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _generateCustomizationId() =>
      'cake_${DateTime.now().millisecondsSinceEpoch}';
}
