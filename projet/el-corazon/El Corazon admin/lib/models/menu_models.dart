class MenuItem {
  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final double basePrice;
  final String? imageUrl;
  final bool isPopular;
  final bool isVegetarian;
  final bool isVegan;
  final bool isAvailable;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<MenuOptionGroup> optionGroups;

  MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.basePrice,
    this.imageUrl,
    this.isPopular = false,
    this.isVegetarian = false,
    this.isVegan = false,
    this.isAvailable = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.optionGroups = const [],
  });

  MenuItem copyWith({
    String? id,
    String? categoryId,
    String? name,
    String? description,
    double? basePrice,
    String? imageUrl,
    bool? isPopular,
    bool? isVegetarian,
    bool? isVegan,
    bool? isAvailable,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<MenuOptionGroup>? optionGroups,
  }) {
    return MenuItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      imageUrl: imageUrl ?? this.imageUrl,
      isPopular: isPopular ?? this.isPopular,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isVegan: isVegan ?? this.isVegan,
      isAvailable: isAvailable ?? this.isAvailable,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      optionGroups: optionGroups ?? this.optionGroups,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'price': basePrice,
      'image_url': imageUrl,
      'is_popular': isPopular,
      'is_vegetarian': isVegetarian,
      'is_vegan': isVegan,
      'is_available': isAvailable,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['id'] ?? '',
      categoryId: map['category_id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      basePrice: (map['price'] as num?)?.toDouble() ??
          (map['base_price'] as num?)?.toDouble() ??
          0.0,
      imageUrl: map['image_url'],
      isPopular: map['is_popular'] ?? false,
      isVegetarian: map['is_vegetarian'] ?? false,
      isVegan: map['is_vegan'] ?? false,
      isAvailable: map['is_available'] ?? true,
      sortOrder: map['sort_order'] ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
      optionGroups: map['option_groups'] != null
          ? List<MenuOptionGroup>.from(
              map['option_groups']?.map((x) => MenuOptionGroup.fromMap(x)),
            )
          : [],
    );
  }
}

class MenuOptionGroup {
  final String id;
  final String menuItemId;
  final String name;
  final String? description;
  final int minSelection;
  final int maxSelection;
  final bool isRequired;
  final int sortOrder;
  final List<MenuOption> options;

  MenuOptionGroup({
    required this.id,
    required this.menuItemId,
    required this.name,
    this.description,
    this.minSelection = 0,
    this.maxSelection = 1,
    this.isRequired = false,
    this.sortOrder = 0,
    this.options = const [],
  });

  MenuOptionGroup copyWith({
    String? id,
    String? menuItemId,
    String? name,
    String? description,
    int? minSelection,
    int? maxSelection,
    bool? isRequired,
    int? sortOrder,
    List<MenuOption>? options,
  }) {
    return MenuOptionGroup(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      description: description ?? this.description,
      minSelection: minSelection ?? this.minSelection,
      maxSelection: maxSelection ?? this.maxSelection,
      isRequired: isRequired ?? this.isRequired,
      sortOrder: sortOrder ?? this.sortOrder,
      options: options ?? this.options,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menu_item_id': menuItemId,
      'name': name,
      'description': description,
      'min_selection': minSelection,
      'max_selection': maxSelection,
      'is_required': isRequired,
      'sort_order': sortOrder,
    };
  }

  factory MenuOptionGroup.fromMap(Map<String, dynamic> map) {
    return MenuOptionGroup(
      id: map['id'] ?? '',
      menuItemId: map['menu_item_id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      minSelection: map['min_selection'] ?? 0,
      maxSelection: map['max_selection'] ?? 1,
      isRequired: map['is_required'] ?? false,
      sortOrder: map['sort_order'] ?? 0,
      options: map['options'] != null
          ? List<MenuOption>.from(
              map['options']?.map((x) => MenuOption.fromMap(x)),
            )
          : [],
    );
  }
}

class MenuOption {
  final String id;
  final String groupId;
  final String name;
  final String? description;
  final double priceModifier;
  final bool isAvailable;
  final int sortOrder;

  MenuOption({
    required this.id,
    required this.groupId,
    required this.name,
    this.description,
    this.priceModifier = 0.0,
    this.isAvailable = true,
    this.sortOrder = 0,
  });

  MenuOption copyWith({
    String? id,
    String? groupId,
    String? name,
    String? description,
    double? priceModifier,
    bool? isAvailable,
    int? sortOrder,
  }) {
    return MenuOption(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      description: description ?? this.description,
      priceModifier: priceModifier ?? this.priceModifier,
      isAvailable: isAvailable ?? this.isAvailable,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'name': name,
      'description': description,
      'price_modifier': priceModifier,
      'is_available': isAvailable,
      'sort_order': sortOrder,
    };
  }

  factory MenuOption.fromMap(Map<String, dynamic> map) {
    return MenuOption(
      id: map['id'] ?? '',
      groupId: map['group_id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      priceModifier: (map['price_modifier'] as num?)?.toDouble() ?? 0.0,
      isAvailable: map['is_available'] ?? true,
      sortOrder: map['sort_order'] ?? 0,
    );
  }
}
