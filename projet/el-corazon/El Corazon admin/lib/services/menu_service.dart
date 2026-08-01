import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/menu_models.dart';
import 'admin_auth_service.dart';

/// Écriture du catalogue — `/api/v1/catalog/manage/*` (Phase 6).
///
/// C'est le seul endroit d'où un **prix** part vers le serveur (C1), et le
/// serveur reste seul à le facturer : la note (`rating_average`) est en lecture
/// seule côté contrat, sans quoi on pourrait fabriquer une réputation.
///
/// L'envoi d'image change de nature : l'app poussait le fichier dans un bucket
/// Supabase **public** puis écrivait l'URL obtenue dans la table. Le stockage v2
/// est privé et servi par URL signées — le fichier est joint à l'article, et le
/// serveur rend l'URL. La méthode d'envoi direct disparaît donc ; le champ
/// `image` d'un article s'écrit par un `multipart` que cet écran ne compose pas
/// encore.
class MenuService extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Établissement supervisé — une seule enseigne pour l'instant.
  static const String _restaurantSlug = 'el-corazon-lome';

  eccore.ManagedCatalogRepository get _catalog =>
      eccore.ManagedCatalogRepository(apiClient: AdminAuthService().apiClient);

  /// L'envoi d'image n'est plus fait par le client.
  ///
  /// Rend `null` : le stockage v2 n'est pas public, il n'y a pas d'URL à
  /// fabriquer côté navigateur. Conservée le temps que les formulaires
  /// envoient l'article en `multipart/form-data` avec sa photo.
  Future<String?> uploadProductImage(
    XFile image,
    String productName, {
    String? oldImageUrl,
  }) async {
    debugPrint("MenuService: l'envoi d'image passera par le formulaire d'article");
    return null;
  }

  Future<List<MenuItem>> getMenuItems(String? categoryId, {bool notify = true}) async {
    if (notify) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final remote = await _catalog.menuItems(
        restaurantSlug: _restaurantSlug,
        categoryId: categoryId,
      );
      return remote.map(_toLocalItem).toList();
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('MenuService: chargement impossible — ${e.code}');
      return [];
    } finally {
      if (notify) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Un article avec ses groupes d'options — le détail les porte.
  Future<MenuItem?> getMenuItem(String id) async {
    try {
      final remote = await _catalog.getMenuItem(id);
      return _toLocalItem(remote);
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('MenuService: article introuvable — ${e.code}');
      return null;
    }
  }

  Future<MenuItem?> createMenuItem(MenuItem item) async {
    try {
      final created = await _catalog.createMenuItem(
        restaurantSlug: _restaurantSlug,
        categoryId: item.categoryId,
        name: item.name,
        slug: _slugifier(item.name),
        price: _versMoney(item.basePrice),
        description: item.description ?? '',
        isAvailable: item.isAvailable,
        isPopular: item.isPopular,
        dietaryTags: _regimes(item),
        sortOrder: item.sortOrder,
      );
      return _toLocalItem(created);
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('MenuService: création refusée — ${e.code}');
      return null;
    }
  }

  Future<bool> updateMenuItem(MenuItem item) async {
    try {
      await _catalog.updateMenuItem(
        menuItemId: item.id,
        name: item.name,
        description: item.description ?? '',
        categoryId: item.categoryId,
        price: _versMoney(item.basePrice),
        isAvailable: item.isAvailable,
        isPopular: item.isPopular,
        dietaryTags: _regimes(item),
        sortOrder: item.sortOrder,
      );
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('MenuService: mise à jour refusée — ${e.code}');
      return false;
    }
  }

  /// Retire un article de la carte — suppression **logique** côté serveur :
  /// il reste lisible depuis les commandes passées, qui en gardent une copie.
  Future<bool> deleteMenuItem(String id) async {
    try {
      await _catalog.deleteMenuItem(id);
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('MenuService: suppression refusée — ${e.code}');
      return false;
    }
  }

  // ------------------------------------------------------ groupes d'options

  Future<MenuOptionGroup?> createOptionGroup(MenuOptionGroup group) async {
    try {
      final created = await _catalog.createOptionGroup(
        menuItemId: group.menuItemId,
        name: group.name,
        minSelect: group.minSelection,
        maxSelect: group.maxSelection,
        sortOrder: group.sortOrder,
      );
      return _toLocalGroup(created, group.menuItemId);
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('MenuService: création de groupe refusée — ${e.code}');
      return null;
    }
  }

  Future<bool> updateOptionGroup(MenuOptionGroup group) async {
    try {
      await _catalog.updateOptionGroup(
        groupId: group.id,
        name: group.name,
        minSelect: group.minSelection,
        maxSelect: group.maxSelection,
        sortOrder: group.sortOrder,
      );
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      return false;
    }
  }

  Future<bool> deleteOptionGroup(String id) async {
    try {
      await _catalog.deleteOptionGroup(id);
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      return false;
    }
  }

  // -------------------------------------------------------------- options

  Future<MenuOption?> createOption(MenuOption option) async {
    try {
      final created = await _catalog.createOption(
        groupId: option.groupId,
        name: option.name,
        priceDelta: _versMoney(option.priceModifier),
        isAvailable: option.isAvailable,
        sortOrder: option.sortOrder,
      );
      return _toLocalOption(created, option.groupId);
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint("MenuService: création d'option refusée — ${e.code}");
      return null;
    }
  }

  Future<bool> updateOption(MenuOption option) async {
    try {
      await _catalog.updateOption(
        optionId: option.id,
        name: option.name,
        priceDelta: _versMoney(option.priceModifier),
        isAvailable: option.isAvailable,
        sortOrder: option.sortOrder,
      );
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      return false;
    }
  }

  Future<bool> deleteOption(String id) async {
    try {
      await _catalog.deleteOption(id);
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      return false;
    }
  }

  // ------------------------------------------------------------- traduction

  MenuItem _toLocalItem(eccore.MenuItem remote) {
    return MenuItem(
      id: remote.id,
      categoryId: remote.categorySlug,
      name: remote.name,
      description: remote.description.isEmpty ? null : remote.description,
      basePrice: remote.price.toMajorUnits(),
      imageUrl: remote.image,
      isPopular: remote.isPopular,
      // Le contrat ne porte pas deux booléens de régime : ils sont dérivés de
      // `dietary_tags`, une liste ouverte que l'exploitation enrichit sans
      // migration.
      isVegetarian: remote.dietaryTags.contains('vegetarian'),
      isVegan: remote.dietaryTags.contains('vegan'),
      isAvailable: remote.isAvailable,
      sortOrder: remote.sortOrder,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      optionGroups: [
        for (final groupe in remote.optionGroups) _toLocalGroup(groupe, remote.id),
      ],
    );
  }

  MenuOptionGroup _toLocalGroup(eccore.OptionGroup remote, String menuItemId) {
    return MenuOptionGroup(
      id: remote.id,
      menuItemId: menuItemId,
      name: remote.name,
      minSelection: remote.minSelect,
      maxSelection: remote.maxSelect,
      isRequired: remote.isRequired,
      sortOrder: remote.sortOrder,
      options: [for (final option in remote.options) _toLocalOption(option, remote.id)],
    );
  }

  MenuOption _toLocalOption(eccore.Option remote, String groupId) {
    return MenuOption(
      id: remote.id,
      groupId: groupId,
      name: remote.name,
      priceModifier: remote.priceDelta.toMajorUnits(),
      isAvailable: remote.isAvailable,
      sortOrder: remote.sortOrder,
    );
  }

  List<String> _regimes(MenuItem item) => [
        if (item.isVegetarian) 'vegetarian',
        if (item.isVegan) 'vegan',
      ];

  /// Les francs CFA n'ont pas de décimale : l'unité mineure est le franc.
  eccore.Money _versMoney(double montant) =>
      eccore.Money(amountMinor: montant.round(), currency: 'XOF');

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
}
