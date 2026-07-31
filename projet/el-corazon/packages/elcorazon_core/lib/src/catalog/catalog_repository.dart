import '../network/api_client.dart';
import 'category.dart';
import 'menu_item.dart';
import 'review.dart';

/// Accès à `/api/v1/catalog/*` et `/api/v1/restaurants/*` en lecture seule —
/// voir `backend/apps/catalog/{serializers,views}.py`. Public
/// (`permission_classes = [AllowAny]`) : passe par [ApiClient] comme le reste,
/// mais ne dépend d'aucune session active.
class CatalogRepository {
  CatalogRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Catégories actives d'un restaurant. Pas de pagination côté serveur — une
  /// carte compte une dizaine de catégories.
  Future<List<Category>> getCategories({required String restaurantSlug}) async {
    final response = await apiClient.get(
      '/catalog/categories/',
      queryParameters: {'restaurant__slug': restaurantSlug},
    );
    final results = response.data as List<dynamic>;
    return results.map((json) => Category.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Articles disponibles d'un restaurant, avec filtres optionnels.
  ///
  /// Le serveur pagine (`PAGE_SIZE=20`) : un menu peut dépasser une page, donc
  /// cette méthode suit `next` jusqu'à épuisement plutôt que de renvoyer la
  /// première page seule.
  /// Les critères de recherche avancée (prix, régimes, allergènes, calories,
  /// temps de préparation, note) sont appliqués **par le serveur**
  /// (`apps/catalog/filters.py`) : filtrer une page déjà reçue ne verrait pas
  /// les articles restés sur les suivantes.
  ///
  /// [priceMinMinor]/[priceMaxMinor] sont en unité mineure, comme tout montant
  /// du contrat (ADR-007). [dietaryTags] et [ingredients] cumulent (l'article
  /// doit tous les porter) ; [excludeAllergens] écarte dès qu'un seul est
  /// présent.
  Future<List<MenuItem>> getMenuItems({
    required String restaurantSlug,
    String? categorySlug,
    bool? isPopular,
    String? search,
    int? priceMinMinor,
    int? priceMaxMinor,
    int? caloriesMin,
    int? caloriesMax,
    int? preparationMaxMinutes,
    double? ratingMin,
    List<String>? dietaryTags,
    List<String>? excludeAllergens,
    List<String>? ingredients,
    String? ordering,
  }) async {
    final items = <MenuItem>[];
    String? path = '/catalog/items/';
    Map<String, dynamic>? queryParameters = {
      'restaurant__slug': restaurantSlug,
      if (categorySlug != null) 'category__slug': categorySlug,
      if (isPopular != null) 'is_popular': isPopular.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (priceMinMinor != null) 'price_min': '$priceMinMinor',
      if (priceMaxMinor != null) 'price_max': '$priceMaxMinor',
      if (caloriesMin != null) 'calories_min': '$caloriesMin',
      if (caloriesMax != null) 'calories_max': '$caloriesMax',
      if (preparationMaxMinutes != null) 'preparation_max': '$preparationMaxMinutes',
      if (ratingMin != null) 'rating_min': '$ratingMin',
      if (dietaryTags != null && dietaryTags.isNotEmpty) 'dietary_tags': dietaryTags.join(','),
      if (excludeAllergens != null && excludeAllergens.isNotEmpty)
        'exclude_allergens': excludeAllergens.join(','),
      if (ingredients != null && ingredients.isNotEmpty) 'ingredients': ingredients.join(','),
      if (ordering != null) 'ordering': ordering,
    };

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      items.addAll(results.map((json) => MenuItem.fromJson(json as Map<String, dynamic>)));

      // `next` est une URL absolue déjà porteuse de ses propres paramètres de
      // requête (page suivante incluse) — ne pas la recombiner avec
      // `queryParameters`, sous peine de dupliquer `page=`.
      path = body['next'] as String?;
      queryParameters = null;
    }

    return items;
  }

  Future<MenuItem> getMenuItem(String id) async {
    final response = await apiClient.get('/catalog/items/$id/');
    return MenuItem.fromJson(response.data as Map<String, dynamic>);
  }

  /// Avis d'un article, les plus récents d'abord (tri du serveur). Lecture
  /// publique : cette méthode fonctionne aussi sans session.
  Future<List<Review>> getReviews(String menuItemId) async {
    final reviews = <Review>[];
    String? path = '/catalog/reviews/';
    Map<String, dynamic>? queryParameters = {'menu_item': menuItemId};

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      reviews.addAll(results.map((json) => Review.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
      queryParameters = null;
    }

    return reviews;
  }

  /// Dépose un avis. **Un seul par article et par utilisateur** (S5) : un
  /// second est refusé par le serveur (409), il n'est pas transformé en mise à
  /// jour — modifier un avis après coup est un geste de modération, pas une
  /// écriture ordinaire. L'appelant doit donc traiter l'[ApiException] plutôt
  /// que de rejouer un `upsert`.
  ///
  /// La note est un entier de 1 à 5 ; `is_verified_purchase` revient calculé
  /// dans la réponse, il ne s'envoie pas.
  Future<Review> submitReview({
    required String menuItemId,
    required int rating,
    String title = '',
    String comment = '',
  }) async {
    final response = await apiClient.post(
      '/catalog/reviews/',
      data: {
        'menu_item': menuItemId,
        'rating': rating,
        'title': title,
        'comment': comment,
      },
    );
    return Review.fromJson(response.data as Map<String, dynamic>);
  }
}
