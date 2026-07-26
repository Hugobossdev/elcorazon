import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/menu_item.dart';
import '../models/order.dart';

class AIRecommendationService extends ChangeNotifier {
  static final AIRecommendationService _instance =
      AIRecommendationService._internal();
  factory AIRecommendationService() => _instance;
  AIRecommendationService._internal();

  final Map<String, List<MenuItem>> _recommendations = {};
  final Map<String, UserPreferences> _userPreferences = {};
  final Map<String, List<Order>> _userOrderHistory = {};

  // Facteurs de recommandation - supprimés car non utilisés

  // Getters
  Map<String, List<MenuItem>> get recommendations =>
      Map.unmodifiable(_recommendations);
  Map<String, UserPreferences> get userPreferences =>
      Map.unmodifiable(_userPreferences);

  /// Initialise le service de recommandations pour un utilisateur
  Future<void> initializeUser(String userId) async {
    await _loadUserPreferences(userId);
    await _loadUserOrderHistory(userId);
    await _generateRecommendations(userId);
  }

  /// Charge les préférences utilisateur
  Future<void> _loadUserPreferences(String userId) async {
    // Simulation des préférences utilisateur basées sur l'historique
    final preferences = UserPreferences(
      favoriteCategories: ['burgers', 'pizzas', 'drinks'],
      dietaryRestrictions: ['vegetarian'],
      priceRange: PriceRange.medium,
      preferredSpiceLevel: SpiceLevel.mild,
      timePreferences: TimePreferences(
        breakfast: 0.3,
        lunch: 0.7,
        dinner: 0.8,
        lateNight: 0.2,
      ),
      seasonalPreferences: {
        'spring': ['salads', 'light_drinks'],
        'summer': ['cold_drinks', 'ice_cream'],
        'autumn': ['warm_drinks', 'comfort_food'],
        'winter': ['hot_drinks', 'soups'],
      },
    );

    _userPreferences[userId] = preferences;
  }

