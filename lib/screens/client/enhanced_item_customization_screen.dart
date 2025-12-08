import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/customization_service.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';

/// Écran de personnalisation amélioré avec tabs et fonctionnalités modernes
class EnhancedItemCustomizationScreen extends StatefulWidget {
  final MenuItem item;
  final Function(MenuItem item, int quantity, Map<String, dynamic> customizations)? onAddToCart;

  const EnhancedItemCustomizationScreen({
    required this.item, 
    this.onAddToCart,
    super.key,
  });

  @override
  State<EnhancedItemCustomizationScreen> createState() =>
      _EnhancedItemCustomizationScreenState();
}

class _EnhancedItemCustomizationScreenState
    extends State<EnhancedItemCustomizationScreen>
    with SingleTickerProviderStateMixin {
  late String _sessionId;
  late String _menuItemId;
  late TabController _tabController;
  final TextEditingController _instructionsController = TextEditingController();
  int _quantity = 1;
  String? _selectedSizeId;

  // Catégories de personnalisation
  static const List<String> _customizationTabs = [
    'Taille',
    'Ingrédient',
    'Sauces',
    'Supplém',
  ];

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _menuItemId = widget.item.id;
    _tabController = TabController(
      length: _customizationTabs.length,
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCustomization();
    });
  }

  Future<void> _initializeCustomization() async {
    final service = Provider.of<CustomizationService>(context, listen: false);
    if (!service.isInitialized) {
      await service.initialize();
    }
    await service.startCustomization(
      _sessionId,
      _menuItemId,
      widget.item.name,
    );
    
    // Sélectionner la taille par défaut si disponible
    final optionsByCategory = service.getOptionsByCategory(
      _menuItemId,
      fallbackName: widget.item.name,
    );
    final sizeOptions = optionsByCategory['size'] ?? [];
    if (sizeOptions.isNotEmpty) {
      final defaultSize = sizeOptions.firstWhere(
        (opt) => opt.isDefault,
        orElse: () => sizeOptions.first,
      );
      _selectedSizeId = defaultSize.id;
      service.updateSelection(_sessionId, 'size', defaultSize.id, true);
    }
  }

  @override
  void dispose() {
    Provider.of<CustomizationService>(context, listen: false)
        .clearCustomization(_sessionId);
    _instructionsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Hero section avec image du produit
          _buildHeroSection(),
          // Tabs de personnalisation
          _buildTabs(),
          // Contenu selon le tab sélectionné
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSizeTab(),
                _buildIngredientsTab(),
                _buildSaucesTab(),
                _buildSupplementsTab(),
              ],
            ),
          ),
          // Instructions spéciales
          _buildSpecialInstructions(),
          // Résumé et actions
          _buildSummaryAndActions(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Personnaliser ${widget.item.name.length > 20 ? '${widget.item.name.substring(0, 20)}...' : widget.item.name}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.reviews_outlined),
          tooltip: 'Avis des clients',
          onPressed: () => context.navigateToProductReviews(widget.item),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Image de fond
          if (widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                widget.item.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  );
                },
              ),
            )
          else
            Container(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          // Overlay avec informations
          Positioned(
            left: 16,
            bottom: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.item.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (widget.item.calories > 0) ...[
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.item.calories} cal',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Icon(
                      Icons.access_time,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.item.preparationTime} min',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: AppColors.primary,
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
        tabs: _customizationTabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _buildSizeTab() {
    return Consumer<CustomizationService>(
      builder: (context, service, _) {
        final optionsByCategory = service.getOptionsByCategory(
          _menuItemId,
          fallbackName: widget.item.name,
        );
        final sizeOptions = optionsByCategory['size'] ?? [];

        if (sizeOptions.isEmpty) {
          return _buildEmptyState('Aucune option de taille disponible');
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Choisissez la taille',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...sizeOptions.map((option) => _buildSizeOption(option, service)),
          ],
        );
      },
    );
  }

  Widget _buildSizeOption(CustomizationOption option, CustomizationService service) {
    final isSelected = _selectedSizeId == option.id;
    final basePrice = widget.item.price;
    final sizePrice = basePrice + option.priceModifier;
    final priceDifference = option.priceModifier;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: RadioListTile<String>(
        value: option.id,
        groupValue: _selectedSizeId,
        onChanged: (value) {
          setState(() {
            _selectedSizeId = value;
          });
          service.updateSelection(_sessionId, 'size', value!, true);
          // Désélectionner les autres tailles
          final optionsByCategory = service.getOptionsByCategory(
            _menuItemId,
            fallbackName: widget.item.name,
          );
          final allSizes = optionsByCategory['size'] ?? [];
          for (final size in allSizes) {
            if (size.id != value) {
              service.updateSelection(_sessionId, 'size', size.id, false);
            }
          }
        },
        activeColor: AppColors.primary,
        title: Text(
          option.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (option.description != null) ...[
              const SizedBox(height: 4),
              Text(
                option.description!,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  PriceFormatter.format(sizePrice),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                if (priceDifference != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priceDifference > 0
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      priceDifference > 0
                          ? '+${PriceFormatter.format(priceDifference)}'
                          : PriceFormatter.format(priceDifference),
                      style: TextStyle(
                        color: priceDifference > 0
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsTab() {
    return Consumer<CustomizationService>(
      builder: (context, service, _) {
        final optionsByCategory = service.getOptionsByCategory(
          _menuItemId,
          fallbackName: widget.item.name,
        );
        final ingredientOptions = optionsByCategory['ingredient'] ?? [];

        if (ingredientOptions.isEmpty) {
          return _buildEmptyState('Aucun ingrédient supplémentaire disponible');
        }

        final customization = service.getCurrentCustomization(_sessionId);
        final selectedIds = customization?.selections['ingredient'] ?? <String>[];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Ingrédients',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...ingredientOptions.map((option) => _buildIngredientOption(
                  option,
                  service,
                  selectedIds.contains(option.id),
                ),),
          ],
        );
      },
    );
  }

  Widget _buildIngredientOption(
    CustomizationOption option,
    CustomizationService service,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          service.updateSelection(
            _sessionId,
            'ingredient',
            option.id,
            value ?? false,
          );
        },
        activeColor: AppColors.primary,
        title: Text(
          option.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (option.description != null) ...[
              const SizedBox(height: 4),
              Text(
                option.description!,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
            if (option.allergens != null && option.allergens!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: option.allergens!.map((allergen) {
                  return Chip(
                    label: Text(
                      allergen,
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.orange.shade50,
                    labelStyle: TextStyle(color: Colors.orange.shade900),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        secondary: Text(
          option.priceModifier > 0
              ? '+${PriceFormatter.format(option.priceModifier)}'
              : 'Gratuit',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSaucesTab() {
    return Consumer<CustomizationService>(
      builder: (context, service, _) {
        final optionsByCategory = service.getOptionsByCategory(
          _menuItemId,
          fallbackName: widget.item.name,
        );
        final sauceOptions = optionsByCategory['sauce'] ?? [];

        if (sauceOptions.isEmpty) {
          return _buildEmptyState('Aucune option disponible');
        }

        final customization = service.getCurrentCustomization(_sessionId);
        final selectedIds = customization?.selections['sauce'] ?? <String>[];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Sauces',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...sauceOptions.map((option) => _buildSauceOption(
                  option,
                  service,
                  selectedIds.contains(option.id),
                ),),
          ],
        );
      },
    );
  }

  Widget _buildSauceOption(
    CustomizationOption option,
    CustomizationService service,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          service.updateSelection(
            _sessionId,
            'sauce',
            option.id,
            value ?? false,
          );
        },
        activeColor: AppColors.primary,
        title: Text(
          option.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: option.description != null
            ? Text(
                option.description!,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              )
            : null,
        secondary: Text(
          option.priceModifier > 0
              ? '+${PriceFormatter.format(option.priceModifier)}'
              : 'Gratuit',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSupplementsTab() {
    return Consumer<CustomizationService>(
      builder: (context, service, _) {
        final optionsByCategory = service.getOptionsByCategory(
          _menuItemId,
          fallbackName: widget.item.name,
        );
        final supplementOptions = optionsByCategory['extra'] ?? [];

        if (supplementOptions.isEmpty) {
          return _buildEmptyState('Aucun supplément disponible');
        }

        final customization = service.getCurrentCustomization(_sessionId);
        final selectedIds = customization?.selections['extra'] ?? <String>[];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Suppléments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...supplementOptions.map((option) => _buildSupplementOption(
                  option,
                  service,
                  selectedIds.contains(option.id),
                ),),
          ],
        );
      },
    );
  }

  Widget _buildSupplementOption(
    CustomizationOption option,
    CustomizationService service,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          service.updateSelection(
            _sessionId,
            'extra',
            option.id,
            value ?? false,
          );
        },
        activeColor: AppColors.primary,
        title: Text(
          option.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: option.description != null
            ? Text(
                option.description!,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              )
            : null,
        secondary: Text(
          option.priceModifier > 0
              ? '+${PriceFormatter.format(option.priceModifier)}'
              : 'Gratuit',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Instructions spéciales',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _instructionsController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ex: Sans oignons, bien cuit, etc.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.edit_note),
            ),
            onChanged: (value) {
              final service =
                  Provider.of<CustomizationService>(context, listen: false);
              service.updateSpecialInstructions(_sessionId, value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAndActions() {
    return Consumer<CustomizationService>(
      builder: (context, service, _) {
        final customization = service.getCurrentCustomization(_sessionId);
        final priceModifier = customization?.totalPriceModifier ?? 0.0;
        
        // Calculer le prix de base selon la taille sélectionnée
        double basePrice = widget.item.price;
        if (_selectedSizeId != null) {
          final optionsByCategory = service.getOptionsByCategory(
            _menuItemId,
            fallbackName: widget.item.name,
          );
          final sizeOptions = optionsByCategory['size'] ?? [];
          if (sizeOptions.isNotEmpty) {
            final selectedSize = sizeOptions.firstWhere(
              (opt) => opt.id == _selectedSizeId,
              orElse: () => sizeOptions.first,
            );
            basePrice = widget.item.price + selectedSize.priceModifier;
          }
        }
        
        final totalPrice = (basePrice + priceModifier) * _quantity;
        final selectedSizeName = _getSelectedSizeName(service);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Résumé
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Résumé',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.item.name} x$_quantity',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            PriceFormatter.format(basePrice * _quantity),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (selectedSizeName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Taille: $selectedSizeName',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (priceModifier > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Options supplémentaires',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '+${PriceFormatter.format(priceModifier * _quantity)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            PriceFormatter.format(totalPrice),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Quantité et bouton
                Row(
                  children: [
                    // Sélecteur de quantité
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: _quantity > 1
                                ? () {
                                    setState(() {
                                      _quantity--;
                                    });
                                  }
                                : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                _quantity++;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Bouton ajouter au panier
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _addToCart(service, totalPrice),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Ajouter au panier',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _getSelectedSizeName(CustomizationService service) {
    if (_selectedSizeId == null) return null;
    final optionsByCategory = service.getOptionsByCategory(
      _menuItemId,
      fallbackName: widget.item.name,
    );
    final sizeOptions = optionsByCategory['size'] ?? [];
    if (sizeOptions.isEmpty) return null;
    try {
      final selectedSize = sizeOptions.firstWhere(
        (opt) => opt.id == _selectedSizeId,
      );
      return selectedSize.name;
    } catch (_) {
      return null;
    }
  }

  Future<void> _addToCart(
    CustomizationService service,
    double totalPrice,
  ) async {
    try {
      final customization = service.finishCustomization(_sessionId);
      if (customization == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la personnalisation'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final cartService = Provider.of<CartService>(context, listen: false);
      
      // Créer un MenuItem avec le prix personnalisé
      final customizedItem = widget.item.copyWith(price: totalPrice / _quantity);
      
      // Préparer les customizations pour le panier
      final customizationsMap = <String, dynamic>{
        'quantity': _quantity,
        'special_instructions': _instructionsController.text.trim().isNotEmpty
            ? _instructionsController.text.trim()
            : null,
      };
      
      // Ajouter les sélections par catégorie
      for (final entry in customization.selections.entries) {
        customizationsMap[entry.key] = entry.value;
      }

      if (widget.onAddToCart != null) {
        widget.onAddToCart!(
          customizedItem,
          _quantity,
          customizationsMap,
        );
      } else {
        // Ajouter au panier avec la quantité
        cartService.addItem(
          customizedItem,
          quantity: _quantity,
          customizations: customizationsMap,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_quantity x ${widget.item.name} ajouté${_quantity > 1 ? 's' : ''} au panier !'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

