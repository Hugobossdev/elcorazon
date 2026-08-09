import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/main.dart' show apiClient;

/// Avis produits contre le backend Django (Phase 6) — `/catalog/reviews/`.
///
/// Trois choses que le client faisait et ne fait plus : calculer la moyenne
/// des notes (elle vit sur l'article, entretenue par `ReviewService.
/// refresh_rating`), déterminer si l'achat est vérifié (le serveur le sait, le
/// client ne pouvait que l'approximer), et transformer un second avis en mise
/// à jour (`upsert`) — le serveur refuse, un avis par article et par personne.
class DjangoReviewRepository {
  DjangoReviewRepository() : _catalog = eccore.CatalogRepository(apiClient: apiClient);

  final eccore.CatalogRepository _catalog;

  Future<List<eccore.Review>> getReviews(String menuItemId) => _catalog.getReviews(menuItemId);

  Future<eccore.Review> submitReview({
    required String menuItemId,
    required int rating,
    String title = '',
    String comment = '',
  }) {
    return _catalog.submitReview(
      menuItemId: menuItemId,
      rating: rating,
      title: title,
      comment: comment,
    );
  }

  /// Note moyenne et nombre d'avis tels que le serveur les tient sur
  /// l'article — jamais recalculés depuis la liste chargée.
  Future<({double average, int count})> getRating(String menuItemId) async {
    final item = await _catalog.getMenuItem(menuItemId);
    return (average: item.ratingAverage, count: item.ratingCount);
  }
}
