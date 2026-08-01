import '../models/money.dart';
import '../network/api_client.dart';
import 'category.dart';
import 'menu_item.dart';
import 'option_template.dart';

/// Écriture du catalogue — `/api/v1/catalog/manage/*`
/// (`backend/apps/catalog/backoffice.py`).
///
/// Séparé de [CatalogRepository], qui est la carte que **lit** un client : un
/// chemin, un public, une permission. Ici tout demande `catalog.write` (ou
/// `catalog.read` en lecture), et le périmètre est celui du serveur — un membre
/// du personnel n'écrit que le catalogue des établissements auxquels il est
/// rattaché.
///
/// C'est le seul endroit où un **prix** s'écrit (C1). La note (`rating_average`,
/// `rating_count`) reste en lecture seule côté serveur : c'est un agrégat des
/// avis, et le rendre inscriptible permettrait de fabriquer une réputation.
class ManagedCatalogRepository {
  ManagedCatalogRepository({required this.apiClient});

  final ApiClient apiClient;

  // ------------------------------------------------------------ catégories

  /// Catégories, **inactives comprises**.
  ///
  /// La liste publique les filtre ; celle-ci les montre, sans quoi désactiver
  /// une catégorie la ferait disparaître de l'écran qui sert à la réactiver.
  Future<List<Category>> categories({String? restaurantSlug}) {
    return _collect(
      '/catalog/manage/categories/',
      Category.fromJson,
      queryParameters: {if (restaurantSlug != null) 'restaurant__slug': restaurantSlug},
    );
  }

