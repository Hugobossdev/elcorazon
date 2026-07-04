import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../models/menu_item.dart';
import 'database_service.dart';

class MarketingCampaign {
  final String id;
  final String name;
  final String type; // 'personalized', 'seasonal', 'promotional', 'retention'
  final String title;
  final String message;
  final List<String> targetUserIds;
  final Map<String, dynamic> conditions;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final Map<String, dynamic> metrics;

  MarketingCampaign({
    required this.id,
    required this.name,
    required this.type,
    required this.title,
    required this.message,
    required this.targetUserIds,
    required this.conditions,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.metrics = const {},
  });
}

class PredictiveAnalytics {
  final String id;
  final String
      type; // 'sales_forecast', 'inventory_prediction', 'customer_behavior'
  final Map<String, dynamic> predictions;
  final double confidence;
  final DateTime generatedAt;
  final Map<String, dynamic> parameters;

  PredictiveAnalytics({
    required this.id,
    required this.type,
    required this.predictions,
    required this.confidence,
    required this.generatedAt,
    required this.parameters,
  });
}

class CustomerInsight {
  final String userId;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> behaviorPatterns;
  final double churnRisk;
  final List<String> recommendedActions;
  final DateTime lastUpdated;

  CustomerInsight({
    required this.userId,
    required this.preferences,
    required this.behaviorPatterns,
    required this.churnRisk,
    required this.recommendedActions,
    required this.lastUpdated,
  });
}

class MarketingService extends ChangeNotifier {
  static final MarketingService _instance = MarketingService._internal();
  factory MarketingService() => _instance;
  MarketingService._internal();

  final DatabaseService _databaseService = DatabaseService();
  List<MarketingCampaign> _campaigns = [];
  final List<PredictiveAnalytics> _analytics = [];
  final Map<String, CustomerInsight> _customerInsights = {};
  bool _isInitialized = false;

