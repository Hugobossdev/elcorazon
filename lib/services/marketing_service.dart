import 'package:flutter/foundation.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/user.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/supabase/supabase_config.dart';

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

  /// Create MarketingCampaign from Supabase data
  factory MarketingCampaign.fromMap(Map<String, dynamic> map) {
    return MarketingCampaign(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      targetUserIds: List<String>.from(map['target_user_ids'] ?? []),
      conditions: Map<String, dynamic>.from(map['conditions'] ?? {}),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      isActive: map['is_active'] as bool? ?? true,
      metrics: Map<String, dynamic>.from(map['metrics'] ?? {}),
    );
  }

  /// Convert MarketingCampaign to Map for Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'title': title,
      'message': message,
      'target_user_ids': targetUserIds,
      'conditions': conditions,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive,
      'metrics': metrics,
    };
  }
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
      // Load campaigns from Supabase
      final response = await SupabaseConfig.client
          .from('marketing_campaigns')
          .select()
          .order('created_at', ascending: false);

      _campaigns = (response as List)
          .map((data) => MarketingCampaign.fromMap(data))
          .toList();
      debugPrint(
          '✅ Loaded ${_campaigns.length} marketing campaigns from Supabase',);
    } catch (e) {
      // Vérifier si c'est une erreur de table manquante
      final errorString = e.toString();
      if (errorString.contains('PGRST205') ||
          (errorString.contains('marketing_campaigns') &&
              errorString.contains('not exist'))) {
        debugPrint('⚠️ Table marketing_campaigns does not exist in Supabase.');
        debugPrint(
            '📋 Please run the SQL script: lib/database/create_marketing_campaigns_table.sql',);
        debugPrint('   You can execute it in Supabase Dashboard > SQL Editor');
        // Fallback to empty list
        _campaigns = [];
      } else {
        debugPrint('❌ Error loading marketing campaigns from Supabase: $e');
        // Fallback to empty list if database is not available
        _campaigns = [];
      }
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
    final Map<String, dynamic> analysis = _analyzeHistoricalSales(historicalOrders);

    // Generate predictions
    final Map<String, dynamic> predictions = {};
    final DateTime startDate = DateTime.now();

    for (int i = 0; i < forecastDays; i++) {
      final DateTime date = startDate.add(Duration(days: i));
      final String dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final double baseSales = analysis['averageDailySales'];

      // Apply day of week factor
      final double dayFactor = _getDayOfWeekFactor(date.weekday);

      // Apply weather factor (simulated)
      final double weatherFactor = _getWeatherFactor(date);

      // Apply trend factor
      final double trendFactor = analysis['trend'];

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

    final PredictiveAnalytics analytics = PredictiveAnalytics(
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

    final double totalSales = orders.fold(0.0, (sum, order) => sum + order.total);
    final double averageOrderValue = totalSales / orders.length;

    // Group orders by date
    final Map<String, double> dailySales = {};
    for (final order in orders) {
      final String dateKey =
          '${order.createdAt.year}-${order.createdAt.month}-${order.createdAt.day}';
      dailySales[dateKey] = (dailySales[dateKey] ?? 0) + order.total;
    }

    final double averageDailySales =
        dailySales.values.fold(0.0, (sum, sales) => sum + sales) /
            dailySales.length;

    // Calculate trend (simplified)
    double trend = 1.0;
    if (dailySales.length > 1) {
      final List<double> salesList = dailySales.values.toList();
      final double firstHalf =
          salesList.take(salesList.length ~/ 2).fold(0.0, (a, b) => a + b);
      final double secondHalf =
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
    final int seed = date.day + date.month;
    final double factor = 0.8 + (seed % 5) * 0.1; // 0.8 to 1.2
    return factor;
  }

  /// Predict inventory needs
  Future<PredictiveAnalytics> predictInventoryNeeds({
    required List<MenuItem> menuItems,
    required List<Order> recentOrders,
    int predictionDays = 3,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final Map<String, dynamic> predictions = {};

    for (final item in menuItems) {
      // Count recent orders for this item
      final int recentCount = recentOrders
          .expand((order) => order.items)
          .where((orderItem) => orderItem.name == item.name)
          .length;

      // Calculate daily average
      final double dailyAverage = recentCount / 7.0; // Assuming 7 days of recent data

      // Predict future need
      final int predictedNeed =
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

    final PredictiveAnalytics analytics = PredictiveAnalytics(
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
    final Map<String, dynamic> preferences = _analyzePreferences(userOrders);

    // Analyze behavior patterns
    final Map<String, dynamic> behaviorPatterns =
        _analyzeBehaviorPatterns(userOrders);

    // Calculate churn risk
    final double churnRisk = _calculateChurnRisk(userOrders, user);

    // Generate recommended actions
    final List<String> recommendedActions =
        _generateRecommendedActions(preferences, behaviorPatterns, churnRisk);

    final CustomerInsight insight = CustomerInsight(
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

    final Map<String, int> categoryCount = {};
    final Map<String, int> itemCount = {};
    final List<double> orderValues = [];
    final Map<int, int> orderHours = {};

    for (final order in orders) {
      orderValues.add(order.total);
      orderHours[order.createdAt.hour] =
          (orderHours[order.createdAt.hour] ?? 0) + 1;

      for (final item in order.items) {
        categoryCount[item.category] = (categoryCount[item.category] ?? 0) + 1;
        itemCount[item.name] = (itemCount[item.name] ?? 0) + 1;
      }
    }

    final String favoriteCategory = categoryCount.entries.isEmpty
        ? 'Burgers'
        : categoryCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final String favoriteItem = itemCount.entries.isEmpty
        ? 'Burger Classic'
        : itemCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final double averageOrderValue =
        orderValues.fold(0.0, (sum, val) => sum + val) / orderValues.length;

    final int peakHour = orderHours.entries.isEmpty
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
    final DateTime now = DateTime.now();
    final int ordersLastMonth = orders
        .where((order) => now.difference(order.createdAt).inDays <= 30)
        .length;

    final double orderFrequency = ordersLastMonth / 4.0; // orders per week

    // Loyalty score
    final double loyaltyScore = _calculateLoyaltyScore(orders);

    // Order consistency
    final bool isConsistent = orders.length > 3 &&
        orders.take(3).every((order) => orders.first.items.any((firstItem) =>
            order.items.any((orderItem) => orderItem.name == firstItem.name),),);

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

    final DateTime now = DateTime.now();
    final int daysSinceLastOrder =
        orders.isEmpty ? 999 : now.difference(orders.first.createdAt).inDays;

    double churnRisk = 0.0;

    // Days since last order factor
    if (daysSinceLastOrder > 30) {
      churnRisk += 0.4;
    } else if (daysSinceLastOrder > 14) {
      churnRisk += 0.2;
    }

    // Order frequency factor
    final int recentOrders = orders
        .where((order) => now.difference(order.createdAt).inDays <= 30)
        .length;
    if (recentOrders == 0) {
      churnRisk += 0.3;
    } else if (recentOrders < 2) {
      churnRisk += 0.2;
    }

    // Engagement factor
    if (user.loyaltyPoints < 100) {
      churnRisk += 0.1;
    }

    return churnRisk.clamp(0.0, 1.0);
  }

  double _calculateLoyaltyScore(List<Order> orders) {
    double score = 0.0;

    // Order count contribution
    score += (orders.length * 0.1).clamp(0.0, 0.3);

    // Consistency contribution
    if (orders.length > 1) {
      final DateTime firstOrder = orders.last.createdAt;
      final DateTime lastOrder = orders.first.createdAt;
      final int daysBetween = lastOrder.difference(firstOrder).inDays;

      if (daysBetween > 0) {
        final double consistency =
            orders.length / (daysBetween / 7.0); // orders per week
        score += (consistency * 0.05).clamp(0.0, 0.3);
      }
    }

    // Recent activity contribution
    final DateTime now = DateTime.now();
    final int recentOrders = orders
        .where((order) => now.difference(order.createdAt).inDays <= 30)
        .length;
    score += (recentOrders * 0.02).clamp(0.0, 0.4);

    return score.clamp(0.0, 1.0);
  }

  List<String> _generateRecommendedActions(Map<String, dynamic> preferences,
      Map<String, dynamic> behaviorPatterns, double churnRisk,) {
    final List<String> actions = [];

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

  // CRUD Operations for Marketing Campaigns

  /// Create a new marketing campaign in Supabase
  Future<MarketingCampaign> createCampaign(MarketingCampaign campaign) async {
    try {
      final campaignData = campaign.toMap();
      // Remove id to let Supabase generate UUID
      campaignData.remove('id');

      final response = await SupabaseConfig.client
          .from('marketing_campaigns')
          .insert(campaignData)
          .select()
          .single();

      final createdCampaign = MarketingCampaign.fromMap(response);
      _campaigns.add(createdCampaign);
      notifyListeners();

      debugPrint('✅ Created marketing campaign: ${createdCampaign.name}');
      return createdCampaign;
    } catch (e) {
      debugPrint('❌ Error creating marketing campaign: $e');
      rethrow;
    }
  }

  /// Update an existing marketing campaign in Supabase
  Future<MarketingCampaign> updateCampaign(MarketingCampaign campaign) async {
    try {
      final campaignData = campaign.toMap();
      // Don't update id, created_at
      campaignData.remove('id');
      campaignData.remove('created_at');

      final response = await SupabaseConfig.client
          .from('marketing_campaigns')
          .update(campaignData)
          .eq('id', campaign.id)
          .select()
          .single();

      final updatedCampaign = MarketingCampaign.fromMap(response);
      final index = _campaigns.indexWhere((c) => c.id == campaign.id);
      if (index != -1) {
        _campaigns[index] = updatedCampaign;
        notifyListeners();
      }

      debugPrint('✅ Updated marketing campaign: ${updatedCampaign.name}');
      return updatedCampaign;
    } catch (e) {
      debugPrint('❌ Error updating marketing campaign: $e');
      rethrow;
    }
  }

  /// Delete a marketing campaign from Supabase
  Future<void> deleteCampaign(String campaignId) async {
    try {
      await SupabaseConfig.client
          .from('marketing_campaigns')
          .delete()
          .eq('id', campaignId);

      _campaigns.removeWhere((c) => c.id == campaignId);
      notifyListeners();

      debugPrint('✅ Deleted marketing campaign: $campaignId');
    } catch (e) {
      debugPrint('❌ Error deleting marketing campaign: $e');
      rethrow;
    }
  }

  /// Get a single campaign by ID
  Future<MarketingCampaign?> getCampaign(String campaignId) async {
    try {
      final response = await SupabaseConfig.client
          .from('marketing_campaigns')
          .select()
          .eq('id', campaignId)
          .maybeSingle();

      if (response != null) {
        return MarketingCampaign.fromMap(response);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting marketing campaign: $e');
      return null;
    }
  }

  /// Update campaign metrics in Supabase
  Future<void> updateCampaignMetrics(
    String campaignId,
    Map<String, dynamic> metricsUpdate,
  ) async {
    try {
      // Get current campaign
      final campaignIndex = _campaigns.indexWhere((c) => c.id == campaignId);
      if (campaignIndex == -1) {
        debugPrint('⚠️ Campaign not found: $campaignId');
        return;
      }

      final campaign = _campaigns[campaignIndex];
      final updatedMetrics = Map<String, dynamic>.from(campaign.metrics);
      updatedMetrics.addAll(metricsUpdate);

      // Update in Supabase
      await SupabaseConfig.client
          .from('marketing_campaigns')
          .update({'metrics': updatedMetrics}).eq('id', campaignId);

      // Update local cache
      final updatedCampaign = MarketingCampaign(
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
        metrics: updatedMetrics,
      );

      _campaigns[campaignIndex] = updatedCampaign;
      notifyListeners();

      debugPrint('✅ Updated metrics for campaign: $campaignId');
    } catch (e) {
      debugPrint('❌ Error updating campaign metrics: $e');
      rethrow;
    }
  }

  // Automated Marketing Campaigns

  /// Create personalized marketing campaigns
  Future<List<MarketingCampaign>> createPersonalizedCampaigns({
    required List<User> users,
    required Map<String, List<Order>> userOrders,
  }) async {
    final List<MarketingCampaign> campaigns = [];

    // Win-back campaign for inactive users
    final List<String> inactiveUsers = [];
    final DateTime thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    for (final user in users) {
      final List<Order> orders = userOrders[user.id] ?? [];
      final bool hasRecentOrder =
          orders.any((order) => order.createdAt.isAfter(thirtyDaysAgo));

      if (!hasRecentOrder && orders.isNotEmpty) {
        inactiveUsers.add(user.id);
      }
    }

    if (inactiveUsers.isNotEmpty) {
      final winBackCampaign = MarketingCampaign(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Win-Back Campaign',
        type: 'retention',
        title: '🎯 On vous a manqué !',
        message:
            'Revenez chez FastFoodGo avec 25% de réduction sur votre prochaine commande !',
        targetUserIds: inactiveUsers,
        conditions: {'lastOrderDays': '>30'},
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
      );

      try {
        final createdCampaign = await createCampaign(winBackCampaign);
        campaigns.add(createdCampaign);
      } catch (e) {
        debugPrint('❌ Error creating win-back campaign: $e');
        // Add to local list even if Supabase fails
        campaigns.add(winBackCampaign);
        _campaigns.add(winBackCampaign);
      }
    }

    // Loyalty reward campaign
    final List<String> loyalUsers = [];
    for (final user in users) {
      if (user.loyaltyPoints > 500) {
        loyalUsers.add(user.id);
      }
    }

    if (loyalUsers.isNotEmpty) {
      final loyaltyCampaign = MarketingCampaign(
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
      );

      try {
        final createdCampaign = await createCampaign(loyaltyCampaign);
        campaigns.add(createdCampaign);
      } catch (e) {
        debugPrint('❌ Error creating loyalty campaign: $e');
        // Add to local list even if Supabase fails
        campaigns.add(loyaltyCampaign);
        _campaigns.add(loyaltyCampaign);
      }
    }

    if (campaigns.isNotEmpty) {
      notifyListeners();
    }

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

      // Update campaign metrics in Supabase
      final campaignIndex = _campaigns.indexWhere((c) => c.id == campaignId);
      if (campaignIndex == -1) {
        debugPrint('⚠️ Campaign not found: $campaignId');
        return false;
      }

      final currentCampaign = _campaigns[campaignIndex];
      final metricsUpdate = {
        'sent': (currentCampaign.metrics['sent'] ?? 0) + userIds.length,
        'lastSent': DateTime.now().toIso8601String(),
      };

      await updateCampaignMetrics(campaignId, metricsUpdate);

      return true;
    } catch (e) {
      debugPrint('❌ Error sending targeted notification: $e');
      // Fallback: update local cache only
      try {
        final int campaignIndex = _campaigns.indexWhere((c) => c.id == campaignId);
        if (campaignIndex != -1) {
          final campaign = _campaigns[campaignIndex];
          final Map<String, dynamic> newMetrics = Map.from(campaign.metrics);
          newMetrics['sent'] = (newMetrics['sent'] ?? 0) + userIds.length;
          newMetrics['lastSent'] = DateTime.now().toIso8601String();

          final MarketingCampaign updatedCampaign = MarketingCampaign(
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
      } catch (localError) {
        debugPrint('❌ Error updating local campaign metrics: $localError');
      }
      return false;
    }
  }

  /// Get marketing dashboard data
  Map<String, dynamic> getMarketingDashboard() {
    final DateTime now = DateTime.now();

    final int activeCampaigns =
        _campaigns.where((c) => c.isActive && c.endDate.isAfter(now)).length;

    final num totalSent =
        _campaigns.fold(0, (sum, c) => sum + (c.metrics['sent'] ?? 0));

    final num totalClicks =
        _campaigns.fold(0, (sum, c) => sum + (c.metrics['clicks'] ?? 0));

    final double clickRate = totalSent > 0 ? (totalClicks / totalSent) * 100 : 0.0;

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
              insight.behaviorPatterns['loyaltyScore'] > 0.7,)
          .length,
      'pendingActions': _customerInsights.values
          .expand((insight) => insight.recommendedActions)
          .length,
    };
  }

  /// Get campaign performance
  Map<String, dynamic> getCampaignPerformance(String campaignId) {
    try {
      final campaign = _campaigns.firstWhere((c) => c.id == campaignId);

      final int sent = campaign.metrics['sent'] ?? 0;
      final int clicks = campaign.metrics['clicks'] ?? 0;
      final int conversions = campaign.metrics['conversions'] ?? 0;
      final int views = campaign.metrics['views'] ?? 0;

      return {
        'sent': sent,
        'clicks': clicks,
        'conversions': conversions,
        'views': views,
        'clickRate':
            sent > 0 ? (clicks / sent * 100).toStringAsFixed(1) : '0.0',
        'conversionRate': clicks > 0
            ? (conversions / clicks * 100).toStringAsFixed(1)
            : '0.0',
        'viewRate': sent > 0 ? (views / sent * 100).toStringAsFixed(1) : '0.0',
        'isActive': campaign.isActive,
        'daysRemaining': campaign.endDate.difference(DateTime.now()).inDays,
      };
    } catch (e) {
      debugPrint('❌ Error getting campaign performance: $e');
      return {
        'sent': 0,
        'clicks': 0,
        'conversions': 0,
        'views': 0,
        'clickRate': '0.0',
        'conversionRate': '0.0',
        'viewRate': '0.0',
        'isActive': false,
        'daysRemaining': 0,
      };
    }
  }

  /// Record campaign view (when user sees the campaign)
  Future<void> recordCampaignView(String campaignId) async {
    try {
      final campaignIndex = _campaigns.indexWhere((c) => c.id == campaignId);
      if (campaignIndex == -1) {
        debugPrint('⚠️ Campaign not found for view: $campaignId');
        return;
      }

      final currentCampaign = _campaigns[campaignIndex];
      final metricsUpdate = {
        'views': (currentCampaign.metrics['views'] ?? 0) + 1,
        'lastViewed': DateTime.now().toIso8601String(),
      };

      await updateCampaignMetrics(campaignId, metricsUpdate);
    } catch (e) {
      debugPrint('❌ Error recording campaign view: $e');
    }
  }

  /// Record campaign click (when user clicks on the campaign)
  Future<void> recordCampaignClick(String campaignId) async {
    try {
      final campaignIndex = _campaigns.indexWhere((c) => c.id == campaignId);
      if (campaignIndex == -1) {
        debugPrint('⚠️ Campaign not found for click: $campaignId');
        return;
      }

      final currentCampaign = _campaigns[campaignIndex];
      final metricsUpdate = {
        'clicks': (currentCampaign.metrics['clicks'] ?? 0) + 1,
        'lastClicked': DateTime.now().toIso8601String(),
      };

      await updateCampaignMetrics(campaignId, metricsUpdate);
    } catch (e) {
      debugPrint('❌ Error recording campaign click: $e');
    }
  }

  /// Record campaign conversion (when user completes an action from the campaign)
  Future<void> recordCampaignConversion(String campaignId) async {
    try {
      final campaignIndex = _campaigns.indexWhere((c) => c.id == campaignId);
      if (campaignIndex == -1) {
        debugPrint('⚠️ Campaign not found for conversion: $campaignId');
        return;
      }

      final currentCampaign = _campaigns[campaignIndex];
      final metricsUpdate = {
        'conversions': (currentCampaign.metrics['conversions'] ?? 0) + 1,
        'lastConversion': DateTime.now().toIso8601String(),
      };

      await updateCampaignMetrics(campaignId, metricsUpdate);
    } catch (e) {
      debugPrint('❌ Error recording campaign conversion: $e');
    }
  }

  void clearMarketingData() {
    _campaigns.clear();
    _analytics.clear();
    _customerInsights.clear();
    notifyListeners();
  }
}
