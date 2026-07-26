import 'package:flutter/material.dart';
import '../../services/global_search_service.dart';
import 'order_management_screen.dart';
import 'menu_management_screen.dart';
import 'client_management_screen.dart';
import 'driver_management_screen.dart';

/// Catégories disponibles pour filtrer les résultats de recherche
enum SearchCategory {
  orders,
  menuItems,
  users,
  drivers,
}

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalSearchService _searchService = GlobalSearchService();
  GlobalSearchResults? _results;
  bool _isSearching = false;
  final List<SearchCategory> _selectedCategories = SearchCategory.values;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = null;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final results = await _searchService.searchAll(query);

    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche Globale'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Rechercher commandes, produits, clients, livreurs...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  onChanged: (value) {
                    _performSearch(value);
                  },
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: SearchCategory.values.map((category) {
                    final isSelected = _selectedCategories.contains(category);
                    return FilterChip(
                      label: Text(_getCategoryLabel(category)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategories.add(category);
                          } else {
                            _selectedCategories.remove(category);
                          }
                          if (_searchController.text.isNotEmpty) {
                            _performSearch(_searchController.text);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Recherchez dans toute l\'application',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commandes, produits, clients, livreurs...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    if (_results!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text('Aucun résultat trouvé', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Essayez avec d\'autres mots-clés',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_results!.orders.isNotEmpty &&
            _selectedCategories.contains(SearchCategory.orders)) ...[
          _buildSectionHeader(
            'Commandes',
            _results!.orders.length,
            Icons.shopping_cart,
            Colors.blue,
          ),
          ..._results!.orders.map((res) => _buildOrderCard(res, theme)),
        ],
        if (_results!.menuItems.isNotEmpty &&
            _selectedCategories.contains(SearchCategory.menuItems)) ...[
          _buildSectionHeader(
            'Produits',
            _results!.menuItems.length,
            Icons.restaurant,
            Colors.orange,
          ),
          ..._results!.menuItems
              .map((res) => _buildMenuItemCard(res, theme)),
        ],
        if (_results!.users.isNotEmpty &&
            _selectedCategories.contains(SearchCategory.users)) ...[
          _buildSectionHeader(
            'Clients',
            _results!.users.length,
            Icons.person,
            Colors.green,
          ),
          ..._results!.users.map((res) => _buildUserCard(res, theme)),
        ],
        if (_results!.drivers.isNotEmpty &&
            _selectedCategories.contains(SearchCategory.drivers)) ...[
          _buildSectionHeader(
            'Livreurs',
            _results!.drivers.length,
            Icons.delivery_dining,
            Colors.purple,
          ),
          ..._results!.drivers.map((res) => _buildDriverCard(res, theme)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(GlobalSearchResult result, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withValues(alpha: 0.1),
          child: const Icon(Icons.shopping_cart, color: Colors.blue),
        ),
        title: Text(result.title),
        subtitle: Text(
          result.createdAt != null
              ? '${result.subtitle} • ${_formatDate(result.createdAt!)}'
              : result.subtitle,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OrderManagementScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItemCard(GlobalSearchResult result, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
          child: const Icon(Icons.restaurant, color: Colors.orange),
        ),
        title: Text(result.title),
        subtitle: Text(result.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MenuManagementScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserCard(GlobalSearchResult result, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.1),
          child: const Icon(Icons.person, color: Colors.green),
        ),
        title: Text(result.title),
        subtitle: Text(result.subtitle),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ClientManagementScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDriverCard(GlobalSearchResult result, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.withValues(alpha: 0.1),
          child: const Icon(Icons.delivery_dining, color: Colors.purple),
        ),
        title: Text(result.title),
        subtitle: Text(result.subtitle),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DriverManagementScreen(),
            ),
          );
        },
      ),
    );
  }

  String _getCategoryLabel(SearchCategory category) {
    switch (category) {
      case SearchCategory.orders:
        return 'Commandes';
      case SearchCategory.menuItems:
        return 'Produits';
      case SearchCategory.users:
        return 'Clients';
      case SearchCategory.drivers:
        return 'Livreurs';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
