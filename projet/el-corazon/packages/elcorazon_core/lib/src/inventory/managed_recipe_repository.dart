import 'package:elcorazon_core/src/inventory/inventory.dart';
import 'package:elcorazon_core/src/inventory/quantity.dart';
import 'package:elcorazon_core/src/network/api_client.dart';

/// Recettes d'une carte — `/api/v1/production/manage/recipes/*`
/// (`backend/apps/production/backoffice.py`).
///
/// Une permission propre (`recipes.read`, `recipes.write`), distincte du
/// catalogue : une recette ne change pas ce que voit le client, elle change le
/// coût matière et ce que la réservation immobilise.
class ManagedRecipeRepository {
  ManagedRecipeRepository({required this.apiClient});

  final ApiClient apiClient;

  static const _base = '/production/manage/recipes/';

  /// Les recettes d'une cuisine — celles de ses plats et de leurs options.
  Future<List<Recipe>> recipes({required String restaurantSlug}) async {
    final items = <Recipe>[];
    String? next = _base;
    Map<String, dynamic>? parameters = {'restaurant': restaurantSlug};

    while (next != null) {
      final response = await apiClient.get(next, queryParameters: parameters);
      final body = response.data as Map<String, dynamic>;
      items.addAll(
        (body['results'] as List<dynamic>)
            .map((json) => Recipe.fromJson(json as Map<String, dynamic>)),
      );
      next = body['next'] as String?;
      parameters = null;
    }
    return items;
  }

  /// Crée la recette d'un plat — ou d'une option, exactement l'un des deux.
  Future<Recipe> create({String? menuItemId, String? optionId, String notes = ''}) async {
    assert(
      (menuItemId == null) != (optionId == null),
      'Une recette vise exactement un plat ou une option.',
    );
    final response = await apiClient.post(
      _base,
      data: {
        if (menuItemId != null) 'menu_item': menuItemId,
        if (optionId != null) 'option': optionId,
        'notes': notes,
      },
    );
    return Recipe.fromJson(response.data as Map<String, dynamic>);
  }

  /// Pose — ou remplace — la quantité d'un ingrédient. Rend la recette entière.
  Future<Recipe> setLine({
    required String recipeId,
    required String ingredientId,
    required Quantity quantity,
  }) async {
    final response = await apiClient.post(
      '$_base$recipeId/lines/',
      data: {'ingredient': ingredientId, 'quantity': quantity.toJson()},
    );
    return Recipe.fromJson(response.data as Map<String, dynamic>);
  }

  /// Retire un ingrédient. Retirer ce qui n'y est pas n'est pas une erreur.
  Future<Recipe> removeLine({required String recipeId, required String ingredientId}) async {
    final response = await apiClient.delete('$_base$recipeId/lines/$ingredientId/');
    return Recipe.fromJson(response.data as Map<String, dynamic>);
  }

  /// Ce qu'il reste à saisir avant de croire le coût matière de la cuisine.
  Future<RecipeCoverage> coverage({required String restaurantSlug}) async {
    final response = await apiClient.get(
      '${_base}coverage/',
      queryParameters: {'restaurant': restaurantSlug},
    );
    return RecipeCoverage.fromJson(response.data as Map<String, dynamic>);
  }
}
