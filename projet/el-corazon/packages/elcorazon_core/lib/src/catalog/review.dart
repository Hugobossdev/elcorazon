/// Auteur d'un avis — miroir de `ReviewAuthorSerializer`
/// (`backend/apps/catalog/serializers.py`) : réduit à ce qu'une page publique
/// doit montrer, sans adresse électronique ni téléphone.
class ReviewAuthor {
  const ReviewAuthor({required this.id, required this.fullName, this.avatarUrl});

  factory ReviewAuthor.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar'] as String?;
    return ReviewAuthor(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      avatarUrl: avatar == null || avatar.isEmpty ? null : avatar,
    );
  }

  final String id;
  final String fullName;
  final String? avatarUrl;
}

/// Avis sur un article — miroir de `ReviewSerializer`.
///
/// [isVerifiedPurchase] est **calculé par le serveur** à la soumission (S1) :
/// le champ est `editable=False` côté modèle, donc absent des sérialiseurs
/// d'écriture — aucune requête ne peut le forcer, et le client n'a plus à
/// deviner l'historique d'achat pour le renseigner lui-même.
class Review {
  const Review({
    required this.id,
    required this.menuItemId,
    required this.author,
    required this.rating,
    required this.title,
    required this.comment,
    required this.isVerifiedPurchase,
    required this.helpfulCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      menuItemId: json['menu_item'] as String,
      author: ReviewAuthor.fromJson(json['user'] as Map<String, dynamic>),
      rating: json['rating'] as int,
      title: json['title'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
      isVerifiedPurchase: json['is_verified_purchase'] as bool,
      helpfulCount: json['helpful_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String menuItemId;
  final ReviewAuthor author;

  /// Entier de 1 à 5 — le serveur refuse tout le reste. Plus de `double` : une
  /// note à 4,5 étoiles n'a jamais existé côté base.
  final int rating;
  final String title;
  final String comment;
  final bool isVerifiedPurchase;
  final int helpfulCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}
