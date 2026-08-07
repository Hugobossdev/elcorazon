/// Catégorie vue de l'exploitation — miroir de `ManagedCategorySerializer`
/// (`backend/apps/catalog/serializers.py`).
///
/// Elle se distingue de [Category], que rend la route publique, sur un point
/// qui compte pour le back-office : **`isActive` existe**. La liste publique ne
/// rend que les catégories actives ; celle du siège les rend toutes, sans quoi
/// désactiver une catégorie la ferait disparaître de l'écran qui sert à la
/// réactiver — c'est le mot du sérialiseur lui-même.
///
/// Le dépôt d'exploitation rendait auparavant des [Category] : le champ
/// arrivait du serveur et se perdait au parsing. Le back-office affichait donc
/// toute catégorie comme active, et sa prochaine modification la réactivait en
/// silence. Même distinction, même raison, que [ManagedCity] face à `City`.
class ManagedCategory {
  const ManagedCategory({
    required this.id,
    required this.restaurantSlug,
    required this.name,
    required this.slug,
    required this.emoji,
    required this.description,
    required this.sortOrder,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory ManagedCategory.fromJson(Map<String, dynamic> json) {
    return ManagedCategory(
      id: json['id'] as String,
      restaurantSlug: json['restaurant'].toString(),
      name: json['name'] as String,
      slug: json['slug'] as String,
      emoji: json['emoji'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sortOrder: json['sort_order'] as int,
      // Absent d'une réponse publique : une catégorie qu'on y voit est active
      // par construction.
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  final String id;
  final String restaurantSlug;
  final String name;
  final String slug;
  final String emoji;
  final String description;
  final int sortOrder;

  /// Une catégorie inactive reste visible du siège, et disparaît du catalogue
  /// client.
  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  ManagedCategory copyWith({
    String? name,
    String? emoji,
    String? description,
    int? sortOrder,
    bool? isActive,
  }) {
    return ManagedCategory(
      id: id,
      restaurantSlug: restaurantSlug,
      name: name ?? this.name,
      slug: slug,
      emoji: emoji ?? this.emoji,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
