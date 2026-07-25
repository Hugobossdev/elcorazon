import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:elcora_fast/models/menu_category.dart';

part 'freezed_menu_item.freezed.dart';
part 'freezed_menu_item.g.dart';

/// Exemple de modèle MenuItem avec Freezed
///
/// Pour générer le code, exécutez :
/// ```bash
/// flutter pub run build_runner build --delete-conflicting-outputs
/// ```
@freezed
class FreezedMenuItem with _$FreezedMenuItem {
  const FreezedMenuItem._();

  const factory FreezedMenuItem({
    required String id,
    required String name,
    required String description,
    required double price,
    required String categoryId,
    MenuCategory? category,
    String? imageUrl,
    @Default(false) bool isPopular,
    @Default(false) bool isVegetarian,
    @Default(false) bool isVegan,
    @Default(true) bool isAvailable,
    @Default(100) int availableQuantity,
    @Default([]) List<String> ingredients,
    @Default(0) int calories,
    @Default(15) int preparationTime,
    @Default(0.0) double rating,
    @Default(0) int reviewCount,
  }) = _FreezedMenuItem;

  factory FreezedMenuItem.fromJson(Map<String, dynamic> json) =>
      _$FreezedMenuItemFromJson(json);

  /// Factory pour créer depuis un Map (compatibilité avec l'ancien code)
  factory FreezedMenuItem.fromMap(Map<String, dynamic> map) {
    // Parser la catégorie depuis la base de données
    String categoryId = map['category_id']?.toString() ?? '';
    MenuCategory? category;

    // Parser la catégorie si elle est incluse dans la réponse (via join)
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
          // Erreur de parsing, continuer sans catégorie
        }
      }
    }

    // Parser les ingrédients
    List<String> ingredients = [];
    if (map['ingredients'] != null) {
      if (map['ingredients'] is String) {
        ingredients = (map['ingredients'] as String)
            .split(',')
            .where((i) => i.trim().isNotEmpty)
            .map((i) => i.trim())
            .toList();
      } else if (map['ingredients'] is List) {
        ingredients =
            (map['ingredients'] as List).map((i) => i.toString()).toList();
      }
    }

    return FreezedMenuItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : 0.0,
      categoryId: categoryId,
      category: category,
      imageUrl: map['image_url']?.toString() ?? map['imageUrl']?.toString(),
      isPopular: map['is_popular'] == 1 || map['is_popular'] == true,
      isVegetarian: map['is_vegetarian'] == 1 || map['is_vegetarian'] == true,
      isVegan: map['is_vegan'] == 1 || map['is_vegan'] == true,
      isAvailable: map['is_available'] != 0 && map['is_available'] != false,
      availableQuantity: (map['available_quantity'] is num)
          ? (map['available_quantity'] as num).toInt()
          : 100,
      ingredients: ingredients,
      calories: (map['calories'] is num) ? (map['calories'] as num).toInt() : 0,
      preparationTime: (map['preparation_time'] is num)
          ? (map['preparation_time'] as num).toInt()
          : 15,
      rating: (map['rating'] is num) ? (map['rating'] as num).toDouble() : 0.0,
      reviewCount: (map['review_count'] is num)
          ? (map['review_count'] as num).toInt()
          : 0,
    );
  }

  /// Méthode pour convertir en Map (compatibilité avec l'ancien code)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category_id': categoryId,
      'category': category?.name ?? categoryId,
      'imageUrl': imageUrl ?? imageUrl,
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
}
