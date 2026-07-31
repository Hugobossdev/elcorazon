import 'package:flutter/foundation.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/utils/price_formatter.dart';

class CustomizationOption {
  final String id;
  final String name;
  final String category; // 'ingredient', 'sauce', 'size', 'cooking', 'extra'
  final double priceModifier;
  final bool isDefault;
  final bool isRequired; // Si l'option est requise pour ce menu item
  final int maxQuantity;
  final String? description;
  final String? imageUrl;
  final List<String>? allergens;

  CustomizationOption({
    required this.id,
    required this.name,
    required this.category,
    this.priceModifier = 0.0,
    this.isDefault = false,
    this.isRequired = false,
    this.maxQuantity = 1,
    this.description,
    this.imageUrl,
    this.allergens,
  });

  /// Depuis le contrat Django (`OptionSerializer` dans son groupe).
  ///
  /// La `category` locale n'a pas d'équivalent : le backend groupe les options
  /// par `OptionGroup` (« Cuisson », « Taille »...) plutôt que par une
  /// étiquette libre. Le nom du groupe en tient lieu — c'est aussi ce que
  /// l'écran affiche en titre de section.
  factory CustomizationOption.fromRemote(eccore.Option option, eccore.OptionGroup group) {
    return CustomizationOption(
      id: option.id,
      name: option.name,
      category: group.name,
      priceModifier: option.priceDelta.toMajorUnits(),
      isDefault: option.isDefault,
      isRequired: group.isRequired,
      maxQuantity: group.maxSelect,
    );
  }

