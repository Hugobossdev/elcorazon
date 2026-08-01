import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'admin_auth_service.dart';

/// Catalogues de fidélisation — `/gamification/manage/*` et
/// `/loyalty/manage/rewards/` (Phase 6).
///
/// Ce sont de la **donnée d'exploitation** : créer « 10 commandes ce mois-ci,
/// 500 points » ne demande pas de déploiement, comme les bornes d'un groupe
/// d'options vivent en base plutôt qu'en dur (ADR-003).
///
/// Ce qui a disparu, et pourquoi :
///
/// * **la suppression.** Effacer un succès emportait par cascade les lignes de
///   progression qui le référencent, c'est-à-dire ce que des clients avaient
///   réellement débloqué ; effacer une récompense rendait illisible un échange
///   passé — « 500 points contre quoi ? » est une question qu'on repose des
///   mois plus tard. Le serveur ne l'expose pas : [deactivate] la remplace, et
///   retire de la circulation sans réécrire le passé ;
/// * **les compteurs de participation.** « Utilisateurs avec badges »
///   demandait de télécharger toutes les lignes de progression de tous les
///   clients pour en compter les identifiants distincts. Les compteurs de
///   [catalogueStats] portent désormais sur le catalogue seul — ce que ce
///   service a en main, et rien de plus ;
/// * **les champs sans contrepartie** — `badge_reward` sur un succès,
///   `criteria` sur un badge, `reward_discount` sur un défi. Ils étaient saisis
///   dans les formulaires et n'étaient lus par rien.
///
/// Les listes restent des `Map` parce que c'est ce que consomment les écrans ;
/// les clés sont **celles du serveur**, pour qu'un champ renommé côté API se
/// voie ici plutôt que de se traduire en silence.
class GamificationService extends ChangeNotifier {
  eccore.ManagedGamificationRepository get _catalogues =>
      eccore.ManagedGamificationRepository(
        apiClient: AdminAuthService().apiClient,
      );

  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _badges = [];
  List<Map<String, dynamic>> _loyaltyRewards = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<Map<String, dynamic>> get achievements => _achievements;
  List<Map<String, dynamic>> get challenges => _challenges;
  List<Map<String, dynamic>> get badges => _badges;
  List<Map<String, dynamic>> get loyaltyRewards => _loyaltyRewards;
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
      _achievements = (await _catalogues.achievements()).map(_succes).toList();
      _challenges = (await _catalogues.challenges()).map(_defi).toList();
      _badges = (await _catalogues.badges()).map(_badge).toList();
      _loyaltyRewards = (await _catalogues.rewards()).map(_recompense).toList();
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Fidélisation : catalogues indisponibles — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- succès

  Future<bool> createAchievement({
    required String name,
    required String conditionType,
    required int conditionValue,
    String description = '',
    String icon = '🏆',
    int pointsReward = 0,
  }) async {
    return _ecrire(() async {
      final cree = await _catalogues.createAchievement(
        name: name,
        description: description,
        icon: icon,
        conditionType: conditionType,
        conditionValue: conditionValue,
        pointsReward: pointsReward,
      );
      _achievements = [..._achievements, _succes(cree)];
    });
  }

  Future<bool> updateAchievement(
    String id, {
    String? name,
    String? description,
    String? icon,
    String? conditionType,
    int? conditionValue,
    int? pointsReward,
    bool? isActive,
  }) async {
    return _ecrire(() async {
      final maj = await _catalogues.updateAchievement(
        achievementId: id,
        name: name,
        description: description,
        icon: icon,
        conditionType: conditionType,
        conditionValue: conditionValue,
        pointsReward: pointsReward,
        isActive: isActive,
      );
      _remplacer(_achievements, _succes(maj));
    });
  }

  /// Retire un succès de la circulation sans effacer ce qui a été débloqué.
  Future<bool> deactivateAchievement(String id) =>
      updateAchievement(id, isActive: false);

  // -------------------------------------------------------------- défis

  Future<bool> createChallenge({
    required String title,
    required String challengeType,
    required String conditionType,
    required int targetValue,
    required DateTime startDate,
    required DateTime endDate,
    String description = '',
    int rewardPoints = 0,
  }) async {
    return _ecrire(() async {
      final cree = await _catalogues.createChallenge(
        title: title,
        description: description,
        challengeType: challengeType,
        conditionType: conditionType,
        targetValue: targetValue,
        rewardPoints: rewardPoints,
        startsAt: startDate,
        endsAt: endDate,
      );
      _challenges = [_defi(cree), ..._challenges];
    });
  }

