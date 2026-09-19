import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/network/page.dart';

/// Un avis client vu de la modération — `/catalog/manage/reviews/`.
///
/// Un avis se **masque**, il ne s'efface pas : masqué, il sort de la liste
/// publique et de la note moyenne de l'article ; le motif et l'auteur du geste
/// restent, et le geste est journalisé.
class ManagedReview {
  const ManagedReview({
    required this.id,
    required this.menuItemId,
    required this.menuItemName,
    required this.restaurantName,
    required this.authorName,
    required this.rating,
    required this.createdAt,
    this.title = '',
    this.comment = '',
    this.isVerifiedPurchase = false,
    this.hiddenAt,
    this.hiddenReason = '',
    this.hiddenByName,
  });

  factory ManagedReview.fromJson(Map<String, dynamic> json) {
    final auteur = json['user'] as Map<String, dynamic>? ?? const {};
    return ManagedReview(
      id: json['id'] as String,
      menuItemId: json['menu_item'] as String,
      menuItemName: json['menu_item_name'] as String? ?? '',
      restaurantName: json['restaurant_name'] as String? ?? '',
      authorName: auteur['full_name'] as String? ?? '',
      rating: json['rating'] as int,
      title: json['title'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
      isVerifiedPurchase: json['is_verified_purchase'] as bool? ?? false,
      hiddenAt: json['hidden_at'] == null ? null : DateTime.parse(json['hidden_at'] as String),
      hiddenReason: json['hidden_reason'] as String? ?? '',
      hiddenByName: json['hidden_by_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String menuItemId;
  final String menuItemName;
  final String restaurantName;
  final String authorName;
  final int rating;
  final String title;
  final String comment;
  final bool isVerifiedPurchase;
  final DateTime? hiddenAt;
  final String hiddenReason;
  final String? hiddenByName;
  final DateTime createdAt;

  bool get estMasque => hiddenAt != null;
}

class ManagedReviewRepository {
  ManagedReviewRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Une page d'avis — `catalog.read`, dans le périmètre du compte.
  ///
  /// [masques] : `true` les seuls masqués, `false` les seuls visibles, `null`
  /// tous. [noteMax] retient les avis au plus de tant d'étoiles — les
  /// mécontents, qu'on lit d'abord.
  Future<Page<ManagedReview>> reviews({
    bool? masques,
    int? noteMax,
    String? recherche,
    int pageSize = 50,
  }) async {
    final response = await apiClient.get(
      '/catalog/manage/reviews/',
      queryParameters: {
        'page_size': pageSize,
        if (masques != null) 'hidden_at__isnull': (!masques).toString(),
        if (noteMax != null) 'rating__lte': noteMax,
        if (recherche != null && recherche.trim().isNotEmpty) 'search': recherche.trim(),
      },
    );
    return Page.fromJson(response.data as Map<String, dynamic>, ManagedReview.fromJson);
  }

  /// Masque un avis — `catalog.write`, motif exigé.
  Future<ManagedReview> hide({required String reviewId, required String reason}) async {
    final response = await apiClient.post(
      '/catalog/manage/reviews/$reviewId/hide/',
      data: {'reason': reason},
    );
    return ManagedReview.fromJson(response.data as Map<String, dynamic>);
  }

  /// Réaffiche un avis masqué.
  Future<ManagedReview> show(String reviewId) async {
    final response = await apiClient.post('/catalog/manage/reviews/$reviewId/show/');
    return ManagedReview.fromJson(response.data as Map<String, dynamic>);
  }
}
