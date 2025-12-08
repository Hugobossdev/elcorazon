import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/supabase/supabase_config.dart';

/// Script d'initialisation de la base de données avec des données réelles
class DatabaseInitializer {
  static final SupabaseClient _supabase = SupabaseConfig.client;

  /// Initialise la base de données avec des données d'El Corazón
  static Future<void> initializeDatabase() async {
    try {
      debugPrint('🚀 Initialisation de la base de données El Corazón...');

      // 1. Créer les catégories de menu
      await _createMenuCategories();

      // 2. Créer les items du menu
      await _createMenuItems();

      // 3. Créer les options de personnalisation
      await _createCustomizationOptions();

      // 4. Initialiser les gâteaux personnalisés
      await _initializeCustomCakes();

      debugPrint('✅ Base de données initialisée avec succès !');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation: $e');
      rethrow;
    }
  }

  /// Crée les catégories de menu
  static Future<void> _createMenuCategories() async {
    debugPrint('📋 Création des catégories de menu...');

    final categories = [
      {
        'id': 'burgers',
        'name': 'burgers',
        'display_name': 'Burgers',
        'emoji': '🍔',
        'description': 'Nos délicieux burgers faits maison',
        'sort_order': 1,
        'is_active': true,
      },
      {
        'id': 'pizzas',
        'name': 'pizzas',
        'display_name': 'Pizzas',
        'emoji': '🍕',
        'description': 'Pizzas artisanales au feu de bois',
        'sort_order': 2,
        'is_active': true,
      },
      {
        'id': 'tacos',
        'name': 'tacos',
        'display_name': 'Tacos',
        'emoji': '🌮',
        'description': 'Tacos authentiques mexicains',
        'sort_order': 3,
        'is_active': true,
      },
      {
        'id': 'drinks',
        'name': 'drinks',
        'display_name': 'Boissons',
        'emoji': '🥤',
        'description': 'Boissons fraîches et chaudes',
        'sort_order': 4,
        'is_active': true,
      },
      {
        'id': 'desserts',
        'name': 'desserts',
        'display_name': 'Desserts',
        'emoji': '🍰',
        'description': 'Desserts gourmands',
        'sort_order': 5,
        'is_active': true,
      },
    ];

    for (final category in categories) {
      try {
        await _supabase.from('menu_categories').upsert(category);
        debugPrint('✅ Catégorie créée: ${category['display_name']}');
      } catch (e) {
        debugPrint('⚠️ Catégorie déjà existante: ${category['display_name']}');
      }
    }
  }

