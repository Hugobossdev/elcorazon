import 'package:flutter/foundation.dart';
import 'package:elcora_fast/models/menu_category.dart';

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String categoryId; // UUID de la catégorie
  MenuCategory? category; // Référence optionnelle à la catégorie (pour l'affichage)
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
  final bool isVipExclusive;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    this.category,
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
    this.isVipExclusive = false,
  });

  MenuItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? categoryId,
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
    bool? isVipExclusive,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
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
      isVipExclusive: isVipExclusive ?? this.isVipExclusive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category_id': categoryId,
      'category': category?.name ?? categoryId,
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
      'is_vip_exclusive': isVipExclusive ? 1 : 0,
    };
  }

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    // Parser la catégorie depuis la base de données
    String categoryId = '';
    MenuCategory? category;
    
    // Récupérer category_id (UUID) - c'est la clé primaire
    categoryId = map['category_id']?.toString() ?? '';
    
    // Parser la catégorie si elle est incluse dans la réponse (via join)
    // Supabase retourne les relations dans un objet ou un tableau
    dynamic categoryData = map['menu_categories'];
    
    if (categoryData != null) {
      // Si c'est un tableau (peut arriver avec certains joins)
      if (categoryData is List && categoryData.isNotEmpty) {
        categoryData = categoryData.first;
      }
      
      // Si c'est un Map, parser la catégorie
      if (categoryData is Map<String, dynamic>) {
        try {
          // S'assurer que l'ID de la catégorie est inclus
          if (categoryData['id'] == null && categoryId.isNotEmpty) {
            categoryData['id'] = categoryId;
          }
          
          category = MenuCategory.fromMap(categoryData);
          
          // Utiliser l'ID de la catégorie parsée si categoryId est vide
          if (categoryId.isEmpty && category.id.isNotEmpty) {
            categoryId = category.id;
          }
        } catch (e) {
          debugPrint('⚠️ Erreur parsing category: $e');
          debugPrint('   Category data: $categoryData');
        }
      }
    }
    
    // Si categoryId est toujours vide après parsing, essayer de le récupérer depuis la catégorie
    if (categoryId.isEmpty && category != null && category.id.isNotEmpty) {
      categoryId = category.id;
    }
    
    // Log si categoryId est toujours vide (mais ne pas bloquer)
    if (categoryId.isEmpty) {
      debugPrint('⚠️ MenuItem.fromMap: category_id est vide pour l\'item ${map['id']} (${map['name']})');
    }

    return MenuItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      categoryId: categoryId,
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
      isVipExclusive: map['is_vip_exclusive'] ?? false,
    );
  }
}
