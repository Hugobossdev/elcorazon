import 'package:flutter/foundation.dart';
import 'database_service.dart';

class Promotion {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String discountType; // 'percentage', 'fixed', 'free_delivery'
  final double discountValue;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> applicableCategories;
  final double minimumOrderAmount;
  final String promoCode;
  final bool isActive;
  final int usageLimit;
  final int usageCount;

  Promotion({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.discountType,
    required this.discountValue,
    required this.startDate,
    required this.endDate,
    this.applicableCategories = const [],
    this.minimumOrderAmount = 0,
    required this.promoCode,
    this.isActive = true,
    this.usageLimit = -1, // -1 means unlimited
    this.usageCount = 0,
  });

  bool get isExpired => DateTime.now().isAfter(endDate);
  bool get isAvailable => isActive && !isExpired && (usageLimit == -1 || usageCount < usageLimit);
  
  double calculateDiscount(double orderAmount) {
    if (!isAvailable || orderAmount < minimumOrderAmount) {
      return 0;
    }

    switch (discountType) {
      case 'percentage':
        return (orderAmount * discountValue / 100).clamp(0, orderAmount);
      case 'fixed':
        return discountValue.clamp(0, orderAmount);
      case 'free_delivery':
        return 500; // Assuming 500 FCFA delivery fee
      default:
        return 0;
    }
  }
}

class PromotionService extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final List<Promotion> _promotions = [];
  bool _isLoading = false;

  List<Promotion> get promotions => List.unmodifiable(_promotions);
  List<Promotion> get activePromotions => 
      _promotions.where((promo) => promo.isAvailable).toList();
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadPromotions();
    } catch (e) {
      debugPrint('Error loading promotions: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadPromotions() async {
    try {
      final promotionsData = await _databaseService.getActivePromotions();
      _promotions.clear();
      _promotions.addAll(promotionsData.map((data) {
        return Promotion(
          id: data['id'] as String,
          title: data['title'] as String? ?? data['name'] as String? ?? '',
          description: data['description'] as String? ?? '',
          imageUrl: data['image_url'] as String? ?? '',
          discountType: data['discount_type'] as String? ?? 'percentage',
          discountValue: (data['discount_value'] as num?)?.toDouble() ?? 0.0,
          startDate: DateTime.parse(data['start_date'] as String),
          endDate: DateTime.parse(data['end_date'] as String),
          promoCode: data['promo_code'] as String? ?? '',
          minimumOrderAmount: (data['minimum_order_amount'] as num?)?.toDouble() ?? 0.0,
          isActive: data['is_active'] as bool? ?? true,
          usageLimit: data['usage_limit'] as int? ?? -1,
          usageCount: data['usage_count'] as int? ?? 0,
          applicableCategories: data['applicable_categories'] is List
              ? List<String>.from(data['applicable_categories'])
              : [],
        );
      }).toList());
    } catch (e) {
      debugPrint('Error loading promotions from database: $e');
      // Fallback to empty list if database fails
      _promotions.clear();
    }
  }

  Promotion? getPromotionByCode(String code) {
    try {
      return _promotions.firstWhere(
        (promo) => promo.promoCode.toLowerCase() == code.toLowerCase() && promo.isAvailable,
      );
    } catch (e) {
      return null;
    }
  }

  List<Promotion> getPromotionsForCategory(String category) {
    return _promotions.where((promo) => 
      promo.isAvailable && 
      (promo.applicableCategories.isEmpty || promo.applicableCategories.contains(category))
    ).toList();
  }

  Future<bool> validatePromoCode(String code, double orderAmount, List<String> categories) async {
    try {
      // Validate with database
      final promoData = await _databaseService.validatePromoCode(code);
      if (promoData == null) return false;
      
      final minimumAmount = (promoData['minimum_order_amount'] as num?)?.toDouble() ?? 0.0;
      if (orderAmount < minimumAmount) return false;
      
      // Check if promotion applies to any of the order categories
      final applicableCategories = promoData['applicable_categories'] is List
          ? List<String>.from(promoData['applicable_categories'])
          : [];
      if (applicableCategories.isNotEmpty) {
        final hasApplicableCategory = categories.any(
          (category) => applicableCategories.contains(category),
        );
        if (!hasApplicableCategory) return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('Error validating promo code: $e');
      return false;
    }
  }

  Future<void> usePromotion(String promoId) async {
    try {
      // Check if promotion exists
      _promotions.firstWhere((p) => p.id == promoId);
      // Note: In a real implementation, you would update the database here
      // For now, we'll reload from database to get updated counts
      await _loadPromotions();
      notifyListeners();
    } catch (e) {
      debugPrint('Error using promotion: $e');
    }
  }

  List<Promotion> getFeaturedPromotions({int limit = 3}) {
    return activePromotions.take(limit).toList();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    await _loadPromotions();

    _isLoading = false;
    notifyListeners();
  }
}