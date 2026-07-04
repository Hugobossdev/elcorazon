import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/menu_category.dart';

/// Repository abstrait pour les opérations sur les menu items
/// Permet de séparer la logique métier de l'accès aux données
abstract class MenuRepository {
  /// Récupère tous les menu items, optionnellement filtrés par catégorie
  Future<List<MenuItem>> getMenuItems({String? categoryId});

  /// Récupère un menu item par son ID
  Future<MenuItem?> getMenuItemById(String id);

  /// Stream des menu items pour la mise à jour en temps réel
  Stream<List<MenuItem>> watchMenuItems({String? categoryId});

  /// Récupère les catégories de menu
  Future<List<MenuCategory>> getMenuCategories();

  /// Recherche des menu items
  Future<List<MenuItem>> searchMenuItems(String query);

  /// Récupère les menu items populaires
  Future<List<MenuItem>> getPopularMenuItems({int limit = 10});
}

