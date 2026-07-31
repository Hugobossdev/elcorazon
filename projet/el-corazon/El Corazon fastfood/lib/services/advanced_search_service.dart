import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/repositories/django_menu_repository.dart';

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

  final eccore.CatalogRepository _catalog =
      eccore.CatalogRepository(apiClient: apiClient);

  /// Recherche avancée — **tous** les critères sont appliqués par le serveur.
  ///
  /// L'implémentation Supabase composait la requête depuis le téléphone puis
  /// finissait le tri en mémoire : les ingrédients et les allergènes étaient
  /// filtrés sur la page reçue, si bien qu'un article correspondant mais absent
  /// de cette page ne remontait jamais. Ici, `apps/catalog/filters.py` filtre
  /// le catalogue entier et le repository suit la pagination jusqu'au bout.
  Future<List<MenuItem>> search(SearchCriteria criteria) async {
    try {
      final items = await _catalog.getMenuItems(
        restaurantSlug: AppConstants.restaurantSlug,
        search: criteria.query,
        // Le contrat désigne les catégories par leur `slug` ; l'écran n'en
        // passe qu'une à la fois.
        categorySlug: (criteria.categoryIds != null && criteria.categoryIds!.isNotEmpty)
            ? criteria.categoryIds!.first
            : null,
        isPopular: criteria.popular,
        priceMinMinor: _toMinor(criteria.minPrice),
        priceMaxMinor: _toMinor(criteria.maxPrice),
        caloriesMin: criteria.minCalories,
        caloriesMax: criteria.maxCalories,
        preparationMaxMinutes: criteria.maxPreparationTime,
        ratingMin: criteria.minRating,
        dietaryTags: [
          if (criteria.vegetarian == true) 'vegetarian',
          if (criteria.vegan == true) 'vegan',
        ],
        excludeAllergens: criteria.excludeAllergens,
        ingredients: criteria.includeIngredients,
        ordering: _orderingFor(criteria.sortBy),
      );

      final results = items
          .where((item) => item.isAvailable)
          .map(DjangoMenuRepository.toLocalMenuItem)
          .toList();

      debugPrint('✅ Recherche avancée: ${results.length} résultats trouvés');
      return results;
    } on eccore.ApiException catch (e) {
      debugPrint('❌ Erreur lors de la recherche avancée: ${e.code}');
      throw Exception('Erreur lors de la recherche: ${e.detail}');
    }
  }

  /// Le contrat exprime les montants en unité mineure (ADR-007) ; l'écran
  /// manipule des francs CFA, dont l'unité mineure est le franc lui-même.
  static int? _toMinor(double? amount) => amount?.round();

  /// Traduit le tri de l'écran vers `ordering` (`OrderingFilter`). Les tris que
  /// le serveur ne porte pas ne sont pas rejoués côté client : ils rendraient
  /// un ordre faux dès que le résultat dépasse une page.
  static String? _orderingFor(SearchSortOption? sortBy) {
    switch (sortBy) {
      case SearchSortOption.priceAsc:
        return 'price_minor';
      case SearchSortOption.priceDesc:
        return '-price_minor';
      case SearchSortOption.nameAsc:
        return 'name';
      case SearchSortOption.ratingDesc:
        return '-rating_average';
      case SearchSortOption.preparationTimeAsc:
        return 'preparation_minutes';
      case SearchSortOption.caloriesAsc:
        return 'calories';
      case SearchSortOption.caloriesDesc:
        return '-calories';
      case SearchSortOption.relevance:
      case null:
        return null;
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

}