  factory CustomizationOption.fromDatabase(Map<String, dynamic> row) {
    // Parser l'option depuis la jointure
    final option = Map<String, dynamic>.from(
        row['customization_options'] as Map<String, dynamic>? ?? {},);

    // Récupérer l'ID (peut être dans option ou dans row)
    final id = (option['id']?.toString() ??
                row['customization_option_id']?.toString() ??
                '')
            .isEmpty
        ? throw Exception('Customization option ID is missing')
        : (option['id'] ?? row['customization_option_id']).toString();

    final name = option['name']?.toString() ?? 'Option';
    final category = option['category']?.toString() ?? 'extra';

    // Parser le price_modifier avec gestion des nulls
    final priceModifier = (option['price_modifier'] as num?)?.toDouble() ?? 0.0;

    // is_default peut être dans row (menu_item_customizations) ou option
    final isDefaultValue = (row['is_default'] as bool?) ??
        (option['is_default'] as bool?) ??
        false;

    // is_required vient de menu_item_customizations
    final isRequiredValue = (row['is_required'] as bool?) ?? false;

    // Parser max_quantity avec gestion des nulls
    int maxQuantityValue = 1;
    if (option['max_quantity'] is int) {
      maxQuantityValue = option['max_quantity'] as int;
    } else if (option['max_quantity'] is num) {
      maxQuantityValue = (option['max_quantity'] as num).toInt();
    } else if (option['max_quantity'] != null) {
      maxQuantityValue = int.tryParse(option['max_quantity'].toString()) ?? 1;
    }
    if (maxQuantityValue < 1) maxQuantityValue = 1;

    final description = option['description']?.toString();
    final imageUrl = option['image_url']?.toString();

    // Parser les allergènes
    List<String>? allergens;
    final rawAllergens = option['allergens'];
    if (rawAllergens is List && rawAllergens.isNotEmpty) {
      allergens = rawAllergens
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (rawAllergens is String && rawAllergens.isNotEmpty) {
      allergens = rawAllergens
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return CustomizationOption(
      id: id,
      name: name,
      category: category,
      priceModifier: priceModifier,
      isDefault: isDefaultValue == true,
      isRequired: isRequiredValue == true,
      maxQuantity: maxQuantityValue,
      description: description,
      imageUrl: imageUrl,
      allergens: allergens,
    );
  }

  CustomizationOption copyWith({
    String? id,
    String? name,
    String? category,
    double? priceModifier,
    bool? isDefault,
    bool? isRequired,
    int? maxQuantity,
    String? description,
    String? imageUrl,
    List<String>? allergens,
  }) {
    return CustomizationOption(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      priceModifier: priceModifier ?? this.priceModifier,
      isDefault: isDefault ?? this.isDefault,
      isRequired: isRequired ?? this.isRequired,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      allergens: allergens ??
          (this.allergens != null ? List<String>.from(this.allergens!) : null),
    );
  }
}

class ItemCustomization {
  final String itemId;
  final String menuItemId;
  final String menuItemName;
  final Map<String, List<String>> selections; // category -> selected option ids
  final Map<String, int> quantities; // option id -> quantity
  final String? specialInstructions;
  final double totalPriceModifier;

  ItemCustomization({
    required this.itemId,
    required this.menuItemId,
    required this.menuItemName,
    required this.selections,
    required this.quantities,
    this.specialInstructions,
    this.totalPriceModifier = 0.0,
  });

  ItemCustomization copyWith({
    String? itemId,
    String? menuItemId,
    String? menuItemName,
    Map<String, List<String>>? selections,
    Map<String, int>? quantities,
    String? specialInstructions,
    double? totalPriceModifier,
  }) {
    return ItemCustomization(
      itemId: itemId ?? this.itemId,
      menuItemId: menuItemId ?? this.menuItemId,
      menuItemName: menuItemName ?? this.menuItemName,
      selections: selections ?? Map.from(this.selections),
      quantities: quantities ?? Map.from(this.quantities),
      specialInstructions: specialInstructions ?? this.specialInstructions,
      totalPriceModifier: totalPriceModifier ?? this.totalPriceModifier,
    );
  }
}

class CategoryConstraint {
  final String category;
  final int minSelections;
  final int maxSelections;
  final bool isRequired;
  final bool isSingleChoice;

  const CategoryConstraint({
    required this.category,
    this.minSelections = 0,
    this.maxSelections = 99,
    this.isRequired = false,
    this.isSingleChoice = false,
  });
}

class CustomizationService extends ChangeNotifier {
  static final CustomizationService _instance =
      CustomizationService._internal();
  factory CustomizationService() => _instance;
  CustomizationService._internal();


  Map<String, List<CustomizationOption>> _itemOptions = {};
  Map<String, List<CustomizationOption>> _defaultOptionsByName = {};
  final Map<String, ItemCustomization> _currentCustomizations = {};
  
  // ✅ Centralisation des contraintes par catégorie
  final Map<String, CategoryConstraint> _categoryConstraints = {
    // Gâteaux - Choix unique requis
    'shape': const CategoryConstraint(category: 'shape', isSingleChoice: true, isRequired: true),
    'size': const CategoryConstraint(category: 'size', isSingleChoice: true, isRequired: true),
    'flavor': const CategoryConstraint(category: 'flavor', isSingleChoice: true, isRequired: true),
    'tiers': const CategoryConstraint(category: 'tiers', isSingleChoice: true, isRequired: true),
    'icing': const CategoryConstraint(category: 'icing', isSingleChoice: true, isRequired: true),
    'dietary': const CategoryConstraint(category: 'dietary', isSingleChoice: true, isRequired: true),
    'color': const CategoryConstraint(category: 'color', isSingleChoice: true),
    'texture': const CategoryConstraint(category: 'texture', isSingleChoice: true),
    
    // Gâteaux - Choix multiples limités
    'filling': const CategoryConstraint(category: 'filling', maxSelections: 2),
    'decoration': const CategoryConstraint(category: 'decoration', maxSelections: 5), // Augmenté à 5
    
    // Burgers/Pizzas - Standards
    'cooking': const CategoryConstraint(category: 'cooking', isSingleChoice: true, isRequired: true),
    'sauce': const CategoryConstraint(category: 'sauce', maxSelections: 2),
    'extra': const CategoryConstraint(category: 'extra', maxSelections: 5),
    'ingredient': const CategoryConstraint(category: 'ingredient', maxSelections: 5),
  };

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadCustomizationOptions();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing Customization Service: $e');
    }
  }