  Future<Category> createCategory({
    required String restaurantSlug,
    required String name,
    required String slug,
    String emoji = '',
    String description = '',
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final response = await apiClient.post(
      '/catalog/manage/categories/',
      data: {
        'restaurant': restaurantSlug,
        'name': name,
        'slug': slug,
        'emoji': emoji,
        'description': description,
        'sort_order': sortOrder,
        'is_active': isActive,
      },
    );
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Category> updateCategory({
    required String categoryId,
    String? name,
    String? emoji,
    String? description,
    int? sortOrder,
    bool? isActive,
  }) async {
    final response = await apiClient.patch(
      '/catalog/manage/categories/$categoryId/',
      data: {
        if (name != null) 'name': name,
        if (emoji != null) 'emoji': emoji,
        if (description != null) 'description': description,
        if (sortOrder != null) 'sort_order': sortOrder,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String categoryId) async {
    await apiClient.delete('/catalog/manage/categories/$categoryId/');
  }

  // --------------------------------------------------------------- articles

  Future<List<MenuItem>> menuItems({String? restaurantSlug, String? categoryId}) {
    return _collect(
      '/catalog/manage/items/',
      MenuItem.fromJson,
      queryParameters: {
        if (restaurantSlug != null) 'restaurant__slug': restaurantSlug,
        if (categoryId != null) 'category': categoryId,
      },
    );
  }

  Future<MenuItem> getMenuItem(String menuItemId) async {
    final response = await apiClient.get('/catalog/manage/items/$menuItemId/');
    return MenuItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MenuItem> createMenuItem({
    required String restaurantSlug,
    required String categoryId,
    required String name,
    required String slug,
    required Money price,
    String description = '',
    int preparationMinutes = 15,
    int? calories,
    List<String> ingredients = const [],
    List<String> allergens = const [],
    List<String> dietaryTags = const [],
    bool isAvailable = true,
    bool isPopular = false,
    bool vipExclusive = false,
    int sortOrder = 0,
  }) async {
    final response = await apiClient.post(
      '/catalog/manage/items/',
      data: {
        'restaurant': restaurantSlug,
        'category': categoryId,
        'name': name,
        'slug': slug,
        'description': description,
        'price': price.toJson(),
        'preparation_minutes': preparationMinutes,
        if (calories != null) 'calories': calories,
        'ingredients': ingredients,
        'allergens': allergens,
        'dietary_tags': dietaryTags,
        'is_available': isAvailable,
        'is_popular': isPopular,
        'vip_exclusive': vipExclusive,
        'sort_order': sortOrder,
      },
    );
    return MenuItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MenuItem> updateMenuItem({
    required String menuItemId,
    String? name,
    String? description,
    String? categoryId,
    Money? price,
    int? preparationMinutes,
    int? calories,
    List<String>? ingredients,
    List<String>? allergens,
    List<String>? dietaryTags,
    bool? isAvailable,
    bool? isPopular,
    bool? vipExclusive,
    int? sortOrder,
  }) async {
    final response = await apiClient.patch(
      '/catalog/manage/items/$menuItemId/',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (categoryId != null) 'category': categoryId,
        if (price != null) 'price': price.toJson(),
        if (preparationMinutes != null) 'preparation_minutes': preparationMinutes,
        if (calories != null) 'calories': calories,
        if (ingredients != null) 'ingredients': ingredients,
        if (allergens != null) 'allergens': allergens,
        if (dietaryTags != null) 'dietary_tags': dietaryTags,
        if (isAvailable != null) 'is_available': isAvailable,
        if (isPopular != null) 'is_popular': isPopular,
        if (vipExclusive != null) 'vip_exclusive': vipExclusive,
        if (sortOrder != null) 'sort_order': sortOrder,
      },
    );
    return MenuItem.fromJson(response.data as Map<String, dynamic>);
  }

  /// Retire un article de la carte.
  ///
  /// Suppression **logique** côté serveur : l'article disparaît du catalogue
  /// mais reste lisible depuis les commandes passées, qui en conservent une
  /// copie figée.
  Future<void> deleteMenuItem(String menuItemId) async {
    await apiClient.delete('/catalog/manage/items/$menuItemId/');
  }

  // ------------------------------------------------------ groupes d'options

  Future<List<OptionGroup>> optionGroups({String? menuItemId}) {
    return _collect(
      '/catalog/manage/option-groups/',
      OptionGroup.fromJson,
      queryParameters: {if (menuItemId != null) 'menu_item': menuItemId},
    );
  }

  Future<OptionGroup> createOptionGroup({
    required String menuItemId,
    required String name,
    int minSelect = 0,
    int maxSelect = 1,
    int sortOrder = 0,
  }) async {
    final response = await apiClient.post(
      '/catalog/manage/option-groups/',
      data: {
        'menu_item': menuItemId,
        'name': name,
        'min_select': minSelect,
        'max_select': maxSelect,
        'sort_order': sortOrder,
      },
    );
    return OptionGroup.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OptionGroup> updateOptionGroup({
    required String groupId,
    String? name,
    int? minSelect,
    int? maxSelect,
    int? sortOrder,
  }) async {
    final response = await apiClient.patch(
      '/catalog/manage/option-groups/$groupId/',
      data: {
        if (name != null) 'name': name,
        if (minSelect != null) 'min_select': minSelect,
        if (maxSelect != null) 'max_select': maxSelect,
        if (sortOrder != null) 'sort_order': sortOrder,
      },
    );
    return OptionGroup.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteOptionGroup(String groupId) async {
    await apiClient.delete('/catalog/manage/option-groups/$groupId/');
  }

  // -------------------------------------------------------------- options

  Future<List<Option>> options({String? groupId}) {
    return _collect(
      '/catalog/manage/options/',
      Option.fromJson,
      queryParameters: {if (groupId != null) 'group': groupId},
    );
  }

  Future<Option> createOption({
    required String groupId,
    required String name,
    required Money priceDelta,
    bool isDefault = false,
    bool isAvailable = true,
    int sortOrder = 0,
  }) async {
    final response = await apiClient.post(
      '/catalog/manage/options/',
      data: {
        'group': groupId,
        'name': name,
        'price_delta': priceDelta.toJson(),
        'is_default': isDefault,
        'is_available': isAvailable,
        'sort_order': sortOrder,
      },
    );
    return Option.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Option> updateOption({
    required String optionId,
    String? name,
    Money? priceDelta,
    bool? isDefault,
    bool? isAvailable,
    int? sortOrder,
  }) async {
    final response = await apiClient.patch(
      '/catalog/manage/options/$optionId/',
      data: {
        if (name != null) 'name': name,
        if (priceDelta != null) 'price_delta': priceDelta.toJson(),
        if (isDefault != null) 'is_default': isDefault,
        if (isAvailable != null) 'is_available': isAvailable,
        if (sortOrder != null) 'sort_order': sortOrder,
      },
    );
    return Option.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteOption(String optionId) async {
    await apiClient.delete('/catalog/manage/options/$optionId/');
  }

  // ------------------------------------------- bibliothèque de modèles

  /// Options réutilisables de l'établissement.
  Future<List<OptionTemplate>> optionTemplates({
    String? restaurantSlug,
    String? groupName,
    bool? isActive,
  }) {
    return _collect(
      '/catalog/manage/option-templates/',
      OptionTemplate.fromJson,
      queryParameters: {
        if (restaurantSlug != null) 'restaurant__slug': restaurantSlug,
        if (groupName != null) 'group_name': groupName,
        if (isActive != null) 'is_active': isActive.toString(),
      },
    );
  }

  Future<OptionTemplate> createOptionTemplate({
    required String restaurantSlug,
    required String name,
    required Money priceDelta,
    String groupName = '',
    bool isDefault = false,
    int sortOrder = 0,
  }) async {
    final response = await apiClient.post(
      '/catalog/manage/option-templates/',
      data: {
        'restaurant': restaurantSlug,
        'name': name,
        'group_name': groupName,
        'price_delta': priceDelta.toJson(),
        'is_default': isDefault,
        'sort_order': sortOrder,
      },
    );
    return OptionTemplate.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OptionTemplate> updateOptionTemplate({
    required String templateId,
    String? name,
    String? groupName,
    Money? priceDelta,
    bool? isDefault,
    bool? isActive,
    int? sortOrder,
  }) async {
    final response = await apiClient.patch(
      '/catalog/manage/option-templates/$templateId/',
      data: {
        if (name != null) 'name': name,
        if (groupName != null) 'group_name': groupName,
        if (priceDelta != null) 'price_delta': priceDelta.toJson(),
        if (isDefault != null) 'is_default': isDefault,
        if (isActive != null) 'is_active': isActive,
        if (sortOrder != null) 'sort_order': sortOrder,
      },
    );
    return OptionTemplate.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteOptionTemplate(String templateId) async {
    await apiClient.delete('/catalog/manage/option-templates/$templateId/');
  }

  /// Applique un modèle à un article — rend le groupe, options comprises.
  ///
  /// **Copie** : l'option créée porte le nom et le prix du modèle au moment de
  /// l'application, puis vit sa propre vie. Ni l'un ni l'autre ne s'envoient
  /// ici, sans quoi « appliquer un modèle » deviendrait « créer une option
  /// quelconque ».
  ///
  /// [groupName] vise un groupe précis ; à défaut, celui du modèle. Le groupe
  /// est créé s'il n'existe pas encore sur l'article.
  Future<OptionGroup> applyTemplate({
    required String menuItemId,
    required String templateId,
    String groupName = '',
  }) async {
    final response = await apiClient.post(
      '/catalog/manage/items/$menuItemId/apply-template/',
      data: {
        'template': templateId,
        if (groupName.isNotEmpty) 'group_name': groupName,
      },
    );
    return OptionGroup.fromJson(response.data as Map<String, dynamic>);
  }

  // --------------------------------------------------------------- interne

  Future<List<T>> _collect<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final items = <T>[];
    String? next = path;
    Map<String, dynamic>? parameters = queryParameters;

    while (next != null) {
      final response = await apiClient.get(next, queryParameters: parameters);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      items.addAll(results.map((json) => fromJson(json as Map<String, dynamic>)));
      next = body['next'] as String?;
      parameters = null;
    }

    return items;
  }
}
