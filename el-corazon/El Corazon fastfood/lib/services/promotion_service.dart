import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Promotion {
  final String id;
  final String name;
  final String description;
  final String promoCode;
  final String discountType; // 'percentage', 'fixed', 'free_delivery'
  final double discountValue;
  final double minOrderAmount;
  final double? maxDiscount;
  final int? usageLimit;
  final int usedCount;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Promotion({
    required this.id,
    required this.name,
    required this.description,
    required this.promoCode,
    required this.discountType,
    required this.discountValue,
    required this.startDate, required this.endDate, required this.createdBy, required this.createdAt, required this.updatedAt, this.minOrderAmount = 0.0,
    this.maxDiscount,
    this.usageLimit,
    this.usedCount = 0,
    this.isActive = true,
  });

  bool get isExpired => DateTime.now().isAfter(endDate);
  bool get isAvailable =>
      isActive && !isExpired && (usageLimit == null || usedCount < usageLimit!);

  double calculateDiscount(double orderAmount) {
    if (!isAvailable || orderAmount < minOrderAmount) {
      return 0;
    }

    double discount = 0.0;
    switch (discountType) {
      case 'percentage':
        discount = (orderAmount * discountValue / 100);
        if (maxDiscount != null && discount > maxDiscount!) {
          discount = maxDiscount!;
        }
        break;
      case 'fixed':
        discount = discountValue;
        break;
      case 'free_delivery':
        discount = 0; // Will be handled separately
        break;
      default:
        discount = 0;
    }

    return discount.clamp(0, orderAmount);
  }

  factory Promotion.fromMap(Map<String, dynamic> map) {
    return Promotion(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      promoCode: map['promo_code'] as String,
      discountType: map['discount_type'] as String,
      discountValue: (map['discount_value'] as num).toDouble(),
      minOrderAmount: (map['min_order_amount'] as num?)?.toDouble() ?? 0.0,
      maxDiscount: (map['max_discount'] as num?)?.toDouble(),
      usageLimit: map['usage_limit'] as int?,
      usedCount: map['used_count'] as int? ?? 0,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      isActive: map['is_active'] as bool? ?? true,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'promo_code': promoCode,
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_order_amount': minOrderAmount,
      'max_discount': maxDiscount,
      'usage_limit': usageLimit,
      'used_count': usedCount,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class PromotionService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Promotion> _promotions = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _promotionsChannel;

  List<Promotion> get promotions => List.unmodifiable(_promotions);
  List<Promotion> get activePromotions =>
      _promotions.where((promo) => promo.isAvailable).toList();
  List<Promotion> get expiredPromotions =>
      _promotions.where((promo) => promo.isExpired).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  PromotionService() {
    _loadPromotions();
    _subscribeToPromotionsRealtime();
  }

  @override
  void dispose() {
    _promotionsChannel?.unsubscribe();
    super.dispose();
  }

  /// Charger toutes les promotions depuis la base de données
  Future<void> _loadPromotions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('promotions')
          .select()
          .eq('is_active', true)
          .gte('end_date', now)
          .lte('start_date', now)
          .order('created_at', ascending: false);

      _promotions = (response as List)
          .map((data) => Promotion.fromMap(data))
          .toList();

      debugPrint('PromotionService: ${_promotions.length} promotions chargées');
    } catch (e) {
      _error = e.toString();
      _promotions = [];
      debugPrint('PromotionService: Erreur chargement promotions - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// S'abonner aux mises à jour en temps réel
  void _subscribeToPromotionsRealtime() {
    try {
      _promotionsChannel = _supabase
          .channel('client_promotions_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'promotions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'is_active',
              value: true,
            ),
            callback: (payload) {
              final data = Map<String, dynamic>.from(payload.newRecord);
              final promotion = Promotion.fromMap(data);
              if (promotion.isAvailable) {
                _promotions.insert(0, promotion);
                notifyListeners();
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'promotions',
            callback: (payload) {
              final data = Map<String, dynamic>.from(payload.newRecord);
              final promotion = Promotion.fromMap(data);
              final index = _promotions.indexWhere((p) => p.id == promotion.id);
              if (index != -1) {
                _promotions[index] = promotion;
              } else if (promotion.isAvailable) {
                _promotions.insert(0, promotion);
              }
              notifyListeners();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to realtime promotions: $e');
    }
  }

  /// Obtenir une promotion par son code
  Promotion? getPromotionByCode(String code) {
    try {
      return _promotions.firstWhere(
        (promo) =>
            promo.promoCode.toUpperCase() == code.toUpperCase() &&
            promo.isAvailable,
      );
    } catch (e) {
      return null;
    }
  }

  /// Valider un code promo
  Future<Map<String, dynamic>?> validatePromoCode({
    required String code,
    required double orderAmount,
    String? userId,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('promotions')
          .select()
          .eq('promo_code', code.toUpperCase())
          .eq('is_active', true)
          .gte('end_date', now)
          .lte('start_date', now)
          .maybeSingle();

      if (response == null) {
        return {'valid': false, 'error': 'Code promo non trouvé'};
      }

      final promotion = Promotion.fromMap(response);

      // Vérifier le montant minimum
      if (orderAmount < promotion.minOrderAmount) {
        return {
          'valid': false,
          'error':
              'Montant minimum de ${promotion.minOrderAmount} FCFA requis',
        };
      }

      // Vérifier la limite d'utilisation
      if (promotion.usageLimit != null &&
          promotion.usedCount >= promotion.usageLimit!) {
        return {'valid': false, 'error': 'Code promo épuisé'};
      }

      // Vérifier si l'utilisateur a déjà utilisé ce code
      if (userId != null) {
        final usageResponse = await _supabase
            .from('promotion_usage')
            .select('id')
            .eq('promotion_id', promotion.id)
            .eq('user_id', userId)
            .maybeSingle();

        if (usageResponse != null) {
          return {
            'valid': false,
            'error': 'Vous avez déjà utilisé ce code promo',
          };
        }
      }

      final discount = promotion.calculateDiscount(orderAmount);

      return {
        'valid': true,
        'promotion': promotion.toMap(),
        'discount': discount,
        'isFreeDelivery': promotion.discountType == 'free_delivery',
      };
    } catch (e) {
      debugPrint('PromotionService: Erreur validation code promo - $e');
      return {'valid': false, 'error': 'Erreur lors de la validation'};
    }
  }

  /// Utiliser une promotion (enregistrer l'utilisation)
  Future<bool> usePromotion({
    required String promotionId,
    required String userId,
    required String orderId,
    required double discountAmount,
  }) async {
    try {
      // Enregistrer l'utilisation
      await _supabase.from('promotion_usage').insert({
        'promotion_id': promotionId,
        'user_id': userId,
        'order_id': orderId,
        'discount_amount': discountAmount,
      });

      // Incrémenter le compteur d'utilisation
      // Récupérer la valeur actuelle et incrémenter
      final currentPromotion = await _supabase
          .from('promotions')
          .select('used_count')
          .eq('id', promotionId)
          .single();
      
      final currentCount = (currentPromotion['used_count'] as int? ?? 0);
      await _supabase
          .from('promotions')
          .update({'used_count': currentCount + 1})
          .eq('id', promotionId);

      // Recharger les promotions
      await _loadPromotions();

      return true;
    } catch (e) {
      debugPrint('PromotionService: Erreur utilisation promotion - $e');
      return false;
    }
  }

  List<Promotion> getFeaturedPromotions({int limit = 3}) {
    return activePromotions.take(limit).toList();
  }

  Future<void> initialize() async {
    await _loadPromotions();
  }

  Future<void> refresh() async {
    await _loadPromotions();
  }
}