  /// Plus de préchargement global des options.
  ///
  /// L'ancienne version lisait d'un coup la table entière des personnalisations
  /// de tous les articles. Le contrat Django ne porte les groupes d'options que
  /// sur le **détail** d'un article (`MenuItemDetailSerializer`), justement
  /// pour ne pas traîner ces lignes dans chaque liste de menu : elles sont donc
  /// chargées à la demande, par article ouvert
  /// ([_loadOptionsForMenuItem]).
  Future<void> _loadCustomizationOptions() async {
    _defaultOptionsByName = _getDefaultCustomizationOptions();
  }

  Map<String, List<CustomizationOption>> _getDefaultCustomizationOptions() {
    return {
      'Burger Classique': [
        CustomizationOption(
          id: 'size-small',
          name: 'Petit',
          category: 'size',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'size-medium',
          name: 'Moyen',
          category: 'size',
          priceModifier: 2.0,
        ),
        CustomizationOption(
          id: 'size-large',
          name: 'Grand',
          category: 'size',
          priceModifier: 4.0,
        ),
        CustomizationOption(
          id: 'cooking-rare',
          name: 'Saignant',
          category: 'cooking',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'cooking-medium',
          name: 'À point',
          category: 'cooking',
        ),
        CustomizationOption(
          id: 'cooking-well',
          name: 'Bien cuit',
          category: 'cooking',
        ),
        CustomizationOption(
          id: 'extra-cheese',
          name: 'Fromage supplémentaire',
          category: 'extra',
          priceModifier: 1.5,
        ),
        CustomizationOption(
          id: 'extra-bacon',
          name: 'Bacon supplémentaire',
          category: 'extra',
          priceModifier: 2.0,
        ),
        CustomizationOption(
          id: 'sauce-ketchup',
          name: 'Ketchup',
          category: 'sauce',
        ),
        CustomizationOption(
          id: 'sauce-mayo',
          name: 'Mayonnaise',
          category: 'sauce',
        ),
        CustomizationOption(
          id: 'sauce-mustard',
          name: 'Moutarde',
          category: 'sauce',
        ),
      ],
      'Gâteau personnalisé': [
        // Formes
        CustomizationOption(
          id: 'cake-shape-round',
          name: 'Rond',
          category: 'shape',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'cake-shape-square',
          name: 'Carré',
          category: 'shape',
          priceModifier: 2000.0,
        ),
        CustomizationOption(
          id: 'cake-shape-heart',
          name: 'Cœur',
          category: 'shape',
          priceModifier: 3500.0,
        ),
        CustomizationOption(
          id: 'cake-shape-rectangle',
          name: 'Rectangle',
          category: 'shape',
          priceModifier: 2500.0,
        ),

        // Tailles
        CustomizationOption(
          id: 'cake-size-small',
          name: 'Petit (6 personnes)',
          category: 'size',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'cake-size-medium',
          name: 'Moyen (10 personnes)',
          category: 'size',
          priceModifier: 6000.0,
        ),
        CustomizationOption(
          id: 'cake-size-large',
          name: 'Grand (16 personnes)',
          category: 'size',
          priceModifier: 11000.0,
        ),

        // Saveurs
        CustomizationOption(
          id: 'cake-flavor-vanilla',
          name: 'Vanille',
          category: 'flavor',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'cake-flavor-chocolate',
          name: 'Chocolat',
          category: 'flavor',
          priceModifier: 2000.0,
        ),
        CustomizationOption(
          id: 'cake-flavor-strawberry',
          name: 'Fraise',
          category: 'flavor',
          priceModifier: 2500.0,
        ),
        CustomizationOption(
          id: 'cake-flavor-mix',
          name: 'Vanille & Chocolat',
          category: 'flavor',
          priceModifier: 3000.0,
        ),

        // Étages
        CustomizationOption(
          id: 'cake-tier-1',
          name: '1 étage (standard)',
          category: 'tiers',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'cake-tier-2',
          name: '2 étages (+12 parts)',
          category: 'tiers',
          priceModifier: 7000.0,
        ),
        CustomizationOption(
          id: 'cake-tier-3',
          name: '3 étages (+20 parts)',
          category: 'tiers',
          priceModifier: 12000.0,
        ),

        // Glaçages / Icing
        CustomizationOption(
          id: 'cake-icing-buttercream',
          name: 'Crème au beurre vanille',
          category: 'icing',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'cake-icing-creamcheese',
          name: 'Cream cheese citron',
          category: 'icing',
          priceModifier: 2500.0,
        ),
        CustomizationOption(
          id: 'cake-icing-ganache',
          name: 'Ganache chocolat noir',
          category: 'icing',
          priceModifier: 3000.0,
        ),

        // Régime / Allergies
        CustomizationOption(
          id: 'cake-diet-standard',
          name: 'Classique',
          category: 'dietary',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'cake-diet-no-nuts',
          name: 'Sans fruits à coque',
          category: 'dietary',
          priceModifier: 1500.0,
        ),
        CustomizationOption(
          id: 'cake-diet-gluten-free',
          name: 'Sans gluten',
          category: 'dietary',
          priceModifier: 3500.0,
        ),
        CustomizationOption(
          id: 'cake-diet-lactose-free',
          name: 'Sans lactose',
          category: 'dietary',
          priceModifier: 3000.0,
        ),

        // Garnitures (multi)
        CustomizationOption(
          id: 'cake-filling-cream',
          name: 'Crème fouettée',
          category: 'filling',
          priceModifier: 1500.0,
          maxQuantity: 2,
        ),
        CustomizationOption(
          id: 'cake-filling-ganache',
          name: 'Ganache chocolat',
          category: 'filling',
          priceModifier: 2000.0,
          maxQuantity: 2,
        ),
        CustomizationOption(
          id: 'cake-filling-fruits',
          name: 'Compotée de fruits rouges',
          category: 'filling',
          priceModifier: 2500.0,
          maxQuantity: 2,
        ),

        // Décorations (multi)
        CustomizationOption(
          id: 'cake-deco-fruits',
          name: 'Fruits frais',
          category: 'decoration',
          priceModifier: 2000.0,
          maxQuantity: 3,
        ),
        CustomizationOption(
          id: 'cake-deco-chocolate',
          name: 'Copeaux de chocolat',
          category: 'decoration',
          priceModifier: 1500.0,
          maxQuantity: 3,
        ),
        CustomizationOption(
          id: 'cake-deco-macarons',
          name: 'Macarons assortis',
          category: 'decoration',
          priceModifier: 3000.0,
          maxQuantity: 3,
        ),
        CustomizationOption(
          id: 'cake-deco-photo',
          name: 'Photo comestible',
          category: 'decoration',
          priceModifier: 4000.0,
        ),
        CustomizationOption(
          id: 'cake-deco-message',
          name: 'Message en sucre',
          category: 'decoration',
          priceModifier: 1000.0,
        ),
        
        // 🎨 NOUVELLES OPTIONS AVANCÉES - Couleurs
        CustomizationOption(
          id: 'cake-color-white',
          name: 'Blanc',
          category: 'color',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'cake-color-pink',
          name: 'Rose',
          category: 'color',
          priceModifier: 1500.0,
        ),
        CustomizationOption(
          id: 'cake-color-blue',
          name: 'Bleu',
          category: 'color',
          priceModifier: 1500.0,
        ),
        CustomizationOption(
          id: 'cake-color-purple',
          name: 'Violet',
          category: 'color',
          priceModifier: 1500.0,
        ),
        CustomizationOption(
          id: 'cake-color-gradient',
          name: 'Dégradé personnalisé',
          category: 'color',
          priceModifier: 3000.0,
        ),
        
        // 🎨 Textures de glaçage
        CustomizationOption(
          id: 'cake-texture-smooth',
          name: 'Lisse',
          category: 'texture',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'cake-texture-rough',
          name: 'Rustique',
          category: 'texture',
          priceModifier: 1000.0,
        ),
        CustomizationOption(
          id: 'cake-texture-ombré',
          name: 'Ombré',
          category: 'texture',
          priceModifier: 2500.0,
        ),
        CustomizationOption(
          id: 'cake-texture-marble',
          name: 'Marbré',
          category: 'texture',
          priceModifier: 2000.0,
        ),
        
        // 🎨 Décorations avancées
        CustomizationOption(
          id: 'cake-deco-flowers',
          name: 'Fleurs comestibles',
          category: 'decoration',
          priceModifier: 3500.0,
          maxQuantity: 3,
        ),
        CustomizationOption(
          id: 'cake-deco-fondant',
          name: 'Pâte à sucre',
          category: 'decoration',
          priceModifier: 4000.0,
          maxQuantity: 3,
        ),
        CustomizationOption(
          id: 'cake-deco-edible-glitter',
          name: 'Paillettes comestibles',
          category: 'decoration',
          priceModifier: 2000.0,
          maxQuantity: 3,
        ),
        CustomizationOption(
          id: 'cake-deco-gold-leaf',
          name: 'Feuille d\'or',
          category: 'decoration',
          priceModifier: 5000.0,
          maxQuantity: 3,
        ),
        CustomizationOption(
          id: 'cake-deco-3d-figures',
          name: 'Figurines 3D',
          category: 'decoration',
          priceModifier: 6000.0,
          maxQuantity: 3,
        ),
        
        // 🎨 Garnitures spéciales
        CustomizationOption(
          id: 'cake-filling-nutella',
          name: 'Nutella',
          category: 'filling',
          priceModifier: 3000.0,
          maxQuantity: 2,
        ),
        CustomizationOption(
          id: 'cake-filling-caramel',
          name: 'Caramel au beurre salé',
          category: 'filling',
          priceModifier: 2500.0,
          maxQuantity: 2,
        ),
        CustomizationOption(
          id: 'cake-filling-lemon-curd',
          name: 'Crème au citron',
          category: 'filling',
          priceModifier: 2000.0,
          maxQuantity: 2,
        ),
      ],
      'Burger Bacon': [
        CustomizationOption(
          id: 'size-small',
          name: 'Petit',
          category: 'size',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'size-medium',
          name: 'Moyen',
          category: 'size',
          priceModifier: 2.0,
        ),
        CustomizationOption(
          id: 'size-large',
          name: 'Grand',
          category: 'size',
          priceModifier: 4.0,
        ),
        CustomizationOption(
          id: 'cooking-rare',
          name: 'Saignant',
          category: 'cooking',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'cooking-medium',
          name: 'À point',
          category: 'cooking',
        ),
        CustomizationOption(
          id: 'cooking-well',
          name: 'Bien cuit',
          category: 'cooking',
        ),
        CustomizationOption(
          id: 'extra-cheese',
          name: 'Fromage supplémentaire',
          category: 'extra',
          priceModifier: 1.5,
        ),
        CustomizationOption(
          id: 'extra-bacon',
          name: 'Bacon supplémentaire',
          category: 'extra',
          priceModifier: 2.0,
        ),
        CustomizationOption(
          id: 'sauce-bbq',
          name: 'Sauce BBQ',
          category: 'sauce',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'sauce-ketchup',
          name: 'Ketchup',
          category: 'sauce',
        ),
      ],
      'Pizza Margherita': [
        CustomizationOption(
          id: 'size-small',
          name: 'Petite (25cm)',
          category: 'size',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'size-medium',
          name: 'Moyenne (30cm)',
          category: 'size',
          priceModifier: 3.0,
        ),
        CustomizationOption(
          id: 'size-large',
          name: 'Grande (35cm)',
          category: 'size',
          priceModifier: 6.0,
        ),
        CustomizationOption(
          id: 'extra-mozzarella',
          name: 'Mozzarella supplémentaire',
          category: 'extra',
          priceModifier: 2.0,
        ),
        CustomizationOption(
          id: 'extra-basil',
          name: 'Basilic frais',
          category: 'extra',
          priceModifier: 1.0,
        ),
      ],
      'Pizza Pepperoni': [
        CustomizationOption(
          id: 'size-small',
          name: 'Petite (25cm)',
          category: 'size',
          isDefault: true,
        ),
        CustomizationOption(
          id: 'size-medium',
          name: 'Moyenne (30cm)',
          category: 'size',
          priceModifier: 3.0,
        ),
        CustomizationOption(
          id: 'size-large',
          name: 'Grande (35cm)',
          category: 'size',
          priceModifier: 6.0,
        ),
        CustomizationOption(
          id: 'extra-pepperoni',
          name: 'Pepperoni supplémentaire',
          category: 'extra',
          priceModifier: 2.5,
        ),
        CustomizationOption(
          id: 'extra-cheese',
          name: 'Fromage supplémentaire',
          category: 'extra',
          priceModifier: 1.5,
        ),
      ],
    };
  }