  Future<bool> updateChallenge(
    String id, {
    String? title,
    String? description,
    String? challengeType,
    String? conditionType,
    int? targetValue,
    int? rewardPoints,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) async {
    return _ecrire(() async {
      final maj = await _catalogues.updateChallenge(
        challengeId: id,
        title: title,
        description: description,
        challengeType: challengeType,
        conditionType: conditionType,
        targetValue: targetValue,
        rewardPoints: rewardPoints,
        startsAt: startDate,
        endsAt: endDate,
        isActive: isActive,
      );
      _remplacer(_challenges, _defi(maj));
    });
  }

  Future<bool> deactivateChallenge(String id) =>
      updateChallenge(id, isActive: false);

  // ------------------------------------------------------------- badges

  Future<bool> createBadge({
    required String title,
    required int pointsRequired,
    String description = '',
    String icon = '🏅',
  }) async {
    return _ecrire(() async {
      final cree = await _catalogues.createBadge(
        title: title,
        description: description,
        icon: icon,
        pointsRequired: pointsRequired,
      );
      _badges = [..._badges, _badge(cree)];
    });
  }

  Future<bool> updateBadge(
    String id, {
    String? title,
    String? description,
    String? icon,
    int? pointsRequired,
    bool? isActive,
  }) async {
    return _ecrire(() async {
      final maj = await _catalogues.updateBadge(
        badgeId: id,
        title: title,
        description: description,
        icon: icon,
        pointsRequired: pointsRequired,
        isActive: isActive,
      );
      _remplacer(_badges, _badge(maj));
    });
  }

  Future<bool> deactivateBadge(String id) => updateBadge(id, isActive: false);

  // -------------------------------------------------------- récompenses

  /// Crée une récompense échangeable contre des points.
  ///
  /// [restaurantSlug] vide en ferait une récompense **nationale**, que le
  /// serveur réserve au siège : elle s'échangerait dans les établissements des
  /// autres.
  Future<bool> createLoyaltyReward({
    required String name,
    required String kind,
    required int pointsCost,
    String description = '',
    double? discount,
    int validityDays = 30,
    String? restaurantId,
  }) async {
    return _ecrire(() async {
      final cree = await _catalogues.createReward(
        name: name,
        description: description,
        kind: kind,
        pointsCost: pointsCost,
        discount: discount == null ? null : _versMoney(discount),
        validityDays: validityDays,
        restaurantId: restaurantId,
      );
      _loyaltyRewards = [..._loyaltyRewards, _recompense(cree)];
    });
  }

  Future<bool> updateLoyaltyReward(
    String id, {
    String? name,
    String? description,
    String? kind,
    int? pointsCost,
    double? discount,
    int? validityDays,
    bool? isActive,
  }) async {
    return _ecrire(() async {
      final maj = await _catalogues.updateReward(
        rewardId: id,
        name: name,
        description: description,
        kind: kind,
        pointsCost: pointsCost,
        discount: discount == null ? null : _versMoney(discount),
        validityDays: validityDays,
        isActive: isActive,
      );
      _remplacer(_loyaltyRewards, _recompense(maj));
    });
  }

  Future<bool> deactivateLoyaltyReward(String id) =>
      updateLoyaltyReward(id, isActive: false);

  // ----------------------------------------------------------- lectures

  /// Compteurs du catalogue — ce que ce service a en main.
  ///
  /// Il n'y a plus de « nombre d'utilisateurs ayant débloqué » : l'obtenir
  /// demandait de charger toutes les lignes de progression de tous les clients
  /// sur un poste de travail. C'est un agrégat, et il appartient aux rapports.
  Map<String, dynamic> get catalogueStats => {
    'total_achievements': _achievements.length,
    'active_achievements': _actifs(_achievements),
    'total_challenges': _challenges.length,
    'active_challenges': _actifs(_challenges),
    'total_badges': _badges.length,
    'active_badges': _actifs(_badges),
    'total_loyalty_rewards': _loyaltyRewards.length,
    'active_loyalty_rewards': _actifs(_loyaltyRewards),
  };

  int _actifs(List<Map<String, dynamic>> items) =>
      items.where((item) => item['is_active'] == true).length;

  // ------------------------------------------------------------ interne

  Future<bool> _ecrire(Future<void> Function() action) async {
    try {
      await action();
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Fidélisation : écriture refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  void _remplacer(List<Map<String, dynamic>> liste, Map<String, dynamic> item) {
    final index = liste.indexWhere((existant) => existant['id'] == item['id']);
    if (index != -1) liste[index] = item;
  }

  Map<String, dynamic> _succes(eccore.ManagedAchievement modele) => {
    'id': modele.id,
    'name': modele.name,
    'description': modele.description,
    'icon': modele.icon,
    'condition_type': modele.conditionType,
    'condition_value': modele.conditionValue,
    'points_reward': modele.pointsReward,
    'is_active': modele.isActive,
  };

  Map<String, dynamic> _defi(eccore.ManagedChallenge modele) => {
    'id': modele.id,
    'title': modele.title,
    'description': modele.description,
    'challenge_type': modele.challengeType,
    'condition_type': modele.conditionType,
    'target_value': modele.targetValue,
    'reward_points': modele.rewardPoints,
    'starts_at': modele.startsAt,
    'ends_at': modele.endsAt,
    'is_active': modele.isActive,
  };

  Map<String, dynamic> _badge(eccore.ManagedBadge modele) => {
    'id': modele.id,
    'title': modele.title,
    'description': modele.description,
    'icon': modele.icon,
    'points_required': modele.pointsRequired,
    'is_active': modele.isActive,
  };

  Map<String, dynamic> _recompense(eccore.ManagedReward modele) => {
    'id': modele.id,
    'name': modele.name,
    'description': modele.description,
    'kind': modele.kind,
    'points_cost': modele.pointsCost,
    'discount': modele.discount.toMajorUnits(),
    'validity_days': modele.validityDays,
    'restaurant': modele.restaurantId,
    'is_active': modele.isActive,
  };

  /// Les francs CFA n'ont pas de décimale : l'unité mineure est le franc.
  eccore.Money _versMoney(double montant) =>
      eccore.Money(amountMinor: montant.round(), currency: 'XOF');
}
