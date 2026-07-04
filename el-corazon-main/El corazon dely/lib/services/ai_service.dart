import 'package:flutter/foundation.dart';
import '../models/menu_item.dart';
import '../models/user.dart';
import '../models/order.dart';

class AIService extends ChangeNotifier {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  bool _isInitialized = false;
  final List<String> _chatHistory = [];
  List<MenuItem> _recommendations = [];
  Map<String, dynamic> _userPreferences = {};

  bool get isInitialized => _isInitialized;
  List<String> get chatHistory => List.unmodifiable(_chatHistory);
  List<MenuItem> get recommendations => List.unmodifiable(_recommendations);

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize AI preferences
      _userPreferences = {
        'favoriteCategories': <String>[],
        'dietaryRestrictions': <String>[],
        'spiceLevel': 'medium',
        'preferredMealTimes': <String>[],
        'budget': 'medium',
      };

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing AI Service: $e');
    }
  }

  // AI Chatbot functionality
  Future<String> sendMessage(String message) async {
    _chatHistory.add('User: $message');

    // Simulate AI processing
    await Future.delayed(const Duration(milliseconds: 500));

    String response = _generateAIResponse(message.toLowerCase());
    _chatHistory.add('Assistant: $response');

    notifyListeners();
    return response;
  }

  String _generateAIResponse(String message) {
    if (message.contains('recommande') || message.contains('suggest')) {
      return '🤖 Basé sur vos habitudes, je vous recommande notre Burger Classic avec des frites croustillantes ! Voulez-vous l\'ajouter à votre panier ?';
    } else if (message.contains('pizza')) {
      return '🍕 Excellente choix ! Notre Pizza Margherita est très populaire. Souhaitez-vous la personnaliser avec des ingrédients supplémentaires ?';
    } else if (message.contains('vegetarien') || message.contains('vegan')) {
      return '🥗 Nous avons plusieurs options végétariennes délicieuses ! Le Wrap Végétarien et la Salade César sont très appréciés.';
    } else if (message.contains('rapide') || message.contains('quick')) {
      return '⚡ Pour une commande rapide, je suggère notre Menu Express : Burger + Frites + Boisson en 10 minutes !';
    } else if (message.contains('prix') || message.contains('price')) {
      return '💰 Nos prix varient de 2000 CFA à 8000 CFA. Quel est votre budget pour ce repas ?';
    } else {
      return '👋 Je suis là pour vous aider ! Posez-moi des questions sur notre menu, des recommandations personnalisées, ou dites-moi ce que vous avez envie de manger.';
    }
  }

  // Smart Recommendations based on user data
  Future<void> generateRecommendations(
      User user, List<Order> orderHistory, List<MenuItem> menuItems) async {
    _recommendations.clear();

    // Analyze user preferences from order history
    Map<String, int> categoryFrequency = {};
    Map<String, int> itemFrequency = {};

    for (var order in orderHistory) {
      for (var item in order.items) {
        final categoryKey = item.category; // OrderItem.category est déjà une String
        categoryFrequency[categoryKey] =
            (categoryFrequency[categoryKey] ?? 0) + 1;
        itemFrequency[item.name] = (itemFrequency[item.name] ?? 0) + 1;
      }
    }

    // Get current time for time-based recommendations
    final hour = DateTime.now().hour;
    String mealTime = hour < 12
        ? 'breakfast'
        : hour < 17
            ? 'lunch'
            : 'dinner';

    // Generate recommendations based on multiple factors
    List<MenuItem> candidates = menuItems.where((item) {
      // Time-based filtering
      if (mealTime == 'breakfast' &&
          item.category != MenuCategory.burgers &&
          item.category != MenuCategory.sides) {
        return false;
      }
      if (mealTime == 'lunch' && item.category == MenuCategory.desserts) {
        return false;
      }

      // Dietary restrictions
      if (_userPreferences['dietaryRestrictions'].contains('vegetarian') &&
          !item.isVegetarian) {
        return false;
      }

      return true;
    }).toList();

    // Sort by preference score
    candidates.sort((a, b) {
      int scoreA =
          _calculatePreferenceScore(a, categoryFrequency, itemFrequency);
      int scoreB =
          _calculatePreferenceScore(b, categoryFrequency, itemFrequency);
      return scoreB.compareTo(scoreA);
    });

    _recommendations = candidates.take(5).toList();
    notifyListeners();
  }

  int _calculatePreferenceScore(
      MenuItem item, Map<String, int> categoryFreq, Map<String, int> itemFreq) {
    int score = 0;

    // Category preference
    final categoryKey = item.category.displayName;
    score += (categoryFreq[categoryKey] ?? 0) * 3;

    // Item preference
    score += (itemFreq[item.name] ?? 0) * 5;

    // Popularity boost
    if (item.isPopular) score += 10;

    // New item penalty (encourage trying new things)
    if (itemFreq[item.name] == null) score += 2;

    return score;
  }

  // Voice Command Processing
  Future<String> processVoiceCommand(String voiceText) async {
    String command = voiceText.toLowerCase();

    // Extract menu items and quantities
    Map<String, dynamic> order = _parseVoiceOrder(command);

    if (order['items'].isNotEmpty) {
      return 'Parfait ! J\'ai compris : ${order['summary']}. Voulez-vous confirmer cette commande ?';
    } else {
      return 'Désolé, je n\'ai pas bien compris votre commande. Pouvez-vous répéter ou utiliser le menu visuel ?';
    }
  }

  Map<String, dynamic> _parseVoiceOrder(String command) {
    List<Map<String, dynamic>> items = [];
    String summary = '';

    // Simple pattern matching for voice commands
    if (command.contains('burger')) {
      items.add({'name': 'Burger Classic', 'quantity': 1});
      summary += '1 Burger Classic';
    }
    if (command.contains('pizza')) {
      items.add({'name': 'Pizza Margherita', 'quantity': 1});
      summary +=
          summary.isEmpty ? '1 Pizza Margherita' : ', 1 Pizza Margherita';
    }
    if (command.contains('coca') || command.contains('boisson')) {
      items.add({'name': 'Coca-Cola', 'quantity': 1});
      summary += summary.isEmpty ? '1 Coca-Cola' : ', 1 Coca-Cola';
    }

    return {'items': items, 'summary': summary};
  }

  // Smart Menu Suggestions
  List<MenuItem> getComplementaryItems(
      MenuItem baseItem, List<MenuItem> menuItems) {
    List<MenuItem> suggestions = [];

    // Rule-based suggestions basées sur l'enum MenuCategory
    if (baseItem.category == MenuCategory.burgers) {
      suggestions.addAll(menuItems.where((item) =>
          item.category == MenuCategory.sides ||
          item.category == MenuCategory.drinks));
    } else if (baseItem.category == MenuCategory.pizzas) {
      suggestions.addAll(menuItems.where((item) =>
          item.category == MenuCategory.drinks ||
          item.category == MenuCategory.desserts));
    } else if (baseItem.category == MenuCategory.drinks) {
      suggestions.addAll(
          menuItems.where((item) => item.category == MenuCategory.desserts));
    }

    return suggestions.take(3).toList();
  }

  // Predictive Analytics
  Map<String, dynamic> predictOrderPatterns(List<Order> orderHistory) {
    Map<String, List<int>> hourlyOrders = {};
    Map<String, int> dailyOrders = {};

    for (var order in orderHistory) {
      String hour = '${order.createdAt.hour}:00';
      String day = _getDayName(order.createdAt.weekday);

      hourlyOrders[hour] = (hourlyOrders[hour] ?? [])..add(1);
      dailyOrders[day] = (dailyOrders[day] ?? 0) + 1;
    }

    // Find peak hours and days
    String peakHour = hourlyOrders.entries
        .reduce((a, b) => a.value.length > b.value.length ? a : b)
        .key;
    String peakDay =
        dailyOrders.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return {
      'peakHour': peakHour,
      'peakDay': peakDay,
      'averageOrderValue': _calculateAverageOrderValue(orderHistory),
      'topCategories': _getTopCategories(orderHistory),
    };
  }

  String _getDayName(int weekday) {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    return days[weekday - 1];
  }

  double _calculateAverageOrderValue(List<Order> orders) {
    if (orders.isEmpty) return 0.0;
    double total = orders.fold(0, (sum, order) => sum + order.total);
    return total / orders.length;
  }

  List<String> _getTopCategories(List<Order> orders) {
    // Compter par catégorie (clé String issue de OrderItem.category)
    final Map<String, int> categoryCount = {};

    for (var order in orders) {
      for (var item in order.items) {
        final categoryKey = item.category;
        categoryCount[categoryKey] =
            (categoryCount[categoryKey] ?? 0) + 1;
      }
    }

    final sorted = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(3).map((e) => e.key).toList();
  }

  void clearChatHistory() {
    _chatHistory.clear();
    notifyListeners();
  }

  void updateUserPreferences(Map<String, dynamic> preferences) {
    _userPreferences.addAll(preferences);
    notifyListeners();
  }
}

