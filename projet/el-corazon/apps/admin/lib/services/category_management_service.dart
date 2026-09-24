import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/presentation/echec.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';

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
  eccore.ManagedCatalogRepository get _catalog =>
      eccore.ManagedCatalogRepository(apiClient: AdminAuthService().apiClient);

  /// À qui rattacher une catégorie créée. Une lecture n'en a pas besoin — le
  /// serveur cloisonne — mais une écriture doit nommer son établissement.
  final RestaurantScopeService _scope = RestaurantScopeService();

  List<eccore.ManagedCategory> _categories = [];
  bool _isLoading = false;
  Echec? _echec;

  /// L'établissement dont la liste affichée provient. Nul tant que rien n'a
  /// été lu — et c'est lui que le rangement désigne au serveur.
  String? _etablissementLu;

  List<eccore.ManagedCategory> get categories => _categories;
  bool get isLoading => _isLoading;

  /// Pourquoi la liste est vide, quand elle l'est **parce que la lecture a
  /// échoué**. Nulle quand elle a abouti — fût-ce sur zéro catégorie.
  Echec? get echec => _echec;

  /// L'établissement de la liste affichée.
  String? get etablissement => _etablissementLu;

  /// La carte d'**un** établissement, et le service le dit.
  ///
  /// La liste était chargée sans filtre : le siège voyait les catégories de
  /// tous ses établissements mêlées, avec les mêmes noms répétés autant de fois
  /// qu'il y a de cuisines — et les faisait glisser dans un ordre commun qui
  /// n'existe pas, `sort_order` étant propre à chaque établissement.
  ///
  /// Le chargement ne se fait plus au constructeur : il partait à l'ouverture
  /// de n'importe quel écran du back-office, le fournisseur étant monté une
  /// fois pour toute l'application.
  Future<void> chargerPour(String? slugEtablissement) async {
    _isLoading = true;
    _echec = null;
    notifyListeners();

    try {
      final remote = await _catalog.categories(restaurantSlug: slugEtablissement);
      _categories = remote;
      _etablissementLu = slugEtablissement;
      eccore.Journal.trace('CategoryManagementService: ${_categories.length} catégorie(s)');
    } on eccore.ApiException catch (e) {
      _echec = Echec.de(e);
      _categories = [];
      eccore.Journal.trace('CategoryManagementService: chargement impossible — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCategories() => chargerPour(_scope.current?.slug);


  /// Rafraîchir les catégories
  Future<void> refreshCategories() async {
    await _loadCategories();
  }

  /// Crée une catégorie dans l'établissement courant. **Lève `ApiException`.**
  ///
  /// Elle rendait `null` sur refus, en gardant le motif dans un champ que
  /// l'écran n'affichait pas : un nom déjà pris se soldait par « Erreur lors
  /// de l'enregistrement », et l'opérateur ressaisissait le même nom.
  Future<eccore.ManagedCategory> createCategory({
    required String name,
    required String displayName,
    required String emoji,
    String? description,
    int? sortOrder,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final etablissement = await _scope.requireSlug();
      if (etablissement == null) {
        throw StateError(RestaurantScopeService.sansPerimetre);
      }

      // L'unicité du slug est une contrainte de base : la vérifier ici par une
      // lecture préalable laissait passer le doublon créé entre-temps.
      final created = await _catalog.createCategory(
        restaurantSlug: etablissement,
        name: displayName.isEmpty ? name : displayName,
        slug: _slugifier(name),
        emoji: emoji,
        description: description ?? '',
        sortOrder: sortOrder ?? _categories.length + 1,
      );

      _categories.add(created);
      _sortCategories();
      return created;
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

  /// Met à jour une catégorie. **Lève `ApiException`.**
  Future<eccore.ManagedCategory> updateCategory(eccore.ManagedCategory category) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await _catalog.updateCategory(
        categoryId: category.id,
        name: category.name,
        emoji: category.emoji,
        description: category.description,
        sortOrder: category.sortOrder,
        isActive: category.isActive,
      );

      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categories[index] = updated;
        _sortCategories();
      }
      return updated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Supprime une catégorie. **Lève `ApiException`.**
  ///
  /// Le refus de supprimer une catégorie encore utilisée vient du serveur
  /// (`on_delete=PROTECT` sur les articles) : le vérifier ici par une lecture
  /// préalable laissait passer l'article ajouté entre la vérification et la
  /// suppression. Le 409 porte la phrase du serveur, que l'écran affiche telle
  /// quelle — elle nomme ce qui bloque.
  Future<void> deleteCategory(String categoryId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _catalog.deleteCategory(categoryId);
      _categories.removeWhere((c) => c.id == categoryId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Range la carte : **un appel, une transaction**. Lève `ApiException`.
  ///
  /// Elle envoyait un `PATCH` par catégorie, en série, et remettait la liste
  /// d'avant sur refus. Au quatrième refus, les trois premiers rangs étaient
  /// déjà écrits : l'écran affichait alors un ordre que la base ne portait
  /// pas, et le rechargement suivant le contredisait.
  ///
  /// La liste envoyée est **entière** — c'est celle de l'écran, qui ne montre
  /// qu'un établissement. Le serveur refuse une liste partielle plutôt que de
  /// laisser les absentes à leur ancien rang.
  Future<void> reorderCategories(List<eccore.ManagedCategory> ordreVoulu) async {
    final etablissement = _etablissementLu ?? _scope.current?.slug;
    if (etablissement == null) {
      throw StateError(RestaurantScopeService.sansPerimetre);
    }

    final avant = List<eccore.ManagedCategory>.from(_categories);
    // L'ordre s'affiche tout de suite : un glisser-déposer qui attend le
    // serveur pour bouger donne l'impression de n'avoir pas pris.
    _categories = List.from(ordreVoulu);
    notifyListeners();

    try {
      _categories = await _catalog.reorderCategories(
        restaurantSlug: etablissement,
        categoryIds: [for (final categorie in ordreVoulu) categorie.id],
      );
      notifyListeners();
    } on eccore.ApiException catch (e) {
      // Rien n'a été écrit — la route est transactionnelle : remettre l'ordre
      // d'avant, c'est remettre celui de la base.
      _categories = avant;
      notifyListeners();
      eccore.Journal.trace('CategoryManagementService: rangement refusé — ${e.code}');
      rethrow;
    }
  }

  /// Active ou désactive une catégorie. **Lève `ApiException`.**
  Future<void> toggleCategoryStatus(String categoryId) async {
    final category = _categories.firstWhere((c) => c.id == categoryId);
    await updateCategory(category.copyWith(isActive: !category.isActive));
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
  List<eccore.ManagedCategory> searchCategories(String query) {
    if (query.isEmpty) return _categories;

    final q = query.toLowerCase();
    return _categories
        .where(
          (category) =>
              category.name.toLowerCase().contains(q) ||
              category.description.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Obtenir les catégories actives
  List<eccore.ManagedCategory> get activeCategories =>
      _categories.where((c) => c.isActive).toList();

  /// Obtenir les catégories inactives
  List<eccore.ManagedCategory> get inactiveCategories =>
      _categories.where((c) => !c.isActive).toList();

  /// Trier les catégories par ordre d'affichage
  void _sortCategories() {
    _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Initialiser le service
  Future<void> initialize() async {
    await _loadCategories();
  }
}
