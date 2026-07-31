import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/menu_category.dart';
import 'package:elcora_fast/repositories/menu_repository.dart';

/// Implémentation `MenuRepository` contre le backend Django (Phase 6) —
/// remplace `SupabaseMenuRepository`. Traduit les DTOs partagés
/// (`eccore.Category`/`eccore.MenuItem`) vers les modèles locaux, sur le même
/// principe que `AppService._fromDjangoUser` : le reste de l'app (écrans,
/// panier, `PriceFormatter`) continue de lire `lib/models/menu_item.dart` sans
/// changement.
class DjangoMenuRepository implements MenuRepository {
  DjangoMenuRepository({eccore.CatalogRepository? catalogRepository})
    : _catalog = catalogRepository ?? eccore.CatalogRepository(apiClient: apiClient);

  final eccore.CatalogRepository _catalog;

  @override
  Future<List<MenuItem>> getMenuItems({String? categoryId}) async {
    final items = await _catalog.getMenuItems(
      restaurantSlug: AppConstants.restaurantSlug,
      categorySlug: categoryId,
    );
    return items.map(toLocalMenuItem).toList();
  }

  @override
  Future<MenuItem?> getMenuItemById(String id) async {
    try {
      final item = await _catalog.getMenuItem(id);
      return toLocalMenuItem(item);
    } on eccore.ApiException catch (error) {
      if (error.status == 404) return null;
      rethrow;
    }
  }

  @override
  Stream<List<MenuItem>> watchMenuItems({String? categoryId}) {
    // Pas de WebSocket catalogue prévu (voir docs/architecture/04-migration-flutter.md) —
    // même polling que l'ancienne implémentation Supabase.
    return Stream.periodic(const Duration(seconds: 30), (_) => null)
        .asyncMap((_) => getMenuItems(categoryId: categoryId));
  }

  @override
  Future<List<MenuCategory>> getMenuCategories() async {
    final categories = await _catalog.getCategories(restaurantSlug: AppConstants.restaurantSlug);
    return categories.map(_toLocalMenuCategory).toList();
  }

  @override
  Future<List<MenuItem>> searchMenuItems(String query) async {
    final items = await _catalog.getMenuItems(
      restaurantSlug: AppConstants.restaurantSlug,
      search: query,
    );
    return items.map(toLocalMenuItem).toList();
  }

  @override
  Future<List<MenuItem>> getPopularMenuItems({int limit = 10}) async {
    final items = await _catalog.getMenuItems(
      restaurantSlug: AppConstants.restaurantSlug,
      isPopular: true,
    );
    return items.take(limit).map(toLocalMenuItem).toList();
  }

  /// Traduction du contrat Django vers le modèle local. Statique et publique :
  /// `AdvancedSearchService` interroge le même endpoint avec ses propres
  /// critères et doit rendre exactement les mêmes objets — deux traductions
  /// divergeraient.
  static MenuItem toLocalMenuItem(eccore.MenuItem item) {
    return MenuItem(
      id: item.id,
      name: item.name,
      description: item.description,
      price: item.price.toMajorUnits(),
      categoryId: item.categorySlug,
      category: MenuCategory(
        id: item.categorySlug,
        name: item.categoryName,
        displayName: item.categoryName,
        emoji: '',
      ),
      imageUrl: item.image,
      isPopular: item.isPopular,
      // Le contrat Django ne porte pas de booléens séparés pour ces deux
      // régimes — dérivés de `dietary_tags` (`common/serializers.py`).
      isVegetarian: item.dietaryTags.contains('vegetarian'),
      isVegan: item.dietaryTags.contains('vegan'),
      isAvailable: item.isAvailable,
      preparationTime: item.preparationMinutes,
      rating: item.ratingAverage,
      reviewCount: item.ratingCount,
      isVipExclusive: item.vipExclusive,
    );
  }

  MenuCategory _toLocalMenuCategory(eccore.Category category) {
    return MenuCategory(
      id: category.slug,
      name: category.name,
      displayName: category.name,
      emoji: category.emoji,
      description: category.description,
      sortOrder: category.sortOrder,
    );
  }
}
