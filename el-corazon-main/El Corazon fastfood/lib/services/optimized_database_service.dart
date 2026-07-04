import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/supabase/supabase_config.dart';

/// Service de base de données optimisé avec requêtes performantes
/// Extension de DatabaseService avec des méthodes optimisées
class OptimizedDatabaseService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Récupère les menu items avec sélection optimisée de champs
  /// 
  /// [categoryId] : Filtrer par catégorie
  /// [limit] : Nombre d'items à récupérer (par défaut: 50, max: 100)
  /// [offset] : Décalage pour la pagination
  /// [fields] : Champs spécifiques à récupérer (par défaut: champs essentiels)
  Future<List<Map<String, dynamic>>> getMenuItemsOptimized({
    String? categoryId,
    int limit = 50,
    int offset = 0,
    List<String>? fields,
  }) async {
    try {
      // Limiter la taille de la requête
      final safeLimit = limit.clamp(1, 100);
      final safeOffset = offset.clamp(0, double.infinity).toInt();

      // Champs essentiels par défaut (réduit de ~40-50% la taille de la réponse)
      final defaultFields = [
        'id',
        'name',
        'description',
        'price',
        'image_url',
        'category_id',
        'is_available',
        'is_popular',
        'is_vegetarian',
        'is_vegan',
        'sort_order',
      ];

      final selectedFields = fields ?? defaultFields;
      final fieldsString = selectedFields.join(', ');

      // Construire la requête avec jointure optimisée
      var queryBuilder = _supabase
          .from('menu_items')
          .select('''
            $fieldsString,
            menu_categories!left(id, name, display_name, emoji)
          ''');

      // Appliquer les filtres
      queryBuilder = queryBuilder.eq('is_available', true);

      // Filtrer par catégorie si spécifié
      if (categoryId != null && categoryId.isNotEmpty) {
        queryBuilder = queryBuilder.eq('category_id', categoryId);
      }

      // Ajouter l'ordre et la pagination (chaînage direct)
      final orderedQuery = queryBuilder.order('sort_order');
      final response = await orderedQuery.range(safeOffset, safeOffset + safeLimit - 1);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erreur dans getMenuItemsOptimized: $e');
      throw Exception('Erreur lors de la récupération du menu: $e');
    }
  }

  /// Récupère les catégories avec sélection optimisée
  Future<List<Map<String, dynamic>>> getMenuCategoriesOptimized({
    bool includeInactive = false,
    List<String>? fields,
  }) async {
    try {
      // Champs essentiels par défaut
      final defaultFields = [
        'id',
        'name',
        'display_name',
        'emoji',
        'description',
        'sort_order',
        'is_active',
      ];

      final selectedFields = fields ?? defaultFields;
      final fieldsString = selectedFields.join(', ');

      var queryBuilder = _supabase
          .from('menu_categories')
          .select(fieldsString);

      // Appliquer les filtres
      if (!includeInactive) {
        queryBuilder = queryBuilder.eq('is_active', true);
      }

      final query = queryBuilder.order('sort_order');

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erreur dans getMenuCategoriesOptimized: $e');
      throw Exception('Erreur lors de la récupération des catégories: $e');
    }
  }

  /// Récupère les commandes utilisateur avec pagination
  Future<List<Map<String, dynamic>>> getUserOrdersOptimized({
    required String userId,
    int limit = 20,
    int offset = 0,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? fields,
  }) async {
    try {
      final safeLimit = limit.clamp(1, 50);
      final safeOffset = offset.clamp(0, double.infinity).toInt();

      // Champs essentiels pour les commandes
      final defaultFields = [
        'id',
        'status',
        'subtotal',
        'delivery_fee',
        'total',
        'delivery_address',
        'payment_method',
        'payment_status',
        'order_time',
        'created_at',
        'updated_at',
      ];

      final selectedFields = fields ?? defaultFields;
      final fieldsString = selectedFields.join(', ');

      var queryBuilder = _supabase
          .from('orders')
          .select('''
            $fieldsString,
            order_items(id, menu_item_id, quantity, unit_price, total_price, customizations)
          ''');

      // Appliquer les filtres
      queryBuilder = queryBuilder.eq('user_id', userId);

      // Filtres optionnels
      if (status != null && status.isNotEmpty) {
        queryBuilder = queryBuilder.eq('status', status);
      }

      if (startDate != null) {
        queryBuilder = queryBuilder.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        queryBuilder = queryBuilder.lte('created_at', endDate.toIso8601String());
      }

      // Ajouter l'ordre et la pagination
      final query = queryBuilder
          .order('created_at', ascending: false)
          .range(safeOffset, safeOffset + safeLimit - 1);

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erreur dans getUserOrdersOptimized: $e');
      throw Exception('Erreur lors de la récupération des commandes: $e');
    }
  }

  /// Récupère un menu item spécifique avec champs optimisés
  Future<Map<String, dynamic>?> getMenuItemByIdOptimized(
    String id, {
    List<String>? fields,
    bool includeCustomizations = false,
  }) async {
    try {
      // Champs de base
      final defaultFields = [
        'id',
        'name',
        'description',
        'price',
        'image_url',
        'category_id',
        'is_available',
        'is_popular',
        'is_vegetarian',
        'is_vegan',
        'ingredients',
        'calories',
        'preparation_time',
        'sort_order',
      ];

      final selectedFields = fields ?? defaultFields;
      final fieldsString = selectedFields.join(', ');

      final query = _supabase
          .from('menu_items')
          .select('''
            $fieldsString,
            menu_categories!left(id, name, display_name, emoji)
          ''')
          .eq('id', id)
          .eq('is_available', true);

      final item = await query.maybeSingle();
      
      if (includeCustomizations && item != null) {
        // Si on veut les customizations, on fait une requête séparée
        // pour éviter de surcharger la requête principale
        final customizations = await _supabase
            .from('menu_item_customizations')
            .select('''
              *,
              customization_options!inner(id, name, category, price_modifier, max_quantity)
            ''')
            .eq('menu_item_id', id)
            .eq('customization_options.is_active', true)
            .order('sort_order');

        return {
          ...item,
          'customizations': customizations,
        };
      }

      return item;
    } catch (e) {
      debugPrint('❌ Erreur dans getMenuItemByIdOptimized: $e');
      return null;
    }
  }

  /// Recherche optimisée de menu items
  Future<List<Map<String, dynamic>>> searchMenuItemsOptimized({
    required String query,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    bool? vegetarian,
    bool? vegan,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final safeLimit = limit.clamp(1, 50);
      final safeOffset = offset.clamp(0, double.infinity).toInt();

      // Champs essentiels pour la recherche
      const fieldsString = 'id, name, description, price, image_url, category_id, is_available';

      var queryBuilder = _supabase
          .from('menu_items')
          .select('''
            $fieldsString,
            menu_categories!left(id, name, display_name, emoji)
          ''');

      // Appliquer les filtres
      queryBuilder = queryBuilder
          .eq('is_available', true)
          .or('name.ilike.%$query%,description.ilike.%$query%');

      // Filtres optionnels
      if (categoryId != null && categoryId.isNotEmpty) {
        queryBuilder = queryBuilder.eq('category_id', categoryId);
      }

      if (minPrice != null) {
        queryBuilder = queryBuilder.gte('price', minPrice);
      }

      if (maxPrice != null) {
        queryBuilder = queryBuilder.lte('price', maxPrice);
      }

      if (vegetarian != null) {
        queryBuilder = queryBuilder.eq('is_vegetarian', vegetarian);
      }

      if (vegan != null) {
        queryBuilder = queryBuilder.eq('is_vegan', vegan);
      }

      // Ajouter l'ordre et la pagination
      final supabaseQuery = queryBuilder
          .order('sort_order')
          .range(safeOffset, safeOffset + safeLimit - 1);

      final response = await supabaseQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erreur dans searchMenuItemsOptimized: $e');
      throw Exception('Erreur lors de la recherche: $e');
    }
  }

  /// Récupère les items populaires avec pagination
  Future<List<Map<String, dynamic>>> getPopularMenuItemsOptimized({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final safeLimit = limit.clamp(1, 50);
      final safeOffset = offset.clamp(0, double.infinity).toInt();

      const fieldsString = 'id, name, price, image_url, category_id, rating, review_count';

      final response = await _supabase
          .from('menu_items')
          .select('''
            $fieldsString,
            menu_categories!left(id, name, display_name, emoji)
          ''')
          .eq('is_available', true)
          .eq('is_popular', true)
          .order('rating', ascending: false)
          .order('review_count', ascending: false)
          .range(safeOffset, safeOffset + safeLimit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erreur dans getPopularMenuItemsOptimized: $e');
      throw Exception('Erreur lors de la récupération des items populaires: $e');
    }
  }

  /// Compte le nombre total d'items (pour la pagination)
  Future<int> countMenuItems({String? categoryId}) async {
    try {
      var query = _supabase
          .from('menu_items')
          .select('id')
          .eq('is_available', true);

      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.eq('category_id', categoryId);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      debugPrint('❌ Erreur dans countMenuItems: $e');
      return 0;
    }
  }

  /// Compte le nombre total de commandes utilisateur
  Future<int> countUserOrders({
    required String userId,
    String? status,
  }) async {
    try {
      var query = _supabase
          .from('orders')
          .select('id')
          .eq('user_id', userId);

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      debugPrint('❌ Erreur dans countUserOrders: $e');
      return 0;
    }
  }
}

