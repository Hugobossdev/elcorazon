import 'package:flutter/foundation.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/menu_category.dart';
import 'package:elcora_fast/repositories/menu_repository.dart';

/// Service de logique métier pour les menu items
/// Utilise un repository pour séparer la logique métier de l'accès aux données
class MenuService extends ChangeNotifier {
  final MenuRepository _repository;

  List<MenuItem> _menuItems = [];
  List<MenuCategory> _categories = [];
  bool _isLoading = false;
  String? _error;

  MenuService(this._repository);

  // Getters
  List<MenuItem> get menuItems => List.unmodifiable(_menuItems);
  List<MenuCategory> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charge les menu items
  Future<void> loadMenuItems({String? categoryId}) async {
    _setLoading(true);
    _error = null;

    try {
      _menuItems = await _repository.getMenuItems(categoryId: categoryId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading menu items: $e');
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Charge les catégories
  Future<void> loadCategories() async {
    try {
      _categories = await _repository.getMenuCategories();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading categories: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Récupère un menu item par son ID
  Future<MenuItem?> getMenuItemById(String id) async {
    try {
      return await _repository.getMenuItemById(id);
    } catch (e) {
      debugPrint('❌ Error getting menu item by id: $e');
      rethrow;
    }
  }

  /// Recherche des menu items
  Future<List<MenuItem>> searchMenuItems(String query) async {
    try {
      return await _repository.searchMenuItems(query);
    } catch (e) {
      debugPrint('❌ Error searching menu items: $e');
      rethrow;
    }
  }

  /// Récupère les menu items populaires
  Future<List<MenuItem>> getPopularMenuItems({int limit = 10}) async {
    try {
      return await _repository.getPopularMenuItems(limit: limit);
    } catch (e) {
      debugPrint('❌ Error getting popular menu items: $e');
      rethrow;
    }
  }

  /// Filtre les menu items par catégorie (local)
  List<MenuItem> getMenuItemsByCategory(String categoryId) {
    return _menuItems
        .where((item) => item.categoryId == categoryId)
        .toList();
  }

  /// Filtre les menu items par disponibilité (local)
  List<MenuItem> getAvailableMenuItems() {
    return _menuItems.where((item) => item.isAvailable).toList();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

