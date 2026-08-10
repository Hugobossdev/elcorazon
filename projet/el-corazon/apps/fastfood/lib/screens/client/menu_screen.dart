import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/catalogue.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/favorites_service.dart';
import 'package:elcora_fast/services/subscription_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/widgets/enhanced_app_bar_actions.dart';
// import '../../widgets/enhanced_animations.dart'; // Supprimé
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
// import '../../widgets/enhanced_search_bar.dart'; // Supprimé

/// Écran de menu
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _filterController;
  late AnimationController _searchController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _filterHeightAnimation;

  eccore.Category? _selectedCategory; // Utilise maintenant la classe eccore.Category
  String _searchQuery = '';
  bool _showFilters = false;
  bool _vegetarianOnly = false;
  bool _veganOnly = false;
  double _maxPrice = 5000.0;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Animation principale
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.easeOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.elasticOut,
      ),
    );

    // Animation des filtres
    _filterController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _filterHeightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _filterController,
        curve: Curves.easeInOut,
      ),
    );

    // Animation de recherche
    _searchController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _filterController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: CustomScrollView(
              slivers: [
                _buildEnhancedAppBar(),
                _buildSearchSection(),
                _buildCategoryFilters(),
                SliverToBoxAdapter(
                  child: _buildAdvancedFeaturesSection(context),
                ),
                if (_showFilters) _buildFiltersSection(),
                _buildMenuItems(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'menu_logo',
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/logo/logo.png',
                  height: 24,
                  width: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.restaurant_menu,
                      size: 20,
                      color: AppColors.primary,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Éléments décoratifs améliorés
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Message contextuel
              Positioned(
                bottom: 50,
                left: 16,
                right: 16,
                child: Consumer<AppService>(
                  builder: (context, appService, child) {
                    final itemCount = appService.menuItems.length;
                    return Text(
                      '$itemCount plats disponibles',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showFilters ? Icons.filter_list_off : Icons.filter_list,
            color: Colors.white,
          ),
          onPressed: _toggleFilters,
          tooltip:
              _showFilters ? 'Masquer les filtres' : 'Afficher les filtres',
        ),
        const EnhancedAppBarActions(),
      ],
    );
  }

  Widget _buildSearchSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _isSearching = value.isNotEmpty;
            });
            if (_isSearching) {
              _searchController.forward();
            } else {
              _searchController.reverse();
            }
          },
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Rechercher un plat, une catégorie...',
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 15,
            ),
            prefixIcon: AnimatedBuilder(
              animation: _searchController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  child: Transform.rotate(
                    angle: _searchController.value * 0.1,
                    child: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.clear_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _isSearching = false;
                      });
                      _searchController.reverse();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final filters = _getCategoryFilters();
    return SliverToBoxAdapter(
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filters.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              final isSelected = _selectedCategory == null;
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: FilterChip(
                  label: const Text('Tous'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                ),
              );
            }
            final filter = filters[index - 1];
            final isSelected = _selectedCategory?.name == filter;
            return Container(
              margin: const EdgeInsets.only(right: 12),
              child: FilterChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      // Trouver la catégorie depuis AppService
                      final appService =
                          Provider.of<AppService>(context, listen: false);
                      _selectedCategory = appService.menuCategories.firstWhere(
                        (c) =>
                            c.name.toLowerCase() == filter.toLowerCase(),
                        orElse: () => appService.menuCategories.isNotEmpty
                            ? appService.menuCategories.first
                            : throw StateError('No categories available'),
                      );
                    } else {
                      _selectedCategory = null;
                    }
                  });
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primary,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdvancedFeaturesSection(BuildContext context) {
    return const SizedBox.shrink();
  }

  List<String> _getCategoryFilters() {
    // Utiliser les catégories depuis AppService
    final appService = Provider.of<AppService>(context, listen: false);
    return appService.menuCategoryDisplayNames;
  }

  Widget _buildFiltersSection() {
    return SliverToBoxAdapter(
      child: SizeTransition(
        sizeFactor: _filterHeightAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DesignEnhancementService.createEnhancedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtres',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text(
                        'Réinitialiser',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        label: const Text('Végétarien'),
                        selected: _vegetarianOnly,
                        onSelected: (selected) {
                          setState(() {
                            _vegetarianOnly = selected;
                            if (selected) _veganOnly = false;
                          });
                        },
                        backgroundColor: AppColors.surface,
                        selectedColor: AppColors.success.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilterChip(
                        label: const Text('Végan'),
                        selected: _veganOnly,
                        onSelected: (selected) {
                          setState(() {
                            _veganOnly = selected;
                            if (selected) _vegetarianOnly = false;
                          });
                        },
                        backgroundColor: AppColors.surface,
                        selectedColor: AppColors.success.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Prix maximum: ${PriceFormatter.format(_maxPrice / 100)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor:
                        AppColors.primary.withValues(alpha: 0.2),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _maxPrice,
                    min: 500,
                    max: 10000,
                    divisions: 19,
                    onChanged: (value) {
                      setState(() {
                        _maxPrice = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItems() {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        if (!appService.isInitialized) {
          return SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(32),
              child: DesignEnhancementService.createEnhancedLoadingIndicator(
                message: 'Chargement du menu...',
              ),
            ),
          );
        }

        final filteredItems = _getFilteredItems(appService.menuItems);

        if (filteredItems.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: DesignEnhancementService.createEnhancedCard(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 80,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Aucun plat trouvé',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Essayez de modifier vos filtres',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    DesignEnhancementService.createEnhancedButton(
                      text: 'Réinitialiser les filtres',
                      onPressed: _clearFilters,
                      backgroundColor: AppColors.primary,
                      textColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Grouper les plats par catégorie
        final itemsByCategory =
            _groupItemsByCategory(filteredItems, appService.menuCategories);

        // Adapter le childAspectRatio en fonction de la taille de l'écran
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenWidth < 360 || screenHeight < 640;

        // Réduire childAspectRatio pour les petits écrans
        final childAspectRatio = isSmallScreen ? 0.52 : 0.56;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, categoryIndex) {
              final categoryEntry =
                  itemsByCategory.entries.toList()[categoryIndex];
              final category = categoryEntry.key;
              final items = categoryEntry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête de catégorie
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isSmallScreen ? 16 : 20,
                      categoryIndex == 0 ? (isSmallScreen ? 12 : 16) : 24,
                      isSmallScreen ? 16 : 20,
                      12,
                    ),
                    child: Row(
                      children: [
                        Text(
                          category.pastille,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            category.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${items.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Description de la catégorie (si disponible)
                  if (category.description.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isSmallScreen ? 16 : 20,
                        0,
                        isSmallScreen ? 16 : 20,
                        16,
                      ),
                      child: Text(
                        category.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  // Grille des plats de cette catégorie
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: isSmallScreen ? 12 : 16,
                        mainAxisSpacing: isSmallScreen ? 12 : 16,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, itemIndex) {
                        final item = items[itemIndex];
                        return Consumer<FavoritesService>(
                          builder: (context, favoritesService, child) {
                            final isFavorite =
                                favoritesService.isFavorite(item);
                            return DesignEnhancementService
                                .createEnhancedMenuItemCard(
                              item: item,
                              onTap: () =>
                                  context.navigateToItemCustomization(item),
                              onAddToCart: () {
                                Provider.of<CartService>(context, listen: false)
                                    .addItem(item);
                                context.showSuccessMessage(
                                  '${item.name} ajouté au panier !',
                                );
                              },
                              onFavoriteTap: () {
                                favoritesService.toggleFavorite(item);
                                if (isFavorite) {
                                  context.showSuccessMessage(
                                    '${item.name} retiré des favoris',
                                  );
                                } else {
                                  context.showSuccessMessage(
                                    '${item.name} ajouté aux favoris',
                                  );
                                }
                              },
                              isFavorite: isFavorite,
                              animationDelay: Duration(
                                milliseconds: 800 +
                                    (categoryIndex * 200) +
                                    (itemIndex * 100),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Espacement entre les catégories
                  if (categoryIndex < itemsByCategory.entries.length - 1)
                    const SizedBox(height: 24),
                ],
              );
            },
            childCount: itemsByCategory.entries.length,
          ),
        );
      },
    );
  }

  /// Groupe les plats par catégorie
  Map<eccore.Category, List<eccore.MenuItem>> _groupItemsByCategory(
    List<eccore.MenuItem> items,
    List<eccore.Category> categories,
  ) {
    final Map<eccore.Category, List<eccore.MenuItem>> grouped = {};

    // Indexé par **slug** : c'est ce que l'article porte. L'ancien modèle
    // local rangeait le slug dans son champ `id`, ce qui masquait l'écart ;
    // `eccore.Category.id` est l'UUID, et la recherche n'aurait rien trouvé.
    final categoryMap = {for (final cat in categories) cat.slug: cat};

    for (final item in items) {
      // Un article dont la catégorie n'est pas dans la liste est rangé à part
      // plutôt que dans la première venue.
      final category = categoryMap[item.categorySlug] ??
          eccore.Category(
            id: item.categorySlug.isEmpty ? 'inconnue' : item.categorySlug,
            restaurantSlug: '',
            name: 'Autres',
            slug: item.categorySlug,
            emoji: '🍽️',
            description: '',
            sortOrder: 999,
          );

      // Ajouter l'item à la catégorie
      grouped.putIfAbsent(category, () => []).add(item);
    }

    // Trier les catégories par sortOrder
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.sortOrder.compareTo(b.key.sortOrder));

    return Map.fromEntries(sortedEntries);
  }

  List<eccore.MenuItem> _getFilteredItems(List<eccore.MenuItem> items) {
    // Droit VIP : un abonnement en cours côté backend (`loyalty/subscriptions`),
    // et non plus le nom d'un plan lu dans le portefeuille local.
    final isVipPremium =
        Provider.of<SubscriptionService>(context).hasActiveSubscription;

    return items.where((item) {
      // VIP Exclusive filter
      if (item.vipExclusive && !isVipPremium) {
        return false;
      }

      // Le filtre porte sur le slug, seul identifiant que l'article partage
      // avec la catégorie.
      if (_selectedCategory != null &&
          item.categorySlug != _selectedCategory!.slug) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty &&
          !item.name.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !item.description
              .toLowerCase()
              .contains(_searchQuery.toLowerCase())) {
        return false;
      }

      // Diet filters
      if (_vegetarianOnly && !item.estVegetarien) return false;
      if (_veganOnly && !item.estVegan) return false;

      // Price filter
      if (item.prixAffiche > _maxPrice) return false;

      return true;
    }).toList();
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
    if (_showFilters) {
      _filterController.forward();
    } else {
      _filterController.reverse();
    }
  }

  void _clearFilters() {
    setState(() {
      _vegetarianOnly = false;
      _veganOnly = false;
      _maxPrice = 5000.0;
      _searchQuery = '';
      _selectedCategory = null;
      _isSearching = false;
    });
    _searchController.reverse();
  }
}
