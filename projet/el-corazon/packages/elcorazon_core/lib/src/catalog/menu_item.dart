import '../models/money.dart';

/// Article du catalogue — miroir de `MenuItemSerializer`
/// (`backend/apps/catalog/serializers.py`). Forme de liste uniquement : pas
/// d'`ingredients`/`calories`/`option_groups` (`MenuItemDetailSerializer`),
/// la personnalisation n'est pas migrée par ce module.
class MenuItem {
  const MenuItem({
    required this.id,
    required this.restaurantSlug,
    required this.categorySlug,
    required this.categoryName,
    required this.name,
    required this.slug,
    required this.description,
    required this.image,
    required this.price,
    required this.preparationMinutes,
    required this.allergens,
    required this.dietaryTags,
    required this.isAvailable,
    required this.isPopular,
    required this.vipExclusive,
    required this.ratingAverage,
    required this.ratingCount,
    required this.sortOrder,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      restaurantSlug: json['restaurant'] as String,
      categorySlug: json['category'] as String,
      categoryName: json['category_name'] as String? ?? '',
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String? ?? '',
      image: json['image'] as String?,
      price: Money.fromJson(json['price'] as Map<String, dynamic>),
      preparationMinutes: json['preparation_minutes'] as int? ?? 0,
      allergens: (json['allergens'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      dietaryTags: (json['dietary_tags'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      isAvailable: json['is_available'] as bool,
      isPopular: json['is_popular'] as bool,
      vipExclusive: json['vip_exclusive'] as bool,
      ratingAverage: double.parse(json['rating_average'].toString()),
      ratingCount: json['rating_count'] as int,
      sortOrder: json['sort_order'] as int,
    );
  }

  final String id;
  final String restaurantSlug;
  final String categorySlug;
  final String categoryName;
  final String name;
  final String slug;
  final String description;
  final String? image;
  final Money price;
  final int preparationMinutes;
  final List<String> allergens;
  final List<String> dietaryTags;
  final bool isAvailable;
  final bool isPopular;
  final bool vipExclusive;
  final double ratingAverage;
  final int ratingCount;
  final int sortOrder;
}
