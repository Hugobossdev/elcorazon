import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/services/menu_service.dart';
import 'package:admin/services/category_management_service.dart';
import 'package:admin/widgets/modern/modern_button.dart';
import 'package:admin/widgets/modern/modern_card.dart';
import 'package:admin/widgets/loading_widget.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/presentation/autorisations.dart';
import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/utils/price_formatter.dart';
import 'package:admin/screens/admin/menu_item_form_dialog.dart';
import 'package:admin/screens/admin/category_management_screen.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({this.rechercheInitiale = '', super.key});

  /// La carte s'ouvre déjà filtrée sur ce texte — ce que fait la recherche
  /// globale quand on clique un produit, plutôt que d'ouvrir la carte entière
  /// et d'y faire rechercher à la main l'article qu'on vient de trouver.
  final String rechercheInitiale;

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
  Future<List<eccore.ManagedMenuItem>>? _menuItemsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _searchController.text = widget.rechercheInitiale;
    _searchQuery = widget.rechercheInitiale.toLowerCase();
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
        final precedent = _currentFilter;
        _currentFilter = switch (_tabController.index) {
          0 => MenuFilter.all,
          1 => MenuFilter.available,
          2 => MenuFilter.unavailable,
          _ => MenuFilter.archived,
        };
        // Franchir la frontière entre la carte et l'archive change la
        // **requête**, pas seulement le tri : sans ce rechargement, l'onglet
        // « Retirés » filtrerait la carte du jour et s'afficherait toujours
        // vide, ce qui se lirait comme « aucun article retiré ».
        if (precedent.litLArchive != _currentFilter.litLArchive) {
          _menuItemsFuture = null;
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
                            // Meme regle que l'ecran des categories : on
                            // montre ce qui est saisi, sans inventer de repli.
                            leading: category.emoji.isEmpty
                                ? const Icon(Icons.folder_outlined, size: 20)
                                : Text(
                                    category.emoji,
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
                                  borderRadius: BorderRadius.circular(12),),
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
                                EdgeInsets.zero,
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
                            Tab(text: 'Retirés'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Tenir la carte demande `catalog.write` : un opérateur
                      // remplissait le formulaire entier avant de récolter un
                      // 403 à l'envoi.
                      if (context.peut('catalog.write'))
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

                      return FutureBuilder<List<eccore.ManagedMenuItem>>(
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
                                message: 'Chargement des produits...',);
                          }

                          if (snapshot.hasError) {
                            return _buildErrorState(snapshot.error!);
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

  Future<List<eccore.ManagedMenuItem>> _loadAllMenuItems(
    MenuService menuService,
    CategoryManagementService categoryService,
  ) async {
    // Récupérer les items (filtrés par catégorie ou tous)
    final items = await menuService.getMenuItems(
      _selectedCategoryId,
      notify: false,
      archived: _currentFilter.litLArchive,
    );

    // Trier par nom
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  List<eccore.ManagedMenuItem> _filterMenuItems(List<eccore.ManagedMenuItem> items) {
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
      case MenuFilter.archived:
        // Rien à retrancher : le serveur n'a rendu que des articles retirés,
        // et « disponible » n'a plus de sens pour eux — un article hors carte
        // ne se commande pas, quelle que soit la valeur du champ.
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
                item.description.toLowerCase().contains(_searchQuery),
          )
          .toList();
    }

    return filtered;
  }

  Widget _buildMenuItemCard(
    BuildContext context,
    eccore.ManagedMenuItem item,
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
                  item.image != null && item.image!.isNotEmpty
                      ? Image.network(
                          item.image!,
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
                            horizontal: 8, vertical: 4,),
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
                              horizontal: 6, vertical: 2,),
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
                          formatMontant(item.price),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (context.peut('catalog.write'))
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
                              case 'restore':
                                _restoreMenuItem(context, item, menuService);
                                break;
                            }
                          },
                          // Un article retiré ne se modifie ni ne se masque :
                          // il n'est plus à la carte. La seule chose à lui
                          // faire est de l'y remettre.
                          itemBuilder: (context) => _currentFilter.litLArchive
                              ? [
                                  const PopupMenuItem(
                                    value: 'restore',
                                    child: Text('Remettre au menu'),
                                  ),
                                ]
                              : [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Modifier'),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(
                                        item.isAvailable ? 'Masquer' : 'Afficher',),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Retirer de la carte',
                                        style: TextStyle(color: scheme.error),),
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
    // Une archive vide n'est pas un catalogue vide : rien n'a été retiré, et
    // proposer « Ajouter un produit » depuis cet onglet créerait un article
    // qui n'y apparaîtrait pas.
    final archive = _currentFilter.litLArchive;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            archive ? Icons.inventory_2_outlined : Icons.restaurant_menu,
            size: 64,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            archive ? 'Aucun article retiré' : 'Aucun produit trouvé',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          if (!archive && context.peut('catalog.write')) ...[
            const SizedBox(height: 24),
            ModernButton(
              label: 'Ajouter un produit',
              icon: Icons.add,
              onPressed: () => _showMenuItemForm(context, null),
            ),
          ],
        ],
      ),
    );
  }

  /// Prend l'erreur, pas sa conversion en texte : `toString()` sur une
  /// `ApiException` rend « ApiException(403, permission_denied, …) », quand la
  /// même exception porte une phrase écrite pour être lue.
  Widget _buildErrorState(Object error) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: scheme.error),
          const SizedBox(height: 16),
          Text(messageErreur(error), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshMenu,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _showMenuItemForm(BuildContext context, eccore.ManagedMenuItem? item) {
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
    eccore.ManagedMenuItem item,
    MenuService menuService,
  ) async {
    // Tous les champs repartent, régimes compris : le serveur remplace la
    // ressource, il ne fusionne pas. N'en renvoyer qu'une partie l'effacerait.
    await menuService.updateMenuItem(
      menuItemId: item.id,
      categoryId: item.categoryId,
      name: item.name,
      basePrice: item.price.toMajorUnits(),
      dietaryTags: item.dietaryTags,
      description: item.description,
      isAvailable: !item.isAvailable,
      isPopular: item.isPopular,
      sortOrder: item.sortOrder,
    );
    unawaited(_refreshMenu());
  }

  Future<void> _deleteMenuItem(
    BuildContext context,
    eccore.ManagedMenuItem item,
    MenuService menuService,
  ) async {
    // Le libellé dit ce qui se passe vraiment. Le serveur **archive** — les
    // commandes passées renvoient à l'article, et un effacement réel rendrait
    // leur historique illisible. Promettre une suppression était donc faux
    // dans les deux sens : celui qui voulait faire disparaître l'article
    // croyait l'avoir fait, et celui qui se trompait de ligne croyait la perte
    // définitive alors que l'onglet « Retirés » la rend en un geste.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer de la carte ?'),
        content: Text(
          '"${item.name}" ne sera plus commandable. Il reste lisible depuis '
          'les commandes passées, et l\'onglet « Retirés » permet de le '
          'remettre au menu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await menuService.deleteMenuItem(item.id);
      unawaited(_refreshMenu());
    }
  }

  Future<void> _restoreMenuItem(
    BuildContext context,
    eccore.ManagedMenuItem item,
    MenuService menuService,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final remis = await menuService.restoreMenuItem(item.id);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          remis
              ? '"${item.name}" est de retour au menu.'
              : menuService.error ?? 'La remise au menu a échoué.',
        ),
      ),
    );
    if (remis) unawaited(_refreshMenu());
  }

  Future<void> _refreshMenu() async {
    final categoryService = context.read<CategoryManagementService>();
    await categoryService.refreshCategories();
    // L'écran a pu être quitté pendant la relecture des catégories.
    if (!mounted) return;
    setState(() {
      _menuItemsFuture = null;
    });
  }
}

/// Ce que l'onglet demande à voir.
///
/// [archived] n'est pas un filtre comme les trois autres : les trois premiers
/// trient une liste déjà chargée, celui-ci change la liste. Le serveur ne mêle
/// jamais la carte du jour et les articles retirés — le défaut est la carte, et
/// l'archive se demande (`?archived=true`).
enum MenuFilter { all, available, unavailable, archived }

extension MenuFilterQuery on MenuFilter {
  /// L'onglet demande-t-il l'archive plutôt que la carte ?
  bool get litLArchive => this == MenuFilter.archived;
}