  /// Charge l'historique des commandes utilisateur
  Future<void> _loadUserOrderHistory(String userId) async {
    // Simulation de l'historique des commandes
    final orders = [
      Order(
        id: 'order_1',
        userId: userId,
        items: [
          OrderItem(
            menuItemId: 'burger_1',
            menuItemName: 'El Corazón Burger',
            name: 'El Corazón Burger',
            category: 'burgers',
            menuItemImage: '',
            quantity: 1,
            unitPrice: 12.99,
            totalPrice: 12.99,
            customizations: {},
          ),
        ],
        subtotal: 12.99,
        total: 17.99,
        status: OrderStatus.delivered,
        deliveryAddress: '123 Main St',
        paymentMethod: PaymentMethod.creditCard,
        orderTime: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Order(
        id: 'order_2',
        userId: userId,
        items: [
          OrderItem(
            menuItemId: 'pizza_1',
            menuItemName: 'Margherita Pizza',
            name: 'Margherita Pizza',
            category: 'pizzas',
            menuItemImage: '',
            quantity: 1,
            unitPrice: 15.99,
            totalPrice: 15.99,
            customizations: {},
          ),
        ],
        subtotal: 15.99,
        total: 20.99,
        status: OrderStatus.delivered,
        deliveryAddress: '123 Main St',
        paymentMethod: PaymentMethod.creditCard,
        orderTime: DateTime.now().subtract(const Duration(days: 3)),
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    _userOrderHistory[userId] = orders;
  }

  /// Génère des recommandations personnalisées pour un utilisateur
  Future<void> _generateRecommendations(String userId) async {
    final preferences = _userPreferences[userId];
    if (preferences == null) return;

    final menuItems = await _getAvailableMenuItems();
    final recommendations = <MenuItem>[];

    // Recommandations basées sur l'historique
    final historyRecommendations =
        _getHistoryBasedRecommendations(userId, menuItems);
    recommendations.addAll(historyRecommendations);

    // Recommandations basées sur l'heure
    final timeRecommendations =
        _getTimeBasedRecommendations(preferences, menuItems);
    recommendations.addAll(timeRecommendations);

    // Recommandations basées sur la météo
    final weatherRecommendations = _getWeatherBasedRecommendations(menuItems);
    recommendations.addAll(weatherRecommendations);

    // Recommandations populaires
    final popularRecommendations = _getPopularRecommendations(menuItems);
    recommendations.addAll(popularRecommendations);

    // Dédupliquer et trier par score
    final uniqueRecommendations =
        _deduplicateAndRank(recommendations, preferences);

    _recommendations[userId] = uniqueRecommendations.take(10).toList();
    notifyListeners();
  }

  /// Recommandations basées sur l'historique des commandes
  List<MenuItem> _getHistoryBasedRecommendations(
      String userId, List<MenuItem> menuItems) {
    final orders = _userOrderHistory[userId] ?? [];
    final categoryFrequency = <String, int>{};

    // Calculer la fréquence des catégories commandées
    for (final order in orders) {
      for (final item in order.items) {
        categoryFrequency[item.category] =
            (categoryFrequency[item.category] ?? 0) + 1;
      }
    }

    // Recommander des items des catégories populaires
    final recommendations = <MenuItem>[];
    final sortedCategories = categoryFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final category in sortedCategories.take(3)) {
      final categoryItems = menuItems
          .where(
              (item) => item.category.displayName.toLowerCase() == category.key)
          .toList();
      if (categoryItems.isNotEmpty) {
        recommendations.add(categoryItems.first);
      }
    }

    return recommendations;
  }

  /// Recommandations basées sur l'heure de la journée
  List<MenuItem> _getTimeBasedRecommendations(
      UserPreferences preferences, List<MenuItem> menuItems) {
    final now = DateTime.now();
    final hour = now.hour;
    final recommendations = <MenuItem>[];

    if (hour >= 6 && hour < 11) {
      // Petit-déjeuner
      final breakfastItems = menuItems
          .where((item) =>
              item.category.displayName.toLowerCase().contains('breakfast') ||
              item.name.toLowerCase().contains('breakfast') ||
              item.name.toLowerCase().contains('pancake') ||
              item.name.toLowerCase().contains('waffle'))
          .toList();
      recommendations.addAll(breakfastItems.take(2));
    } else if (hour >= 11 && hour < 15) {
      // Déjeuner
      final lunchItems = menuItems
          .where((item) =>
              item.category.displayName.toLowerCase().contains('lunch') ||
              item.category.displayName.toLowerCase().contains('burger') ||
              item.category.displayName.toLowerCase().contains('sandwich'))
          .toList();
      recommendations.addAll(lunchItems.take(2));
    } else if (hour >= 15 && hour < 18) {
      // Goûter
      final snackItems = menuItems
          .where((item) =>
              item.category.displayName.toLowerCase().contains('dessert') ||
              item.category.displayName.toLowerCase().contains('drink') ||
              item.name.toLowerCase().contains('snack'))
          .toList();
      recommendations.addAll(snackItems.take(2));
    } else {
      // Dîner
      final dinnerItems = menuItems
          .where((item) =>
              item.category.displayName.toLowerCase().contains('pizza') ||
              item.category.displayName.toLowerCase().contains('pasta') ||
              item.category.displayName.toLowerCase().contains('dinner'))
          .toList();
      recommendations.addAll(dinnerItems.take(2));
    }

    return recommendations;
  }

  /// Recommandations basées sur la météo (simulée)
  List<MenuItem> _getWeatherBasedRecommendations(List<MenuItem> menuItems) {
    // Simulation de la météo
    final isHot = Random().nextBool();
    final recommendations = <MenuItem>[];

    if (isHot) {
      // Temps chaud - boissons froides, salades
      final coldItems = menuItems
          .where((item) =>
              item.category.displayName.toLowerCase().contains('drink') ||
              item.category.displayName.toLowerCase().contains('salad') ||
              item.name.toLowerCase().contains('ice') ||
              item.name.toLowerCase().contains('cold'))
          .toList();
      recommendations.addAll(coldItems.take(2));
    } else {
      // Temps froid - boissons chaudes, soupes
      final hotItems = menuItems
          .where((item) =>
              item.category.displayName.toLowerCase().contains('soup') ||
              item.name.toLowerCase().contains('hot') ||
              item.name.toLowerCase().contains('warm') ||
              item.category.displayName.toLowerCase().contains('coffee'))
          .toList();
      recommendations.addAll(hotItems.take(2));
    }

    return recommendations;
  }

  /// Recommandations populaires
  List<MenuItem> _getPopularRecommendations(List<MenuItem> menuItems) {
    // Simulation des items populaires
    final popularItems = menuItems
        .where((item) =>
            item.name.toLowerCase().contains('special') ||
            item.name.toLowerCase().contains('deluxe') ||
            item.name.toLowerCase().contains('premium'))
        .toList();

    return popularItems.take(2).toList();
  }

  /// Dédupliquer et classer les recommandations
  List<MenuItem> _deduplicateAndRank(
      List<MenuItem> recommendations, UserPreferences preferences) {
    final uniqueItems = <String, MenuItem>{};

    for (final item in recommendations) {
      uniqueItems[item.id] = item;
    }

    final rankedItems = uniqueItems.values.toList();

    // Trier par score de recommandation
    rankedItems.sort((a, b) {
      final scoreA = _calculateRecommendationScore(a, preferences);
      final scoreB = _calculateRecommendationScore(b, preferences);
      return scoreB.compareTo(scoreA);
    });

    return rankedItems;
  }

  /// Calcule le score de recommandation pour un item
  double _calculateRecommendationScore(
      MenuItem item, UserPreferences preferences) {
    double score = 0.0;

    // Score basé sur les catégories favorites
    if (preferences.favoriteCategories
        .contains(item.category.displayName.toLowerCase())) {
      score += 0.3;
    }

    // Score basé sur la gamme de prix
    if (item.price <= 10 && preferences.priceRange == PriceRange.low) {
      score += 0.2;
    } else if (item.price > 10 &&
        item.price <= 20 &&
        preferences.priceRange == PriceRange.medium) {
      score += 0.2;
    } else if (item.price > 20 && preferences.priceRange == PriceRange.high) {
      score += 0.2;
    }

    // Score basé sur les restrictions alimentaires
    if (preferences.dietaryRestrictions.contains('vegetarian') &&
        item.isVegetarian) {
      score += 0.2;
    }
    if (preferences.dietaryRestrictions.contains('vegan') && item.isVegan) {
      score += 0.2;
    }

    // Score basé sur la popularité (simulé)
    score += Random().nextDouble() * 0.1;

    return score;
  }

  /// Obtient les items du menu disponibles
  Future<List<MenuItem>> _getAvailableMenuItems() async {
    // Simulation des items du menu
    return [
      MenuItem(
        id: 'burger_1',
        name: 'El Corazón Burger',
        description: 'Burger signature avec viande hachée premium',
        price: 12.99,
        category: MenuCategory.burgers,
        imageUrl: 'https://example.com/burger1.jpg',
        isVegetarian: false,
        isVegan: false,
      ),
      MenuItem(
        id: 'pizza_1',
        name: 'Margherita Pizza',
        description: 'Pizza classique avec tomate, mozzarella et basilic',
        price: 15.99,
        category: MenuCategory.pizzas,
        imageUrl: 'https://example.com/pizza1.jpg',
        isVegetarian: true,
        isVegan: false,
      ),
      MenuItem(
        id: 'drink_1',
        name: 'Coca-Cola',
        description: 'Boisson gazeuse rafraîchissante',
        price: 3.99,
        category: MenuCategory.drinks,
        imageUrl: 'https://example.com/drink1.jpg',
        isVegetarian: true,
        isVegan: true,
      ),
    ];
  }

  /// Met à jour les préférences utilisateur
  Future<void> updateUserPreferences(
      String userId, UserPreferences preferences) async {
    _userPreferences[userId] = preferences;
    await _generateRecommendations(userId);
    notifyListeners();
  }

  /// Ajoute une commande à l'historique utilisateur
  Future<void> addOrderToHistory(String userId, Order order) async {
    _userOrderHistory[userId] = (_userOrderHistory[userId] ?? [])..add(order);
    await _generateRecommendations(userId);
    notifyListeners();
  }

  /// Obtient les recommandations pour un utilisateur
  List<MenuItem> getRecommendationsForUser(String userId) {
    return _recommendations[userId] ?? [];
  }

  /// Obtient les recommandations basées sur un item
  List<MenuItem> getSimilarItems(MenuItem item) {
    // Simulation d'items similaires
    final similarItems = <MenuItem>[];
    final allItems = _recommendations.values.expand((list) => list).toList();

    // Trouver des items de la même catégorie
    final sameCategoryItems = allItems
        .where((otherItem) =>
            otherItem.category == item.category && otherItem.id != item.id)
        .toList();

    similarItems.addAll(sameCategoryItems.take(3));

    return similarItems;
  }

  /// Analyse les tendances de commande
  Map<String, dynamic> analyzeOrderTrends(String userId) {
    final orders = _userOrderHistory[userId] ?? [];
    final trends = <String, dynamic>{};

    // Tendance par catégorie
    final categoryTrends = <String, int>{};
    for (final order in orders) {
      for (final item in order.items) {
        categoryTrends[item.category] =
            (categoryTrends[item.category] ?? 0) + 1;
      }
    }

    trends['categoryTrends'] = categoryTrends;
    trends['totalOrders'] = orders.length;
    trends['averageOrderValue'] = orders.isNotEmpty
        ? orders.map((o) => o.total).reduce((a, b) => a + b) / orders.length
        : 0.0;

    return trends;
  }
}

class UserPreferences {
  final List<String> favoriteCategories;
  final List<String> dietaryRestrictions;
  final PriceRange priceRange;
  final SpiceLevel preferredSpiceLevel;
  final TimePreferences timePreferences;
  final Map<String, List<String>> seasonalPreferences;

  UserPreferences({
    required this.favoriteCategories,
    required this.dietaryRestrictions,
    required this.priceRange,
    required this.preferredSpiceLevel,
    required this.timePreferences,
    required this.seasonalPreferences,
  });
}

class TimePreferences {
  final double breakfast;
  final double lunch;
  final double dinner;
  final double lateNight;

  TimePreferences({
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.lateNight,
  });
}

enum PriceRange { low, medium, high }

enum SpiceLevel { mild, medium, hot }
