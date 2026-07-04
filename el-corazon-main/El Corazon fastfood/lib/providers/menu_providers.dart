import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/repositories/menu_repository.dart';
import 'package:elcora_fast/repositories/supabase_menu_repository.dart';

/// Provider du repository de menu
/// Permet d'injecter facilement le repository dans les autres providers
final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return SupabaseMenuRepository();
});

/// Provider pour charger les menu items
final menuItemsProvider = FutureProvider<List<MenuItem>>((ref) async {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.getMenuItems();
});

/// Provider pour charger les menu items par catégorie
final menuItemsByCategoryProvider = FutureProvider.family<List<MenuItem>, String?>((ref, categoryId) async {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.getMenuItems(categoryId: categoryId);
});

/// Provider pour charger les catégories
final menuCategoriesProvider = FutureProvider((ref) async {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.getMenuCategories();
});

/// Provider pour récupérer un menu item par ID
final menuItemProvider = FutureProvider.family<MenuItem?, String>((ref, itemId) async {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.getMenuItemById(itemId);
});

/// Provider pour rechercher des menu items
final searchMenuItemsProvider = FutureProvider.family<List<MenuItem>, String>((ref, query) async {
  final repository = ref.watch(menuRepositoryProvider);
  if (query.isEmpty) {
    return repository.getMenuItems();
  }
  return repository.searchMenuItems(query);
});

/// Provider pour les menu items populaires
final popularMenuItemsProvider = FutureProvider<List<MenuItem>>((ref) async {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.getPopularMenuItems();
});

