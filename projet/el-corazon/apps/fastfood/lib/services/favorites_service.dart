import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  final List<eccore.MenuItem> _favorites = [];
  bool _isInitialized = false;

  List<eccore.MenuItem> get favorites => List.unmodifiable(_favorites);
  int get count => _favorites.length;
  bool get isEmpty => _favorites.isEmpty;
  bool get isInitialized => _isInitialized;

  /// Initialiser le service de favoris
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadFavoritesFromStorage();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      Journal.trace('Error initializing FavoritesService: $e');
    }
  }

  /// Charger les favoris depuis le stockage
  Future<void> _loadFavoritesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoriteIds = prefs.getStringList('favorites') ?? [];

      // Convertir les IDs en MenuItems
      // Pour l'instant, on garde juste les IDs
      _favorites.clear();
      Journal.trace('Loaded ${favoriteIds.length} favorites from storage');
    } catch (e) {
      Journal.trace('Error loading favorites from storage: $e');
    }
  }

  /// Sauvegarder les favoris dans le stockage
  Future<void> _saveFavoritesToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoriteIds = _favorites.map((item) => item.id).toList();
      await prefs.setStringList('favorites', favoriteIds);
      Journal.trace('Saved ${favoriteIds.length} favorites to storage');
    } catch (e) {
      Journal.trace('Error saving favorites to storage: $e');
    }
  }

  /// Vérifier si un produit est en favori
  bool isFavorite(eccore.MenuItem item) {
    return _favorites.any((favorite) => favorite.id == item.id);
  }

  /// Ajouter un produit aux favoris
  Future<bool> addToFavorites(eccore.MenuItem item) async {
    try {
      if (!isFavorite(item)) {
        _favorites.add(item);
        await _saveFavoritesToStorage();
        notifyListeners();
        Journal.trace('Added ${item.name} to favorites');
        return true;
      }
      return false;
    } catch (e) {
      Journal.trace('Error adding to favorites: $e');
      return false;
    }
  }

  /// Retirer un produit des favoris
  Future<bool> removeFromFavorites(eccore.MenuItem item) async {
    try {
      final initialLength = _favorites.length;
      _favorites.removeWhere((favorite) => favorite.id == item.id);
      final removed = initialLength > _favorites.length;
      
      if (removed) {
        await _saveFavoritesToStorage();
        notifyListeners();
        Journal.trace('Removed ${item.name} from favorites');
        return true;
      }
      return false;
    } catch (e) {
      Journal.trace('Error removing from favorites: $e');
      return false;
    }
  }

  /// Basculer l'état favori d'un produit
  Future<bool> toggleFavorite(eccore.MenuItem item) async {
    if (isFavorite(item)) {
      return await removeFromFavorites(item);
    } else {
      return await addToFavorites(item);
    }
  }

  /// Récupérer tous les favoris
  List<eccore.MenuItem> getFavorites() {
    return List.unmodifiable(_favorites);
  }

  /// Supprimer tous les favoris
  Future<void> clearFavorites() async {
    _favorites.clear();
    await _saveFavoritesToStorage();
    notifyListeners();
    Journal.trace('Cleared all favorites');
  }

  /// Mettre à jour un produit dans les favoris
  Future<void> updateFavorite(eccore.MenuItem item) async {
    final index = _favorites.indexWhere((favorite) => favorite.id == item.id);
    if (index != -1) {
      _favorites[index] = item;
      await _saveFavoritesToStorage();
      notifyListeners();
    }
  }
}

