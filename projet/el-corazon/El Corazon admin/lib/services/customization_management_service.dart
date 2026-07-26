import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_models.dart';

/// Modèle pour une option de personnalisation complète (avec infos de liaison)
class CustomizationOptionModel {
  final String id;
  final String name;
  final String category;
  final double priceModifier;
  final bool isDefault;
  final int maxQuantity;
  final String? description;
  final String? imageUrl;
  final List<String> allergens;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomizationOptionModel({
    required this.id,
    required this.name,
    required this.category,
    this.priceModifier = 0.0,
    this.isDefault = false,
    this.maxQuantity = 1,
    this.description,
    this.imageUrl,
    this.allergens = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomizationOptionModel.fromMap(Map<String, dynamic> map) {
    List<String> allergensList = [];
    if (map['allergens'] is List) {
      allergensList = (map['allergens'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (map['allergens'] is String &&
        (map['allergens'] as String).isNotEmpty) {
      allergensList = (map['allergens'] as String)
          .split(',')
          .map((e) => e.trim())
          .toList();
    }

    return CustomizationOptionModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? 'extra',
      priceModifier: (map['price_modifier'] as num?)?.toDouble() ?? 0.0,
      isDefault: map['is_default'] as bool? ?? false,
      maxQuantity: (map['max_quantity'] as num?)?.toInt() ?? 1,
      description: map['description']?.toString(),
      imageUrl: map['image_url']?.toString(),
      allergens: allergensList,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price_modifier': priceModifier,
      'is_default': isDefault,
      'max_quantity': maxQuantity,
      'description': description,
      'image_url': imageUrl,
      'allergens': allergens,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CustomizationOptionModel copyWith({
    String? id,
    String? name,
    String? category,
    double? priceModifier,
    bool? isDefault,
    int? maxQuantity,
    String? description,
    String? imageUrl,
    List<String>? allergens,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomizationOptionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      priceModifier: priceModifier ?? this.priceModifier,
      isDefault: isDefault ?? this.isDefault,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      allergens: allergens ?? this.allergens,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Modèle pour l'association entre un menu item et une option
class MenuItemCustomization {
  final String id;
  final String menuItemId;
  final String menuItemName;
  final String customizationOptionId;
  final String customizationOptionName;
  final bool isRequired;
  final int sortOrder;

  MenuItemCustomization({
    required this.id,
    required this.menuItemId,
    required this.menuItemName,
    required this.customizationOptionId,
    required this.customizationOptionName,
    this.isRequired = false,
    this.sortOrder = 0,
  });

  factory MenuItemCustomization.fromMap(Map<String, dynamic> map) {
    // Parser les jointures Supabase
    // Supabase retourne les jointures avec le nom de la table au pluriel
    String menuItemName = '';
    final menuItemsData = map['menu_items'];
    if (menuItemsData is Map) {
      menuItemName = menuItemsData['name']?.toString() ?? '';
    } else if (map['menu_item'] is Map) {
      menuItemName = (map['menu_item'] as Map)['name']?.toString() ?? '';
    } else if (map['menu_item_name'] != null) {
      menuItemName = map['menu_item_name'].toString();
    }

    String optionName = '';
    final optionsData = map['customization_options'];
    if (optionsData is Map) {
      optionName = optionsData['name']?.toString() ?? '';
    } else if (map['customization_option'] is Map) {
      optionName =
          (map['customization_option'] as Map)['name']?.toString() ?? '';
    } else if (map['customization_option_name'] != null) {
      optionName = map['customization_option_name'].toString();
    }

    return MenuItemCustomization(
      id: map['id']?.toString() ?? '',
      menuItemId: map['menu_item_id']?.toString() ?? '',
      menuItemName: menuItemName,
      customizationOptionId: map['customization_option_id']?.toString() ?? '',
      customizationOptionName: optionName,
      isRequired: map['is_required'] as bool? ?? false,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class CustomizationManagementService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

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
    await Future.wait([
      _loadOptions(),
      _loadMenuItems(),
      _loadMenuItemCustomizations(),
    ]);
  }

  /// Charger toutes les options de personnalisation
  Future<void> _loadOptions() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase
          .from('customization_options')
          .select('*')
          .order('category')
          .order('name');

      _options = (response as List)
          .map((data) {
            try {
              return CustomizationOptionModel.fromMap(
                data as Map<String, dynamic>,
              );
            } catch (e) {
              debugPrint('❌ Erreur parsing option: $e');
              return null;
            }
          })
          .whereType<CustomizationOptionModel>()
          .toList();

      debugPrint('✅ ${_options.length} options de personnalisation chargées');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Erreur chargement options: $e');
      _options = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger tous les menu items
  Future<void> _loadMenuItems() async {
    try {
      final response = await _supabase
          .from('menu_items')
          .select('*')
          .order('name');

      _menuItems = (response as List)
          .map((data) {
            try {
              return MenuItem.fromMap(data as Map<String, dynamic>);
            } catch (e) {
              debugPrint('❌ Erreur parsing menu item: $e');
              return null;
            }
          })
          .whereType<MenuItem>()
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur chargement menu items: $e');
      _menuItems = [];
    }
  }

  /// Charger toutes les associations menu items - options
  Future<void> _loadMenuItemCustomizations() async {
    try {
      final response = await _supabase
          .from('menu_item_customizations')
          .select('''
            *,
            menu_items!inner(name),
            customization_options!inner(name)
          ''')
          .order('menu_item_id')
          .order('sort_order');

      _menuItemCustomizations = (response as List)
          .map((data) {
            try {
              return MenuItemCustomization.fromMap(
                data as Map<String, dynamic>,
              );
            } catch (e) {
              debugPrint('❌ Erreur parsing association: $e');
              return null;
            }
          })
          .whereType<MenuItemCustomization>()
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur chargement associations: $e');
      _menuItemCustomizations = [];
    }
  }

  /// Créer une nouvelle option de personnalisation
  Future<CustomizationOptionModel?> createOption({
    required String name,
    required String category,
    double priceModifier = 0.0,
    bool isDefault = false,
    int maxQuantity = 1,
    String? description,
    String? imageUrl,
    List<String> allergens = const [],
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase
          .from('customization_options')
          .insert({
            'name': name,
            'category': category,
            'price_modifier': priceModifier,
            'is_default': isDefault,
            'max_quantity': maxQuantity,
            'description': description,
            'image_url': imageUrl,
            'allergens': allergens,
            'is_active': true,
          })
          .select()
          .single();

      final newOption = CustomizationOptionModel.fromMap(response);
      _options.add(newOption);
      _options.sort((a, b) {
        final catCompare = a.category.compareTo(b.category);
        if (catCompare != 0) return catCompare;
        return a.name.compareTo(b.name);
      });

      _isLoading = false;
      notifyListeners();
      return newOption;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Erreur création option: $e');
      return null;
    }
  }

  /// Mettre à jour une option de personnalisation
  Future<bool> updateOption(CustomizationOptionModel option) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase
          .from('customization_options')
          .update({
            'name': option.name,
            'category': option.category,
            'price_modifier': option.priceModifier,
            'is_default': option.isDefault,
            'max_quantity': option.maxQuantity,
            'description': option.description,
            'image_url': option.imageUrl,
            'allergens': option.allergens,
            'is_active': option.isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', option.id);

      final index = _options.indexWhere((o) => o.id == option.id);
      if (index != -1) {
        _options[index] = option;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Erreur mise à jour option: $e');
      return false;
    }
  }

  /// Supprimer une option de personnalisation
  Future<bool> deleteOption(String optionId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Vérifier si l'option est utilisée
      final usedIn = _menuItemCustomizations
          .where((m) => m.customizationOptionId == optionId)
          .toList();

      if (usedIn.isNotEmpty) {
        _error =
            'Cette option est utilisée par ${usedIn.length} menu item(s). Supprimez d\'abord les associations.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _supabase.from('customization_options').delete().eq('id', optionId);

      _options.removeWhere((o) => o.id == optionId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Erreur suppression option: $e');
      return false;
    }
  }

  /// Associer une option à un menu item
  Future<bool> associateOptionToMenuItem({
    required String menuItemId,
    required String optionId,
    bool isRequired = false,
    int sortOrder = 0,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Vérifier si l'association existe déjà
      final existing = await _supabase
          .from('menu_item_customizations')
          .select('id')
          .eq('menu_item_id', menuItemId)
          .eq('customization_option_id', optionId)
          .maybeSingle();

      if (existing != null) {
        _error = 'Cette option est déjà associée à ce menu item';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _supabase.from('menu_item_customizations').insert({
        'menu_item_id': menuItemId,
        'customization_option_id': optionId,
        'is_required': isRequired,
        'sort_order': sortOrder,
      });

      // Recharger les associations et les menu items pour mettre à jour les noms
      await Future.wait([_loadMenuItemCustomizations(), _loadMenuItems()]);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Erreur association option: $e');
      return false;
    }
  }

  /// Retirer une option d'un menu item
  Future<bool> removeOptionFromMenuItem({
    required String menuItemId,
    required String optionId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase
          .from('menu_item_customizations')
          .delete()
          .eq('menu_item_id', menuItemId)
          .eq('customization_option_id', optionId);

      await _loadMenuItemCustomizations();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Erreur retrait option: $e');
      return false;
    }
  }

  /// Mettre à jour une association (is_required, sort_order)
  Future<bool> updateMenuItemCustomization({
    required String associationId,
    bool? isRequired,
    int? sortOrder,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final updateData = <String, dynamic>{};
      if (isRequired != null) updateData['is_required'] = isRequired;
      if (sortOrder != null) updateData['sort_order'] = sortOrder;

      if (updateData.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return true;
      }

      await _supabase
          .from('menu_item_customizations')
          .update(updateData)
          .eq('id', associationId);

      await _loadMenuItemCustomizations();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Erreur mise à jour association: $e');
      return false;
    }
  }

  /// Obtenir les options associées à un menu item
  List<MenuItemCustomization> getOptionsForMenuItem(String menuItemId) {
    return _menuItemCustomizations
        .where((m) => m.menuItemId == menuItemId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Obtenir les options disponibles (non associées à un menu item)
  List<CustomizationOptionModel> getAvailableOptionsForMenuItem(
    String menuItemId,
  ) {
    final associatedIds = getOptionsForMenuItem(
      menuItemId,
    ).map((m) => m.customizationOptionId).toSet();

    return _options
        .where((o) => !associatedIds.contains(o.id) && o.isActive)
        .toList();
  }

  /// Rafraîchir les données
  Future<void> refresh() async {
    await _loadData();
  }

  /// Obtenir les options par catégorie
  Map<String, List<CustomizationOptionModel>> getOptionsByCategory() {
    final Map<String, List<CustomizationOptionModel>> grouped = {};
    for (var option in _options) {
      grouped.putIfAbsent(option.category, () => []);
      grouped[option.category]!.add(option);
    }
    return grouped;
  }
}