  List<CustomizationOption> _getOptionsForMenuItem(
    String menuItemId, {
    String? fallbackName,
  }) {
    // D'abord, essayer de charger depuis la base de données si pas encore chargé
    final stored = _itemOptions[menuItemId];
    if (stored != null && stored.isNotEmpty) {
      debugPrint(
          '✅ Options trouvées en cache pour $menuItemId: ${stored.length} options',);
      return stored;
    }

    // Fallback sur les options par défaut basées sur le nom (vérifier plusieurs variantes)
    if (fallbackName != null) {
      // Essayer le nom exact
      var defaults = _defaultOptionsByName[fallbackName];

      // Si pas trouvé, essayer des variantes
      if (defaults == null) {
        final lowerName = fallbackName.toLowerCase();
        for (final entry in _defaultOptionsByName.entries) {
          if (entry.key.toLowerCase() == lowerName ||
              lowerName.contains(entry.key.toLowerCase()) ||
              entry.key.toLowerCase().contains(lowerName)) {
            defaults = entry.value;
            debugPrint(
                '✅ Options par défaut trouvées pour "$fallbackName" via variante "${entry.key}"',);
            break;
          }
        }
      }

      if (defaults != null && defaults.isNotEmpty) {
        final cloned = defaults.map((opt) => opt.copyWith()).toList();
        _itemOptions[menuItemId] = cloned;
        debugPrint(
            '✅ ${cloned.length} options par défaut chargées pour $menuItemId',);
        return cloned;
      }
    }

    debugPrint(
        '⚠️ Aucune option trouvée pour $menuItemId (fallback: $fallbackName)',);
    _itemOptions.putIfAbsent(menuItemId, () => []);
    return _itemOptions[menuItemId]!;
  }

