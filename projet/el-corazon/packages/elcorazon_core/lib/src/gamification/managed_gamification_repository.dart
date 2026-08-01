import '../models/money.dart';
import '../network/api_client.dart';

/// Succès vu du back-office — miroir de `ManagedAchievementSerializer`.
///
/// Distinct d'[Achievement], et pas par recopie : celui-là porte la progression
/// d'*un* client (`progress`, `is_unlocked`), qui n'a aucun sens sur un écran
/// d'édition. Ici on édite l'objet, pas ce que quelqu'un en a fait.
class ManagedAchievement {
  const ManagedAchievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.conditionType,
    required this.conditionValue,
    required this.pointsReward,
    required this.isActive,
  });

  factory ManagedAchievement.fromJson(Map<String, dynamic> json) {
    return ManagedAchievement(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '🏆',
      conditionType: json['condition_type'] as String,
      conditionValue: json['condition_value'] as int,
      pointsReward: json['points_reward'] as int,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String description;
  final String icon;

  /// Ce qui est compté — `orders_count`, `restaurants_count`… La liste vient du
  /// serveur (`AchievementCondition`) : un critère inventé côté client ne
  /// compterait jamais rien.
  final String conditionType;
  final int conditionValue;
  final int pointsReward;
  final bool isActive;
}

/// Badge vu du back-office — miroir de `ManagedBadgeSerializer`.
class ManagedBadge {
  const ManagedBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.pointsRequired,
    required this.isActive,
  });

  factory ManagedBadge.fromJson(Map<String, dynamic> json) {
    return ManagedBadge(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '🏅',
      pointsRequired: json['points_required'] as int,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String title;
  final String description;
  final String icon;

  /// Adossé aux points gagnés **à vie**, pas au solde courant : un badge ne se
  /// retire pas parce que des points ont été dépensés.
  final int pointsRequired;
  final bool isActive;
}

/// Défi vu du back-office — miroir de `ManagedChallengeSerializer`.
class ManagedChallenge {
  const ManagedChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.challengeType,
    required this.conditionType,
    required this.targetValue,
    required this.rewardPoints,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
  });

  factory ManagedChallenge.fromJson(Map<String, dynamic> json) {
    return ManagedChallenge(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      challengeType: json['challenge_type'] as String,
      conditionType: json['condition_type'] as String,
      targetValue: json['target_value'] as int,
      rewardPoints: json['reward_points'] as int,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String title;
  final String description;
  final String challengeType;
  final String conditionType;
  final int targetValue;
  final int rewardPoints;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;

  bool isOpenAt(DateTime moment) =>
      isActive && moment.isAfter(startsAt) && moment.isBefore(endsAt);
}

/// Récompense vue du back-office — miroir de `ManagedRewardSerializer`.
class ManagedReward {
  const ManagedReward({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required this.pointsCost,
    required this.discount,
    required this.validityDays,
    required this.isActive,
    this.restaurantId,
  });

  factory ManagedReward.fromJson(Map<String, dynamic> json) {
    return ManagedReward(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      kind: json['kind'] as String,
      pointsCost: json['points_cost'] as int,
      discount: Money.fromJson(json['discount'] as Map<String, dynamic>),
      validityDays: json['validity_days'] as int,
      restaurantId: json['restaurant'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String description;
  final String kind;
  final int pointsCost;
  final Money discount;
  final int validityDays;

  /// Vide = récompense **nationale**, échangeable partout. Le serveur la
  /// réserve au siège : elle engage tous les établissements.
  final String? restaurantId;
  final bool isActive;

  bool get isNational => restaurantId == null;
}

/// Catalogues de fidélisation — `/gamification/manage/*` et
/// `/loyalty/manage/rewards/`.
///
/// Ce sont de la **donnée d'exploitation** : créer « 10 commandes ce mois-ci,
/// 500 points » ne demande pas de déploiement, exactement comme les bornes d'un
/// groupe d'options vivent en base plutôt qu'en dur (ADR-003).
///
/// Ce dépôt ne **débloque** rien et ne **crédite** rien. Les succès s'obtiennent
/// en commandant, par les signaux du domaine ; les points s'acquièrent à la
/// livraison et se dépensent à l'échange. Une attribution manuelle depuis un
/// écran d'administration frapperait monnaie, et le journal des points ne dirait
/// plus d'où vient un solde.
///
/// Aucune suppression non plus : effacer un succès emporterait par cascade ce
/// que des clients ont réellement débloqué, et une récompense retirée rendrait
/// illisible un échange passé. `isActive` retire de la circulation sans
/// réécrire le passé.
class ManagedGamificationRepository {
  ManagedGamificationRepository({required this.apiClient});

  final ApiClient apiClient;

  // ------------------------------------------------------------- succès

  Future<List<ManagedAchievement>> achievements({bool? isActive}) {
    return _collect(
      '/gamification/manage/achievements/',
      ManagedAchievement.fromJson,
      queryParameters: {if (isActive != null) 'is_active': isActive.toString()},
    );
  }

  Future<ManagedAchievement> createAchievement({
    required String name,
    required String conditionType,
    required int conditionValue,
    String description = '',
    String icon = '🏆',
    int pointsReward = 0,
  }) async {
    final response = await apiClient.post(
      '/gamification/manage/achievements/',
      data: {
        'name': name,
        'description': description,
        'icon': icon,
        'condition_type': conditionType,
        'condition_value': conditionValue,
        'points_reward': pointsReward,
      },
    );
    return ManagedAchievement.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ManagedAchievement> updateAchievement({
    required String achievementId,
    String? name,
    String? description,
    String? icon,
    String? conditionType,
    int? conditionValue,
    int? pointsReward,
    bool? isActive,
  }) async {
    final response = await apiClient.patch(
      '/gamification/manage/achievements/$achievementId/',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (icon != null) 'icon': icon,
        if (conditionType != null) 'condition_type': conditionType,
        if (conditionValue != null) 'condition_value': conditionValue,
        if (pointsReward != null) 'points_reward': pointsReward,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return ManagedAchievement.fromJson(response.data as Map<String, dynamic>);
  }

  // -------------------------------------------------------------- badges

  Future<List<ManagedBadge>> badges({bool? isActive}) {
    return _collect(
      '/gamification/manage/badges/',
      ManagedBadge.fromJson,
      queryParameters: {if (isActive != null) 'is_active': isActive.toString()},
    );
  }

  Future<ManagedBadge> createBadge({
    required String title,
    required int pointsRequired,
    String description = '',
    String icon = '🏅',
  }) async {
    final response = await apiClient.post(
      '/gamification/manage/badges/',
      data: {
        'title': title,
        'description': description,
        'icon': icon,
        'points_required': pointsRequired,
      },
    );
    return ManagedBadge.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ManagedBadge> updateBadge({
    required String badgeId,
    String? title,
    String? description,
    String? icon,
    int? pointsRequired,
    bool? isActive,
  }) async {
    final response = await apiClient.patch(
      '/gamification/manage/badges/$badgeId/',
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (icon != null) 'icon': icon,
        if (pointsRequired != null) 'points_required': pointsRequired,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return ManagedBadge.fromJson(response.data as Map<String, dynamic>);
  }

  // --------------------------------------------------------------- défis

  Future<List<ManagedChallenge>> challenges({bool? isActive}) {
    return _collect(
      '/gamification/manage/challenges/',
      ManagedChallenge.fromJson,
      queryParameters: {if (isActive != null) 'is_active': isActive.toString()},
    );
  }

  Future<ManagedChallenge> createChallenge({
    required String title,
    required String challengeType,
    required String conditionType,
    required int targetValue,
    required DateTime startsAt,
    required DateTime endsAt,
    String description = '',
    int rewardPoints = 0,
  }) async {
    final response = await apiClient.post(
      '/gamification/manage/challenges/',
      data: {
        'title': title,
        'description': description,
        'challenge_type': challengeType,
        'condition_type': conditionType,
        'target_value': targetValue,
        'reward_points': rewardPoints,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
      },
    );
    return ManagedChallenge.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ManagedChallenge> updateChallenge({
    required String challengeId,
    String? title,
    String? description,
    String? challengeType,
    String? conditionType,
    int? targetValue,
    int? rewardPoints,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? isActive,
  }) async {
    final response = await apiClient.patch(
      '/gamification/manage/challenges/$challengeId/',
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (challengeType != null) 'challenge_type': challengeType,
        if (conditionType != null) 'condition_type': conditionType,
        if (targetValue != null) 'target_value': targetValue,
        if (rewardPoints != null) 'reward_points': rewardPoints,
        if (startsAt != null) 'starts_at': startsAt.toUtc().toIso8601String(),
        if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
        if (isActive != null) 'is_active': isActive,
      },
    );
    return ManagedChallenge.fromJson(response.data as Map<String, dynamic>);
  }

  // --------------------------------------------------------- récompenses

  Future<List<ManagedReward>> rewards({bool? isActive}) {
    return _collect(
      '/loyalty/manage/rewards/',
      ManagedReward.fromJson,
      queryParameters: {if (isActive != null) 'is_active': isActive.toString()},
    );
  }

  /// Crée une récompense.
  ///
  /// [restaurantId] vide en fait une récompense **nationale**, que le serveur
  /// réserve au siège : elle s'échangerait dans les établissements des autres.
  Future<ManagedReward> createReward({
    required String name,
    required String kind,
    required int pointsCost,
    String description = '',
    Money? discount,
    int validityDays = 30,
    String? restaurantId,
  }) async {
    final response = await apiClient.post(
      '/loyalty/manage/rewards/',
      data: {
        'name': name,
        'description': description,
        'kind': kind,
        'points_cost': pointsCost,
        if (discount != null) 'discount': discount.toJson(),
        'validity_days': validityDays,
        'restaurant': restaurantId,
      },
    );
    return ManagedReward.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ManagedReward> updateReward({
    required String rewardId,
    String? name,
    String? description,
    String? kind,
    int? pointsCost,
    Money? discount,
    int? validityDays,
    bool? isActive,
  }) async {
    final response = await apiClient.patch(
      '/loyalty/manage/rewards/$rewardId/',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (kind != null) 'kind': kind,
        if (pointsCost != null) 'points_cost': pointsCost,
        if (discount != null) 'discount': discount.toJson(),
        if (validityDays != null) 'validity_days': validityDays,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return ManagedReward.fromJson(response.data as Map<String, dynamic>);
  }

  // ------------------------------------------------------------- interne

  Future<List<T>> _collect<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final items = <T>[];
    String? next = path;
    Map<String, dynamic>? parametres = queryParameters;

    while (next != null) {
      final response = await apiClient.get(next, queryParameters: parametres);
      final page = response.data as Map<String, dynamic>;
      items.addAll(
        (page['results'] as List<dynamic>).map(
          (json) => fromJson(json as Map<String, dynamic>),
        ),
      );
      next = page['next'] as String?;
      parametres = null;
    }

    return items;
  }
}
