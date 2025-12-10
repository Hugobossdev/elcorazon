import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/menu_category.dart';
import 'package:elcora_fast/supabase/supabase_config.dart';
import 'package:elcora_fast/repositories/menu_repository.dart';

import 'package:elcora_fast/config/api_config.dart';

/// Implémentation Supabase du MenuRepository
class SupabaseMenuRepository implements MenuRepository {
  // Use a getter to ensure we always get the current client instance
  SupabaseClient get _supabase => SupabaseConfig.client;

  @override
  Future<List<MenuItem>> getMenuItems({String? categoryId}) async {
    try {
      // Debug log to verify Supabase URL being used
      debugPrint(
          '🔍 Fetching menu items using Supabase URL: ${ApiConfig.supabaseUrl}');

      const fieldsString = '''
        id, name, description, price, image_url, category_id,
        is_available, is_popular, is_vegetarian, is_vegan,
        ingredients, calories, preparation_time, sort_order,
        rating, review_count, is_vip_exclusive
      ''';

      var queryBuilder = _supabase.from('menu_items').select('''
            $fieldsString,
            menu_categories!left(id, name, display_name, emoji)
          ''');

      queryBuilder = queryBuilder.eq('is_available', true);

      if (categoryId != null && categoryId.isNotEmpty) {
        queryBuilder = queryBuilder.eq('category_id', categoryId);
      }

      final response = await queryBuilder.order('sort_order');

      final items = (response as List<dynamic>)
          .map((data) => MenuItem.fromMap(data as Map<String, dynamic>))
          .toList();

      return items;
    } catch (e) {
      debugPrint('❌ Error in SupabaseMenuRepository.getMenuItems: $e');
      throw Exception('Erreur lors de la récupération du menu: $e');
    }
  }

  @override
  Future<MenuItem?> getMenuItemById(String id) async {
    try {
      final response = await _supabase.from('menu_items').select('''
            *,
            menu_categories!left(id, name, display_name, emoji)
          ''').eq('id', id).maybeSingle();

      if (response == null) {
        return null;
      }

      return MenuItem.fromMap(response);
    } catch (e) {
      debugPrint('❌ Error in SupabaseMenuRepository.getMenuItemById: $e');
      if (e is PostgrestException && e.code == 'PGRST116') {
        return null; // Item not found
      }
      throw Exception('Erreur lors de la récupération de l\'item: $e');
    }
  }

  @override
  Stream<List<MenuItem>> watchMenuItems({String? categoryId}) {
    // Implémentation basique avec polling
    // Pour une vraie implémentation temps réel, utiliser Supabase Realtime
    return Stream.periodic(const Duration(seconds: 30), (_) => null)
        .asyncMap((_) => getMenuItems(categoryId: categoryId));
  }

  @override
  Future<List<MenuCategory>> getMenuCategories() async {
    try {
      final response = await _supabase
          .from('menu_categories')
          .select(
              'id, name, display_name, emoji, description, sort_order, is_active')
          .eq('is_active', true)
          .order('sort_order');

      final categories = (response as List<dynamic>)
          .map((data) => MenuCategory.fromMap(data as Map<String, dynamic>))
          .toList();

      return categories;
    } catch (e) {
      debugPrint('❌ Error in SupabaseMenuRepository.getMenuCategories: $e');
      throw Exception('Erreur lors de la récupération des catégories: $e');
    }
  }

  @override
  Future<List<MenuItem>> searchMenuItems(String query) async {
    try {
      if (query.isEmpty) {
        return getMenuItems();
      }

      final response = await _supabase
          .from('menu_items')
          .select('''
            *,
            menu_categories!left(id, name, display_name, emoji)
          ''')
          .eq('is_available', true)
          .ilike('name', '%$query%')
          .order('sort_order');

      final items = (response as List<dynamic>)
          .map((data) => MenuItem.fromMap(data as Map<String, dynamic>))
          .toList();

      return items;
    } catch (e) {
      debugPrint('❌ Error in SupabaseMenuRepository.searchMenuItems: $e');
      throw Exception('Erreur lors de la recherche: $e');
    }
  }

  @override
  Future<List<MenuItem>> getPopularMenuItems({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('menu_items')
          .select('''
            *,
            menu_categories!left(id, name, display_name, emoji)
          ''')
          .eq('is_available', true)
          .eq('is_popular', true)
          .order('rating', ascending: false)
          .limit(limit);

      final items = (response as List<dynamic>)
          .map((data) => MenuItem.fromMap(data as Map<String, dynamic>))
          .toList();

      return items;
    } catch (e) {
      debugPrint('❌ Error in SupabaseMenuRepository.getPopularMenuItems: $e');
      throw Exception(
          'Erreur lors de la récupération des items populaires: $e');
    }
  }
}
