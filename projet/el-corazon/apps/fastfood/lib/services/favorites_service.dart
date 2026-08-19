import 'package:elcora_fast/services/app_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plats mis en favori par le client.
///
/// ## Ce qui était perdu à chaque redémarrage
///
/// Le service enregistrait bien les identifiants des favoris, mais son
/// chargement les lisait pour aussitôt `clear()` la liste sans rien en faire —
/// « pour l'instant, on garde juste les IDs ». Les favoris étaient donc écrits
/// sur le disque et jamais relus : rouvrir l'application les effaçait tous.
///
/// ## Les identifiants font foi, pas les objets
///
/// Ce qu'on retient d'un favori, c'est **l'identifiant du plat**, pas la copie
/// du plat telle qu'elle était le jour du clic. Un prix qui change, une photo
/// remplacée, une description corrigée : le favori doit suivre le catalogue,
/// pas figer un instantané. [favorites] résout donc les identifiants sur le
/// catalogue courant à chaque lecture.
///
/// Cela règle aussi l'ordre d'arrivée : le cœur s'affiche juste dès le
/// démarrage, avant même que le menu ne soit chargé, puisque [isFavorite] ne
/// consulte que les identifiants.
class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  static const String _cle = 'favorites';

  /// Identifiants des plats en favori. La seule chose qui se persiste.
  final Set<String> _identifiants = <String>{};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Favoris **résolus sur le catalogue courant**.
  ///
  /// Un plat retiré de la carte disparaît de la liste sans être oublié : son
  /// identifiant reste en mémoire, et il reparaît si le restaurant le remet.
  List<eccore.MenuItem> get favorites {
    final catalogue = _catalogue();
    return List.unmodifiable(
      catalogue.where((item) => _identifiants.contains(item.id)),
    );
  }

  /// Nombre de favoris **affichables** — ceux que le catalogue sait résoudre.
  /// C'est ce que compte la liste, donc c'est ce qu'il faut annoncer.
  int get count => favorites.length;

  bool get isEmpty => favorites.isEmpty;

  /// Catalogue courant, ou rien s'il n'est pas encore disponible.
  ///
  /// `AppService` lève tant qu'il n'a pas été construit avec son conteneur
  /// Riverpod — au démarrage, et dans un test qui ne monte pas l'application.
  /// Un favori ne vaut pas de faire tomber l'écran qui l'affiche.
  List<eccore.MenuItem> _catalogue() {
    try {
      return AppService().menuItems;
    } catch (e) {
      Journal.trace('FavoritesService : catalogue indisponible ($e)');
      return const [];
    }
  }

  /// Relit les favoris enregistrés.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _identifiants
        ..clear()
        ..addAll(prefs.getStringList(_cle) ?? const []);

      _isInitialized = true;
      Journal.trace('FavoritesService : ${_identifiants.length} favoris relus');
      notifyListeners();
    } catch (e) {
      Journal.trace('FavoritesService : échec de la relecture ($e)');
      // Le service reste utilisable : les favoris du jour fonctionneront,
      // seule la mémoire des sessions précédentes manque.
      _isInitialized = true;
    }
  }

  /// Remet le service à l'état d'avant sa première lecture.
  ///
  /// Le service est un singleton : sans ce point de reprise, deux cas de test
  /// se transmettraient leurs favoris et le second mesurerait l'état laissé
  /// par le premier.
  @visibleForTesting
  void reinitialiser() {
    _identifiants.clear();
    _isInitialized = false;
  }

  Future<void> _enregistrer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_cle, _identifiants.toList());
    } catch (e) {
      Journal.trace('FavoritesService : échec de l\'enregistrement ($e)');
    }
  }

  bool isFavorite(eccore.MenuItem item) => _identifiants.contains(item.id);

  /// Ajoute un plat. Rend `false` s'il y était déjà.
  Future<bool> addToFavorites(eccore.MenuItem item) async {
    if (!_identifiants.add(item.id)) return false;

    notifyListeners();
    await _enregistrer();
    return true;
  }

  /// Retire un plat. Rend `false` s'il n'y était pas.
  Future<bool> removeFromFavorites(eccore.MenuItem item) async {
    if (!_identifiants.remove(item.id)) return false;

    notifyListeners();
    await _enregistrer();
    return true;
  }

  Future<bool> toggleFavorite(eccore.MenuItem item) {
    return isFavorite(item)
        ? removeFromFavorites(item)
        : addToFavorites(item);
  }

  List<eccore.MenuItem> getFavorites() => favorites;

  Future<void> clearFavorites() async {
    if (_identifiants.isEmpty) return;

    _identifiants.clear();
    notifyListeners();
    await _enregistrer();
  }
}
