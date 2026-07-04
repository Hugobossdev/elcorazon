import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/menu_models.dart';

class MenuService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Upload une image de produit vers Supabase Storage
  ///
  /// [image] : Le fichier image à uploader
  /// [productName] : Le nom du produit (utilisé pour générer le nom de fichier)
  /// [oldImageUrl] : URL de l'ancienne image à supprimer (optionnel)
  ///
  /// Retourne l'URL publique de l'image uploadée, ou null en cas d'erreur
  Future<String?> uploadProductImage(
    XFile image,
    String productName, {
    String? oldImageUrl,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Lire les bytes de l'image
      final bytes = await image.readAsBytes();

      // Vérifier la taille (max 5MB)
      const maxSize = 5 * 1024 * 1024; // 5MB
      if (bytes.length > maxSize) {
        _error = 'L\'image est trop grande (max 5MB)';
        return null;
      }

      // Générer un nom de fichier unique
      final fileExt = image.path.split('.').last.toLowerCase();
      final sanitizedName = productName
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_$sanitizedName.$fileExt';
      final filePath = 'products/$fileName';

      // Upload vers Supabase Storage
      await _supabase.storage.from('product-images').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true, // Permet de remplacer si le fichier existe déjà
            ),
          );

      // Obtenir l'URL publique
      final imageUrl =
          _supabase.storage.from('product-images').getPublicUrl(filePath);

      // Supprimer l'ancienne image si fournie
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        try {
          // Extraire le chemin du fichier depuis l'URL
          final uri = Uri.parse(oldImageUrl);
          final pathSegments = uri.pathSegments;
          if (pathSegments.isNotEmpty) {
            // Le chemin est généralement après '/storage/v1/object/public/product-images/'
            final oldFilePath = pathSegments.last;
            if (oldFilePath != fileName) {
              // Ne supprimer que si c'est un fichier différent
              await _supabase.storage
                  .from('product-images')
                  .remove([oldFilePath]);
            }
          }
        } catch (e) {
          // Ignorer les erreurs de suppression (fichier peut ne plus exister)
          debugPrint('Warning: Could not delete old image: $e');
        }
      }

      debugPrint('✅ Image uploadée avec succès: $imageUrl');
      return imageUrl;
    } catch (e) {
      _error = 'Erreur lors de l\'upload: ${e.toString()}';
      debugPrint('❌ Error uploading product image: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Menu Items ---

  Future<List<MenuItem>> getMenuItems(
    String? categoryId, {
    bool notify = true,
  }) async {
    try {
      if (notify) {
        _isLoading = true;
        _error = null;
        notifyListeners();
      }

      var query = _supabase.from('menu_items').select();

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      final response = await query.order('sort_order', ascending: true);

      return (response as List).map((e) => MenuItem.fromMap(e)).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching menu items: $e');
      return [];
    } finally {
      if (notify) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<MenuItem?> getMenuItem(String id) async {
    try {
      final response = await _supabase
          .from('menu_items')
          .select('*, menu_option_groups(*, menu_options(*))')
          .eq('id', id)
          .single();

      // Sort groups and options manually since nested ordering in select is tricky
      final item = MenuItem.fromMap(response);
      item.optionGroups.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (var group in item.optionGroups) {
        group.options.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }
      return item;
    } catch (e) {
      debugPrint('Error fetching menu item: $e');
      return null;
    }
  }

  Future<MenuItem?> createMenuItem(MenuItem item) async {
    try {
      _isLoading = true;
      notifyListeners();

      final data = item.toMap();
      data.remove('id'); // Let DB generate ID
      data.remove('created_at');
      data.remove('updated_at');
      data.remove(
        'option_groups',
      ); // Handle separately if needed, but usually empty on create

      final response =
          await _supabase.from('menu_items').insert(data).select().single();

      return MenuItem.fromMap(response);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error creating menu item: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateMenuItem(MenuItem item) async {
    try {
      _isLoading = true;
      notifyListeners();

      final data = item.toMap();
      data.remove('id');
      data.remove('created_at');
      data['updated_at'] = DateTime.now().toIso8601String();
      data.remove('option_groups');

      await _supabase.from('menu_items').update(data).eq('id', item.id);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating menu item: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMenuItem(String id) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _supabase.from('menu_items').delete().eq('id', id);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting menu item: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Option Groups ---

  Future<MenuOptionGroup?> createOptionGroup(MenuOptionGroup group) async {
    try {
      final data = group.toMap();
      data.remove('id');
      data.remove('options');

      final response = await _supabase
          .from('menu_option_groups')
          .insert(data)
          .select()
          .single();

      return MenuOptionGroup.fromMap(response);
    } catch (e) {
      debugPrint('Error creating option group: $e');
      return null;
    }
  }

  Future<bool> updateOptionGroup(MenuOptionGroup group) async {
    try {
      final data = group.toMap();
      data.remove('id');
      data.remove('menu_item_id'); // Should not change
      data.remove('options');

      await _supabase
          .from('menu_option_groups')
          .update(data)
          .eq('id', group.id);
      return true;
    } catch (e) {
      debugPrint('Error updating option group: $e');
      return false;
    }
  }

  Future<bool> deleteOptionGroup(String id) async {
    try {
      await _supabase.from('menu_option_groups').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting option group: $e');
      return false;
    }
  }

  // --- Options ---

  Future<MenuOption?> createOption(MenuOption option) async {
    try {
      final data = option.toMap();
      data.remove('id');

      final response =
          await _supabase.from('menu_options').insert(data).select().single();

      return MenuOption.fromMap(response);
    } catch (e) {
      debugPrint('Error creating option: $e');
      return null;
    }
  }

  Future<bool> updateOption(MenuOption option) async {
    try {
      final data = option.toMap();
      data.remove('id');
      data.remove('group_id'); // Should not change

      await _supabase.from('menu_options').update(data).eq('id', option.id);
      return true;
    } catch (e) {
      debugPrint('Error updating option: $e');
      return false;
    }
  }

  Future<bool> deleteOption(String id) async {
    try {
      await _supabase.from('menu_options').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting option: $e');
      return false;
    }
  }
}
