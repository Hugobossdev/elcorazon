import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/promo_code.dart';

class PromoCodeService extends ChangeNotifier {
  static final PromoCodeService _instance = PromoCodeService._internal();
  factory PromoCodeService() => _instance;
  PromoCodeService._internal();

  List<PromoCode> _promoCodes = [];
  List<PromoCodeUsage> _promoCodeUsages = [];
  PromoCode? _currentPromoCode;
  bool _isInitialized = false;

  // Getters
  List<PromoCode> get promoCodes => List.unmodifiable(_promoCodes);
  List<PromoCodeUsage> get promoCodeUsages =>
      List.unmodifiable(_promoCodeUsages);
  List<PromoCodeUsage> get usedPromoCodes =>
      List.unmodifiable(_promoCodeUsages);
  PromoCode? get currentPromoCode => _currentPromoCode;
  bool get isInitialized => _isInitialized;
  bool get hasActivePromoCode => _currentPromoCode != null;

  /// Initialise le service et charge les codes promo depuis le stockage local
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadPromoCodes();
      await _loadPromoCodeUsages();
      _isInitialized = true;
      notifyListeners();
      debugPrint(
          'PromoCodeService: Initialisé avec ${_promoCodes.length} codes promo');
    } catch (e) {
      debugPrint('PromoCodeService: Erreur d\'initialisation - $e');
    }
  }

  /// Charge les codes promo depuis le stockage local
  Future<void> _loadPromoCodes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final promoCodesJson = prefs.getStringList('promo_codes') ?? [];

      _promoCodes = promoCodesJson
          .map((json) => PromoCode.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      debugPrint('PromoCodeService: Erreur de chargement des codes promo - $e');
    }
  }

  /// Charge les utilisations des codes promo depuis le stockage local
  Future<void> _loadPromoCodeUsages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usagesJson = prefs.getStringList('promo_code_usages') ?? [];

      _promoCodeUsages = usagesJson
          .map((json) => PromoCodeUsage.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      debugPrint(
          'PromoCodeService: Erreur de chargement des utilisations - $e');
    }
  }

  /// Sauvegarde les codes promo dans le stockage local
  Future<void> _savePromoCodes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final promoCodesJson = _promoCodes
          .map((promoCode) => jsonEncode(promoCode.toJson()))
          .toList();

      await prefs.setStringList('promo_codes', promoCodesJson);
    } catch (e) {
      debugPrint('PromoCodeService: Erreur de sauvegarde des codes promo - $e');
    }
  }

  /// Sauvegarde les utilisations des codes promo dans le stockage local
  Future<void> _savePromoCodeUsages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usagesJson =
          _promoCodeUsages.map((usage) => jsonEncode(usage.toJson())).toList();

      await prefs.setStringList('promo_code_usages', usagesJson);
    } catch (e) {
      debugPrint(
          'PromoCodeService: Erreur de sauvegarde des utilisations - $e');
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
      // Rechercher le code promo
      final promoCode = _promoCodes
          .where((pc) => pc.code.toUpperCase() == code.toUpperCase())
          .firstOrNull;

      if (promoCode == null) {
        return PromoCodeValidationResult(
          isValid: false,
          errorMessage: 'Code promo non trouvé',
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
      final minimumAmount = promoCode.minimumOrderAmount;
      if (minimumAmount != null && orderAmount < minimumAmount) {
        return PromoCodeValidationResult(
          isValid: false,
          errorMessage:
              'Commande minimum de ${minimumAmount.toInt()} FCFA requise',
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
      final hasUsedCode = _promoCodeUsages.any((usage) =>
          usage.userId == userId && usage.promoCodeId == promoCode.id);

      if (hasUsedCode && promoCode.usageLimit == 1) {
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
    final currentPromoCode = _currentPromoCode;
    if (currentPromoCode == null) return;

    try {
      final usage = PromoCodeUsage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        promoCodeId: currentPromoCode.id,
        orderId: orderId,
        discountAmount: discountAmount,
        usedAt: DateTime.now(),
      );

      _promoCodeUsages.add(usage);

      // Incrémenter le compteur d'utilisation
      final index =
          _promoCodes.indexWhere((pc) => pc.id == currentPromoCode.id);
      if (index != -1) {
        _promoCodes[index] = _promoCodes[index].copyWith(
          usageCount: _promoCodes[index].usageCount + 1,
          updatedAt: DateTime.now(),
        );
      }

      await _savePromoCodeUsages();
      await _savePromoCodes();

      debugPrint('PromoCodeService: Utilisation du code promo enregistrée');
    } catch (e) {
      debugPrint(
          'PromoCodeService: Erreur d\'enregistrement de l\'utilisation - $e');
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
            promoCode.description.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Obtient l'historique des utilisations d'un utilisateur
  List<PromoCodeUsage> getUserPromoCodeUsages(String userId) {
    return _promoCodeUsages.where((usage) => usage.userId == userId).toList();
  }

  /// Obtient les statistiques des codes promo
  Map<String, dynamic> getPromoCodeStats() {
    final activeCount = _promoCodes.where((pc) => pc.isValid).length;
    final expiredCount = _promoCodes.where((pc) => pc.isExpired).length;
    final usedUpCount = _promoCodes.where((pc) => pc.isUsedUp).length;
    final totalUsages = _promoCodeUsages.length;

    return {
      'total': _promoCodes.length,
      'active': activeCount,
      'expired': expiredCount,
      'used_up': usedUpCount,
      'total_usages': totalUsages,
      'current_code': _currentPromoCode?.code,
    };
  }

  /// Crée un nouveau code promo (pour les admins)
  Future<PromoCode> createPromoCode({
    required String code,
    required String name,
    required String description,
    required PromoCodeType type,
    required double value,
    double? minimumOrderAmount,
    double? maximumDiscountAmount,
    int? usageLimit,
    required DateTime endDate,
    List<String> applicableCategories = const [],
    List<String> applicableItems = const [],
    bool isForNewUsersOnly = false,
  }) async {
    try {
      final newPromoCode = PromoCode(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        code: code.toUpperCase(),
        name: name,
        description: description,
        type: type,
        value: value,
        minimumOrderAmount: minimumOrderAmount,
        maximumDiscountAmount: maximumDiscountAmount,
        usageLimit: usageLimit,
        usageCount: 0,
        startDate: DateTime.now(),
        endDate: endDate,
        status: PromoCodeStatus.active,
        applicableCategories: applicableCategories,
        applicableItems: applicableItems,
        isForNewUsersOnly: isForNewUsersOnly,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _promoCodes.add(newPromoCode);
      await _savePromoCodes();
      notifyListeners();

      debugPrint('PromoCodeService: Code promo créé - ${newPromoCode.code}');
      return newPromoCode;
    } catch (e) {
      debugPrint('PromoCodeService: Erreur de création du code promo - $e');
      rethrow;
    }
  }

  /// Efface tous les codes promo (pour les tests)
  Future<void> clearAllPromoCodes() async {
    _promoCodes.clear();
    _promoCodeUsages.clear();
    _currentPromoCode = null;
    await _savePromoCodes();
    await _savePromoCodeUsages();
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
