import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/services/admin_auth_service.dart';

/// Code promotionnel tel que l'affichent les écrans du back-office.
///
/// Vue locale d'`eccore.Promotion`, et non un second modèle : les montants sont
/// convertis une fois en unité majeure pour l'affichage, jamais pour recalculer
/// une remise.
///
/// `calculateDiscount` a disparu. L'ancienne version appliquait le pourcentage,
/// plafonnait, puis bornait — côté client. C'est le calcul que fait déjà le
/// serveur au devis de commande, et le dupliquer donnait deux réponses
/// possibles à « combien remise ce code ? », dont une seule était facturée
/// (C1).
class Promotion {
  Promotion({
    required this.id,
    required this.code,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.startDate,
    required this.endDate,
    required this.usedCount,
    required this.isActive,
    this.minOrderAmount = 0.0,
    this.maxDiscount,
    this.usageLimit,
    this.restaurantSlug,
    this.ownerEmail,
  });

  factory Promotion.fromRemote(eccore.Promotion remote) {
    return Promotion(
      id: remote.id,
      code: remote.code,
      description: remote.description,
      discountType: remote.kind,
      // Un pourcentage pour l'un, un montant pour l'autre : le serveur ne
      // renseigne que le champ qui correspond à la nature de la remise.
      discountValue: remote.kind == eccore.DiscountKind.percentage
          ? (remote.percentage ?? 0)
          : (remote.amount?.toMajorUnits() ?? 0),
      minOrderAmount: remote.minOrderAmount?.toMajorUnits() ?? 0,
      maxDiscount: remote.maxDiscount?.toMajorUnits(),
      usageLimit: remote.usageLimit,
      usedCount: remote.usedCount,
      startDate: remote.startsAt.toLocal(),
      endDate: remote.endsAt.toLocal(),
      isActive: remote.isActive,
      restaurantSlug: remote.restaurantSlug,
      ownerEmail: remote.ownerEmail,
    );
  }

  final String id;
  final String code;
  final String description;
  final String discountType;
  final double discountValue;
  final double minOrderAmount;
  final double? maxDiscount;
  final int? usageLimit;
  final int usedCount;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  /// Vide = code national. Le serveur refuse qu'un compte cloisonné en crée.
  final String? restaurantSlug;

  /// Bénéficiaire d'un code nominatif, issu d'un échange de points.
  final String? ownerEmail;

  bool get isNational => restaurantSlug == null;
  bool get isPersonal => ownerEmail != null;
  bool get isExpired => DateTime.now().isAfter(endDate);

  /// Indicatif : c'est le serveur qui tranche à l'application du code, avec sa
  /// propre horloge.
  bool get isAvailable =>
      isActive &&
      !isExpired &&
      (usageLimit == null || usedCount < usageLimit!);
}

/// Codes promotionnels — `/api/v1/promotions/` (Phase 6).
///
/// Trois choses ont changé, et chacune fermait un trou :
///
/// * **le compteur d'utilisations ne s'écrit plus depuis ici.** L'ancien code
///   pouvait remettre `used_count` à zéro, c'est-à-dire rouvrir un quota épuisé
///   sans que rien n'en garde trace. Il est tenu par le serveur, sous verrou, à
///   la création de chaque commande ;
/// * **on ne frappe plus de code nominatif.** Un code au nom d'un client naît
///   d'un échange de points de fidélité — donc d'un débit. En créer un ici
///   distribuerait des récompenses gratuites ;
/// * **la remise ne se calcule plus à l'écran** (voir [Promotion]).
///
/// Il n'y a pas de suppression : `isActive` suspend. Les commandes passées
/// portent la remise de ce code, et l'effacer rendrait leur addition illisible.
class PromotionService extends ChangeNotifier {
  eccore.PromotionRepository get _promotions =>
      eccore.PromotionRepository(apiClient: AdminAuthService().apiClient);

  List<Promotion> _promotionsLocales = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<Promotion> get promotions => _promotionsLocales;
  List<Promotion> get activePromotions =>
      _promotionsLocales.where((p) => p.isAvailable).toList();

