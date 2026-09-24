import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/presentation/echec.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Ce qu'on lit d'un code à l'écran, sans recopier le modèle.
extension EtatDePromotion on eccore.Promotion {
  bool get isNational => restaurantSlug == null;
  bool get isPersonal => ownerEmail != null;
  bool get isExpired => DateTime.now().isAfter(endsAt);

  /// Utilisable maintenant : active, dans sa période, quota non épuisé.
  bool get isAvailable =>
      isActive &&
      !isExpired &&
      !DateTime.now().isBefore(startsAt) &&
      (usageLimit == null || usedCount < usageLimit!);
}

/// Codes promotionnels — `/promotions/` (Phase 6).
///
/// ## Ce qui a changé
///
/// Le service recopiait chaque code dans un modèle local dont tous les
/// montants étaient des `double` : la devise était perdue en route, et l'écran
/// affichait « 500 FCFA » pour un code de Douala comme pour un code de Lomé.
/// Les écrans reçoivent désormais le modèle du socle, montants en [eccore.Money].
///
/// Les écritures laissent remonter l'`ApiException` : le dialogue affiche le
/// refus (code déjà pris, devise, quota) sans se fermer. Plus de chargement
/// au démarrage de l'application — l'écran le demande à son ouverture.
class PromotionService extends ChangeNotifier {
  PromotionService({eccore.PromotionRepository? depot}) : _depot = depot;

  final eccore.PromotionRepository? _depot;

  eccore.PromotionRepository get _promotions =>
      _depot ?? eccore.PromotionRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.Promotion> _codes = const [];
  bool _enCours = false;
  Echec? _echec;
  bool _initialise = false;

  List<eccore.Promotion> get promotions => _codes;
  List<eccore.Promotion> get activePromotions => _codes.where((p) => p.isAvailable).toList();
  List<eccore.Promotion> get expiredPromotions => _codes.where((p) => !p.isAvailable).toList();
  bool get isLoading => _enCours;
  Echec? get echec => _echec;

  Future<void> initialize() async {
    if (_initialise) return;
    _initialise = true;
    await refresh();
  }

  Future<void> refresh() async {
    _enCours = true;
    _echec = null;
    notifyListeners();
    try {
      _codes = await _promotions.list();
    } on eccore.ApiException catch (e) {
      _echec = Echec.de(e);
      eccore.Journal.trace('Promotions : chargement impossible — ${e.code}');
    } finally {
      _enCours = false;
      notifyListeners();
    }
  }

  /// Crée un code. [restaurantSlug] nul : code **national**, réservé au siège.
  /// Lève `ApiException`.
  Future<eccore.Promotion> creer({
    required String code,
    required String description,
    required String kind,
    required DateTime startsAt,
    required DateTime endsAt,
    required String? restaurantSlug,
    double? percentage,
    eccore.Money? amount,
    eccore.Money? minOrderAmount,
    eccore.Money? maxDiscount,
    int? usageLimit,
    int? usageLimitPerUser,
  }) async {
    final cree = await _promotions.create(
      code: code,
      description: description,
      kind: kind,
      percentage: percentage,
      amount: amount,
      minOrderAmount: minOrderAmount,
      maxDiscount: maxDiscount,
      startsAt: startsAt,
      endsAt: endsAt,
      usageLimit: usageLimit,
      usageLimitPerUser: usageLimitPerUser,
      restaurantSlug: restaurantSlug,
    );
    _codes = [cree, ..._codes];
    notifyListeners();
    return cree;
  }

  /// Réécrit les conditions d'un code — une limite laissée vide est
  /// **effacée**. Lève `ApiException`.
  Future<eccore.Promotion> remplacer({
    required String id,
    required String description,
    required String kind,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool isActive,
    double? percentage,
    eccore.Money? amount,
    eccore.Money? minOrderAmount,
    eccore.Money? maxDiscount,
    int? usageLimit,
    int? usageLimitPerUser,
  }) async {
    final maj = await _promotions.replace(
      promotionId: id,
      description: description,
      kind: kind,
      percentage: percentage,
      amount: amount,
      minOrderAmount: minOrderAmount,
      maxDiscount: maxDiscount,
      startsAt: startsAt,
      endsAt: endsAt,
      usageLimit: usageLimit,
      usageLimitPerUser: usageLimitPerUser,
      isActive: isActive,
    );
    _remplacerLocalement(maj);
    return maj;
  }

  /// Suspend ou réactive un code. Lève `ApiException`.
  Future<void> basculer(eccore.Promotion promotion) async {
    final maj = await _promotions.setActive(promotionId: promotion.id, isActive: !promotion.isActive);
    _remplacerLocalement(maj);
  }

  void _remplacerLocalement(eccore.Promotion maj) {
    _codes = [for (final code in _codes) code.id == maj.id ? maj : code];
    notifyListeners();
  }
}
