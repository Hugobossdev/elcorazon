import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:elcora_fast/repositories/django_review_repository.dart';

/// Agrégat d'affichage d'un article : la moyenne et le total viennent du
/// serveur (`rating_average`/`rating_count` sur l'article), seule la
/// répartition par étoile est comptée localement à partir des avis déjà
/// chargés — c'est de la mise en forme, pas une règle métier.
class ProductRating {
  const ProductRating({
    required this.menuItemId,
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  final String menuItemId;
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution;
}

/// Avis produits, contre le backend Django (Phase 6).
///
/// Le modèle local `ProductReview` disparaît au profit de `eccore.Review` :
/// il portait un `userName` et un `isVerifiedPurchase` que le client
/// renseignait lui-même, ainsi que des `photos` et un `isHelpful` qui n'ont
/// pas d'équivalent dans le contrat.
class ReviewRatingService extends ChangeNotifier {
  final DjangoReviewRepository _repository = DjangoReviewRepository();

  List<eccore.Review> _reviews = [];
  final Map<String, ProductRating> _ratings = {};
  bool _isLoading = false;
  String? _error;

  List<eccore.Review> get reviews => List.unmodifiable(_reviews);
  Map<String, ProductRating> get ratings => Map.unmodifiable(_ratings);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadReviews(String menuItemId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _reviews = await _repository.getReviews(menuItemId);
      eccore.Journal.trace('✅ Chargé ${_reviews.length} avis pour $menuItemId');
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('❌ Chargement des avis: ${e.code}');
      _reviews = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// À appeler après [loadReviews] : la répartition se compte sur les avis en
  /// mémoire, la moyenne et le total viennent du serveur.
  Future<void> loadRating(String menuItemId) async {
    try {
      final rating = await _repository.getRating(menuItemId);

      final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final review in _reviews.where((r) => r.menuItemId == menuItemId)) {
        distribution[review.rating] = (distribution[review.rating] ?? 0) + 1;
      }

      _ratings[menuItemId] = ProductRating(
        menuItemId: menuItemId,
        averageRating: rating.average,
        totalReviews: rating.count,
        ratingDistribution: distribution,
      );
      notifyListeners();
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('❌ Chargement de la note de $menuItemId: ${e.code}');
    }
  }

  /// Dépose un avis. [rating] est un entier de 1 à 5 ; un second avis sur le
  /// même article est refusé par le serveur (S5) et remonte dans [error] avec
  /// son motif, au lieu d'être silencieusement transformé en modification.
  Future<bool> addReview({
    required String menuItemId,
    required int rating,
    String title = '',
    String comment = '',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final review = await _repository.submitReview(
        menuItemId: menuItemId,
        rating: rating,
        title: title,
        comment: comment,
      );
      _reviews.insert(0, review);
      await loadRating(menuItemId);
      eccore.Journal.trace('✅ Avis déposé: ${review.id}');
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('❌ Dépôt de l\'avis: ${e.code}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Vrai si [userId] a déjà un avis sur cet article parmi ceux chargés — ce
  /// que le serveur refusera de toute façon en écriture.
  bool hasReviewed({required String userId, required String menuItemId}) {
    return _reviews.any((r) => r.menuItemId == menuItemId && r.author.id == userId);
  }
}