  /// Périmés, suspendus ou épuisés — ce qui ne remise plus rien aujourd'hui.
  ///
  /// Le complément d'[activePromotions] et non « ceux dont la date est
  /// passée » : un code suspendu ou dont le quota est consommé ne remise pas
  /// davantage, et le ranger ailleurs le rendrait introuvable.
  List<Promotion> get expiredPromotions =>
      _promotionsLocales.where((p) => !p.isAvailable).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final codes = await _promotions.list();
      _promotionsLocales = codes.map(Promotion.fromRemote).toList();
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('Promotions : chargement impossible — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crée un code.
  ///
  /// [restaurantSlug] vide crée un code **national**, que le serveur refuse à
  /// un compte cloisonné sur un établissement : il remiserait aussi les autres.
  Future<Promotion?> createPromotion({
    required String code,
    required String discountType,
    required double discountValue,
    required DateTime startDate,
    required DateTime endDate,
    String description = '',
    double minOrderAmount = 0,
    double? maxDiscount,
    int? usageLimit,
    int? usageLimitPerUser,
    String? restaurantSlug,
  }) async {
    try {
      final cree = await _promotions.create(
        code: code.toUpperCase(),
        description: description,
        kind: discountType,
        percentage: discountType == eccore.DiscountKind.percentage
            ? discountValue
            : null,
        amount: discountType == eccore.DiscountKind.fixed
            ? _versMoney(discountValue)
            : null,
        minOrderAmount: minOrderAmount > 0 ? _versMoney(minOrderAmount) : null,
        maxDiscount: maxDiscount == null ? null : _versMoney(maxDiscount),
        startsAt: startDate,
        endsAt: endDate,
        usageLimit: usageLimit,
        usageLimitPerUser: usageLimitPerUser,
        restaurantSlug: restaurantSlug,
      );
      final locale = Promotion.fromRemote(cree);
      _promotionsLocales = [locale, ..._promotionsLocales];
      notifyListeners();
      return locale;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('Promotions : création refusée — ${e.code}');
      notifyListeners();
      return null;
    }
  }

  /// Modifie un code. Ni le code lui-même ni son compteur : le premier est son
  /// identité — celle qui circule déjà chez les clients — et le second
  /// appartient au serveur.
  Future<bool> updatePromotion({
    required String id,
    String? description,
    String? discountType,
    double? discountValue,
    double? minOrderAmount,
    double? maxDiscount,
    DateTime? startDate,
    DateTime? endDate,
    int? usageLimit,
    int? usageLimitPerUser,
    bool? isActive,
  }) async {
    try {
      final maj = await _promotions.update(
        promotionId: id,
        description: description,
        percentage:
            discountType == eccore.DiscountKind.percentage ? discountValue : null,
        amount: discountType == eccore.DiscountKind.fixed && discountValue != null
            ? _versMoney(discountValue)
            : null,
        minOrderAmount:
            minOrderAmount == null ? null : _versMoney(minOrderAmount),
        maxDiscount: maxDiscount == null ? null : _versMoney(maxDiscount),
        startsAt: startDate,
        endsAt: endDate,
        usageLimit: usageLimit,
        usageLimitPerUser: usageLimitPerUser,
        isActive: isActive,
      );
      _remplacer(Promotion.fromRemote(maj));
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('Promotions : modification refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  /// Suspend ou réactive un code — la seule façon de le retirer de la
  /// circulation.
  Future<bool> togglePromotionStatus(String id, bool isActive) async {
    try {
      final maj = await _promotions.setActive(
        promotionId: id,
        isActive: isActive,
      );
      _remplacer(Promotion.fromRemote(maj));
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('Promotions : suspension refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  void _remplacer(Promotion promotion) {
    final index = _promotionsLocales.indexWhere((p) => p.id == promotion.id);
    if (index != -1) _promotionsLocales[index] = promotion;
    notifyListeners();
  }

  /// Les francs CFA n'ont pas de décimale : l'unité mineure est le franc.
  eccore.Money _versMoney(double montant) =>
      eccore.Money(amountMinor: montant.round(), currency: 'XOF');
}
