import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import '../models/menu_models.dart';
import 'admin_auth_service.dart';

/// Option de la bibliothèque réutilisable — miroir local d'`OptionTemplate`.
///
/// Elle ne porte plus que ce que le serveur enregistre. Les champs de l'ancien
/// catalogue Supabase (`description`, `image_url`, `allergens`, `max_quantity`)
/// ont disparu : les afficher dans un formulaire alors que rien ne les stocke
/// donnerait à l'exploitation le sentiment de saisir une information qui, en
/// réalité, se perdrait à l'enregistrement. La quantité maximale, elle, est
/// désormais une propriété du **groupe** (`min_select` / `max_select`), pas de
/// l'option.
class CustomizationOptionModel {
  final String id;
  final String name;

  /// Groupe suggéré à l'application — « Cuisson », « Suppléments ».
  final String category;
  final double priceModifier;
  final bool isDefault;
  final bool isActive;
  final int sortOrder;

  CustomizationOptionModel({
    required this.id,
    required this.name,
    required this.category,
    this.priceModifier = 0.0,
    this.isDefault = false,
    this.isActive = true,
    this.sortOrder = 0,
  });

  CustomizationOptionModel copyWith({
    String? id,
    String? name,
    String? category,
    double? priceModifier,
    bool? isDefault,
    bool? isActive,
    int? sortOrder,
  }) {
    return CustomizationOptionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      priceModifier: priceModifier ?? this.priceModifier,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// Option posée sur un article — un exemplaire, pas un lien.
///
/// L'ancien modèle appelait ceci une « association » : une ligne reliant un
/// article à une option du catalogue global. Ici, [customizationOptionId] est
/// l'identifiant d'une option qui **appartient** à l'article. La détacher, c'est
/// la supprimer ; elle ne survit nulle part ailleurs.
class MenuItemCustomization {
  final String id;
  final String menuItemId;
  final String menuItemName;
  final String customizationOptionId;
  final String customizationOptionName;

  /// Groupe qui la porte — c'est lui qui décide du caractère obligatoire.
  final String groupId;
  final String groupName;
  final bool isRequired;
  final int sortOrder;

  MenuItemCustomization({
    required this.id,
    required this.menuItemId,
    required this.menuItemName,
    required this.customizationOptionId,
    required this.customizationOptionName,
    this.groupId = '',
    this.groupName = '',
    this.isRequired = false,
    this.sortOrder = 0,
  });
}

/// Bibliothèque d'options réutilisables — `/catalog/manage/option-templates/`
/// (Phase 6).
///
/// Le modèle a changé, et c'est ce qui explique la forme de ce service.
///
/// Côté Supabase, une option vivait dans un catalogue global et une table
/// d'association la reliait à plusieurs articles : corriger son prix changeait
/// donc, en silence, ce que facturaient tous les articles qui s'en servaient —
/// y compris pendant qu'un client composait son panier.
///
/// Côté v2, la bibliothèque reste, mais **appliquer un modèle copie l'option
/// sur l'article**. Le prix facturé est celui porté par l'article (C1), et
/// corriger un modèle ne reprice rien de ce qui est déjà en vitrine. Détacher
/// une option, c'est donc la supprimer du groupe de l'article, pas rompre une
/// association.
class CustomizationManagementService extends ChangeNotifier {
  /// Établissement supervisé — une seule enseigne pour l'instant.
  static const String _restaurantSlug = 'el-corazon-lome';

  eccore.ManagedCatalogRepository get _catalog =>
      eccore.ManagedCatalogRepository(apiClient: AdminAuthService().apiClient);

  List<CustomizationOptionModel> _options = [];
  List<MenuItemCustomization> _menuItemCustomizations = [];
  List<MenuItem> _menuItems = [];
  bool _isLoading = false;
  String? _error;

  List<CustomizationOptionModel> get options => _options;
  List<MenuItemCustomization> get menuItemCustomizations =>
      _menuItemCustomizations;
  List<MenuItem> get menuItems => _menuItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CustomizationManagementService() {
    _loadData();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final modeles = await _catalog.optionTemplates(
        restaurantSlug: _restaurantSlug,
      );
      _options = modeles.map(_toLocalOption).toList();

      final articles = await _catalog.menuItems(restaurantSlug: _restaurantSlug);
      _menuItems = articles.map(_toLocalMenuItem).toList();

      // Les options réellement posées sur les articles sont celles de leurs
      // groupes : il n'y a plus de table d'association à lire, et la forme
      // back-office de l'article les porte déjà — d'où une seule requête.
      _menuItemCustomizations = [
        for (final article in articles)
          for (final groupe in article.optionGroups)
            for (final option in groupe.options)
              MenuItemCustomization(
                id: option.id,
                menuItemId: article.id,
                menuItemName: article.name,
                customizationOptionId: option.id,
                customizationOptionName: option.name,
                groupId: groupe.id,
                groupName: groupe.name,
                isRequired: groupe.isRequired,
                sortOrder: option.sortOrder,
              ),
      ];
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Personnalisations : chargement impossible — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => _loadData();

  // ------------------------------------------------------- bibliothèque

  Future<CustomizationOptionModel?> createOption({
    required String name,
    required String category,
    double priceModifier = 0.0,
    bool isDefault = false,
    int sortOrder = 0,
  }) async {
    try {
      final cree = await _catalog.createOptionTemplate(
        restaurantSlug: _restaurantSlug,
        name: name,
        groupName: category,
        priceDelta: _versMoney(priceModifier),
        isDefault: isDefault,
        sortOrder: sortOrder,
      );
      final locale = _toLocalOption(cree);
      _options.add(locale);
      notifyListeners();
      return locale;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Personnalisations : création refusée — ${e.code}');
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateOption(CustomizationOptionModel option) async {
    try {
      final maj = await _catalog.updateOptionTemplate(
        templateId: option.id,
        name: option.name,
        groupName: option.category,
        priceDelta: _versMoney(option.priceModifier),
        isDefault: option.isDefault,
        isActive: option.isActive,
        sortOrder: option.sortOrder,
      );
      final index = _options.indexWhere((o) => o.id == option.id);
      if (index != -1) _options[index] = _toLocalOption(maj);
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Personnalisations : mise à jour refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  /// Retire un modèle de la bibliothèque.
  ///
  /// Sans effet sur les articles : les options déjà appliquées sont des copies,
  /// elles restent en vitrine. C'est précisément l'intérêt de la copie.
  Future<bool> deleteOption(String optionId) async {
    try {
      await _catalog.deleteOptionTemplate(optionId);
      _options.removeWhere((o) => o.id == optionId);
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Personnalisations : suppression refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  // -------------------------------------------------------- application

  /// Applique un modèle à un article — le serveur y **copie** l'option.
  ///
  /// [isRequired] ne se pose pas sur l'option mais sur le **groupe** qui la
  /// reçoit : « obligatoire » veut dire qu'il faut choisir dans ce groupe
  /// (`min_select ≥ 1`), pas que cette option-là est imposée.
  Future<bool> associateOptionToMenuItem({
    required String menuItemId,
    required String templateId,
    bool isRequired = false,
  }) async {
    try {
      final groupe = await _catalog.applyTemplate(
        menuItemId: menuItemId,
        templateId: templateId,
      );

      if (isRequired && !groupe.isRequired) {
        await _catalog.updateOptionGroup(groupId: groupe.id, minSelect: 1);
      }

      await _loadData();
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.status == 409
          ? 'Cette option figure déjà sur cet article.'
          : e.detail;
      debugPrint('Personnalisations : application refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  /// Retire une option d'un article : elle est supprimée de son groupe.
  Future<bool> removeOptionFromMenuItem({required String optionId}) async {
    try {
      await _catalog.deleteOption(optionId);
      await _loadData();
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Personnalisations : retrait refusé — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  // ------------------------------------------------------------ lectures

  List<MenuItemCustomization> getOptionsForMenuItem(String menuItemId) {
    return _menuItemCustomizations
        .where((c) => c.menuItemId == menuItemId)
        .toList();
  }

  /// Modèles pas encore posés sur cet article.
  ///
  /// Le nom fait foi, faute d'un lien : l'option de l'article est une copie, et
  /// rien en base ne la rattache au modèle dont elle est issue.
  List<CustomizationOptionModel> getAvailableOptionsForMenuItem(
    String menuItemId,
  ) {
    final deja = getOptionsForMenuItem(
      menuItemId,
    ).map((c) => c.customizationOptionName).toSet();
    return _options
        .where((o) => o.isActive && !deja.contains(o.name))
        .toList();
  }

  Map<String, List<CustomizationOptionModel>> getOptionsByCategory() {
    final parCategorie = <String, List<CustomizationOptionModel>>{};
    for (final option in _options) {
      parCategorie.putIfAbsent(option.category, () => []).add(option);
    }
    return parCategorie;
  }

  // ---------------------------------------------------------- traduction

  CustomizationOptionModel _toLocalOption(eccore.OptionTemplate modele) {
    return CustomizationOptionModel(
      id: modele.id,
      name: modele.name,
      category: modele.groupName.isEmpty ? 'extra' : modele.groupName,
      priceModifier: modele.priceDelta.toMajorUnits(),
      isDefault: modele.isDefault,
      isActive: modele.isActive,
      sortOrder: modele.sortOrder,
    );
  }

  MenuItem _toLocalMenuItem(eccore.MenuItem remote) {
    return MenuItem(
      id: remote.id,
      categoryId: remote.categorySlug,
      name: remote.name,
      description: remote.description.isEmpty ? null : remote.description,
      basePrice: remote.price.toMajorUnits(),
      imageUrl: remote.image,
      isPopular: remote.isPopular,
      isVegetarian: remote.dietaryTags.contains('vegetarian'),
      isVegan: remote.dietaryTags.contains('vegan'),
      isAvailable: remote.isAvailable,
      sortOrder: remote.sortOrder,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Les francs CFA n'ont pas de décimale : l'unité mineure est le franc.
  eccore.Money _versMoney(double montant) =>
      eccore.Money(amountMinor: montant.round(), currency: 'XOF');
}
