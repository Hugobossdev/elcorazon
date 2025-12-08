import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/supabase/supabase_config.dart';

/// Critères de recherche avancée
class SearchCriteria {
  final String? query;
  final List<String>? categoryIds;
  final double? minPrice;
  final double? maxPrice;
  final List<String>? excludeAllergens;
  final List<String>? includeIngredients;
  final bool? vegetarian;
  final bool? vegan;
  final bool? popular;
  final int? minCalories;
  final int? maxCalories;
  final int? maxPreparationTime;
  final double? minRating;
  final SearchSortOption? sortBy;

  const SearchCriteria({
    this.query,
    this.categoryIds,
    this.minPrice,
    this.maxPrice,
    this.excludeAllergens,
    this.includeIngredients,
    this.vegetarian,
    this.vegan,
    this.popular,
    this.minCalories,
    this.maxCalories,
    this.maxPreparationTime,
    this.minRating,
    this.sortBy,
  });

  /// Créer une copie avec des modifications
  SearchCriteria copyWith({
    String? query,
    List<String>? categoryIds,
    double? minPrice,
    double? maxPrice,
    List<String>? excludeAllergens,
    List<String>? includeIngredients,
    bool? vegetarian,
    bool? vegan,
    bool? popular,
    int? minCalories,
    int? maxCalories,
    int? maxPreparationTime,
    double? minRating,
    SearchSortOption? sortBy,
  }) {
    return SearchCriteria(
      query: query ?? this.query,
      categoryIds: categoryIds ?? this.categoryIds,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      excludeAllergens: excludeAllergens ?? this.excludeAllergens,
      includeIngredients: includeIngredients ?? this.includeIngredients,
      vegetarian: vegetarian ?? this.vegetarian,
      vegan: vegan ?? this.vegan,
      popular: popular ?? this.popular,
      minCalories: minCalories ?? this.minCalories,
      maxCalories: maxCalories ?? this.maxCalories,
      maxPreparationTime: maxPreparationTime ?? this.maxPreparationTime,
      minRating: minRating ?? this.minRating,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// Vérifier si des critères sont définis
  bool get hasCriteria {
    return query != null ||
        (categoryIds != null && categoryIds!.isNotEmpty) ||
        minPrice != null ||
        maxPrice != null ||
        (excludeAllergens != null && excludeAllergens!.isNotEmpty) ||
        (includeIngredients != null && includeIngredients!.isNotEmpty) ||
        vegetarian != null ||
        vegan != null ||
        popular != null ||
        minCalories != null ||
        maxCalories != null ||
        maxPreparationTime != null ||
        minRating != null;
  }
}

/// Options de tri pour la recherche
enum SearchSortOption {
  relevance, // Pertinence (par défaut)
  priceAsc, // Prix croissant
  priceDesc, // Prix décroissant
  ratingDesc, // Note décroissante
  nameAsc, // Nom alphabétique
  preparationTimeAsc, // Temps de préparation croissant
  caloriesAsc, // Calories croissantes
  caloriesDesc, // Calories décroissantes
}

/// Service de recherche avancée pour les menu items
class AdvancedSearchService {
  static final AdvancedSearchService _instance = AdvancedSearchService._internal();
  factory AdvancedSearchService() => _instance;
  AdvancedSearchService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Recherche avancée avec critères multiples
  Future<List<MenuItem>> search(SearchCriteria criteria) async {
    try {
      const fieldsString = '''
        id, name, description, price, image_url, category_id,
        is_available, is_popular, is_vegetarian, is_vegan,
        ingredients, calories, preparation_time, sort_order,
        rating, review_count
      ''';

      var queryBuilder = _supabase
          .from('menu_items')
          .select('''
            $fieldsString,
            menu_categories!left(id, name, display_name, emoji)
          ''');

      // Toujours filtrer par disponibilité
      queryBuilder = queryBuilder.eq('is_available', true);

      // Recherche textuelle (nom et description)
      if (criteria.query != null && criteria.query!.isNotEmpty) {
        final searchTerm = criteria.query!.trim();
        queryBuilder = queryBuilder.or(
          'name.ilike.%$searchTerm%,description.ilike.%$searchTerm%',
        );
      }

      // Filtre par catégories
      if (criteria.categoryIds != null && criteria.categoryIds!.isNotEmpty) {
        queryBuilder = queryBuilder.inFilter('category_id', criteria.categoryIds!);
      }

      // Filtre par prix
      if (criteria.minPrice != null) {
        queryBuilder = queryBuilder.gte('price', criteria.minPrice!);
      }
      if (criteria.maxPrice != null) {
        queryBuilder = queryBuilder.lte('price', criteria.maxPrice!);
      }

      // Filtre végétarien
      if (criteria.vegetarian == true) {
        queryBuilder = queryBuilder.eq('is_vegetarian', true);
      }

      // Filtre végan
      if (criteria.vegan == true) {
        queryBuilder = queryBuilder.eq('is_vegan', true);
      }

      // Filtre populaire
      if (criteria.popular == true) {
        queryBuilder = queryBuilder.eq('is_popular', true);
      }

      // Filtre par calories
      if (criteria.minCalories != null) {
        queryBuilder = queryBuilder.gte('calories', criteria.minCalories!);
      }
      if (criteria.maxCalories != null) {
        queryBuilder = queryBuilder.lte('calories', criteria.maxCalories!);
      }

      // Filtre par temps de préparation
      if (criteria.maxPreparationTime != null) {
        queryBuilder = queryBuilder.lte('preparation_time', criteria.maxPreparationTime!);
      }

      // Filtre par note minimale
      if (criteria.minRating != null) {
        queryBuilder = queryBuilder.gte('rating', criteria.minRating!);
      }

      // Appliquer le tri
      final sortedQuery = _applySorting(queryBuilder, criteria.sortBy);

      // Exécuter la requête
      final response = await sortedQuery;

      var items = (response as List<dynamic>)
          .map((data) => MenuItem.fromMap(data as Map<String, dynamic>))
          .toList();

      // Filtres côté client (pour les ingrédients et allergènes)
      items = _filterByIngredients(items, criteria.includeIngredients);
      items = _filterByAllergens(items, criteria.excludeAllergens);

      debugPrint('✅ Recherche avancée: ${items.length} résultats trouvés');
      return items;
    } catch (e) {
      debugPrint('❌ Erreur lors de la recherche avancée: $e');
      throw Exception('Erreur lors de la recherche: $e');
    }
  }

  /// Recherche simple (compatibilité avec l'ancien code)
  Future<List<MenuItem>> searchSimple(String query) async {
    return search(SearchCriteria(query: query));
  }

  /// Recherche par ingrédients
  Future<List<MenuItem>> searchByIngredients(List<String> ingredients) async {
    return search(SearchCriteria(includeIngredients: ingredients));
  }

  /// Recherche sans allergènes
  Future<List<MenuItem>> searchWithoutAllergens(List<String> allergens) async {
    return search(SearchCriteria(excludeAllergens: allergens));
  }

  /// Recherche par prix
  Future<List<MenuItem>> searchByPrice({
    double? minPrice,
    double? maxPrice,
  }) async {
    return search(SearchCriteria(
      minPrice: minPrice,
      maxPrice: maxPrice,
    ),);
  }

  /// Recherche végétarienne/végane
  Future<List<MenuItem>> searchByDiet({
    bool? vegetarian,
    bool? vegan,
  }) async {
    return search(SearchCriteria(
      vegetarian: vegetarian,
      vegan: vegan,
    ),);
  }

  /// Recherche combinée (tous les critères)
  Future<List<MenuItem>> searchCombined({
    String? query,
    List<String>? categoryIds,
    double? minPrice,
    double? maxPrice,
    List<String>? excludeAllergens,
    List<String>? includeIngredients,
    bool? vegetarian,
    bool? vegan,
    bool? popular,
    int? minCalories,
    int? maxCalories,
    int? maxPreparationTime,
    double? minRating,
    SearchSortOption? sortBy,
  }) async {
    return search(SearchCriteria(
      query: query,
      categoryIds: categoryIds,
      minPrice: minPrice,
      maxPrice: maxPrice,
      excludeAllergens: excludeAllergens,
      includeIngredients: includeIngredients,
      vegetarian: vegetarian,
      vegan: vegan,
      popular: popular,
      minCalories: minCalories,
      maxCalories: maxCalories,
      maxPreparationTime: maxPreparationTime,
      minRating: minRating,
      sortBy: sortBy,
    ),);
  }

  /// Appliquer le tri
  dynamic _applySorting(
    dynamic queryBuilder,
    SearchSortOption? sortBy,
  ) {
    switch (sortBy) {
      case SearchSortOption.priceAsc:
        return queryBuilder.order('price', ascending: true);
      case SearchSortOption.priceDesc:
        return queryBuilder.order('price', ascending: false);
      case SearchSortOption.ratingDesc:
        return queryBuilder.order('rating', ascending: false);
      case SearchSortOption.nameAsc:
        return queryBuilder.order('name', ascending: true);
      case SearchSortOption.preparationTimeAsc:
        return queryBuilder.order('preparation_time', ascending: true);
      case SearchSortOption.caloriesAsc:
        return queryBuilder.order('calories', ascending: true);
      case SearchSortOption.caloriesDesc:
        return queryBuilder.order('calories', ascending: false);
      case SearchSortOption.relevance:
      default:
        // Tri par pertinence (popularité et note)
        return queryBuilder.order('is_popular', ascending: false)
            .order('rating', ascending: false);
    }
  }

  /// Filtrer par ingrédients (côté client)
  List<MenuItem> _filterByIngredients(
    List<MenuItem> items,
    List<String>? includeIngredients,
  ) {
    if (includeIngredients == null || includeIngredients.isEmpty) {
      return items;
    }

    return items.where((item) {
      final itemIngredients = item.ingredients.map((i) => i.toLowerCase()).toList();
      return includeIngredients.any((ingredient) {
        final lowerIngredient = ingredient.toLowerCase();
        return itemIngredients.any((itemIng) => itemIng.contains(lowerIngredient));
      });
    }).toList();
  }

  /// Filtrer par allergènes (côté client)
  List<MenuItem> _filterByAllergens(
    List<MenuItem> items,
    List<String>? excludeAllergens,
  ) {
    if (excludeAllergens == null || excludeAllergens.isEmpty) {
      return items;
    }

    return items.where((item) {
      // Vérifier les allergènes dans les ingrédients
      final itemIngredients = item.ingredients.map((i) => i.toLowerCase()).toList();
      
      // Vérifier si aucun allergène exclu n'est présent
      return !excludeAllergens.any((allergen) {
        final lowerAllergen = allergen.toLowerCase();
        return itemIngredients.any((ingredient) => ingredient.contains(lowerAllergen));
      });
    }).toList();
  }

  /// Obtenir les suggestions de recherche basées sur l'historique
  Future<List<String>> getSearchSuggestions(String partialQuery) async {
    try {
      if (partialQuery.isEmpty) {
        return [];
      }

      // Rechercher les items correspondants
      final results = await search(SearchCriteria(query: partialQuery));

      // Extraire les suggestions (noms d'items)
      final suggestions = results
          .map((item) => item.name)
          .where((name) => name.toLowerCase().startsWith(partialQuery.toLowerCase()))
          .take(5)
          .toList();

      return suggestions;
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des suggestions: $e');
      return [];
    }
  }

  /// Recherche avec pagination
  Future<SearchResult> searchWithPagination(
    SearchCriteria criteria, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final offset = (page - 1) * pageSize;
      
      // Construire la requête de base
      const fieldsString = '''
        id, name, description, price, image_url, category_id,
        is_available, is_popular, is_vegetarian, is_vegan,
        ingredients, calories, preparation_time, sort_order,
        rating, review_count
      ''';

      var queryBuilder = _supabase
          .from('menu_items')
          .select('''
            $fieldsString,
            menu_categories!left(id, name, display_name, emoji)
          ''');

      // Appliquer les filtres (même logique que search)
      queryBuilder = queryBuilder.eq('is_available', true);

      if (criteria.query != null && criteria.query!.isNotEmpty) {
        final searchTerm = criteria.query!.trim();
        queryBuilder = queryBuilder.or(
          'name.ilike.%$searchTerm%,description.ilike.%$searchTerm%',
        );
      }

      if (criteria.categoryIds != null && criteria.categoryIds!.isNotEmpty) {
        queryBuilder = queryBuilder.inFilter('category_id', criteria.categoryIds!);
      }

      if (criteria.minPrice != null) {
        queryBuilder = queryBuilder.gte('price', criteria.minPrice!);
      }
      if (criteria.maxPrice != null) {
        queryBuilder = queryBuilder.lte('price', criteria.maxPrice!);
      }

      if (criteria.vegetarian == true) {
        queryBuilder = queryBuilder.eq('is_vegetarian', true);
      }

      if (criteria.vegan == true) {
        queryBuilder = queryBuilder.eq('is_vegan', true);
      }

      if (criteria.popular == true) {
        queryBuilder = queryBuilder.eq('is_popular', true);
      }

      // Appliquer le tri
      final sortedQuery = _applySorting(queryBuilder, criteria.sortBy);

      // Pagination
      final paginatedQuery = sortedQuery.range(offset, offset + pageSize - 1);

      // Exécuter
      final response = await paginatedQuery;

      var items = (response as List<dynamic>)
          .map((data) => MenuItem.fromMap(data as Map<String, dynamic>))
          .toList();

      // Filtres côté client
      items = _filterByIngredients(items, criteria.includeIngredients);
      items = _filterByAllergens(items, criteria.excludeAllergens);

      // Pour le count, on utilise la longueur de la liste filtrée
      // Note: Pour un vrai count, il faudrait faire une requête séparée
      final totalCount = items.length;
      final totalPages = (totalCount / pageSize).ceil();

      return SearchResult(
        items: items,
        totalCount: totalCount,
        currentPage: page,
        totalPages: totalPages,
        hasMore: page < totalPages,
      );
    } catch (e) {
      debugPrint('❌ Erreur lors de la recherche paginée: $e');
      throw Exception('Erreur lors de la recherche: $e');
    }
  }
}

/// Résultat de recherche avec pagination
class SearchResult {
  final List<MenuItem> items;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final bool hasMore;

  const SearchResult({
    required this.items,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.hasMore,
  });
}

