class MenuCategory {
  final String id;
  final String name;
  final String displayName;
  final String emoji;
  final String? description;
  final int sortOrder;
  final bool isActive;

  const MenuCategory({
    required this.id,
    required this.name,
    required this.displayName,
    required this.emoji,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory MenuCategory.fromMap(Map<String, dynamic> map) {
    return MenuCategory(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      displayName: map['display_name']?.toString() ??
          map['displayName']?.toString() ??
          map['name']?.toString() ??
          '',
      emoji: map['emoji']?.toString() ?? '',
      description: map['description']?.toString(),
      sortOrder: map['sort_order'] is int
          ? map['sort_order'] as int
          : (map['sort_order'] is num
              ? (map['sort_order'] as num).toInt()
              : (map['sortOrder'] is num ? (map['sortOrder'] as num).toInt() : 0)),
      isActive: map['is_active'] is bool
          ? map['is_active'] as bool
          : (map['is_active'] == 1 ||
              map['isActive'] == true ||
              map['is_active']?.toString() == 'true'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'emoji': emoji,
      'description': description,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }
  
  // JSON Serialization support
  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory.fromMap(json);
  Map<String, dynamic> toJson() => toMap();
}
