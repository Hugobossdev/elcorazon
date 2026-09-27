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
    this.image,
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
      image: _url(json['image']),
    );
  }

  /// L'inverse de [Category.fromJson] — voir [MenuItem.toJson] pour le
  /// pourquoi : le cache local doit pouvoir relire ce qu'il a rangé.
  Map<String, dynamic> toJson() => {
        'id': id,
        'restaurant': restaurantSlug,
        'name': name,
        'slug': slug,
        'emoji': emoji,
        'description': description,
        'sort_order': sortOrder,
        'image': image,
      };

  final String id;
  final String restaurantSlug;
  final String name;
  final String slug;
  final String emoji;
  final String description;
  final int sortOrder;

  /// Photo de la catégorie (lot 3) — URL publique, `null` sans photo. Les
  /// applications gardent alors leur illustration choisie par le slug.
  final String? image;
}

/// Une URL absente ou vide se lit `null` : « pas de photo » n'a qu'une forme.
String? _url(Object? valeur) {
  final texte = valeur?.toString() ?? '';
  return texte.isEmpty ? null : texte;
}