  /// Charge les options de personnalisation pour un menu item spécifique
  Future<void> _loadOptionsForMenuItem(String menuItemId) async {
    if (_itemOptions.containsKey(menuItemId) &&
        _itemOptions[menuItemId]!.isNotEmpty) {
      return; // Déjà chargé
    }

    try {
      final item = await eccore.CatalogRepository(apiClient: apiClient)
          .getMenuItem(menuItemId);

      final options = [
        for (final group in item.optionGroups)
          for (final option in group.options)
            if (option.isAvailable) CustomizationOption.fromRemote(option, group),
      ];

      if (options.isNotEmpty) {
        _itemOptions[menuItemId] = options;
        debugPrint(
            '✅ Loaded ${options.length} customization options for menu item $menuItemId',);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Error loading customization options for $menuItemId: $e');
    }
  }

  List<CustomizationOption> getOptionsForMenuItem(
    String menuItemId, {
    String? fallbackName,
  }) {
    return _getOptionsForMenuItem(menuItemId, fallbackName: fallbackName);
  }

  // Get options by category for an item
  Map<String, List<CustomizationOption>> getOptionsByCategory(
    String menuItemId, {
    String? fallbackName,
  }) {
    final allOptions =
        getOptionsForMenuItem(menuItemId, fallbackName: fallbackName);
    final Map<String, List<CustomizationOption>> categorized = {};

    for (final option in allOptions) {
      categorized[option.category] = (categorized[option.category] ?? [])
        ..add(option);
    }

    return categorized;
  }

  // Start customizing an item session
  Future<void> startCustomization(
    String sessionId,
    String menuItemId,
    String menuItemName,
  ) async {
    // S'assurer que le service est initialisé
    if (!_isInitialized) {
      await initialize();
    }

    // Essayer de charger depuis la base de données
    if (_isInitialized) {
      await _loadOptionsForMenuItem(menuItemId);
    }

    final options =
        _getOptionsForMenuItem(menuItemId, fallbackName: menuItemName);

    debugPrint(
        '🎂 Start customization pour $menuItemName ($menuItemId): ${options.length} options disponibles',);

    final Map<String, List<String>> defaultSelections = {};
    final Map<String, int> defaultQuantities = {};

    // Set default selections - pour les catégories single choice, ne garder qu'une seule option par défaut
    final singleChoiceCategories = {
      'shape',
      'size',
      'flavor',
      'tiers',
      'icing',
      'dietary',
    };

    for (final option in options) {
      if (option.isDefault) {
        final category = option.category;

        // Pour les catégories single choice, remplacer l'option précédente si elle existe
        if (singleChoiceCategories.contains(category)) {
          defaultSelections[category] = [option.id];
        } else {
          // Pour les catégories multi-choice, ajouter à la liste
          defaultSelections[category] = (defaultSelections[category] ?? [])
            ..add(option.id);
        }

        defaultQuantities[option.id] = 1;
      }
    }

    debugPrint('🎂 Sélections par défaut: $defaultSelections');

    _currentCustomizations[sessionId] = ItemCustomization(
      itemId: sessionId,
      menuItemId: menuItemId,
      menuItemName: menuItemName,
      selections: defaultSelections,
      quantities: defaultQuantities,
    );

    notifyListeners();
  }

  // Get current customization for a session
  ItemCustomization? getCurrentCustomization(String sessionId) {
    return _currentCustomizations[sessionId];
  }

  // Update selection for an option
  void updateSelection(
      String sessionId, String category, String optionId, bool isSelected,) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return;

    final Map<String, List<String>> newSelections =
        Map.from(customization.selections);

    if (isSelected) {
      newSelections[category] = (newSelections[category] ?? [])..add(optionId);
    } else {
      newSelections[category]?.remove(optionId);
      if (newSelections[category]?.isEmpty == true) {
        newSelections.remove(category);
      }
    }

    _currentCustomizations[sessionId] =
        customization.copyWith(selections: newSelections);
    notifyListeners();
  }

