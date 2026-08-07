import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart' hide Category;

import 'package:admin/models/category.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Catégories du catalogue — `/api/v1/catalog/manage/categories/` (Phase 6).
///
/// Deux vérifications que l'app faisait elle-même disparaissent, et c'est un
/// gain : l'unicité du nom et le refus de supprimer une catégorie qui contient
/// des articles. Toutes deux se faisaient par une requête de lecture suivie
/// d'une écriture — entre les deux, un autre opérateur pouvait créer le doublon
/// ou ajouter l'article. Le serveur les tient sous contrainte, et rend un 400
/// ou un 409 que cet écran affiche.
///
class CategoryManagementService extends ChangeNotifier {
  /// Établissement supervisé. Le jour où le back-office en gérera plusieurs,
  /// ce champ devient une sélection alimentée par `/restaurants/`.
  static const String _restaurantSlug = 'el-corazon-lome';

  eccore.ManagedCatalogRepository get _catalog =>
      eccore.ManagedCatalogRepository(apiClient: AdminAuthService().apiClient);

  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CategoryManagementService() {
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final remote = await _catalog.categories(restaurantSlug: _restaurantSlug);
      _categories = remote.map(_toLocal).toList();
      eccore.Journal.trace('CategoryManagementService: ${_categories.length} catégorie(s)');
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      _categories = [];
      eccore.Journal.trace('CategoryManagementService: chargement impossible — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Category _toLocal(eccore.Category remote) {
    return Category(
      id: remote.id,
      name: remote.name,
      description: remote.description.isEmpty ? null : remote.description,
      displayOrder: remote.sortOrder,
      emoji: remote.emoji,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // L'unicité du slug est une contrainte de base : la vérifier ici par une
      // lecture préalable laissait passer le doublon créé entre-temps.
      final created = await _catalog.createCategory(
        restaurantSlug: _restaurantSlug,
        name: displayName.isEmpty ? name : displayName,
        slug: _slugifier(name),
        emoji: emoji,
        description: description ?? '',
        sortOrder: sortOrder ?? _categories.length + 1,
      );

      final locale = _toLocal(created);
      _categories.add(locale);
      _sortCategories();
      return locale;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('CategoryManagementService: création refusée — ${e.code}');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Identifiant lisible dérivé du nom — le serveur exige un slug.
  static String _slugifier(String valeur) {
    final base = valeur
        .toLowerCase()
        .replaceAll(RegExp('[àáâãäå]'), 'a')
        .replaceAll(RegExp('[èéêë]'), 'e')
        .replaceAll(RegExp('[ìíîï]'), 'i')
        .replaceAll(RegExp('[òóôõö]'), 'o')
        .replaceAll(RegExp('[ùúûü]'), 'u')
        .replaceAll(RegExp('[ç]'), 'c')
        .replaceAll(RegExp('[^a-z0-9]+'), '-');
    return base.replaceAll(RegExp('^-+|-+\u0024'), '');
  }

  /// Mettre à jour une catégorie
  Future<bool> updateCategory(Category category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _catalog.updateCategory(
        categoryId: category.id,
        name: category.name,
        emoji: category.emoji,
        description: category.description ?? '',
        sortOrder: category.displayOrder,
        isActive: category.isActive,
      );

      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categories[index] = _toLocal(updated);
        _sortCategories();
      }
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('CategoryManagementService: mise à jour refusée — ${e.code}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Supprimer une catégorie
  /// Supprime une catégorie.
  ///
  /// Le refus de supprimer une catégorie encore utilisée vient du serveur
  /// (`on_delete=PROTECT` sur les articles) : le vérifier ici par une lecture
  /// préalable laissait passer l'article ajouté entre la vérification et la
  /// suppression.
  Future<bool> deleteCategory(String categoryId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _catalog.deleteCategory(categoryId);
      _categories.removeWhere((c) => c.id == categoryId);
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.status == 409
          ? 'Cette catégorie contient encore des articles.'
          : e.detail;
      eccore.Journal.trace('CategoryManagementService: suppression refusée — ${e.code}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Réorganiser les catégories
  /// Réordonne les catégories.
  ///
  /// Un `PATCH` par catégorie déplacée : le contrat n'a pas de route de
  /// réordonnancement en lot, et l'ordre est une simple valeur (`sort_order`).
  Future<bool> reorderCategories(List<Category> reorderedCategories) async {
    final avant = List<Category>.from(_categories);
    _categories = List.from(reorderedCategories);
    notifyListeners();

    try {
      for (var i = 0; i < _categories.length; i++) {
        await _catalog.updateCategory(
          categoryId: _categories[i].id,
          sortOrder: i + 1,
        );
      }
      return true;
    } on eccore.ApiException catch (e) {
      // Remettre l'ordre affiché tel qu'il est réellement en base : laisser
      // l'écran montrer un ordre que le serveur a refusé induirait l'opérateur
      // en erreur au prochain chargement.
      _categories = avant;
      _error = e.detail;
      notifyListeners();
      eccore.Journal.trace('CategoryManagementService: réordonnancement refusé — ${e.code}');
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
      eccore.Journal.trace(
        'CategoryManagementService: Erreur toggle statut catégorie - $e',
      );
      return false;
    }
  }

  /// Statistiques d'une catégorie : nombre d'articles et disponibilité.
  ///
  /// Le chiffre d'affaires et la note moyenne par catégorie ne sont plus
  /// calculés ici. Ils l'étaient par deux requêtes croisant `order_items` et
  /// `menu_items` depuis le navigateur — un agrégat métier reconstruit côté
  /// client, sur des lignes de commande que le back-office n'a aucune raison de
  /// parcourir. Les rapports de chiffre d'affaires vivent dans
  /// `/analytics/reports/`.
  Future<Map<String, dynamic>> getCategoryStats(String categoryId) async {
    try {
      final articles = await _catalog.menuItems(categoryId: categoryId);
      return {
        'total_items': articles.length,
        'active_items': articles.where((item) => item.isAvailable).length,
      };
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('CategoryManagementService: statistiques indisponibles — ${e.code}');
      return {'total_items': 0, 'active_items': 0};
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
