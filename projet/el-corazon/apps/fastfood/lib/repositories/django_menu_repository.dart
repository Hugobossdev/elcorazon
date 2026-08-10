import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/repositories/menu_repository.dart';

/// Le catalogue, contre le backend Django.
///
/// Il ne traduit plus rien : `eccore.CatalogRepository` rend déjà les entités
/// que les écrans lisent. Ce qui reste est le peu que l'application ajoute —
/// l'établissement dont il s'agit, et la périodicité du rafraîchissement.
class DjangoMenuRepository implements MenuRepository {
  DjangoMenuRepository({eccore.CatalogRepository? catalogRepository})
    : _catalog =
          catalogRepository ?? eccore.CatalogRepository(apiClient: apiClient);

  final eccore.CatalogRepository _catalog;

  @override
  Future<List<eccore.MenuItem>> getMenuItems({String? categoryId}) {
    return _catalog.getMenuItems(
      restaurantSlug: AppConstants.restaurantSlug,
      categorySlug: categoryId,
    );
  }

  @override
  Future<eccore.MenuItem?> getMenuItemById(String id) async {
    try {
      return await _catalog.getMenuItem(id);
    } on eccore.ApiException catch (error) {
      if (error.status == 404) return null;
      rethrow;
    }
  }

  @override
  Stream<List<eccore.MenuItem>> watchMenuItems({String? categoryId}) {
    // Pas de WebSocket catalogue prévu — voir
    // `docs/architecture/04-migration-flutter.md`. Même périodicité que
    // l'implémentation Supabase qu'elle remplace.
    return Stream.periodic(const Duration(seconds: 30), (_) => null)
        .asyncMap((_) => getMenuItems(categoryId: categoryId));
  }

  @override
  Future<List<eccore.Category>> getMenuCategories() {
    return _catalog.getCategories(restaurantSlug: AppConstants.restaurantSlug);
  }

  @override
  Future<List<eccore.MenuItem>> searchMenuItems(String query) {
    return _catalog.getMenuItems(
      restaurantSlug: AppConstants.restaurantSlug,
      search: query,
    );
  }

  @override
  Future<List<eccore.MenuItem>> getPopularMenuItems({int limit = 10}) async {
    final items = await _catalog.getMenuItems(
      restaurantSlug: AppConstants.restaurantSlug,
      isPopular: true,
    );
    return items.take(limit).toList();
  }
}