  // Update quantity for an option
  void updateQuantity(String sessionId, String optionId, int quantity) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return;

    final Map<String, int> newQuantities = Map.from(customization.quantities);

    if (quantity <= 0) {
      newQuantities.remove(optionId);
    } else {
      newQuantities[optionId] = quantity;
    }

    _currentCustomizations[sessionId] =
        customization.copyWith(quantities: newQuantities);
    notifyListeners();
  }

  // Update special instructions
  void updateSpecialInstructions(String sessionId, String instructions) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return;

    _currentCustomizations[sessionId] = customization.copyWith(
      specialInstructions: instructions.isEmpty ? null : instructions,
    );
    notifyListeners();
  }

  // Calculate total price modifier for an item
  double calculatePriceModifier(String sessionId) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return 0.0;

    double total = 0.0;

    for (final entry in customization.selections.entries) {
      for (final optionId in entry.value) {
        final quantity = customization.quantities[optionId] ?? 1;
        final option = _findOptionById(optionId);
        if (option != null) {
          total += option.priceModifier * quantity;
        }
      }
    }

    return total;
  }

  // Find option by ID
  CustomizationOption? _findOptionById(String optionId) {
    for (final options in _itemOptions.values) {
      for (final option in options) {
        if (option.id == optionId) {
          return option;
        }
      }
    }
    return null;
  }

  // Clear customization for an item
  void clearCustomization(String sessionId) {
    _currentCustomizations.remove(sessionId);
    notifyListeners();
  }

  // Clear all customizations
  void clearAllCustomizations() {
    _currentCustomizations.clear();
    notifyListeners();
  }

  // Get constraint for a category
  CategoryConstraint getCategoryConstraint(String category) {
    return _categoryConstraints[category] ?? 
        CategoryConstraint(category: category);
  }

  // Validate customization for an item
  Map<String, dynamic> validateCustomization(
      String sessionId, String menuItemName,) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) {
      return {
        'isValid': false,
        'errors': ['Personnalisation introuvable'],
      };
    }

    final List<String> errors = [];
    final List<CustomizationOption> availableOptions = getOptionsForMenuItem(
      customization.menuItemId,
      fallbackName: menuItemName,
    );

    // Group options by category
    final Map<String, List<CustomizationOption>> optionsByCategory = {};
    for (final option in availableOptions) {
      optionsByCategory[option.category] =
          (optionsByCategory[option.category] ?? [])..add(option);
    }

    // ✅ Validation centralisée basée sur _categoryConstraints
    // 1. Vérifier les catégories présentes dans les options disponibles
    for (final category in optionsByCategory.keys) {
      final constraint = getCategoryConstraint(category);
      final selectedOptions = customization.selections[category] ?? [];
      final selectedCount = selectedOptions.length;

      // Vérifier si requis
      if (constraint.isRequired && selectedCount == 0) {
        // Double vérification : est-ce que cette catégorie a vraiment des options disponibles ?
        if (optionsByCategory[category]!.isNotEmpty) {
           errors.add(
              'Veuillez sélectionner une option pour ${_translateCategory(category)}',);
        }
      }

      // Vérifier max selections (pour multi-choice)
      if (!constraint.isSingleChoice && selectedCount > constraint.maxSelections) {
        errors.add(
            'Maximum ${constraint.maxSelections} choix pour ${_translateCategory(category)}',);
      }
      
      // Vérifier min selections (si > 0)
      if (selectedCount < constraint.minSelections) {
         errors.add(
            'Veuillez sélectionner au moins ${constraint.minSelections} option(s) pour ${_translateCategory(category)}',);
      }
    }

    // Validate quantities
    for (final entry in customization.quantities.entries) {
      final option = _findOptionById(entry.key);
      if (option != null && entry.value > option.maxQuantity) {
        errors.add(
            'Quantité maximale dépassée pour ${option.name} (max: ${option.maxQuantity})',);
      }
    }

    return {'isValid': errors.isEmpty, 'errors': errors};
  }

  // Finish customization and return the final customization
  ItemCustomization? finishCustomization(String sessionId) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return null;

    // Calculate final price modifier
    final double totalPriceModifier = calculatePriceModifier(sessionId);

    // Create final customization with calculated price modifier
    final finalCustomization = customization.copyWith(
      totalPriceModifier: totalPriceModifier,
    );

    // Remove from current customizations
    _currentCustomizations.remove(sessionId);
    notifyListeners();

    return finalCustomization;
  }

  // Get customization summary as string
  String getCustomizationSummary(String sessionId) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return '';

    final List<String> summaryParts = [];

    // Add selected options
    for (final entry in customization.selections.entries) {
      final String category = _translateCategory(entry.key);
      final List<String> optionNames = [];

      for (final optionId in entry.value) {
        final option = _findOptionById(optionId);
        if (option != null) {
          final int quantity = customization.quantities[optionId] ?? 1;
          String optionText = option.name;
          if (quantity > 1) {
            optionText += ' (x$quantity)';
          }
          if (option.priceModifier != 0) {
            optionText +=
                ' (${option.priceModifier > 0 ? '+' : ''}${PriceFormatter.format(option.priceModifier)})';
          }
          optionNames.add(optionText);
        }
      }

      if (optionNames.isNotEmpty) {
        summaryParts.add('$category: ${optionNames.join(', ')}');
      }
    }

    // Add special instructions
    if (customization.specialInstructions?.isNotEmpty == true) {
      summaryParts.add('Instructions: ${customization.specialInstructions}');
    }

    return summaryParts.join('\n');
  }

  // Translate category names to French
  String _translateCategory(String category) {
    switch (category) {
      case 'size':
        return 'Taille';
      case 'cooking':
        return 'Cuisson';
      case 'ingredient':
        return 'Ingrédients';
      case 'sauce':
        return 'Sauces';
      case 'extra':
        return 'Extras';
      case 'shape':
        return 'Forme';
      case 'flavor':
        return 'Saveur';
      case 'filling':
        return 'Garniture';
      case 'decoration':
        return 'Décoration';
      case 'color':
        return 'Couleur';
      case 'texture':
        return 'Texture';
      case 'tiers':
        return 'Étages';
      case 'icing':
        return 'Glaçage';
      case 'dietary':
        return 'Préférence alimentaire';
      default:
        return category;
    }
  }

  String translateCategory(String category) => _translateCategory(category);
}
