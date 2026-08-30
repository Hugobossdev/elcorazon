import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/catalogue.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/favorites_service.dart';
import 'package:elcora_fast/services/subscription_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/widgets/enhanced_app_bar_actions.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart';
import 'package:elcora_fast/widgets/menu_item_card.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: 'Le menu',
        showBack: false,
        centerTitle: false,
        actions: [
          GlassIconButton(
            icon: _showFilters
                ? Icons.filter_list_off_rounded
                : Icons.tune_rounded,
            tooltip: _showFilters
                ? 'Masquer les filtres'
                : 'Afficher les filtres',
            filled: _showFilters,
            onPressed: _toggleFilters,
          ),
          const EnhancedAppBarActions(),
        ],
      ),
      // Une ouverture en fondu et un léger glissement, sans le
      // `ScaleTransition` en `elasticOut` qui faisait tressauter la carte
      // entière à chaque venue sur l'écran : une liste qui rebondit se lit mal
      // et se touche encore plus mal, puisque les cibles bougent sous le doigt.
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: SizedBox(height: DesignConstants.spacingM),
              ),
              _buildSearchSection(),
              _buildCategoryFilters(),
              if (_showFilters) _buildFiltersSection(),
              _buildMenuItems(),
              const SliverToBoxAdapter(
                child: SizedBox(height: DesignConstants.spacingXL),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Champ de recherche du menu.
  ///
  /// Modifiable, contrairement à celui de l'accueil : ici il y a bien quelque
  /// chose à filtrer sous les doigts — toute la carte est à l'écran.
  ///
  /// Le compte de plats disponibles, que la barre rouge d'avant affichait dans
  /// son grand entête, est passé sous le champ : il tient en une ligne, se lit
  /// aussi bien, et rend les 140 px de bandeau décoratif à la carte elle-même.
  Widget _buildSearchSection() {
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DesignConstants.edgeMargin,
          0,
          DesignConstants.edgeMargin,
          DesignConstants.spacingS,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSearchField(
              hintText: 'Rechercher un plat, une catégorie…',
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
              trailing: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: theme.colorScheme.primary,
                      tooltip: 'Effacer la recherche',
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _isSearching = false;
                        });
                        _searchController.reverse();
                      },
                    ),
            ),
            const SizedBox(height: DesignConstants.spacingS),
            Consumer<AppService>(
              builder: (context, appService, child) {
                final nombre = appService.menuItems.length;
                if (nombre == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '$nombre plat${nombre > 1 ? 's' : ''} à la carte',
                    style: AppTypography.bodyMd(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Rail de catégories, en puces.
  ///
  /// Il remplace la rangée maison de `_pastilleCategorie` : même rendu, même
  /// comportement — pas de coche qui élargisse la puce au moment du choix et
  /// décale les suivantes sous le doigt — mais partagé avec l'accueil, où le
  /// même rail existait en double.
  Widget _buildCategoryFilters() {
    final filtres = _getCategoryFilters();
    final libelles = ['Tous', ...filtres];
    final retenue = _selectedCategory == null
        ? 0
        : filtres.indexWhere((f) => f == _selectedCategory!.name) + 1;

    return SliverToBoxAdapter(
      child: CategoryChipBar(
        labels: libelles,
        selectedIndex: retenue,
        onSelected: (index) {
          if (index == 0) {
            setState(() => _selectedCategory = null);
          } else {
            _selectionnerCategorie(libelles[index]);
          }
        },
      ),
    );
  }

  /// Retient la catégorie nommée [libelle], ou revient à « Tous » si le nom ne
  /// correspond à rien de connu.
  ///
  /// La version précédente se rabattait sur la **première** catégorie de la
  /// liste : cliquer sur « Desserts » pouvait afficher les entrées. Elle levait
  /// même une `StateError` quand le catalogue n'était pas encore chargé.
  void _selectionnerCategorie(String libelle) {
    final appService = Provider.of<AppService>(context, listen: false);
    final trouvee = appService.menuCategories
        .where((c) => c.name.toLowerCase() == libelle.toLowerCase())
        .firstOrNull;

    setState(() => _selectedCategory = trouvee);
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
          // Des silhouettes aux proportions des cartes, plutôt qu'un anneau
          // au centre d'un écran vide : la mise en page ne saute plus au
          // moment où le menu arrive.
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: DesignConstants.spacingM),
              child: FoodCardSkeletonList(),
            ),
          );
        }

        final filteredItems = _getFilteredItems(appService.menuItems);

        if (filteredItems.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: DesignConstants.spacingXL,
              ),
              child: EmptyStateWidget(
                title: 'Aucun plat trouvé',
                message: _searchQuery.isEmpty
                    ? 'Aucun plat ne correspond à ces filtres.'
                    : 'Aucun plat ne correspond à « $_searchQuery ».',
                icon: Icons.search_off_rounded,
                actionText: 'Réinitialiser les filtres',
                onAction: _clearFilters,
              ),
            ),
          );
        }

        // Grouper les plats par catégorie
        final itemsByCategory =
            _groupItemsByCategory(filteredItems, appService.menuCategories);

        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenWidth < 360 || screenHeight < 640;

        // Nombre de colonnes déduit d'une largeur de carte **souhaitée**, et
        // non figé à deux. Deux colonnes sur un navigateur de bureau donnaient
        // des cartes de 600 px de large pour une photo de 400 px ; six
        // colonnes de 200 px montrent la carte du restaurant, ce qu'on est
        // venu voir.
        final marge = isSmallScreen ? 12.0 : 16.0;
        final gouttiere = isSmallScreen ? 12.0 : 16.0;
        final grille = GeometrieGrille.calculer(
          context: context,
          largeurDisponible: screenWidth - 2 * marge,
          gouttiere: gouttiere,
        );

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
                  //
                  // Aligné sur la **même marge que la grille**. L'en-tête
                  // s'écartait de 16 ou 20 px quand les cartes commençaient à
                  // 12 ou 16 : le titre flottait de quelques pixels à droite
                  // de la colonne qu'il annonce.
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      marge,
                      categoryIndex == 0 ? (isSmallScreen ? 12 : 16) : 24,
                      marge,
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
                            // Sans limite, un intitulé long chassait le
                            // compteur hors de la ligne.
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.headlineSm(
                              color: Theme.of(context).colorScheme.onSurface,
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
                      padding: EdgeInsets.fromLTRB(marge, 0, marge, 16),
                      child: Text(
                        category.description,
                        style: AppTypography.bodyMd(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  // Grille des plats de cette catégorie
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: marge),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: grille.colonnes,
                        crossAxisSpacing: gouttiere,
                        mainAxisSpacing: gouttiere,
                        // Hauteur **réservée**, pas déduite d'un rapport : la
                        // carte annonce ce qu'il lui faut pour l'échelle de
                        // police en vigueur, la grille le lui accorde.
                        mainAxisExtent: grille.hauteurCellule,
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
                              onAddToCart: () =>
                                  context.addToCartOrCustomize(item),
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
