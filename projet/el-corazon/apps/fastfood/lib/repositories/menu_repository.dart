import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Accès au catalogue, vu par l'application.
///
/// L'abstraction survit à la migration : elle sépare les écrans de la source
/// des données, et c'est elle qui a permis de remplacer Supabase par Django
/// sans toucher aux écrans. Ce sont les **types** qui changent — plus de
/// modèles locaux, les entités du socle directement.
abstract class MenuRepository {
  /// Les articles, éventuellement d'une seule catégorie (par son slug).
  Future<List<eccore.MenuItem>> getMenuItems({String? categoryId});

  Future<eccore.MenuItem?> getMenuItemById(String id);

  /// Le catalogue rafraîchi périodiquement — il n'y a pas de WebSocket
  /// catalogue.
  Stream<List<eccore.MenuItem>> watchMenuItems({String? categoryId});

  Future<List<eccore.Category>> getMenuCategories();

  Future<List<eccore.MenuItem>> searchMenuItems(String query);

  Future<List<eccore.MenuItem>> getPopularMenuItems({int limit = 10});
}
