import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/repositories/menu_repository.dart';
import 'package:elcora_fast/services/kitchen_context_service.dart';

/// Le catalogue, contre le backend Django.
///
/// Il ne traduit plus rien : `eccore.CatalogRepository` rend déjà les entités
/// que les écrans lisent. Ce qui reste est le peu que l'application ajoute —
/// l'établissement dont il s'agit, et la périodicité du rafraîchissement.
///
/// La cuisine vient de [KitchenContextService] et non d'une constante : le
/// catalogue est **par cuisine** côté serveur, si bien qu'un slug écrit en dur
/// rendrait la carte de Lomé sous le nom de n'importe quelle autre cuisine.
///
/// Quand aucune cuisine ne peut être désignée, `exigerSlug` lève
/// `CuisineIndisponible` avec sa cause — panne, réponse vide, adresse hors
/// zone —, et c'est elle que l'écran de la carte affiche.
class DjangoMenuRepository implements MenuRepository {
  DjangoMenuRepository({
    eccore.CatalogRepository? catalogRepository,
    KitchenContextService? kitchenContext,
  }) : _catalog =
           catalogRepository ?? eccore.CatalogRepository(apiClient: apiClient),
       _contexte = kitchenContext ?? KitchenContextService();

  final eccore.CatalogRepository _catalog;
  final KitchenContextService _contexte;

  @override
  Future<List<eccore.MenuItem>> getMenuItems({String? categoryId}) async {
    return _catalog.getMenuItems(
      restaurantSlug: await _contexte.exigerSlug(),
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
  Future<List<eccore.Category>> getMenuCategories() async {
    return _catalog.getCategories(restaurantSlug: await _contexte.exigerSlug());
  }

  @override
  Future<List<eccore.MenuItem>> searchMenuItems(String query) async {
    return _catalog.getMenuItems(
      restaurantSlug: await _contexte.exigerSlug(),
      search: query,
    );
  }

  @override
  Future<List<eccore.MenuItem>> getPopularMenuItems({int limit = 10}) async {
    final items = await _catalog.getMenuItems(
      restaurantSlug: await _contexte.exigerSlug(),
      isPopular: true,
    );
    return items.take(limit).toList();
  }
}
