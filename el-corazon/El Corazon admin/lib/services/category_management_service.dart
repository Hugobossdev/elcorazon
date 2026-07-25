import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';

class CategoryManagementService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _categoriesChannel;

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CategoryManagementService() {
    _loadCategories();
    _subscribeToCategoriesRealtime();
  }

  @override
  void dispose() {
    _categoriesChannel?.unsubscribe();
    super.dispose();
  }

  /// S'abonner aux mises à jour en temps réel
  void _subscribeToCategoriesRealtime() {
    try {
      _categoriesChannel = _supabase
          .channel('admin_categories_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'menu_categories',
            callback: (payload) {
              final data = Map<String, dynamic>.from(payload.newRecord);
              final category = Category.fromMap(data);
              _categories.add(category);
              _sortCategories();
              notifyListeners();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'menu_categories',
            callback: (payload) {
              final data = Map<String, dynamic>.from(payload.newRecord);
              final category = Category.fromMap(data);
              final index = _categories.indexWhere((c) => c.id == category.id);
              if (index != -1) {
                _categories[index] = category;
                _sortCategories();
                notifyListeners();
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'menu_categories',
            callback: (payload) {
              final oldData = Map<String, dynamic>.from(payload.oldRecord);
              final id = oldData['id'] as String?;
              if (id != null) {
                _categories.removeWhere((c) => c.id == id);
                notifyListeners();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to realtime categories: $e');
    }
  }

  /// Charger toutes les catégories avec mécanisme de retry
  Future<void> _loadCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        // Délai progressif pour laisser la connexion respirer en cas d'échec précédent
        if (retryCount > 0) {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }

        final response = await _supabase
            .from('menu_categories')
            .select('*')
            .order('sort_order', ascending: true);

        _categories =
            (response as List).map((data) => Category.fromMap(data)).toList();

        debugPrint(
          'CategoryManagementService: ${_categories.length} catégories chargées',
        );
        break; // Succès, sortir de la boucle
      } catch (e) {
        retryCount++;
        debugPrint(
          'CategoryManagementService: Tentative $retryCount/$maxRetries échouée - $e',
        );

        if (retryCount >= maxRetries) {
          _error =
              'Impossible de charger les catégories après plusieurs tentatives. Vérifiez votre connexion.';
          _categories = [];
          debugPrint(
            'CategoryManagementService: Erreur fatale chargement catégories - $e',
          );
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Rafraîchir les catégories
  Future<void> refreshCategories() async {
    await _loadCategories();
  }

  /// Créer une nouvelle catégorie
  Future<Category?> createCategory({
    required String name,
    required String displayName,
    required String emoji,
    String? description,
    int? sortOrder,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Vérifier que le nom n'existe pas déjà
      final existing = await _supabase
          .from('menu_categories')
          .select('id')
          .eq('name', name)
          .maybeSingle();

      if (existing != null) {
        _error = 'Une catégorie avec ce nom existe déjà';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final newOrder = sortOrder ?? (_categories.length + 1);

      final response = await _supabase
          .from('menu_categories')
          .insert({
            'name': name,
            'display_name': displayName,
            'emoji': emoji,
            'description': description,
            'sort_order': newOrder,
            'is_active': true,
          })
          .select()
          .single();

      final newCategory = Category.fromMap(response);
      _categories.add(newCategory);
      _sortCategories();

      _isLoading = false;
      notifyListeners();
      return newCategory;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('CategoryManagementService: Erreur création catégorie - $e');
      return null;
    }
  }

  /// Mettre à jour une catégorie
  Future<bool> updateCategory(Category category) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Vérifier l'unicité du nom si modifié
      final existing = await _supabase
          .from('menu_categories')
          .select('id')
          .eq('name', category.name)
          .neq('id', category.id)
          .maybeSingle();

      if (existing != null) {
        _error = 'Une catégorie avec ce nom existe déjà';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _supabase.from('menu_categories').update({
        'name': category.name,
        'display_name': category.name,
        'emoji': '🍽️',
        'description': category.description,
        'sort_order': category.displayOrder,
        'is_active': category.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', category.id);

      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categories[index] = category;
        _sortCategories();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint(
        'CategoryManagementService: Erreur mise à jour catégorie - $e',
      );
      return false;
    }
  }

  /// Supprimer une catégorie
  Future<bool> deleteCategory(String categoryId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Vérifier qu'il n'y a pas d'éléments de menu dans cette catégorie
      final menuItems = await _supabase
          .from('menu_items')
          .select('id')
          .eq('category_id', categoryId)
          .limit(1);

      if ((menuItems as List).isNotEmpty) {
        _error =
            'Impossible de supprimer une catégorie contenant des éléments de menu';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _supabase.from('menu_categories').delete().eq('id', categoryId);
      _categories.removeWhere((c) => c.id == categoryId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint(
        'CategoryManagementService: Erreur suppression catégorie - $e',
      );
      return false;
    }
  }

  /// Réorganiser les catégories
  Future<bool> reorderCategories(List<Category> reorderedCategories) async {
    try {
      // Mise à jour optimiste locale
      // On met à jour les sort_order (displayOrder) des objets en mémoire
      for (int i = 0; i < reorderedCategories.length; i++) {
        reorderedCategories[i] =
            reorderedCategories[i].copyWith(displayOrder: i + 1);
      }

      // On remplace la liste locale immédiatement pour refléter le changement dans l'UI
      _categories = List.from(reorderedCategories);
      notifyListeners();

      // Mettre à jour en base de données en parallèle
      final updates = <Future>[];
      for (int i = 0; i < _categories.length; i++) {
        updates.add(_supabase.from('menu_categories').update({
          'sort_order': i + 1,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _categories[i].id));
      }

      await Future.wait(updates);

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint(
        'CategoryManagementService: Erreur réorganisation catégories - $e',
      );
      // En cas d'erreur, on recharge pour rétablir la vérité
      await _loadCategories();
      return false;
    }
  }

  /// Activer/Désactiver une catégorie
  Future<bool> toggleCategoryStatus(String categoryId) async {
    try {
      final category = _categories.firstWhere((c) => c.id == categoryId);
      final updatedCategory = category.copyWith(isActive: !category.isActive);
      return await updateCategory(updatedCategory);
    } catch (e) {
      debugPrint(
        'CategoryManagementService: Erreur toggle statut catégorie - $e',
      );
      return false;
    }
  }

  /// Obtenir les statistiques d'une catégorie
  Future<Map<String, dynamic>> getCategoryStats(String categoryId) async {
    try {
      // Compter les éléments de menu dans cette catégorie
      final menuItems = await _supabase
          .from('menu_items')
          .select('id, is_available')
          .eq('category_id', categoryId);

      final items = menuItems as List;
      final totalItems = items.length;
      final activeItems =
          items.where((item) => item['is_available'] == true).length;

      // Calculer le revenu total de la catégorie
      final revenueResponse = await _supabase
          .from('order_items')
          .select('total_price, orders!inner(status)')
          .eq('menu_items.category_id', categoryId);

      final revenue = (revenueResponse as List)
          .where((item) => item['orders']?['status'] == 'delivered')
          .fold<double>(
            0.0,
            (sum, item) =>
                sum + ((item['total_price'] as num?)?.toDouble() ?? 0.0),
          );

      // Calculer la note moyenne
      final ratingResponse = await _supabase
          .from('menu_items')
          .select('rating')
          .eq('category_id', categoryId)
          .gt('rating', 0);

      final ratings = (ratingResponse as List)
          .map((item) => (item['rating'] as num?)?.toDouble() ?? 0.0)
          .toList();

      final avgRating = ratings.isNotEmpty
          ? ratings.reduce((a, b) => a + b) / ratings.length
          : 0.0;

      return {
        'total_items': totalItems,
        'active_items': activeItems,
        'inactive_items': totalItems - activeItems,
        'total_revenue': revenue,
        'average_rating': avgRating,
        'popularity_score':
            totalItems > 0 ? (activeItems / totalItems) * 100 : 0.0,
      };
    } catch (e) {
      debugPrint('CategoryManagementService: Erreur stats catégorie - $e');
      return {};
    }
  }

  /// Obtenir les statistiques globales des catégories
  Map<String, dynamic> getGlobalCategoryStats() {
    final totalCategories = _categories.length;
    final activeCategories = _categories.where((c) => c.isActive).length;
    final inactiveCategories = totalCategories - activeCategories;

    return {
      'total_categories': totalCategories,
      'active_categories': activeCategories,
      'inactive_categories': inactiveCategories,
    };
  }

  /// Rechercher des catégories
  List<Category> searchCategories(String query) {
    if (query.isEmpty) return _categories;

    final q = query.toLowerCase();
    return _categories
        .where(
          (category) =>
              category.name.toLowerCase().contains(q) ||
              (category.description?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  /// Obtenir les catégories actives
  List<Category> get activeCategories =>
      _categories.where((c) => c.isActive).toList();

  /// Obtenir les catégories inactives
  List<Category> get inactiveCategories =>
      _categories.where((c) => !c.isActive).toList();

  /// Trier les catégories par ordre d'affichage
  void _sortCategories() {
    _categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// Initialiser le service
  Future<void> initialize() async {
    await _loadCategories();
  }
}
