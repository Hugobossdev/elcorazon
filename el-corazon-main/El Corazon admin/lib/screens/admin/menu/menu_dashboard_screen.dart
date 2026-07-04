import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/menu_service.dart';
import '../../../services/category_management_service.dart';
import '../../../models/menu_models.dart';
import '../../../widgets/loading_widget.dart';
import 'product_editor_screen.dart';

class MenuDashboardScreen extends StatefulWidget {
  const MenuDashboardScreen({super.key});

  @override
  State<MenuDashboardScreen> createState() => _MenuDashboardScreenState();
}

class _MenuDashboardScreenState extends State<MenuDashboardScreen> {
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final categoryService = Provider.of<CategoryManagementService>(
      context,
      listen: false,
    );
    await categoryService.refreshCategories();
    if (categoryService.categories.isNotEmpty && _selectedCategoryId == null) {
      setState(() {
        _selectedCategoryId = categoryService.categories.first.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryService = Provider.of<CategoryManagementService>(context);

    if (categoryService.isLoading) {
      return const Center(
        child: LoadingWidget(message: 'Chargement des catégories...'),
      );
    }

    if (categoryService.categories.isEmpty) {
      return const Center(
        child: Text('Aucune catégorie disponible. Veuillez en créer une.'),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar des catégories
          Container(
            width: 250,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: ListView.builder(
              itemCount: categoryService.categories.length,
              itemBuilder: (context, index) {
                final category = categoryService.categories[index];
                final isSelected = category.id == _selectedCategoryId;
                return ListTile(
                  title: Text(category.name),
                  selected: isSelected,
                  selectedTileColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = category.id;
                    });
                  },
                );
              },
            ),
          ),
          // Liste des produits
          Expanded(
            child: _selectedCategoryId == null
                ? const Center(child: Text('Sélectionnez une catégorie'))
                : _ProductList(categoryId: _selectedCategoryId!),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_selectedCategoryId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ProductEditorScreen(categoryId: _selectedCategoryId!),
              ),
            ).then((_) => setState(() {})); // Refresh on return
          }
        },
        label: const Text('Nouveau Produit'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _ProductList extends StatefulWidget {
  final String categoryId;

  const _ProductList({required this.categoryId});

  @override
  State<_ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<_ProductList> {
  @override
  void didUpdateWidget(covariant _ProductList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      // Trigger refresh if needed, but FutureBuilder handles it
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuService = Provider.of<MenuService>(context, listen: false);

    return FutureBuilder<List<MenuItem>>(
      future: menuService.getMenuItems(widget.categoryId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const Center(
            child: Text('Aucun produit dans cette catégorie.'),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductEditorScreen(
                        categoryId: widget.categoryId,
                        menuItem: item,
                      ),
                    ),
                  ).then((_) => setState(() {}));
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: item.imageUrl != null
                          ? Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.fastfood, size: 50),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${item.basePrice.toStringAsFixed(0)} FCFA',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
