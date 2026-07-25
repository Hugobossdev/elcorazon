enum MenuCategory {
  burgers,
  pizzas,
  drinks,
  desserts,
  sides,
  salads,
  combos,
  specials,
}

extension MenuCategoryExtension on MenuCategory {
  String get displayName {
    switch (this) {
      case MenuCategory.burgers:
        return 'Burgers';
      case MenuCategory.pizzas:
        return 'Pizzas';
      case MenuCategory.drinks:
        return 'Drinks';
      case MenuCategory.desserts:
        return 'Desserts';
      case MenuCategory.sides:
        return 'Sides';
      case MenuCategory.salads:
        return 'Salads';
      case MenuCategory.combos:
        return 'Combos';
      case MenuCategory.specials:
        return 'Specials';
    }
  }

  String get emoji {
    switch (this) {
      case MenuCategory.burgers:
        return '🍔';
      case MenuCategory.pizzas:
        return '🍕';
      case MenuCategory.drinks:
        return '🥤';
      case MenuCategory.desserts:
        return '🍰';
      case MenuCategory.sides:
        return '🍟';
      case MenuCategory.salads:
        return '🥗';
      case MenuCategory.combos:
        return '🍽️';
      case MenuCategory.specials:
        return '⭐';
    }
  }
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final MenuCategory category;
  final String? imageUrl;
  final bool isPopular;
  final bool isVegetarian;
  final bool isVegan;
  final bool isAvailable;
  final int availableQuantity;
  final List<String> ingredients;
  final int calories;
  final int preparationTime; // in minutes
  final double rating;
  final int reviewCount;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.imageUrl,
    this.isPopular = false,
    this.isVegetarian = false,
    this.isVegan = false,
    this.isAvailable = true,
    this.availableQuantity = 100,
    this.ingredients = const [],
    this.calories = 0,
    this.preparationTime = 15,
    this.rating = 0.0,
    this.reviewCount = 0,
  });

  MenuItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    MenuCategory? category,
    String? imageUrl,
    bool? isPopular,
    bool? isVegetarian,
    bool? isVegan,
    bool? isAvailable,
    int? availableQuantity,
    List<String>? ingredients,
    int? calories,
    int? preparationTime,
    double? rating,
    int? reviewCount,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isPopular: isPopular ?? this.isPopular,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isVegan: isVegan ?? this.isVegan,
      isAvailable: isAvailable ?? this.isAvailable,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      ingredients: ingredients ?? this.ingredients,
      calories: calories ?? this.calories,
      preparationTime: preparationTime ?? this.preparationTime,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category.toString(),
      'imageUrl': imageUrl,
      'isPopular': isPopular ? 1 : 0,
      'isVegetarian': isVegetarian ? 1 : 0,
      'isVegan': isVegan ? 1 : 0,
      'isAvailable': isAvailable ? 1 : 0,
      'availableQuantity': availableQuantity,
      'ingredients': ingredients.join(','),
      'calories': calories,
      'preparationTime': preparationTime,
      'rating': rating,
      'reviewCount': reviewCount,
    };
  }

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    // Handle category from database structure
    MenuCategory category;
    if (map['menu_categories'] != null) {
      final categoryData = map['menu_categories'] as Map<String, dynamic>;
      final categoryName = categoryData['name'] as String;
      category = MenuCategory.values.firstWhere(
        (e) => e.toString().split('.').last == categoryName,
        orElse: () => MenuCategory.burgers,
      );
    } else {
      category = MenuCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category_id'],
        orElse: () => MenuCategory.burgers,
      );
    }

    return MenuItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: map['price']?.toDouble() ?? 0.0,
      category: category,
      imageUrl: map['image_url'],
      isPopular: map['is_popular'] ?? false,
      isVegetarian: map['is_vegetarian'] ?? false,
      isVegan: map['is_vegan'] ?? false,
      isAvailable: map['is_available'] ?? true,
      availableQuantity: map['available_quantity'] ?? 100,
      ingredients: map['ingredients'] is List
          ? List<String>.from(map['ingredients'])
          : (map['ingredients'] as String?)
                  ?.split(',')
                  .where((i) => i.isNotEmpty)
                  .toList() ??
              [],
      calories: map['calories'] ?? 0,
      preparationTime: map['preparation_time'] ?? 15,
      rating: map['rating']?.toDouble() ?? 0.0,
      reviewCount: map['review_count'] ?? 0,
    );
  }
}