  /// Crée les items du menu
  static Future<void> _createMenuItems() async {
    debugPrint('🍽️ Création des items du menu...');

    final menuItems = [
      // BURGERS
      {
        'id': 'burger-classic',
        'name': 'Burger Classique',
        'description': 'Steak haché, salade, tomate, oignon, sauce burger',
        'price': 12.50,
        'category_id': 'burgers',
        'image_url':
            'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400',
        'preparation_time': 15,
        'is_popular': true,
        'is_vegetarian': false,
        'is_vegan': false,
        'is_available': true,
        'sort_order': 1,
        'rating': 4.5,
        'review_count': 128,
      },
      {
        'id': 'burger-bacon',
        'name': 'Burger Bacon',
        'description':
            'Steak haché, bacon croustillant, cheddar, salade, sauce BBQ',
        'price': 14.90,
        'category_id': 'burgers',
        'image_url':
            'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=400',
        'preparation_time': 18,
        'is_popular': true,
        'is_vegetarian': false,
        'is_vegan': false,
        'is_available': true,
        'sort_order': 2,
        'rating': 4.7,
        'review_count': 95,
      },
      {
        'id': 'burger-veggie',
        'name': 'Burger Végétarien',
        'description': 'Steak végétal, avocat, tomate, salade, sauce tahini',
        'price': 13.50,
        'category_id': 'burgers',
        'image_url':
            'https://images.unsplash.com/photo-1525059696034-4967a729002e?w=400',
        'preparation_time': 12,
        'is_popular': false,
        'is_vegetarian': true,
        'is_vegan': true,
        'is_available': true,
        'sort_order': 3,
        'rating': 4.2,
        'review_count': 67,
      },

      // PIZZAS
      {
        'id': 'pizza-margherita',
        'name': 'Pizza Margherita',
        'description': 'Tomate, mozzarella, basilic frais',
        'price': 16.90,
        'category_id': 'pizzas',
        'image_url':
            'https://images.unsplash.com/photo-1604382354936-07c5d9983bd3?w=400',
        'preparation_time': 20,
        'is_popular': true,
        'is_vegetarian': true,
        'is_vegan': false,
        'is_available': true,
        'sort_order': 1,
        'rating': 4.6,
        'review_count': 156,
      },
      {
        'id': 'pizza-pepperoni',
        'name': 'Pizza Pepperoni',
        'description': 'Tomate, mozzarella, pepperoni, origan',
        'price': 18.50,
        'category_id': 'pizzas',
        'image_url':
            'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=400',
        'preparation_time': 22,
        'is_popular': true,
        'is_vegetarian': false,
        'is_vegan': false,
        'is_available': true,
        'sort_order': 2,
        'rating': 4.8,
        'review_count': 203,
      },
      {
        'id': 'pizza-4-fromages',
        'name': 'Pizza 4 Fromages',
        'description': 'Mozzarella, gorgonzola, parmesan, chèvre',
        'price': 19.90,
        'category_id': 'pizzas',
        'image_url':
            'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400',
        'preparation_time': 25,
        'is_popular': false,
        'is_vegetarian': true,
        'is_vegan': false,
        'is_available': true,
        'sort_order': 3,
        'rating': 4.4,
        'review_count': 89,
      },

      // TACOS
      {
        'id': 'tacos-poulet',
        'name': 'Tacos Poulet',
        'description': 'Poulet grillé, salade, tomate, sauce mexicaine',
        'price': 11.90,
        'category_id': 'tacos',
        'image_url':
            'https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=400',
        'preparation_time': 10,
        'is_popular': true,
        'is_vegetarian': false,
        'is_vegan': false,
        'is_available': true,
        'sort_order': 1,
        'rating': 4.3,
        'review_count': 112,
      },
      {
        'id': 'tacos-boeuf',
        'name': 'Tacos Boeuf',
        'description': 'Boeuf mariné, avocat, oignon rouge, coriandre',
        'price': 13.50,
        'category_id': 'tacos',
        'image_url':
            'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=400',
        'preparation_time': 12,
        'is_popular': false,
        'is_vegetarian': false,
        'is_vegan': false,
        'is_available': true,
        'sort_order': 2,
        'rating': 4.5,
        'review_count': 78,
      },

      // BOISSONS
      {
        'id': 'coca-cola',
        'name': 'Coca-Cola',
        'description': 'Boisson gazeuse 33cl',
        'price': 3.50,
        'category_id': 'drinks',
        'image_url':
            'https://images.unsplash.com/photo-1581636625402-29b2a704ef13?w=400',
        'preparation_time': 2,
        'is_popular': true,
        'is_vegetarian': true,
        'is_vegan': true,
        'is_available': true,
        'sort_order': 1,
        'rating': 4.0,
        'review_count': 45,
      },
      {
        'id': 'jus-orange',
        'name': 'Jus d\'Orange',
        'description': 'Jus d\'orange frais pressé',
        'price': 4.50,
        'category_id': 'drinks',
        'image_url':
            'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=400',
        'preparation_time': 3,
        'is_popular': false,
        'is_vegetarian': true,
        'is_vegan': true,
        'is_available': true,
        'sort_order': 2,
        'rating': 4.2,
        'review_count': 32,
      },

      // DESSERTS
      {
        'id': 'tiramisu',
        'name': 'Tiramisu',
        'description': 'Dessert italien au café et mascarpone',
        'price': 6.90,
        'category_id': 'desserts',
        'image_url':
            'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=400',
        'preparation_time': 5,
        'is_popular': true,
        'is_vegetarian': true,
        'is_vegan': false,
        'is_available': true,
        'sort_order': 1,
        'rating': 4.7,
        'review_count': 89,
      },
      {
        'id': 'brownie-chocolat',
        'name': 'Brownie Chocolat',
        'description': 'Brownie au chocolat noir avec glace vanille',
        'price': 5.50,
        'category_id': 'desserts',
        'image_url':
            'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=400',
        'preparation_time': 4,
        'is_popular': false,
        'is_vegetarian': true,
        'is_vegan': false,
        'is_available': true,
        'sort_order': 2,
        'rating': 4.4,
        'review_count': 56,
      },
    ];

    for (final item in menuItems) {
      try {
        await _supabase.from('menu_items').upsert(item);
        debugPrint('✅ Item créé: ${item['name']}');
      } catch (e) {
        debugPrint('⚠️ Item déjà existant: ${item['name']}');
      }
    }
  }

