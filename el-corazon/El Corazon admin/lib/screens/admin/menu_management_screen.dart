import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/menu_models.dart';
import '../../services/menu_service.dart';
import '../../services/category_management_service.dart';
import '../../widgets/modern/modern_button.dart';
import '../../widgets/modern/modern_card.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/dialog_helper.dart';
import '../../utils/price_formatter.dart';
import 'menu_item_form_dialog.dart';
import 'category_management_screen.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;
  MenuFilter _currentFilter = MenuFilter.all;
  Future<List<MenuItem>>? _menuItemsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _searchController.addListener(_onSearchChanged);

    // Initialiser les catégories au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryService = context.read<CategoryManagementService>();
      categoryService.refreshCategories();

      // Si on a des catégories mais aucune sélectionnée, sélectionner la première par défaut (optionnel,
      // ici on laisse null pour "Toutes" ou on pourrait forcer)
    });
  }

  void _onTabChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        switch (_tabController.index) {
          case 0:
            _currentFilter = MenuFilter.all;
            break;
          case 1:
            _currentFilter = MenuFilter.available;
            break;
          case 2:
            _currentFilter = MenuFilter.unavailable;
            break;
        }
      });
    });
  }

  void _onSearchChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          // Sidebar des catégories (visible sur grands écrans ou drawer sur mobile)
          // Pour simplifier ici, on met une sidebar fixe de 250px
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Catégories',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Expanded(
                  child: Consumer<CategoryManagementService>(
                    builder: (context, categoryService, child) {
                      if (categoryService.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final categories = categoryService.categories;

                      return ListView.builder(
                        itemCount: categories.length + 1, // +1 pour "Toutes"
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              leading: const Icon(Icons.grid_view),
                              title: const Text('Toutes'),
                              selected: _selectedCategoryId == null,
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId = null;
                                  _menuItemsFuture = null; // Recharger
                                });
                              },
                            );
                          }

                          final category = categories[index - 1];
                          return ListTile(
                            leading: Text(
                              category.emoji != null &&
                                      category.emoji!.isNotEmpty
                                  ? category.emoji!
                                  : '📁',
                              style: const TextStyle(fontSize: 20),
                            ),
                            title: Text(category.name),
                            selected: _selectedCategoryId == category.id,
                            onTap: () {
                              setState(() {
                                _selectedCategoryId = category.id;
                                _menuItemsFuture = null; // Recharger
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ModernButton(
                    label: 'Gérer Catégories',
                    icon: Icons.settings,
                    variant: ModernButtonVariant.secondary,
                    isFullWidth: true,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CategoryManagementScreen(),
                        ),
                      ).then((_) => _refreshMenu());
                    },
                  ),
                ),
              ],
            ),
          ),

          // Zone principale
          Expanded(
            child: Column(
              children: [
                // Header / AppBar de la zone principale
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.of(context).pop(),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).scaffoldBackgroundColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Rechercher un produit...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).scaffoldBackgroundColor,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Filtres rapides
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          indicatorSize: TabBarIndicatorSize.label,
                          dividerColor: Colors.transparent,
                          labelColor: scheme.primary,
                          unselectedLabelColor: scheme.onSurfaceVariant,
                          tabs: const [
                            Tab(text: 'Tous'),
                            Tab(text: 'Disponibles'),
                            Tab(text: 'Indisponibles'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ModernButton(
                        label: 'Nouveau Produit',
                        icon: Icons.add,
                        onPressed: () => _showMenuItemForm(context, null),
                      ),
                    ],
                  ),
                ),

                // Contenu principal (Grille)
                Expanded(
                  child: Consumer2<MenuService, CategoryManagementService>(
                    builder: (context, menuService, categoryService, child) {
                      // Initial load logic
                      _menuItemsFuture ??= Future.microtask(
                        () => _loadAllMenuItems(menuService, categoryService),
                      );

                      return FutureBuilder<List<MenuItem>>(
                        future: _menuItemsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !menuService.isLoading) {
                            // Avoid loading if just notifying
                            // return const LoadingWidget(message: 'Chargement...');
                            // Laisse le loading à menuService si possible ou affiche un loader léger
                          }

                          if (menuService.isLoading) {
                            return const LoadingWidget(
                                message: 'Chargement des produits...');
                          }

                          if (snapshot.hasError) {
                            return _buildErrorState(snapshot.error.toString());
                          }

                          final allItems = snapshot.data ?? [];
                          final filteredItems = _filterMenuItems(allItems);

                          if (filteredItems.isEmpty) {
                            return _buildEmptyState();
                          }

                          return RefreshIndicator(
                            onRefresh: _refreshMenu,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(24),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 350,
                                mainAxisExtent:
                                    300, // Hauteur augmentée pour éviter l'overflow
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                return _buildMenuItemCard(
                                  context,
                                  filteredItems[index],
                                  menuService,
                                  categoryService,
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<MenuItem>> _loadAllMenuItems(
    MenuService menuService,
    CategoryManagementService categoryService,
  ) async {
    // Récupérer les items (filtrés par catégorie ou tous)
    final items = await menuService.getMenuItems(_selectedCategoryId, notify: false);

    // Trier par nom
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  List<MenuItem> _filterMenuItems(List<MenuItem> items) {
    var filtered = items;

    // Filtre par statut (Tab)
    switch (_currentFilter) {
      case MenuFilter.all:
        break;
      case MenuFilter.available:
        filtered = filtered.where((item) => item.isAvailable).toList();
        break;
      case MenuFilter.unavailable:
        filtered = filtered.where((item) => !item.isAvailable).toList();
        break;
    }

    // Filtre par catégorie (Sidebar)
    // Note: Déjà filtré au chargement si _selectedCategoryId != null, mais
    // on le garde ici au cas où on chargerait tout en cache.
    if (_selectedCategoryId != null) {
      filtered = filtered
          .where((item) => item.categoryId == _selectedCategoryId)
          .toList();
    }

    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (item) =>
                item.name.toLowerCase().contains(_searchQuery) ||
                (item.description?.toLowerCase().contains(_searchQuery) ??
                    false),
          )
          .toList();
    }

    return filtered;
  }

  Widget _buildMenuItemCard(
    BuildContext context,
    MenuItem item,
    MenuService menuService,
    CategoryManagementService categoryService,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Trouver le nom de la catégorie (safe check)
    String categoryName = 'Inconnue';
    try {
      final cat =
          categoryService.categories.firstWhere((c) => c.id == item.categoryId);
      categoryName = cat.name;
    } catch (_) {}

    return ModernCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showMenuItemForm(context, item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.fastfood,
                              size: 40,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Container(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.fastfood,
                            size: 40,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                  // Badges
                  if (item.isPopular)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.tertiary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: 0.12),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 12, color: scheme.onTertiary),
                            const SizedBox(width: 4),
                            Text(
                              'Populaire',
                              style: TextStyle(
                                color: scheme.onTertiary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!item.isAvailable)
                    Positioned.fill(
                      child: Container(
                        color: scheme.shadow.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: Text(
                          'INDISPONIBLE',
                          style: TextStyle(
                            color: scheme.onInverseSurface,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Infos
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            categoryName.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatPrice(item.basePrice),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _showMenuItemForm(context, item);
                                break;
                              case 'toggle':
                                _toggleAvailability(context, item, menuService);
                                break;
                              case 'delete':
                                _deleteMenuItem(context, item, menuService);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Modifier'),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                  item.isAvailable ? 'Masquer' : 'Afficher'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Supprimer',
                                  style: TextStyle(color: scheme.error)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 64,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun produit trouvé',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          ModernButton(
            label: 'Ajouter un produit',
            icon: Icons.add,
            onPressed: () => _showMenuItemForm(context, null),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: scheme.error),
          const SizedBox(height: 16),
          Text('Erreur: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshMenu,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _showMenuItemForm(BuildContext context, MenuItem? item) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => MenuItemFormDialog(
        menuItem: item,
        onSaved: () {
          _refreshMenu();
        },
      ),
    );
  }

  Future<void> _toggleAvailability(
    BuildContext context,
    MenuItem item,
    MenuService menuService,
  ) async {
    final updatedItem = item.copyWith(isAvailable: !item.isAvailable);
    await menuService.updateMenuItem(updatedItem);
    _refreshMenu();
  }

  Future<void> _deleteMenuItem(
    BuildContext context,
    MenuItem item,
    MenuService menuService,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Voulez-vous vraiment supprimer "${item.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await menuService.deleteMenuItem(item.id);
      _refreshMenu();
    }
  }

  Future<void> _refreshMenu() async {
    final categoryService = context.read<CategoryManagementService>();
    await categoryService.refreshCategories();
    // Force reload of future
    setState(() {
      _menuItemsFuture = null;
    });
  }
}

enum MenuFilter { all, available, unavailable }
