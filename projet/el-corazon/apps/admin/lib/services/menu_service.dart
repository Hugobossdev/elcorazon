import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';

/// Écriture du catalogue — `/api/v1/catalog/manage/*` (Phase 6).
///
/// C'est le seul endroit d'où un **prix** part vers le serveur (C1), et le
/// serveur reste seul à le facturer : la note (`rating_average`) est en lecture
/// seule côté contrat, sans quoi on pourrait fabriquer une réputation.
///
/// L'envoi d'image change de nature : l'app poussait le fichier dans un bucket
/// Supabase **public** puis écrivait l'URL obtenue dans la table. Le fichier est
/// désormais joint à l'article par un `multipart`, et c'est le serveur qui le
/// range et qui rend l'URL — l'application n'a ni les identifiants du stockage
/// ni le nom des compartiments.
class MenuService extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// À qui rattacher un article créé. La lecture s'en passe : le serveur rend
  /// déjà le périmètre du compte.
  final RestaurantScopeService _scope = RestaurantScopeService();

  /// Plafond accepté pour une photo de produit.
  ///
  /// Le sélecteur recompresse déjà à 85 % et borne le côté long à 1920 px, si
  /// bien qu'une photo de téléphone en sort très en dessous. Ce plafond attrape
  /// ce qui échappe à la recompression — un PNG plein écran, une capture, un
  /// fichier choisi depuis un disque sur la version web — et le refuse **avant**
  /// de faire voyager les octets.
  static const int _tailleMaxImage = 5 * 1024 * 1024;

  eccore.ManagedCatalogRepository get _catalog =>
      eccore.ManagedCatalogRepository(apiClient: AdminAuthService().apiClient);

  /// Joint une image à un article et rend l'URL **que le serveur a retenue**.
  ///
  /// L'article doit exister : il n'y a pas d'image sans article à qui
  /// l'attacher. Pour une création, l'ordre est « créer, puis envoyer l'image »
  /// — les formulaires gardent la photo choisie de côté et l'envoient une fois
  /// l'identifiant connu.
  ///
  /// Il n'y a plus d'`oldImageUrl` à passer : le serveur efface lui-même le
  /// fichier remplacé (`common/files.py`). Le lui faire faire depuis ici
  /// supposait que le client sache traduire une URL en chemin de stockage, et
  /// ne couvrait de toute façon pas les écritures venues d'ailleurs.
  Future<String?> uploadProductImage({
    required String menuItemId,
    required XFile image,
  }) async {
    try {
      // `readAsBytes` plutôt qu'un chemin : sur le web, un fichier choisi n'a
      // pas de chemin lisible, et le back-office tourne aussi dans un
      // navigateur.
      final octets = await image.readAsBytes();

      if (octets.length > _tailleMaxImage) {
        final mo = (octets.length / (1024 * 1024)).toStringAsFixed(1);
        _error = 'Image trop lourde ($mo Mo) : le maximum est de 5 Mo.';
        notifyListeners();
        return null;
      }

      final maj = await _catalog.uploadMenuItemImage(
        menuItemId: menuItemId,
        filename: image.name,
        bytes: octets,
        contentType: image.mimeType,
      );

      _error = null;
      notifyListeners();
      return maj.image;
    } on eccore.ApiException catch (e) {
      // Le serveur refuse ce qui n'est pas une image : `ImageField` la fait
      // ouvrir par Pillow. Un fichier renommé en `.jpg` sort donc en 400, et
      // non en image cassée découverte par un client.
      _error = e.detail;
      eccore.Journal.trace("MenuService: envoi d'image refusé — ${e.code}");
      notifyListeners();
      return null;
    }
  }

  /// Retire l'image d'un article. Le serveur efface le fichier.
  Future<bool> removeProductImage(String menuItemId) async {
    try {
      await _catalog.clearMenuItemImage(menuItemId);
      _error = null;
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace("MenuService: retrait d'image refusé — ${e.code}");
      notifyListeners();
      return false;
    }
  }

  Future<List<eccore.ManagedMenuItem>> getMenuItems(
    String? categoryId, {
    bool notify = true,
  }) async {
    if (notify) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final remote = await _catalog.menuItems(categoryId: categoryId);
      return remote;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('MenuService: chargement impossible — ${e.code}');
      return [];
    } finally {
      if (notify) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Un article avec ses groupes d'options — le détail les porte.
  Future<eccore.ManagedMenuItem?> getMenuItem(String id) async {
    try {
      return _catalog.getMenuItem(id);
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('MenuService: article introuvable — ${e.code}');
      return null;
    }
  }

  Future<eccore.ManagedMenuItem?> createMenuItem({
    required String categoryId,
    required String name,
    required double basePrice,
    required List<String> dietaryTags,
    String description = '',
    bool isAvailable = true,
    bool isPopular = false,
    int sortOrder = 0,
  }) async {
    try {
      final etablissement = await _scope.requireSlug();
      if (etablissement == null) {
        _error = RestaurantScopeService.sansPerimetre;
        return null;
      }

      return await _catalog.createMenuItem(
        restaurantSlug: etablissement,
        categoryId: categoryId,
        name: name,
        slug: _slugifier(name),
        price: _versMoney(basePrice),
        description: description,
        isAvailable: isAvailable,
        isPopular: isPopular,
        dietaryTags: dietaryTags,
        sortOrder: sortOrder,
      );
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('MenuService: création refusée — ${e.code}');
      return null;
    }
  }

  /// [dietaryTags] part **entière** : la liste est ouverte côté serveur, et n'y
  /// renvoyer que les deux régimes de l'écran effacerait les autres.
  Future<bool> updateMenuItem({
    required String menuItemId,
    required String categoryId,
    required String name,
    required double basePrice,
    required List<String> dietaryTags,
    String description = '',
    bool isAvailable = true,
    bool isPopular = false,
    int sortOrder = 0,
  }) async {
    try {
      await _catalog.updateMenuItem(
        menuItemId: menuItemId,
        name: name,
        description: description,
        categoryId: categoryId,
        price: _versMoney(basePrice),
        isAvailable: isAvailable,
        isPopular: isPopular,
        dietaryTags: dietaryTags,
        sortOrder: sortOrder,
      );
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('MenuService: mise à jour refusée — ${e.code}');
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
      eccore.Journal.trace('MenuService: suppression refusée — ${e.code}');
      return false;
    }
  }

  // ------------------------------------------------------ groupes d'options

  Future<eccore.OptionGroup?> createOptionGroup({
    required String menuItemId,
    required String name,
    int minSelect = 0,
    int maxSelect = 1,
    int sortOrder = 0,
  }) async {
    try {
      return await _catalog.createOptionGroup(
        menuItemId: menuItemId,
        name: name,
        minSelect: minSelect,
        maxSelect: maxSelect,
        sortOrder: sortOrder,
      );
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('MenuService: création de groupe refusée — ${e.code}');
      return null;
    }
  }

  Future<bool> updateOptionGroup({
    required String groupId,
    required String name,
    int minSelect = 0,
    int maxSelect = 1,
    int sortOrder = 0,
  }) async {
    try {
      await _catalog.updateOptionGroup(
        groupId: groupId,
        name: name,
        minSelect: minSelect,
        maxSelect: maxSelect,
        sortOrder: sortOrder,
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

  Future<eccore.Option?> createOption({
    required String groupId,
    required String name,
    required double priceModifier,
    bool isAvailable = true,
    int sortOrder = 0,
  }) async {
    try {
      return await _catalog.createOption(
        groupId: groupId,
        name: name,
        priceDelta: _versMoney(priceModifier),
        isAvailable: isAvailable,
        sortOrder: sortOrder,
      );
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace("MenuService: création d'option refusée — ${e.code}");
      return null;
    }
  }

  Future<bool> updateOption({
    required String optionId,
    required String name,
    required double priceModifier,
    bool isAvailable = true,
    int sortOrder = 0,
  }) async {
    try {
      await _catalog.updateOption(
        optionId: optionId,
        name: name,
        priceDelta: _versMoney(priceModifier),
        isAvailable: isAvailable,
        sortOrder: sortOrder,
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