  List<MarketingCampaign> get campaigns => List.unmodifiable(_campaigns);
  List<PredictiveAnalytics> get analytics => List.unmodifiable(_analytics);
  Map<String, CustomerInsight> get customerInsights =>
      Map.unmodifiable(_customerInsights);
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadMarketingData();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing Marketing Service: $e');
    }
  }

  Future<void> _loadMarketingData() async {
    try {
      // Load campaigns from database - campaigns are stored as promotions
      // In a real implementation, you would have a separate campaigns table
      // For now, we'll use promotions as campaigns
      final promotions = await _databaseService.getActivePromotions();
      
      _campaigns = promotions.map((data) {
        return MarketingCampaign(
          id: data['id'] as String,
          name: data['name'] as String? ?? data['title'] as String? ?? '',
          type: 'promotional',
          title: data['title'] as String? ?? data['name'] as String? ?? '',
          message: data['description'] as String? ?? '',
          targetUserIds: [],
          conditions: {},
          startDate: DateTime.parse(data['start_date'] as String),
          endDate: DateTime.parse(data['end_date'] as String),
          metrics: {
            'views': data['views_count'] as int? ?? 0,
            'clicks': data['clicks_count'] as int? ?? 0,
            'conversions': data['usage_count'] as int? ?? 0,
          },
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading marketing data: $e');
      _campaigns = [];
    }
  }

  // Predictive Analytics Functions

  /// Generate sales forecast
  Future<PredictiveAnalytics> generateSalesForecast({
    required List<Order> historicalOrders,
    int forecastDays = 7,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    // Analyze historical data
    Map<String, dynamic> analysis = _analyzeHistoricalSales(historicalOrders);

    // Generate predictions
    Map<String, dynamic> predictions = {};
    DateTime startDate = DateTime.now();

    for (int i = 0; i < forecastDays; i++) {
      DateTime date = startDate.add(Duration(days: i));
      String dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      double baseSales = analysis['averageDailySales'];

      // Apply day of week factor
      double dayFactor = _getDayOfWeekFactor(date.weekday);

      // Apply weather factor (simulated)
      double weatherFactor = _getWeatherFactor(date);

      // Apply trend factor
      double trendFactor = analysis['trend'];

      predictions[dateKey] = {
        'expectedSales':
            (baseSales * dayFactor * weatherFactor * trendFactor).round(),
        'expectedOrders':
            ((baseSales * dayFactor * weatherFactor * trendFactor) /
                    analysis['averageOrderValue'])
                .round(),
        'confidence': 0.75 + (i * -0.05), // Confidence decreases over time
      };
    }

    PredictiveAnalytics analytics = PredictiveAnalytics(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'sales_forecast',
      predictions: predictions,
      confidence: 0.75,
      generatedAt: DateTime.now(),
      parameters: {
        'forecastDays': forecastDays,
        'dataPoints': historicalOrders.length,
        'method': 'time_series_analysis',
      },
    );

    _analytics.add(analytics);
    notifyListeners();

    return analytics;
  }

  Map<String, dynamic> _analyzeHistoricalSales(List<Order> orders) {
    if (orders.isEmpty) {
      return {
        'averageDailySales': 50000.0,
        'averageOrderValue': 7500.0,
        'trend': 1.0,
      };
    }

    double totalSales = orders.fold(0.0, (sum, order) => sum + order.total);
    double averageOrderValue = totalSales / orders.length;

    // Group orders by date
    Map<String, double> dailySales = {};
    for (var order in orders) {
      String dateKey =
          '${order.createdAt.year}-${order.createdAt.month}-${order.createdAt.day}';
      dailySales[dateKey] = (dailySales[dateKey] ?? 0) + order.total;
    }

    double averageDailySales =
        dailySales.values.fold(0.0, (sum, sales) => sum + sales) /
            dailySales.length;

    // Calculate trend (simplified)
    double trend = 1.0;
    if (dailySales.length > 1) {
      List<double> salesList = dailySales.values.toList();
      double firstHalf =
          salesList.take(salesList.length ~/ 2).fold(0.0, (a, b) => a + b);
      double secondHalf =
          salesList.skip(salesList.length ~/ 2).fold(0.0, (a, b) => a + b);
      trend = secondHalf / firstHalf;
    }

    return {
      'averageDailySales': averageDailySales,
      'averageOrderValue': averageOrderValue,
      'trend': trend,
    };
  }

  double _getDayOfWeekFactor(int weekday) {
    // Monday = 1, Sunday = 7
    const factors = {
      1: 0.8, // Monday
      2: 0.9, // Tuesday
      3: 0.9, // Wednesday
      4: 1.0, // Thursday
      5: 1.2, // Friday
      6: 1.3, // Saturday
      7: 1.1, // Sunday
    };
    return factors[weekday] ?? 1.0;
  }

  double _getWeatherFactor(DateTime date) {
    // Simulate weather impact
    int seed = date.day + date.month;
    double factor = 0.8 + (seed % 5) * 0.1; // 0.8 to 1.2
    return factor;
  }

  /// Predict inventory needs
  Future<PredictiveAnalytics> predictInventoryNeeds({
    required List<MenuItem> menuItems,
    required List<Order> recentOrders,
    int predictionDays = 3,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    Map<String, dynamic> predictions = {};

    for (var item in menuItems) {
      // Count recent orders for this item
      int recentCount = recentOrders
          .expand((order) => order.items)
          .where((orderItem) => orderItem.name == item.name)
          .length;

      // Calculate daily average
      double dailyAverage = recentCount / 7.0; // Assuming 7 days of recent data

      // Predict future need
      int predictedNeed =
          (dailyAverage * predictionDays * 1.2).ceil(); // 20% buffer

      predictions[item.name] = {
        'currentStock': item.availableQuantity,
        'predictedNeed': predictedNeed,
        'reorderSuggested': predictedNeed > item.availableQuantity,
        'suggestedOrderQuantity': predictedNeed > item.availableQuantity
            ? (predictedNeed - item.availableQuantity + 10)
            : 0,
      };
    }

    PredictiveAnalytics analytics = PredictiveAnalytics(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'inventory_prediction',
      predictions: predictions,
      confidence: 0.65,
      generatedAt: DateTime.now(),
      parameters: {
        'predictionDays': predictionDays,
        'itemsAnalyzed': menuItems.length,
      },
    );

    _analytics.add(analytics);
    notifyListeners();

    return analytics;
  }

  // Customer Behavior Analysis

  /// Analyze customer behavior and generate insights
  Future<CustomerInsight> analyzeCustomerBehavior({
    required String userId,
    required List<Order> userOrders,
    required User user,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    // Analyze preferences
    Map<String, dynamic> preferences = _analyzePreferences(userOrders);

    // Analyze behavior patterns
    Map<String, dynamic> behaviorPatterns =
        _analyzeBehaviorPatterns(userOrders);

    // Calculate churn risk
    double churnRisk = _calculateChurnRisk(userOrders, user);

    // Generate recommended actions
    List<String> recommendedActions =
        _generateRecommendedActions(preferences, behaviorPatterns, churnRisk);

    CustomerInsight insight = CustomerInsight(
      userId: userId,
      preferences: preferences,
      behaviorPatterns: behaviorPatterns,
      churnRisk: churnRisk,
      recommendedActions: recommendedActions,
      lastUpdated: DateTime.now(),
    );

    _customerInsights[userId] = insight;
    notifyListeners();

    return insight;
  }

  Map<String, dynamic> _analyzePreferences(List<Order> orders) {
    if (orders.isEmpty) return {};

    Map<String, int> categoryCount = {};
    Map<String, int> itemCount = {};
    List<double> orderValues = [];
    Map<int, int> orderHours = {};

    for (var order in orders) {
      orderValues.add(order.total);
      orderHours[order.createdAt.hour] =
          (orderHours[order.createdAt.hour] ?? 0) + 1;

      for (var item in order.items) {
        categoryCount[item.category] = (categoryCount[item.category] ?? 0) + 1;
        itemCount[item.name] = (itemCount[item.name] ?? 0) + 1;
      }
    }

    String favoriteCategory = categoryCount.entries.isEmpty
        ? 'Burgers'
        : categoryCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    String favoriteItem = itemCount.entries.isEmpty
        ? 'Burger Classic'
        : itemCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    double averageOrderValue =
        orderValues.fold(0.0, (sum, val) => sum + val) / orderValues.length;

    int peakHour = orderHours.entries.isEmpty
        ? 12
        : orderHours.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return {
      'favoriteCategory': favoriteCategory,
      'favoriteItem': favoriteItem,
      'averageOrderValue': averageOrderValue,
      'peakOrderHour': peakHour,
      'preferredMealTime': _getMealTime(peakHour),
    };
  }

  Map<String, dynamic> _analyzeBehaviorPatterns(List<Order> orders) {
    if (orders.isEmpty) return {};

    // Order frequency
    DateTime now = DateTime.now();
    int ordersLastMonth = orders
        .where((order) => now.difference(order.createdAt).inDays <= 30)
        .length;

    double orderFrequency = ordersLastMonth / 4.0; // orders per week

    // Loyalty score
    double loyaltyScore = _calculateLoyaltyScore(orders);

    // Order consistency
    bool isConsistent = orders.length > 3 &&
        orders.take(3).every((order) => orders.first.items.any((firstItem) =>
            order.items.any((orderItem) => orderItem.name == firstItem.name)));

    return {
      'orderFrequency': orderFrequency,
      'loyaltyScore': loyaltyScore,
      'isConsistentOrderer': isConsistent,
      'totalOrders': orders.length,
      'lastOrderDays':
          orders.isEmpty ? 999 : now.difference(orders.first.createdAt).inDays,
    };
  }

  double _calculateChurnRisk(List<Order> orders, User user) {
    if (orders.isEmpty) return 0.9;

    DateTime now = DateTime.now();
    int daysSinceLastOrder =
        orders.isEmpty ? 999 : now.difference(orders.first.createdAt).inDays;

    double churnRisk = 0.0;

    // Days since last order factor
    if (daysSinceLastOrder > 30) {
      churnRisk += 0.4;
    } else if (daysSinceLastOrder > 14) churnRisk += 0.2;

    // Order frequency factor
    int recentOrders = orders
        .where((order) => now.difference(order.createdAt).inDays <= 30)
        .length;
    if (recentOrders == 0) {
      churnRisk += 0.3;
    } else if (recentOrders < 2) churnRisk += 0.2;

    // Engagement factor
    if (user.loyaltyPoints < 100) churnRisk += 0.1;

    return churnRisk.clamp(0.0, 1.0);
  }

  double _calculateLoyaltyScore(List<Order> orders) {
    double score = 0.0;

    // Order count contribution
    score += (orders.length * 0.1).clamp(0.0, 0.3);

    // Consistency contribution
    if (orders.length > 1) {
      DateTime firstOrder = orders.last.createdAt;
      DateTime lastOrder = orders.first.createdAt;
      int daysBetween = lastOrder.difference(firstOrder).inDays;

      if (daysBetween > 0) {
        double consistency =
            orders.length / (daysBetween / 7.0); // orders per week
        score += (consistency * 0.05).clamp(0.0, 0.3);
      }
    }

    // Recent activity contribution
    DateTime now = DateTime.now();
    int recentOrders = orders
        .where((order) => now.difference(order.createdAt).inDays <= 30)
        .length;
    score += (recentOrders * 0.02).clamp(0.0, 0.4);

    return score.clamp(0.0, 1.0);
  }

  List<String> _generateRecommendedActions(Map<String, dynamic> preferences,
      Map<String, dynamic> behaviorPatterns, double churnRisk) {
    List<String> actions = [];

    // High churn risk actions
    if (churnRisk > 0.7) {
      actions.add('Envoyer offre de reconquête personnalisée');
      actions.add('Proposer une remise de 20% sur leur plat favori');
    } else if (churnRisk > 0.4) {
      actions.add('Envoyer notification de nouveautés');
      actions.add('Proposer un programme de fidélité renforcé');
    }

    // Low order frequency actions
    if (behaviorPatterns['orderFrequency'] != null &&
        behaviorPatterns['orderFrequency'] < 1.0) {
      actions.add('Envoyer rappel hebdomadaire personnalisé');
      actions.add('Proposer un menu découverte');
    }

    // High value customer actions
    if (preferences['averageOrderValue'] != null &&
        preferences['averageOrderValue'] > 10000) {
      actions.add('Inviter au programme VIP');
      actions.add('Proposer des avant-premières de nouveaux produits');
    }

    // Consistent customer rewards
    if (behaviorPatterns['isConsistentOrderer'] == true) {
      actions.add('Proposer une commande récurrente automatique');
      actions.add('Offrir des points de fidélité bonus');
    }

    return actions.isNotEmpty ? actions : ['Maintenir engagement actuel'];
  }

  String _getMealTime(int hour) {
    if (hour < 11) {
      return 'breakfast';
    } else if (hour < 16)
      return 'lunch';
    else
      return 'dinner';
  }

  // Automated Marketing Campaigns

  /// Create personalized marketing campaigns
  Future<List<MarketingCampaign>> createPersonalizedCampaigns({
    required List<User> users,
    required Map<String, List<Order>> userOrders,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    List<MarketingCampaign> campaigns = [];

    // Win-back campaign for inactive users
    List<String> inactiveUsers = [];
    DateTime thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    for (var user in users) {
      List<Order> orders = userOrders[user.id] ?? [];
      bool hasRecentOrder =
          orders.any((order) => order.createdAt.isAfter(thirtyDaysAgo));

      if (!hasRecentOrder && orders.isNotEmpty) {
        inactiveUsers.add(user.id);
      }
    }

    if (inactiveUsers.isNotEmpty) {
      campaigns.add(MarketingCampaign(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Win-Back Campaign',
        type: 'retention',
        title: '🎯 On vous a manqué !',
        message:
            'Revenez chez El Corazon Dely avec 25% de réduction sur votre prochaine commande !',
        targetUserIds: inactiveUsers,
        conditions: {'lastOrderDays': '>30'},
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
      ));
    }

    // Loyalty reward campaign
    List<String> loyalUsers = [];
    for (var user in users) {
      if (user.loyaltyPoints > 500) {
        loyalUsers.add(user.id);
      }
    }

    if (loyalUsers.isNotEmpty) {
      campaigns.add(MarketingCampaign(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        name: 'Loyalty Reward',
        type: 'personalized',
        title: '🏆 Merci pour votre fidélité !',
        message:
            'Profitez d\'un repas gratuit grâce à vos points de fidélité !',
        targetUserIds: loyalUsers,
        conditions: {'loyaltyPoints': '>500'},
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 14)),
      ));
    }

    _campaigns.addAll(campaigns);
    notifyListeners();

    return campaigns;
  }

  /// Send targeted notification
  Future<bool> sendTargetedNotification({
    required String campaignId,
    required List<String> userIds,
    required String title,
    required String message,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      // Simulate sending notifications
      debugPrint('Sending notification to ${userIds.length} users: $title');

      // Update campaign metrics
      int campaignIndex = _campaigns.indexWhere((c) => c.id == campaignId);
      if (campaignIndex != -1) {
        var campaign = _campaigns[campaignIndex];
        Map<String, dynamic> newMetrics = Map.from(campaign.metrics);
        newMetrics['sent'] = (newMetrics['sent'] ?? 0) + userIds.length;
        newMetrics['lastSent'] = DateTime.now().toIso8601String();

        MarketingCampaign updatedCampaign = MarketingCampaign(
          id: campaign.id,
          name: campaign.name,
          type: campaign.type,
          title: campaign.title,
          message: campaign.message,
          targetUserIds: campaign.targetUserIds,
          conditions: campaign.conditions,
          startDate: campaign.startDate,
          endDate: campaign.endDate,
          isActive: campaign.isActive,
          metrics: newMetrics,
        );

        _campaigns[campaignIndex] = updatedCampaign;
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('Error sending targeted notification: $e');
      return false;
    }
  }

  /// Get marketing dashboard data
  Map<String, dynamic> getMarketingDashboard() {
    DateTime now = DateTime.now();

    int activeCampaigns =
        _campaigns.where((c) => c.isActive && c.endDate.isAfter(now)).length;

    num totalSent =
        _campaigns.fold(0, (sum, c) => sum + (c.metrics['sent'] ?? 0));

    num totalClicks =
        _campaigns.fold(0, (sum, c) => sum + (c.metrics['clicks'] ?? 0));

    double clickRate = totalSent > 0 ? (totalClicks / totalSent) * 100 : 0.0;

    return {
      'activeCampaigns': activeCampaigns,
      'totalNotificationsSent': totalSent,
      'clickThroughRate': clickRate,
      'customersAnalyzed': _customerInsights.length,
      'highChurnRiskCustomers': _customerInsights.values
          .where((insight) => insight.churnRisk > 0.7)
          .length,
      'loyalCustomers': _customerInsights.values
          .where((insight) =>
              insight.behaviorPatterns['loyaltyScore'] != null &&
              insight.behaviorPatterns['loyaltyScore'] > 0.7)
          .length,
      'pendingActions': _customerInsights.values
          .expand((insight) => insight.recommendedActions)
          .length,
    };
  }

  /// Get campaign performance
  Map<String, dynamic> getCampaignPerformance(String campaignId) {
    var campaign = _campaigns.firstWhere((c) => c.id == campaignId);

    int sent = campaign.metrics['sent'] ?? 0;
    int clicks = campaign.metrics['clicks'] ?? 0;
    int conversions = campaign.metrics['conversions'] ?? 0;

    return {
      'sent': sent,
      'clicks': clicks,
      'conversions': conversions,
      'clickRate': sent > 0 ? (clicks / sent * 100).toStringAsFixed(1) : '0.0',
      'conversionRate':
          clicks > 0 ? (conversions / clicks * 100).toStringAsFixed(1) : '0.0',
      'isActive': campaign.isActive,
      'daysRemaining': campaign.endDate.difference(DateTime.now()).inDays,
    };
  }

  void clearMarketingData() {
    _campaigns.clear();
    _analytics.clear();
    _customerInsights.clear();
    notifyListeners();
  }
}
