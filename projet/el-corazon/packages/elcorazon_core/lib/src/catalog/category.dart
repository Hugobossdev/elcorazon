/// Catégorie du catalogue — miroir de `CategorySerializer`
/// (`backend/apps/catalog/serializers.py`).
class Category {
  const Category({
    required this.id,
    required this.restaurantSlug,
    required this.name,
    required this.slug,
    required this.emoji,
    required this.description,
    required this.sortOrder,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      restaurantSlug: json['restaurant'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      emoji: json['emoji'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sortOrder: json['sort_order'] as int,
    );
  }

  final String id;
  final String restaurantSlug;
  final String name;
  final String slug;
  final String emoji;
  final String description;
  final int sortOrder;
}
