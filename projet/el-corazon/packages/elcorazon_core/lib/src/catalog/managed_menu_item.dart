import 'package:elcorazon_core/src/catalog/menu_item.dart';
import 'package:elcorazon_core/src/models/money.dart';

/// Article du catalogue vu de l'exploitation — miroir de
/// `ManagedMenuItemSerializer` (`backend/apps/catalog/serializers.py`).
///
/// Il se distingue de [MenuItem], que rend la route publique, sur quatre points
/// qui comptent pour le back-office :
///
/// * **la catégorie est un identifiant, pas un slug.** La forme publique la
///   rend en `SlugRelatedField` ; celle du siège en clé primaire, parce que
///   c'est par elle qu'on réaffecte un article. `MenuItem.fromJson` lisait cet
///   UUID dans un champ nommé `categorySlug` : le back-office s'en tirait parce
///   qu'il résout le nom lui-même, mais le nom du champ mentait ;
/// * **`category_name` n'existe pas.** Il retombait sur la chaîne vide, ce que
///   personne n'a remarqué faute de le lire ;
/// * **le stock est rendu.** `tracks_stock` et `stock_quantity` arrivaient du
///   serveur et n'étaient lus nulle part : le siège ne pouvait pas voir un
///   article en rupture ;
/// * **les groupes d'options accompagnent la liste**, là où la forme publique
///   les réserve au détail — le serveur le dit : « le back-office travaille sur
///   un seul établissement, depuis un poste fixe ».
///
/// Même distinction, même raison, que [ManagedCategory] face à `Category`.
class ManagedMenuItem {
  const ManagedMenuItem({
    required this.id,
    required this.restaurantSlug,
    required this.categoryId,
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
    required this.tracksStock,
    required this.ratingAverage,
    required this.ratingCount,
    required this.sortOrder,
    this.stockQuantity,
    this.ingredients = const [],
    this.calories,
    this.optionGroups = const [],
    this.isDeleted = false,
  });

  factory ManagedMenuItem.fromJson(Map<String, dynamic> json) {
    return ManagedMenuItem(
      id: json['id'] as String,
      restaurantSlug: json['restaurant'].toString(),
      categoryId: json['category'].toString(),
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String? ?? '',
      image: json['image'] as String?,
      price: Money.fromJson(json['price'] as Map<String, dynamic>),
      preparationMinutes: json['preparation_minutes'] as int? ?? 0,
      allergens: _chaines(json['allergens']),
      dietaryTags: _chaines(json['dietary_tags']),
      isAvailable: json['is_available'] as bool,
      isPopular: json['is_popular'] as bool,
      vipExclusive: json['vip_exclusive'] as bool,
      tracksStock: json['tracks_stock'] as bool? ?? false,
      stockQuantity: json['stock_quantity'] as int?,
      ratingAverage: double.parse('${json['rating_average']}'),
      ratingCount: json['rating_count'] as int,
      sortOrder: json['sort_order'] as int,
      ingredients: _chaines(json['ingredients']),
      calories: json['calories'] as int?,
      optionGroups: (json['option_groups'] as List<dynamic>? ?? const [])
          .map((groupe) => OptionGroup.fromJson(groupe as Map<String, dynamic>))
          .toList(),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  final String id;
  final String restaurantSlug;

  /// Identifiant (UUID) de la catégorie — c'est par lui qu'on la réaffecte.
  final String categoryId;

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

  /// L'article a un stock suivi. Quand c'est faux, [stockQuantity] ne veut
  /// rien dire — un article sans suivi n'est jamais en rupture.
  final bool tracksStock;

  final int? stockQuantity;
  final double ratingAverage;
  final int ratingCount;
  final int sortOrder;
  final List<String> ingredients;
  final int? calories;
  final List<OptionGroup> optionGroups;

  /// Retiré de la carte sans être effacé — les commandes passées le référencent.
  final bool isDeleted;

  /// Stock suivi et épuisé.
  ///
  /// Un article dont le stock n'est pas suivi n'est jamais en rupture : c'est
  /// [isAvailable] qui décide alors de sa présence à la carte.
  bool get estEnRupture => tracksStock && (stockQuantity ?? 0) <= 0;

  static List<String> _chaines(Object? valeur) =>
      (valeur as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
}
