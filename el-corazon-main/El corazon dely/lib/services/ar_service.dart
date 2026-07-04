import 'package:flutter/foundation.dart';
import '../models/menu_item.dart';

class ARService extends ChangeNotifier {
  static final ARService _instance = ARService._internal();
  factory ARService() => _instance;
  ARService._internal();

  bool _isInitialized = false;
  bool _isARSupported = false;
  bool _isARActive = false;
  String? _currentViewingItem;
  Map<String, String> _ar3DModels = {};

  bool get isInitialized => _isInitialized;
  bool get isARSupported => _isARSupported;
  bool get isARActive => _isARActive;
  String? get currentViewingItem => _currentViewingItem;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check AR support (simulated)
      _isARSupported = await _checkARSupport();

      // Initialize 3D model mappings
      _initializeARModels();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing AR Service: $e');
    }
  }

  Future<bool> _checkARSupport() async {
    // Simulate AR capability check
    await Future.delayed(const Duration(milliseconds: 500));

    // Assume 70% of devices support AR
    return DateTime.now().millisecond % 10 < 7;
  }

  void _initializeARModels() {
    _ar3DModels = {
      'Burger Classic': 'models/burger_classic.glb',
      'Pizza Margherita': 'models/pizza_margherita.glb',
      'Wrap Végétarien': 'models/wrap_vegetarian.glb',
      'Sandwich Poulet': 'models/sandwich_chicken.glb',
      'Salade César': 'models/salad_caesar.glb',
      'Frites Croustillantes': 'models/fries_crispy.glb',
      'Nuggets de Poulet': 'models/nuggets_chicken.glb',
      'Coca-Cola': 'models/coca_cola.glb',
      'Jus d\'Orange': 'models/orange_juice.glb',
      'Mousse au Chocolat': 'models/chocolate_mousse.glb',
    };
  }

  // Launch AR viewer for a menu item
  Future<bool> viewItemInAR(MenuItem item) async {
    if (!_isARSupported || !_isInitialized) {
      return false;
    }

    try {
      _isARActive = true;
      _currentViewingItem = item.name;
      notifyListeners();

      // Simulate AR loading time
      await Future.delayed(const Duration(seconds: 2));

      // In a real implementation, this would launch the AR viewer
      debugPrint('Launching AR view for: ${item.name}');

      return true;
    } catch (e) {
      debugPrint('Error launching AR view: $e');
      _isARActive = false;
      _currentViewingItem = null;
      notifyListeners();
      return false;
    }
  }

  // Close AR viewer
  void closeARViewer() {
    _isARActive = false;
    _currentViewingItem = null;
    notifyListeners();
  }

  // Get AR model info for an item
  Map<String, dynamic> getARModelInfo(String itemName) {
    bool hasModel = _ar3DModels.containsKey(itemName);

    return {
      'hasModel': hasModel,
      'modelPath': hasModel ? _ar3DModels[itemName] : null,
      'isSupported': _isARSupported,
      'features': hasModel ? _getModelFeatures(itemName) : <String>[],
    };
  }

  List<String> _getModelFeatures(String itemName) {
    // Define features for different item types
    if (itemName.contains('Burger') || itemName.contains('Sandwich')) {
      return [
        'Vue 360° interactive',
        'Zoom sur les ingrédients',
        'Animation de construction',
        'Comparaison de tailles',
        'Personnalisation visuelle',
      ];
    } else if (itemName.contains('Pizza')) {
      return [
        'Vue 360° interactive',
        'Zoom sur la garniture',
        'Animation de découpe',
        'Choix de la taille',
        'Ajout d\'ingrédients en temps réel',
      ];
    } else if (itemName.contains('Salade')) {
      return [
        'Vue détaillée des ingrédients',
        'Animation de mélange',
        'Informations nutritionnelles',
        'Personnalisation des légumes',
      ];
    } else {
      return [
        'Vue 360° interactive',
        'Zoom détaillé',
        'Informations produit',
        'Comparaison visuelle',
      ];
    }
  }

  // AR Menu Browser
  List<MenuItem> getARCompatibleItems(List<MenuItem> allItems) {
    return allItems
        .where((item) => _ar3DModels.containsKey(item.name))
        .toList();
  }

  // Virtual customization in AR
  Map<String, dynamic> getCustomizationOptions(String itemName) {
    Map<String, dynamic> options = {
      'size': <String>[],
      'ingredients': <String>[],
      'sauces': <String>[],
      'extras': <String>[],
    };

    if (itemName.contains('Burger')) {
      options['size'] = ['Normal', 'Maxi', 'XXL'];
      options['ingredients'] = [
        'Tomate',
        'Oignon',
        'Salade',
        'Cornichon',
        'Fromage'
      ];
      options['sauces'] = ['Ketchup', 'Mayonnaise', 'Moutarde', 'Sauce BBQ'];
      options['extras'] = ['Bacon', 'Double Steak', 'Avocat'];
    } else if (itemName.contains('Pizza')) {
      options['size'] = ['Petite (25cm)', 'Moyenne (30cm)', 'Grande (35cm)'];
      options['ingredients'] = [
        'Mozzarella',
        'Tomates',
        'Basilic',
        'Champignons',
        'Olives'
      ];
      options['sauces'] = ['Sauce Tomate', 'Crème Fraîche', 'Pesto'];
      options['extras'] = ['Pepperoni', 'Anchois', 'Roquette'];
    }

    return options;
  }

  // AR Shopping experience
  Future<Map<String, dynamic>> simulateARShopping(
      MenuItem item, Map<String, dynamic> customizations) async {
    await Future.delayed(const Duration(seconds: 1));

    double basePrice = item.price;
    double totalPrice = basePrice;
    List<String> modifications = [];

    // Calculate price changes based on customizations
    if (customizations['size'] != null) {
      switch (customizations['size']) {
        case 'Maxi':
        case 'Moyenne (30cm)':
          totalPrice += 1000; // +1000 CFA
          modifications.add('Taille: ${customizations['size']}');
          break;
        case 'XXL':
        case 'Grande (35cm)':
          totalPrice += 2000; // +2000 CFA
          modifications.add('Taille: ${customizations['size']}');
          break;
      }
    }

    if (customizations['extras'] != null) {
      List<String> extras = List<String>.from(customizations['extras']);
      for (String extra in extras) {
        totalPrice += 500; // +500 CFA per extra
        modifications.add('Extra: $extra');
      }
    }

    return {
      'originalPrice': basePrice,
      'finalPrice': totalPrice,
      'modifications': modifications,
      'previewImage': 'ar_preview_${item.id}.jpg',
      'estimatedCalories': _estimateCalories(item, customizations),
    };
  }

  int _estimateCalories(MenuItem item, Map<String, dynamic> customizations) {
    int baseCalories = 400; // Base calories for most items

    if (item.name.contains('Burger')) {
      baseCalories = 550;
    } else if (item.name.contains('Pizza'))
      baseCalories = 300;
    else if (item.name.contains('Salade'))
      baseCalories = 200;
    else if (item.name.contains('Frites')) baseCalories = 350;

    // Add calories for extras
    if (customizations['extras'] != null) {
      List<String> extras = List<String>.from(customizations['extras']);
      baseCalories += extras.length * 100;
    }

    // Adjust for size
    if (customizations['size'] != null) {
      switch (customizations['size']) {
        case 'Maxi':
        case 'Moyenne (30cm)':
          baseCalories = (baseCalories * 1.3).round();
          break;
        case 'XXL':
        case 'Grande (35cm)':
          baseCalories = (baseCalories * 1.6).round();
          break;
      }
    }

    return baseCalories;
  }

  // AR Table Placement feature
  Map<String, dynamic> getTablePlacementInfo() {
    return {
      'isAvailable': _isARSupported && _isARActive,
      'supportedSurfaces': ['Table', 'Comptoir', 'Bureau'],
      'minArea': '30cm x 30cm',
      'instructions': [
        'Pointez votre caméra vers une surface plate',
        'Bougez lentement pour détecter la surface',
        'Touchez l\'écran pour placer votre commande',
        'Utilisez les gestes pour ajuster la position',
      ],
    };
  }

  // Save AR interaction data for analytics
  void logARInteraction(String itemName, String action,
      {Map<String, dynamic>? metadata}) {
    Map<String, dynamic> logData = {
      'timestamp': DateTime.now().toIso8601String(),
      'item': itemName,
      'action': action,
      'metadata': metadata ?? {},
    };

    debugPrint('AR Interaction: $logData');
    // In real implementation, send to analytics service
  }
}
