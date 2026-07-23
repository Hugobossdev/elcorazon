import 'package:elcora_fast/models/menu_category.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/services/api/api_client.dart';
import 'package:elcora_fast/services/api/paged_result.dart';

/// Accès au catalogue (catégories, articles, recherche) via l'API Laravel.
class MenuApi {
  MenuApi._internal();
  static final MenuApi _instance = MenuApi._internal();
  factory MenuApi() => _instance;

  final ApiClient _client = ApiClient();

  /// Catégories actives, triées par `sort_order`.
  Future<List<MenuCategory>> getCategories({bool withCounts = false}) async {
    final response = await _client.get('/menu/categories', query: {
      if (withCounts) 'with_counts': 'true',
    });
    final list = (response['data'] as List? ?? []);
    return list
        .map((e) => MenuCategory.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Un article par son id (catégorie et personnalisations incluses).
  Future<MenuItem> getItem(String id) async {
    final response = await _client.get('/menu/items/$id');
    return MenuItem.fromMap(_normalize(response['data'] as Map<String, dynamic>));
  }

  /// Liste paginée d'articles avec filtres optionnels.
  Future<PagedResult<MenuItem>> getItems({
    String? categoryId,
    String? search,
    bool popularOnly = false,
    bool includeUnavailable = false,
    String? sort,
    String? direction,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _client.get('/menu/items', query: {
      'page': page,
      'per_page': perPage,
      if (categoryId != null) 'category_id': categoryId,
      if (search != null && search.isNotEmpty) 'search': search,
      if (popularOnly) 'popular_only': 'true',
      if (includeUnavailable) 'include_unavailable': 'true',
      if (sort != null) 'sort': sort,
      if (direction != null) 'direction': direction,
    });

    final data = (response['data'] as List? ?? []);
    final items = data
        .map((e) => MenuItem.fromMap(_normalize(e as Map<String, dynamic>)))
        .toList();

    return PagedResult<MenuItem>(
      items: items,
      currentPage: (response['current_page'] as num?)?.toInt() ?? page,
      lastPage: (response['last_page'] as num?)?.toInt() ?? page,
      total: (response['total'] as num?)?.toInt() ?? items.length,
    );
  }

  /// Raccourci : tous les articles d'une catégorie (première page élargie).
  Future<List<MenuItem>> getItemsByCategory(String categoryId,
      {int perPage = 100}) async {
    final result =
        await getItems(categoryId: categoryId, perPage: perPage);
    return result.items;
  }

  /// Raccourci : articles populaires.
  Future<List<MenuItem>> getPopularItems({int perPage = 20}) async {
    final result = await getItems(popularOnly: true, perPage: perPage);
    return result.items;
  }

  /// L'API Laravel imbrique la catégorie sous la clé `category` ;
  /// `MenuItem.fromMap` attend la clé Supabase `menu_categories`. On adapte.
  Map<String, dynamic> _normalize(Map<String, dynamic> item) {
    if (item['category'] != null && item['menu_categories'] == null) {
      return {...item, 'menu_categories': item['category']};
    }
    return item;
  }
}
