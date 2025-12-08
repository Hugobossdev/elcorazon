import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/models/promo_code.dart';

/// Service de codes promo utilisant Supabase directement
class PromoCodeService extends ChangeNotifier {
  static final PromoCodeService _instance = PromoCodeService._internal();
  factory PromoCodeService() => _instance;
  PromoCodeService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<PromoCode> _promoCodes = [];
  PromoCode? _currentPromoCode;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _promoCodesChannel;

  // Getters
  List<PromoCode> get promoCodes => List.unmodifiable(_promoCodes);
  PromoCode? get currentPromoCode => _currentPromoCode;
  bool get isInitialized => _isInitialized;
  bool get hasActivePromoCode => _currentPromoCode != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void dispose() {
    _promoCodesChannel?.unsubscribe();
    super.dispose();
  }

  /// Initialise le service et charge les codes promo depuis Supabase
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _loadPromoCodes();
      _subscribeToPromoCodesRealtime();

      _isInitialized = true;
      debugPrint(
          'PromoCodeService: Initialisé avec ${_promoCodes.length} codes promo',);
    } catch (e) {
      _error = e.toString();
      debugPrint('PromoCodeService: Erreur d\'initialisation - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charge les codes promo depuis Supabase
  Future<void> _loadPromoCodes() async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('promotions')
          .select()
          .eq('is_active', true)
          .gte('end_date', now) // Date de fin >= maintenant (pas encore expiré)
          .lte('start_date', now) // Date de début <= maintenant (déjà commencé)
          .order('created_at', ascending: false);

      _promoCodes = (response as List).map((data) {
        return _promotionToPromoCode(data);
      }).toList();

      debugPrint('PromoCodeService: ${_promoCodes.length} codes promo chargés');
    } catch (e) {
      _error = e.toString();
      _promoCodes = [];
      debugPrint('PromoCodeService: Erreur de chargement des codes promo - $e');
    }
  }

  /// Convertit une promotion Supabase en PromoCode
  PromoCode _promotionToPromoCode(Map<String, dynamic> data) {
    // Déterminer le type de code promo
    PromoCodeType type;
    switch (data['discount_type']) {
      case 'percentage':
        type = PromoCodeType.percentage;
        break;
      case 'fixed':
        type = PromoCodeType.fixedAmount;
        break;
      case 'free_delivery':
        type = PromoCodeType.freeDelivery;
        break;
      default:
        type = PromoCodeType.percentage;
    }

    // Déterminer le statut
    PromoCodeStatus status;
    final isExpired = DateTime.now().isAfter(DateTime.parse(data['end_date']));
    final isUsedUp = data['usage_limit'] != null &&
        (data['used_count'] as int) >= (data['usage_limit'] as int);

    if (!data['is_active']) {
      status = PromoCodeStatus.inactive;
    } else if (isExpired) {
      status = PromoCodeStatus.expired;
    } else if (isUsedUp) {
      status = PromoCodeStatus.usedUp;
    } else {
      status = PromoCodeStatus.active;
    }

    return PromoCode(
      id: data['id'] as String,
      code: data['promo_code'] as String,
      name: data['name'] as String,
      description: data['description'] as String,
      type: type,
      value: (data['discount_value'] as num).toDouble(),
      minimumOrderAmount: (data['min_order_amount'] as num?)?.toDouble(),
      maximumDiscountAmount: (data['max_discount'] as num?)?.toDouble(),
      usageLimit: data['usage_limit'] as int?,
      usageCount: data['used_count'] as int? ?? 0,
      startDate: DateTime.parse(data['start_date'] as String),
      endDate: DateTime.parse(data['end_date'] as String),
      status: status,
      applicableCategories: const [], // Non disponible dans promotions
      applicableItems: const [], // Non disponible dans promotions
      isForNewUsersOnly: false, // Non disponible dans promotions
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }

  /// S'abonner aux mises à jour en temps réel
  void _subscribeToPromoCodesRealtime() {
    try {
      _promoCodesChannel = _supabase
          .channel('client_promo_codes_realtime')
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
              final promoCode = _promotionToPromoCode(data);
              if (promoCode.isValid) {
                _promoCodes.insert(0, promoCode);
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
              final promoCode = _promotionToPromoCode(data);
              final index =
                  _promoCodes.indexWhere((pc) => pc.id == promoCode.id);
              if (index != -1) {
                _promoCodes[index] = promoCode;
              } else if (promoCode.isValid) {
                _promoCodes.insert(0, promoCode);
              }
              notifyListeners();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to realtime promo codes: $e');
    }
  }

  /// Valide et applique un code promo
  Future<PromoCodeValidationResult> validateAndApplyPromoCode({
    required String code,
    required double orderAmount,
    required String userId,
    bool isNewUser = false,
  }) async {
    try {
      // Rechercher le code promo dans la liste locale
      final promoCode = _promoCodes
          .where((pc) => pc.code.toUpperCase() == code.toUpperCase())
          .firstOrNull;

      if (promoCode == null) {
        // Essayer de charger depuis Supabase
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
          return PromoCodeValidationResult(
            isValid: false,
            errorMessage: 'Code promo non trouvé',
          );
        }

        final loadedPromoCode = _promotionToPromoCode(response);
        if (!loadedPromoCode.isValid) {
          return PromoCodeValidationResult(
            isValid: false,
            errorMessage: 'Code promo non valide',
          );
        }

        // Vérifier le montant minimum
        if (loadedPromoCode.minimumOrderAmount != null &&
            orderAmount < loadedPromoCode.minimumOrderAmount!) {
          return PromoCodeValidationResult(
            isValid: false,
            errorMessage:
                'Commande minimum de ${loadedPromoCode.minimumOrderAmount!.toInt()} FCFA requise',
          );
        }

        // Vérifier si l'utilisateur a déjà utilisé ce code
        final usageResponse = await _supabase
            .from('promotion_usage')
            .select('id')
            .eq('promotion_id', loadedPromoCode.id)
            .eq('user_id', userId)
            .maybeSingle();

        if (usageResponse != null) {
          return PromoCodeValidationResult(
            isValid: false,
            errorMessage: 'Vous avez déjà utilisé ce code promo',
          );
        }

        // Calculer la réduction
        final discountAmount = loadedPromoCode.calculateDiscount(orderAmount);

        // Appliquer le code promo
        _currentPromoCode = loadedPromoCode;

        notifyListeners();

        return PromoCodeValidationResult(
          isValid: true,
          promoCode: loadedPromoCode,
          discountAmount: discountAmount,
          isFreeDelivery: loadedPromoCode.type == PromoCodeType.freeDelivery,
        );
      }

      // Vérifier si le code est valide
      if (!promoCode.isValid) {
        String errorMessage = 'Code promo non valide';
        if (promoCode.isExpired) {
          errorMessage = 'Code promo expiré';
        } else if (promoCode.isUsedUp) {
          errorMessage = 'Code promo épuisé';
        } else if (promoCode.status != PromoCodeStatus.active) {
          errorMessage = 'Code promo inactif';
        }

        return PromoCodeValidationResult(
          isValid: false,
          errorMessage: errorMessage,
        );
      }

      // Vérifier le montant minimum de commande
      if (promoCode.minimumOrderAmount != null &&
          orderAmount < promoCode.minimumOrderAmount!) {
        return PromoCodeValidationResult(
          isValid: false,
          errorMessage:
              'Commande minimum de ${promoCode.minimumOrderAmount!.toInt()} FCFA requise',
        );
      }

      // Vérifier si c'est pour les nouveaux utilisateurs uniquement
      if (promoCode.isForNewUsersOnly && !isNewUser) {
        return PromoCodeValidationResult(
          isValid: false,
          errorMessage: 'Ce code est réservé aux nouveaux utilisateurs',
        );
      }

      // Vérifier si l'utilisateur a déjà utilisé ce code
      final usageResponse = await _supabase
          .from('promotion_usage')
          .select('id')
          .eq('promotion_id', promoCode.id)
          .eq('user_id', userId)
          .maybeSingle();

      if (usageResponse != null) {
        return PromoCodeValidationResult(
          isValid: false,
          errorMessage: 'Vous avez déjà utilisé ce code promo',
        );
      }

      // Calculer la réduction
      final discountAmount = promoCode.calculateDiscount(orderAmount);

      // Appliquer le code promo
      _currentPromoCode = promoCode;

      notifyListeners();

      return PromoCodeValidationResult(
        isValid: true,
        promoCode: promoCode,
        discountAmount: discountAmount,
        isFreeDelivery: promoCode.type == PromoCodeType.freeDelivery,
      );
    } catch (e) {
      debugPrint('PromoCodeService: Erreur de validation du code promo - $e');
      return PromoCodeValidationResult(
        isValid: false,
        errorMessage: 'Erreur lors de la validation du code promo',
      );
    }
  }

  /// Retire le code promo actuel
  void removeCurrentPromoCode() {
    _currentPromoCode = null;
    notifyListeners();
  }

  /// Enregistre l'utilisation d'un code promo
  Future<void> recordPromoCodeUsage({
    required String userId,
    required String orderId,
    required double discountAmount,
  }) async {
    if (_currentPromoCode == null) return;

    try {
      // Enregistrer l'utilisation dans Supabase
      await _supabase.from('promotion_usage').insert({
        'promotion_id': _currentPromoCode!.id,
        'user_id': userId,
        'order_id': orderId,
        'discount_amount': discountAmount,
      });

      // Incrémenter le compteur d'utilisation
      // Récupérer la valeur actuelle et incrémenter
      final currentPromotion = await _supabase
          .from('promotions')
          .select('used_count')
          .eq('id', _currentPromoCode!.id)
          .single();
      
      final currentCount = (currentPromotion['used_count'] as int? ?? 0);
      await _supabase
          .from('promotions')
          .update({'used_count': currentCount + 1})
          .eq('id', _currentPromoCode!.id);

      // Recharger les codes promo
      await _loadPromoCodes();

      debugPrint('PromoCodeService: Utilisation du code promo enregistrée');
    } catch (e) {
      debugPrint(
          'PromoCodeService: Erreur d\'enregistrement de l\'utilisation - $e',);
    }
  }

  /// Obtient les codes promo actifs
  List<PromoCode> getActivePromoCodes() {
    return _promoCodes.where((pc) => pc.isValid).toList();
  }

  /// Obtient les codes promo par type
  List<PromoCode> getPromoCodesByType(PromoCodeType type) {
    return _promoCodes.where((pc) => pc.type == type && pc.isValid).toList();
  }

  /// Obtient les codes promo pour nouveaux utilisateurs
  List<PromoCode> getNewUserPromoCodes() {
    return _promoCodes
        .where((pc) => pc.isForNewUsersOnly && pc.isValid)
        .toList();
  }

  /// Recherche des codes promo
  List<PromoCode> searchPromoCodes(String query) {
    if (query.isEmpty) return getActivePromoCodes();

    final lowercaseQuery = query.toLowerCase();
    return _promoCodes
        .where((promoCode) =>
            promoCode.code.toLowerCase().contains(lowercaseQuery) ||
            promoCode.name.toLowerCase().contains(lowercaseQuery) ||
            promoCode.description.toLowerCase().contains(lowercaseQuery),)
        .toList();
  }

  /// Obtient l'historique des utilisations d'un utilisateur
  Future<List<Map<String, dynamic>>> getUserPromoCodeUsages(String userId) async {
    try {
      final response = await _supabase
          .from('promotion_usage')
          .select('*, promotions(name, promo_code)')
          .eq('user_id', userId)
          .order('used_at', ascending: false);

      return (response as List).map((usage) {
        return {
          'id': usage['id'],
          'promoCodeId': usage['promotion_id'],
          'promoCodeName': usage['promotions']?['name'],
          'promoCode': usage['promotions']?['promo_code'],
          'orderId': usage['order_id'],
          'discountAmount': usage['discount_amount'],
          'usedAt': usage['used_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('PromoCodeService: Erreur historique utilisations - $e');
      return [];
    }
  }

  /// Obtient les statistiques des codes promo
  Map<String, dynamic> getPromoCodeStats() {
    final activeCount = _promoCodes.where((pc) => pc.isValid).length;
    final expiredCount = _promoCodes.where((pc) => pc.isExpired).length;
    final usedUpCount = _promoCodes.where((pc) => pc.isUsedUp).length;

    return {
      'total': _promoCodes.length,
      'active': activeCount,
      'expired': expiredCount,
      'used_up': usedUpCount,
      'current_code': _currentPromoCode?.code,
    };
  }

  /// Rafraîchir les codes promo
  Future<void> refresh() async {
    await _loadPromoCodes();
    notifyListeners();
  }
}

class PromoCodeValidationResult {
  final bool isValid;
  final PromoCode? promoCode;
  final double discountAmount;
  final bool isFreeDelivery;
  final String? errorMessage;

  PromoCodeValidationResult({
    required this.isValid,
    this.promoCode,
    this.discountAmount = 0.0,
    this.isFreeDelivery = false,
    this.errorMessage,
  });
}

