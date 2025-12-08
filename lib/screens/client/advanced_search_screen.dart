import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/menu_category.dart';
import 'package:elcora_fast/services/advanced_search_service.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/price_formatter.dart';

/// Écran de recherche avancée avec filtres multiples
class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AdvancedSearchService _searchService = AdvancedSearchService();

  List<MenuItem> _results = [];
  bool _isLoading = false;
  bool _showFilters = false;

  // Filtres
  List<String> _selectedCategoryIds = [];
  double _minPrice = 0.0;
  double _maxPrice = 10000.0;
  bool _vegetarianOnly = false;
  bool _veganOnly = false;
  bool _popularOnly = false;
  List<String> _excludeAllergens = [];
  int? _maxPreparationTime;
  double? _minRating;
  SearchSortOption _sortBy = SearchSortOption.relevance;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _performSearch();
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Construire les critères de recherche
      final criteria = SearchCriteria(
        query: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        categoryIds: _selectedCategoryIds.isEmpty ? null : _selectedCategoryIds,
        minPrice: _minPrice > 0 ? _minPrice : null,
        maxPrice: _maxPrice < 10000 ? _maxPrice : null,
        vegetarian: _vegetarianOnly ? true : null,
        vegan: _veganOnly ? true : null,
        popular: _popularOnly ? true : null,
        excludeAllergens: _excludeAllergens.isEmpty ? null : _excludeAllergens,
        maxPreparationTime: _maxPreparationTime,
        minRating: _minRating,
        sortBy: _sortBy,
      );

      final results = await _searchService.search(criteria);

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la recherche: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedCategoryIds = [];
      _minPrice = 0.0;
      _maxPrice = 10000.0;
      _vegetarianOnly = false;
      _veganOnly = false;
      _popularOnly = false;
      _excludeAllergens = [];
      _maxPreparationTime = null;
      _minRating = null;
      _sortBy = SearchSortOption.relevance;
    });
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    final appService = Provider.of<AppService>(context);
    final categories = appService.menuCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche Avancée'),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un plat, un ingrédient...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Filtres (expandable)
          if (_showFilters) _buildFiltersSection(categories),

          // Résultats
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? _buildEmptyState()
                    : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(List<MenuCategory> categories) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Catégories
            Text(
              'Catégories',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: categories.map((category) {
                final isSelected = _selectedCategoryIds.contains(category.id);
                return FilterChip(
                  label: Text(category.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategoryIds.add(category.id);
                      } else {
                        _selectedCategoryIds.remove(category.id);
                      }
                    });
                    _performSearch();
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Prix
            Text(
              'Prix',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            RangeSlider(
              values: RangeValues(_minPrice, _maxPrice),
              max: 10000,
              divisions: 100,
              labels: RangeLabels(
                '${_minPrice.toInt()} FCFA',
                '${_maxPrice.toInt()} FCFA',
              ),
              onChanged: (values) {
                setState(() {
                  _minPrice = values.start;
                  _maxPrice = values.end;
                });
                _performSearch();
              },
            ),

            const SizedBox(height: 16),

            // Options diététiques
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
                      _performSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: const Text('Végan'),
                    selected: _veganOnly,
                    onSelected: (selected) {
                      setState(() {
                        _veganOnly = selected;
                        if (selected) _vegetarianOnly = false;
                      });
                      _performSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: const Text('Populaire'),
                    selected: _popularOnly,
                    onSelected: (selected) {
                      setState(() {
                        _popularOnly = selected;
                      });
                      _performSearch();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tri
            Text(
              'Trier par',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            DropdownButton<SearchSortOption>(
              value: _sortBy,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: SearchSortOption.relevance,
                  child: Text('Pertinence'),
                ),
                DropdownMenuItem(
                  value: SearchSortOption.priceAsc,
                  child: Text('Prix croissant'),
                ),
                DropdownMenuItem(
                  value: SearchSortOption.priceDesc,
                  child: Text('Prix décroissant'),
                ),
                DropdownMenuItem(
                  value: SearchSortOption.ratingDesc,
                  child: Text('Meilleure note'),
                ),
                DropdownMenuItem(
                  value: SearchSortOption.nameAsc,
                  child: Text('Nom A-Z'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _sortBy = value;
                  });
                  _performSearch();
                }
              },
            ),

            const SizedBox(height: 16),

            // Bouton réinitialiser
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.clear_all),
                label: const Text('Réinitialiser les filtres'),
                onPressed: _clearFilters,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun résultat trouvé',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier vos critères de recherche',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: item.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.restaurant, size: 40),
            title: Text(item.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (item.isVegetarian)
                      const Chip(
                        label: Text('Végétarien'),
                        padding: EdgeInsets.zero,
                        labelPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    if (item.isVegan)
                      const Chip(
                        label: Text('Végan'),
                        padding: EdgeInsets.zero,
                        labelPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    if (item.rating > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      Text(item.rating.toStringAsFixed(1)),
                    ],
                  ],
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  PriceFormatter.format(item.price),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                ),
                if (item.preparationTime > 0)
                  Text(
                    '${item.preparationTime} min',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            onTap: () {
              // Naviguer vers les détails de l'item
            },
          ),
        );
      },
    );
  }
}

