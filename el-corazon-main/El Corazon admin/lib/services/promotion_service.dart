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
    this.minOrderAmount = 0.0,
    this.maxDiscount,
    this.usageLimit,
    this.usedCount = 0,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
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
      final response = await _supabase
          .from('promotions')
          .select('*')
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
          .channel('admin_promotions_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'promotions',
            callback: (payload) {
              final data = Map<String, dynamic>.from(payload.newRecord);
              final promotion = Promotion.fromMap(data);
              _promotions.insert(0, promotion);
              notifyListeners();
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
                notifyListeners();
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'promotions',
            callback: (payload) {
              final oldData = Map<String, dynamic>.from(payload.oldRecord);
              final id = oldData['id'] as String?;
              if (id != null) {
                _promotions.removeWhere((p) => p.id == id);
                notifyListeners();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to realtime promotions: $e');
    }
  }

  /// Créer une nouvelle promotion
  Future<Promotion?> createPromotion({
    required String name,
    required String description,
    required String promoCode,
    required String discountType,
    required double discountValue,
    double minOrderAmount = 0.0,
    double? maxDiscount,
    int? usageLimit,
    required DateTime startDate,
    required DateTime endDate,
    bool isActive = true,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Vérifier que le code promo n'existe pas déjà
      final existing = await _supabase
          .from('promotions')
          .select('id')
          .eq('promo_code', promoCode.toUpperCase())
          .maybeSingle();

      if (existing != null) {
        _error = 'Un code promo avec ce code existe déjà';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Récupérer l'ID de l'admin actuel
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        _error = 'Vous devez être connecté pour créer une promotion';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_user_id', currentUser.id)
          .maybeSingle();

      if (userResponse == null) {
        _error = 'Utilisateur non trouvé';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final createdBy = userResponse['id'] as String;

      final response = await _supabase
          .from('promotions')
          .insert({
            'name': name,
            'description': description,
            'promo_code': promoCode.toUpperCase(),
            'discount_type': discountType,
            'discount_value': discountValue,
            'min_order_amount': minOrderAmount,
            'max_discount': maxDiscount,
            'usage_limit': usageLimit,
            'used_count': 0,
            'start_date': startDate.toIso8601String(),
            'end_date': endDate.toIso8601String(),
            'is_active': isActive,
            'created_by': createdBy,
          })
          .select()
          .single();

      final promotion = Promotion.fromMap(response);
      _promotions.insert(0, promotion);

      _isLoading = false;
      notifyListeners();
      return promotion;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('PromotionService: Erreur création promotion - $e');
      return null;
    }
  }

  /// Mettre à jour une promotion
  Future<bool> updatePromotion(String id, Map<String, dynamic> updates) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      updates['updated_at'] = DateTime.now().toIso8601String();

      // Si le code promo est modifié, vérifier qu'il n'existe pas déjà
      if (updates.containsKey('promo_code')) {
        final existing = await _supabase
            .from('promotions')
            .select('id')
            .eq('promo_code', updates['promo_code'].toString().toUpperCase())
            .neq('id', id)
            .maybeSingle();

        if (existing != null) {
          _error = 'Un code promo avec ce code existe déjà';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        updates['promo_code'] = updates['promo_code'].toString().toUpperCase();
      }

      await _supabase.from('promotions').update(updates).eq('id', id);

      // Recharger les promotions
      await _loadPromotions();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('PromotionService: Erreur mise à jour promotion - $e');
      return false;
    }
  }

  /// Supprimer une promotion
  Future<bool> deletePromotion(String id) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase.from('promotions').delete().eq('id', id);

      _promotions.removeWhere((p) => p.id == id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('PromotionService: Erreur suppression promotion - $e');
      return false;
    }
  }

  /// Activer/Désactiver une promotion
  Future<bool> togglePromotionStatus(String id, bool isActive) async {
    return await updatePromotion(id, {'is_active': isActive});
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

  /// Obtenir les statistiques d'une promotion
  Future<Map<String, dynamic>> getPromotionStats(String id) async {
    try {
      final promotion = _promotions.firstWhere((p) => p.id == id);

      // Récupérer les utilisations de la promotion
      final usageResponse = await _supabase
          .from('promotion_usage')
          .select('*')
          .eq('promotion_id', id);

      final usages = usageResponse as List;
      final totalDiscount = usages.fold<double>(
        0.0,
        (sum, usage) => sum + ((usage['discount_amount'] as num?)?.toDouble() ?? 0.0),
      );

      final uniqueUsers = usages.map((u) => u['user_id']).toSet().length;

      return {
        'total_uses': usages.length,
        'unique_users': uniqueUsers,
        'total_discount_given': totalDiscount,
        'average_discount': usages.isNotEmpty ? totalDiscount / usages.length : 0.0,
        'usage_rate': promotion.usageLimit != null
            ? (usages.length / promotion.usageLimit!) * 100
            : null,
        'is_active': promotion.isActive,
        'is_expired': promotion.isExpired,
        'days_remaining': promotion.isExpired
            ? 0
            : promotion.endDate.difference(DateTime.now()).inDays,
      };
    } catch (e) {
      debugPrint('PromotionService: Erreur stats promotion - $e');
      return {};
    }
  }

  /// Obtenir l'historique d'utilisation d'une promotion
  Future<List<Map<String, dynamic>>> getPromotionUsageHistory(String id) async {
    try {
      final response = await _supabase
          .from('promotion_usage')
          .select('*, orders(id, total, created_at), users(name, email)')
          .eq('promotion_id', id)
          .order('used_at', ascending: false);

      return (response as List).map((usage) {
        return {
          'id': usage['id'],
          'user_id': usage['user_id'],
          'user_name': usage['users']?['name'],
          'user_email': usage['users']?['email'],
          'order_id': usage['order_id'],
          'order_total': usage['orders']?['total'],
          'discount_amount': usage['discount_amount'],
          'used_at': usage['used_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('PromotionService: Erreur historique utilisation - $e');
      return [];
    }
  }

  /// Rafraîchir les promotions
  Future<void> refresh() async {
    await _loadPromotions();
  }

  /// Initialiser le service
  Future<void> initialize() async {
    await _loadPromotions();
  }
}
