import 'package:elcora_fast/services/favorites_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favoris — ce qui doit survivre à la fermeture de l'application.
///
/// Le service enregistrait les identifiants puis, à la relecture, vidait la
/// liste sans jamais s'en servir. Les favoris étaient donc écrits sur le disque
/// et perdus au redémarrage suivant : le client rouvrait l'application devant
/// une liste vide, sans que rien ne signale d'erreur.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  eccore.MenuItem plat(String identifiant) {
    return eccore.MenuItem(
      id: identifiant,
      restaurantSlug: 'el-corazon',
      categorySlug: 'grillades',
      categoryName: 'Grillades',
      name: 'Plat $identifiant',
      slug: 'plat-$identifiant',
      description: '',
      image: null,
      price: const eccore.Money(amountMinor: 4500, currency: 'XOF'),
      preparationMinutes: 20,
      allergens: const [],
      dietaryTags: const [],
      isAvailable: true,
      isPopular: false,
      vipExclusive: false,
      ratingAverage: 0,
      ratingCount: 0,
      sortOrder: 1,
    );
  }

  setUp(() => FavoritesService().reinitialiser());

  group('Mémoire des favoris', () {
    test('les favoris enregistrés sont relus au démarrage', () async {
      SharedPreferences.setMockInitialValues({
        'favorites': ['poulet-braise', 'tilapia'],
      });

      final service = FavoritesService();
      await service.initialize();

      expect(service.isFavorite(plat('poulet-braise')), isTrue);
      expect(service.isFavorite(plat('tilapia')), isTrue);
      expect(service.isFavorite(plat('alloco')), isFalse);
    });

    test('un démarrage sans favori enregistré n\'en invente aucun', () async {
      SharedPreferences.setMockInitialValues({});

      final service = FavoritesService();
      await service.initialize();

      expect(service.isFavorite(plat('poulet-braise')), isFalse);
    });

    test('un favori ajouté est écrit sur le disque', () async {
      SharedPreferences.setMockInitialValues({});
      final service = FavoritesService();
      await service.initialize();

      await service.addToFavorites(plat('poulet-braise'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('favorites'), ['poulet-braise']);
    });

    test('un favori retiré disparaît du disque', () async {
      SharedPreferences.setMockInitialValues({
        'favorites': ['poulet-braise', 'tilapia'],
      });
      final service = FavoritesService();
      await service.initialize();

      await service.removeFromFavorites(plat('poulet-braise'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('favorites'), ['tilapia']);
    });
  });

  group('Bascule', () {
    test('basculer deux fois ramène à l\'état de départ', () async {
      SharedPreferences.setMockInitialValues({});
      final service = FavoritesService();
      await service.initialize();

      final article = plat('poulet-braise');
      await service.toggleFavorite(article);
      expect(service.isFavorite(article), isTrue);

      await service.toggleFavorite(article);
      expect(service.isFavorite(article), isFalse);
    });

    test('ajouter deux fois le même plat ne le compte qu\'une fois', () async {
      SharedPreferences.setMockInitialValues({});
      final service = FavoritesService();
      await service.initialize();

      final article = plat('poulet-braise');
      expect(await service.addToFavorites(article), isTrue);
      // Le second ajout rend `false` : rien n'a changé, et l'appelant peut
      // s'en servir pour ne pas afficher deux fois « ajouté aux favoris ».
      expect(await service.addToFavorites(article), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('favorites'), ['poulet-braise']);
    });

    test('retirer un plat absent ne fait rien et le dit', () async {
      SharedPreferences.setMockInitialValues({});
      final service = FavoritesService();
      await service.initialize();

      expect(await service.removeFromFavorites(plat('inconnu')), isFalse);
    });
  });

  group('Résolution sur le catalogue', () {
    test('sans catalogue chargé, la liste est vide mais le cœur reste juste',
        () async {
      // `AppService` n'est pas monté ici : la liste ne peut rien résoudre.
      // Le cœur, lui, ne consulte que les identifiants — c'est ce qui lui
      // permet de s'afficher juste avant même que le menu n'arrive.
      SharedPreferences.setMockInitialValues({
        'favorites': ['poulet-braise'],
      });
      final service = FavoritesService();
      await service.initialize();

      expect(service.favorites, isEmpty);
      expect(service.isFavorite(plat('poulet-braise')), isTrue);
    });
  });
}