  /// Crée les options de personnalisation
  static Future<void> _createCustomizationOptions() async {
    debugPrint('⚙️ Création des options de personnalisation...');

    final customizations = [
      {
        'id': 'sauce-burger',
        'name': 'Sauce Burger',
        'display_name': 'Sauce',
        'type': 'single_choice',
        'is_required': false,
        'is_active': true,
        'sort_order': 1,
      },
      {
        'id': 'sauce-pizza',
        'name': 'Sauce Pizza',
        'display_name': 'Base',
        'type': 'single_choice',
        'is_required': true,
        'is_active': true,
        'sort_order': 1,
      },
      {
        'id': 'taille-pizza',
        'name': 'Taille Pizza',
        'display_name': 'Taille',
        'type': 'single_choice',
        'is_required': true,
        'is_active': true,
        'sort_order': 2,
      },
    ];

    for (final customization in customizations) {
      try {
        await _supabase.from('customization_options').upsert(customization);
        debugPrint('✅ Option créée: ${customization['display_name']}');
      } catch (e) {
        debugPrint('⚠️ Option déjà existante: ${customization['display_name']}');
      }
    }
  }

  /// Vérifie si la base de données est initialisée
  static Future<bool> isDatabaseInitialized() async {
    try {
      await _supabase.from('menu_categories').select('count').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Initialise les gâteaux personnalisés et leurs options
  static Future<void> _initializeCustomCakes() async {
    debugPrint('🎂 Initialisation des gâteaux personnalisés...');

    try {
      // 1. S'assurer que la catégorie desserts existe
      await _supabase.from('menu_categories').upsert({
        'id': 'desserts',
        'name': 'desserts',
        'display_name': 'Desserts',
        'emoji': '🍰',
        'description': 'Desserts gourmands et sucrés',
        'sort_order': 5,
        'is_active': true,
      });

      // 2. Créer l'item "Gâteau personnalisé"
      final dessertsCategory = await _supabase
          .from('menu_categories')
          .select('id')
          .eq('name', 'desserts')
          .single();

      final customCakeId = 'cake-custom-personnalise';
      await _supabase.from('menu_items').upsert({
        'id': customCakeId,
        'name': 'Gâteau personnalisé',
        'description':
            'Composez votre gâteau idéal : forme, taille, saveur et décor. Créez une pièce unique sur-mesure pour toutes vos occasions spéciales.',
        'price': 20000.0,
        'category_id': dessertsCategory['id'],
        'image_url':
            'https://images.unsplash.com/photo-1542281286-9e0a16bb7366?auto=format&fit=crop&w=600&q=80',
        'is_popular': true,
        'is_available': true,
        'preparation_time': 90,
        'sort_order': 999,
        'is_vegetarian': false,
        'is_vegan': false,
      });

      debugPrint('✅ Item "Gâteau personnalisé" créé');

      // 3. Créer les options de personnalisation pour les gâteaux
      await _createCakeCustomizationOptions(customCakeId);

      debugPrint('✅ Gâteaux personnalisés initialisés avec succès');
    } catch (e) {
      debugPrint('⚠️ Erreur lors de l\'initialisation des gâteaux: $e');
      // Ne pas bloquer l'initialisation si les gâteaux échouent
    }
  }

  /// Crée toutes les options de personnalisation pour les gâteaux
  static Future<void> _createCakeCustomizationOptions(
      String customCakeId) async {
    // Formes
    final shapes = [
      {'id': 'cake-shape-round', 'name': 'Rond', 'price_modifier': 0.0, 'is_default': true, 'sort_order': 1},
      {'id': 'cake-shape-square', 'name': 'Carré', 'price_modifier': 2000.0, 'is_default': false, 'sort_order': 2},
      {'id': 'cake-shape-heart', 'name': 'Cœur', 'price_modifier': 3500.0, 'is_default': false, 'sort_order': 3},
      {'id': 'cake-shape-rectangle', 'name': 'Rectangle', 'price_modifier': 2500.0, 'is_default': false, 'sort_order': 4},
    ];

    // Tailles
    final sizes = [
      {'id': 'cake-size-small', 'name': 'Petit (6 personnes)', 'price_modifier': 0.0, 'is_default': true, 'sort_order': 1},
      {'id': 'cake-size-medium', 'name': 'Moyen (10 personnes)', 'price_modifier': 6000.0, 'is_default': false, 'sort_order': 2},
      {'id': 'cake-size-large', 'name': 'Grand (16 personnes)', 'price_modifier': 11000.0, 'is_default': false, 'sort_order': 3},
    ];

    // Saveurs
    final flavors = [
      {'id': 'cake-flavor-vanilla', 'name': 'Vanille', 'price_modifier': 0.0, 'is_default': true, 'sort_order': 1},
      {'id': 'cake-flavor-chocolate', 'name': 'Chocolat', 'price_modifier': 2000.0, 'is_default': false, 'sort_order': 2},
      {'id': 'cake-flavor-strawberry', 'name': 'Fraise', 'price_modifier': 2500.0, 'is_default': false, 'sort_order': 3},
      {'id': 'cake-flavor-mix', 'name': 'Vanille & Chocolat', 'price_modifier': 3000.0, 'is_default': false, 'sort_order': 4},
    ];

    // Étages
    final tiers = [
      {'id': 'cake-tier-1', 'name': '1 étage (standard)', 'price_modifier': 0.0, 'is_default': true, 'sort_order': 1},
      {'id': 'cake-tier-2', 'name': '2 étages (+12 parts)', 'price_modifier': 7000.0, 'is_default': false, 'sort_order': 2},
      {'id': 'cake-tier-3', 'name': '3 étages (+20 parts)', 'price_modifier': 12000.0, 'is_default': false, 'sort_order': 3},
    ];

    // Glaçages
    final icings = [
      {'id': 'cake-icing-buttercream', 'name': 'Crème au beurre vanille', 'price_modifier': 0.0, 'is_default': true, 'sort_order': 1},
      {'id': 'cake-icing-creamcheese', 'name': 'Cream cheese citron', 'price_modifier': 2500.0, 'is_default': false, 'sort_order': 2},
      {'id': 'cake-icing-ganache', 'name': 'Ganache chocolat noir', 'price_modifier': 3000.0, 'is_default': false, 'sort_order': 3},
    ];

    // Régimes
    final dietary = [
      {'id': 'cake-diet-standard', 'name': 'Classique', 'price_modifier': 0.0, 'is_default': true, 'sort_order': 1},
      {'id': 'cake-diet-no-nuts', 'name': 'Sans fruits à coque', 'price_modifier': 1500.0, 'is_default': false, 'sort_order': 2},
      {'id': 'cake-diet-gluten-free', 'name': 'Sans gluten', 'price_modifier': 3500.0, 'is_default': false, 'sort_order': 3},
      {'id': 'cake-diet-lactose-free', 'name': 'Sans lactose', 'price_modifier': 3000.0, 'is_default': false, 'sort_order': 4},
    ];

    // Garnitures (multi-sélection max 2)
    final fillings = [
      {'id': 'cake-filling-cream', 'name': 'Crème fouettée', 'price_modifier': 1500.0, 'is_default': false, 'max_quantity': 2, 'sort_order': 1},
      {'id': 'cake-filling-ganache', 'name': 'Ganache chocolat', 'price_modifier': 2000.0, 'is_default': false, 'max_quantity': 2, 'sort_order': 2},
      {'id': 'cake-filling-fruits', 'name': 'Compotée de fruits rouges', 'price_modifier': 2500.0, 'is_default': false, 'max_quantity': 2, 'sort_order': 3},
    ];

    // Décorations (multi-sélection max 3)
    final decorations = [
      {'id': 'cake-deco-fruits', 'name': 'Fruits frais', 'price_modifier': 2000.0, 'is_default': false, 'max_quantity': 3, 'sort_order': 1},
      {'id': 'cake-deco-chocolate', 'name': 'Copeaux de chocolat', 'price_modifier': 1500.0, 'is_default': false, 'max_quantity': 3, 'sort_order': 2},
      {'id': 'cake-deco-macarons', 'name': 'Macarons assortis', 'price_modifier': 3000.0, 'is_default': false, 'max_quantity': 3, 'sort_order': 3},
      {'id': 'cake-deco-photo', 'name': 'Photo comestible', 'price_modifier': 4000.0, 'is_default': false, 'max_quantity': 1, 'sort_order': 4},
      {'id': 'cake-deco-message', 'name': 'Message en sucre', 'price_modifier': 1000.0, 'is_default': false, 'max_quantity': 1, 'sort_order': 5},
    ];

    // Créer toutes les options
    final allOptions = [
      ...shapes.map((s) => {...s, 'category': 'shape', 'max_quantity': 1, 'description': 'Forme du gâteau'}),
      ...sizes.map((s) => {...s, 'category': 'size', 'max_quantity': 1, 'description': 'Taille du gâteau'}),
      ...flavors.map((f) => {...f, 'category': 'flavor', 'max_quantity': 1, 'description': 'Saveur du gâteau'}),
      ...tiers.map((t) => {...t, 'category': 'tiers', 'max_quantity': 1, 'description': 'Nombre d\'étages'}),
      ...icings.map((i) => {...i, 'category': 'icing', 'max_quantity': 1, 'description': 'Type de glaçage'}),
      ...dietary.map((d) => {...d, 'category': 'dietary', 'max_quantity': 1, 'description': 'Options diététiques'}),
      ...fillings.map((f) => {...f, 'category': 'filling', 'description': 'Garniture entre les couches'}),
      ...decorations.map((d) => {...d, 'category': 'decoration', 'description': 'Décoration du gâteau'}),
    ];

    // Insérer les options
    for (final option in allOptions) {
      try {
        await _supabase.from('customization_options').upsert({
          'id': option['id'],
          'name': option['name'],
          'category': option['category'],
          'price_modifier': option['price_modifier'],
          'is_default': option['is_default'] ?? false,
          'max_quantity': option['max_quantity'] ?? 1,
          'description': option['description'],
          'is_active': true,
        });
      } catch (e) {
        debugPrint('⚠️ Erreur création option ${option['id']}: $e');
      }
    }

    // Lier les options au gâteau personnalisé
    int sortOrder = 1;
    final categories = ['shape', 'size', 'flavor', 'tiers', 'icing', 'dietary', 'filling', 'decoration'];

    for (final category in categories) {
      final categoryOptions = allOptions.where((o) => o['category'] == category).toList();
      
      for (final option in categoryOptions) {
        try {
          await _supabase.from('menu_item_customizations').upsert({
            'menu_item_id': customCakeId,
            'customization_option_id': option['id'],
            'is_required': (option['is_default'] == true && category != 'filling' && category != 'decoration'),
            'sort_order': sortOrder++,
          });
        } catch (e) {
          debugPrint('⚠️ Erreur liaison option ${option['id']}: $e');
        }
      }
    }

    debugPrint('✅ Options de personnalisation des gâteaux créées');
  }

  /// Réinitialise complètement la base de données
  static Future<void> resetDatabase() async {
    try {
      debugPrint('🔄 Réinitialisation de la base de données...');

      // Supprimer toutes les données (attention: destructif!)
      await _supabase.from('menu_item_customizations').delete().neq('id', '');
      await _supabase.from('customization_options').delete().neq('id', '');
      await _supabase.from('menu_items').delete().neq('id', '');
      await _supabase.from('menu_categories').delete().neq('id', '');

      debugPrint('✅ Base de données réinitialisée');

      // Réinitialiser avec les données par défaut
      await initializeDatabase();
    } catch (e) {
      debugPrint('❌ Erreur lors de la réinitialisation: $e');
      rethrow;
    }
  }
}
