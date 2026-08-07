import 'package:elcorazon_core/src/models/money.dart';

/// Article du catalogue — miroir de `MenuItemSerializer`
/// (`backend/apps/catalog/serializers.py`).
///
/// [ingredients], [calories] et [optionGroups] n'existent que sur le **détail**
/// (`MenuItemDetailSerializer`, `getMenuItem`) : la liste ne les porte pas, à
/// dessein — une page de vingt articles traînerait des centaines de lignes que
/// l'écran de liste n'affiche pas. Ils sont donc vides après un `getMenuItems`,
/// et renseignés après un `getMenuItem`.
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
    this.ingredients = const [],
    this.calories,
    this.optionGroups = const [],
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
      ingredients:
          (json['ingredients'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      calories: json['calories'] as int?,
      optionGroups: (json['option_groups'] as List<dynamic>? ?? const [])
          .map((json) => OptionGroup.fromJson(json as Map<String, dynamic>))
          .toList(),
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

  /// Renseignés par le détail seulement — voir la note de classe.
  final List<String> ingredients;
  final int? calories;
  final List<OptionGroup> optionGroups;
}

/// Groupe d'options d'un article — miroir de `OptionGroupSerializer`.
///
/// [minSelect]/[maxSelect] portent la règle de choix ; [isRequired] est calculé
/// par le serveur (`min_select > 0`) plutôt que déduit ici, pour que les deux
/// côtés ne puissent pas diverger.
class OptionGroup {
  const OptionGroup({
    required this.id,
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.isRequired,
    required this.sortOrder,
    required this.options,
  });

  factory OptionGroup.fromJson(Map<String, dynamic> json) {
    return OptionGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      minSelect: json['min_select'] as int? ?? 0,
      maxSelect: json['max_select'] as int? ?? 1,
      isRequired: json['is_required'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((json) => Option.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String name;
  final int minSelect;
  final int maxSelect;
  final bool isRequired;
  final int sortOrder;
  final List<Option> options;
}

/// Option d'un groupe — miroir de `OptionSerializer`.
///
/// [priceDelta] est le **supplément**, pas un prix : le total reste calculé par
/// le serveur (C1). Une option indisponible reste visible mais marquée —
/// masquer ferait croire à un menu qui change de forme d'une minute à l'autre.
class Option {
  const Option({
    required this.id,
    required this.name,
    required this.priceDelta,
    required this.isDefault,
    required this.isAvailable,
    required this.sortOrder,
  });

  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(
      id: json['id'] as String,
      name: json['name'] as String,
      priceDelta: Money.fromJson(json['price_delta'] as Map<String, dynamic>),
      isDefault: json['is_default'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final Money priceDelta;
  final bool isDefault;
  final bool isAvailable;
  final int sortOrder;
}
