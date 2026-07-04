import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/order.dart';

class AdvancedGamificationService extends ChangeNotifier {
  static final AdvancedGamificationService _instance =
      AdvancedGamificationService._internal();
  factory AdvancedGamificationService() => _instance;
  AdvancedGamificationService._internal();

  final Map<String, UserGamingProfile> _userProfiles = {};
  final List<Achievement> _achievements = [];
  final List<Challenge> _challenges = [];
  final List<Leaderboard> _leaderboards = [];
  final Map<String, List<Reward>> _userRewards = {};

  // Getters
  Map<String, UserGamingProfile> get userProfiles =>
      Map.unmodifiable(_userProfiles);
  List<Achievement> get achievements => List.unmodifiable(_achievements);
  List<Challenge> get challenges => List.unmodifiable(_challenges);
  List<Leaderboard> get leaderboards => List.unmodifiable(_leaderboards);

  /// Initialise le service de gamification
  Future<void> initialize() async {
    await _initializeAchievements();
    await _initializeChallenges();
    await _initializeLeaderboards();
    debugPrint('AdvancedGamificationService: Service initialisé');
  }

  /// Initialise les achievements
  Future<void> _initializeAchievements() async {
    _achievements.addAll([
      Achievement(
        id: 'first_order',
        name: 'Première Commande',
        description: 'Passez votre première commande',
        icon: '🎉',
        category: AchievementCategory.order,
        rarity: AchievementRarity.common,
        points: 50,
        requirements: {'orders': 1},
      ),
      Achievement(
        id: 'burger_lover',
        name: 'Amoureux des Burgers',
        description: 'Commandez 10 burgers',
        icon: '🍔',
        category: AchievementCategory.food,
        rarity: AchievementRarity.uncommon,
        points: 100,
        requirements: {'burger_orders': 10},
      ),
      Achievement(
        id: 'pizza_master',
        name: 'Maître Pizza',
        description: 'Commandez 15 pizzas',
        icon: '🍕',
        category: AchievementCategory.food,
        rarity: AchievementRarity.rare,
        points: 200,
        requirements: {'pizza_orders': 15},
      ),
      Achievement(
        id: 'early_bird',
        name: 'Lève-tôt',
        description: 'Commandez avant 9h du matin',
        icon: '🌅',
        category: AchievementCategory.time,
        rarity: AchievementRarity.uncommon,
        points: 75,
        requirements: {'early_orders': 1},
      ),
      Achievement(
        id: 'night_owl',
        name: 'Noctambule',
        description: 'Commandez après 22h',
        icon: '🦉',
        category: AchievementCategory.time,
        rarity: AchievementRarity.uncommon,
        points: 75,
        requirements: {'late_orders': 1},
      ),
      Achievement(
        id: 'social_butterfly',
        name: 'Papillon Social',
        description: 'Partagez 5 commandes sur les réseaux sociaux',
        icon: '🦋',
        category: AchievementCategory.social,
        rarity: AchievementRarity.rare,
        points: 150,
        requirements: {'shared_orders': 5},
      ),
      Achievement(
        id: 'group_leader',
        name: 'Leader de Groupe',
        description: 'Organisez 3 commandes groupées',
        icon: '👑',
        category: AchievementCategory.social,
        rarity: AchievementRarity.epic,
        points: 300,
        requirements: {'group_orders': 3},
      ),
      Achievement(
        id: 'loyal_customer',
        name: 'Client Fidèle',
        description: 'Commandez pendant 7 jours consécutifs',
        icon: '💎',
        category: AchievementCategory.loyalty,
        rarity: AchievementRarity.legendary,
        points: 500,
        requirements: {'consecutive_days': 7},
      ),
      Achievement(
        id: 'speed_master',
        name: 'Maître de Vitesse',
        description: 'Commandez en moins de 2 minutes',
        icon: '⚡',
        category: AchievementCategory.speed,
        rarity: AchievementRarity.rare,
        points: 200,
        requirements: {'fast_order_time': 120},
      ),
      Achievement(
        id: 'big_spender',
        name: 'Gros Dépensier',
        description: 'Dépensez plus de 65.000 FCFA en une commande',
        icon: '💰',
        category: AchievementCategory.money,
        rarity: AchievementRarity.epic,
        points: 400,
        requirements: {'single_order_amount': 65000},
      ),
    ]);
  }

  /// Initialise les défis
  Future<void> _initializeChallenges() async {
    _challenges.addAll([
      Challenge(
        id: 'weekly_order',
        name: 'Défi Hebdomadaire',
        description: 'Commandez 3 fois cette semaine',
        type: ChallengeType.weekly,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        requirements: {'orders': 3},
        reward: Reward(
          id: 'weekly_reward',
          name: 'Récompense Hebdomadaire',
          type: RewardType.discount,
          value: 10.0,
          description: '10% de réduction sur votre prochaine commande',
        ),
        isActive: true,
      ),
      Challenge(
        id: 'monthly_social',
        name: 'Défi Social Mensuel',
        description: 'Partagez 10 commandes ce mois',
        type: ChallengeType.monthly,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        requirements: {'shared_orders': 10},
        reward: Reward(
          id: 'monthly_reward',
          name: 'Récompense Mensuelle',
          type: RewardType.points,
          value: 1000.0,
          description: '1000 points bonus',
        ),
        isActive: true,
      ),
    ]);
  }

  /// Initialise les classements
  Future<void> _initializeLeaderboards() async {
    _leaderboards.addAll([
      Leaderboard(
        id: 'monthly_orders',
        name: 'Commandes du Mois',
        description: 'Utilisateurs avec le plus de commandes ce mois',
        type: LeaderboardType.monthly,
        metric: LeaderboardMetric.orders,
        entries: [],
      ),
      Leaderboard(
        id: 'total_points',
        name: 'Points Totaux',
        description: 'Utilisateurs avec le plus de points',
        type: LeaderboardType.allTime,
        metric: LeaderboardMetric.points,
        entries: [],
      ),
      Leaderboard(
        id: 'social_shares',
        name: 'Partages Sociaux',
        description: 'Utilisateurs les plus actifs socialement',
        type: LeaderboardType.monthly,
        metric: LeaderboardMetric.socialShares,
        entries: [],
      ),
    ]);
  }

  /// Initialise le profil de jeu d'un utilisateur
  Future<UserGamingProfile> initializeUserProfile(String userId) async {
    final profile = UserGamingProfile(
      userId: userId,
      totalPoints: 0,
      level: 1,
      experience: 0,
      badges: [],
      achievements: [],
      streak: 0,
      lastOrderDate: null,
      statistics: UserStatistics(
        totalOrders: 0,
        totalSpent: 0.0,
        favoriteCategory: '',
        averageOrderTime: 0,
        socialShares: 0,
        groupOrders: 0,
      ),
    );

    _userProfiles[userId] = profile;
    notifyListeners();

    debugPrint('AdvancedGamificationService: Profil initialisé pour $userId');
    return profile;
  }

  /// Traite une commande pour les achievements et points
  Future<void> processOrder(Order order) async {
    final userId = order.userId;
    final profile = _userProfiles[userId];

    if (profile == null) {
      await initializeUserProfile(userId);
      return processOrder(order);
    }

    // Mettre à jour les statistiques
    profile.statistics.totalOrders++;
    profile.statistics.totalSpent += order.total;

    // Calculer les points de la commande
    final orderPoints = _calculateOrderPoints(order);
    profile.totalPoints += orderPoints;
    profile.experience += orderPoints;

    // Vérifier le niveau
    final newLevel = _calculateLevel(profile.experience);
    if (newLevel > profile.level) {
      profile.level = newLevel;
      _awardLevelUpReward(userId, newLevel);
    }

    // Vérifier les achievements
    await _checkAchievements(userId, order);

    // Vérifier les défis
    await _checkChallenges(userId, order);

    // Mettre à jour le streak
    _updateStreak(profile, order.orderTime);

    // Mettre à jour les classements
    _updateLeaderboards(userId, profile);

    notifyListeners();
    debugPrint(
      'AdvancedGamificationService: Commande traitée pour $userId - $orderPoints points',
    );
  }

  /// Calcule les points d'une commande
  int _calculateOrderPoints(Order order) {
    int points = 0;

    // Points de base
    points += (order.total * 10).round();

    // Bonus pour catégories spécifiques
    for (final item in order.items) {
      switch (item.category.toString().toLowerCase()) {
        case 'burgers':
          points += 5;
          break;
        case 'pizzas':
          points += 8;
          break;
        case 'drinks':
          points += 2;
          break;
        case 'desserts':
          points += 3;
          break;
      }
    }

    // Bonus pour commande groupée
    if (order.items.length > 3) {
      points += 20;
    }

    return points;
  }

  /// Calcule le niveau basé sur l'expérience
  int _calculateLevel(int experience) {
    return (experience / 1000).floor() + 1;
  }

  /// Vérifie les achievements
  Future<void> _checkAchievements(String userId, Order order) async {
    final profile = _userProfiles[userId]!;

    for (final achievement in _achievements) {
      if (profile.achievements.contains(achievement.id)) continue;

      bool earned = false;

      switch (achievement.id) {
        case 'first_order':
          earned = profile.statistics.totalOrders >= 1;
          break;
        case 'burger_lover':
          earned = _countCategoryOrders(userId, 'burgers') >= 10;
          break;
        case 'pizza_master':
          earned = _countCategoryOrders(userId, 'pizzas') >= 15;
          break;
        case 'early_bird':
          earned = order.orderTime.hour < 9;
          break;
        case 'night_owl':
          earned = order.orderTime.hour >= 22;
          break;
        case 'big_spender':
          earned = order.total >= 100;
          break;
        case 'speed_master':
          // Simuler le temps de commande
          earned = Random().nextInt(300) < 120;
          break;
      }

      if (earned) {
        await _awardAchievement(userId, achievement);
      }
    }
  }

  /// Vérifie les défis
  Future<void> _checkChallenges(String userId, Order order) async {
    final profile = _userProfiles[userId]!;

    for (final challenge in _challenges.where((c) => c.isActive)) {
      bool completed = false;

      switch (challenge.id) {
        case 'weekly_order':
          completed = _getWeeklyOrders(userId) >= 3;
          break;
        case 'monthly_social':
          completed = profile.statistics.socialShares >= 10;
          break;
      }

      if (completed && !profile.completedChallenges.contains(challenge.id)) {
        await _awardChallengeReward(userId, challenge);
      }
    }
  }

  /// Attribue un achievement
  Future<void> _awardAchievement(String userId, Achievement achievement) async {
    final profile = _userProfiles[userId]!;
    profile.achievements.add(achievement.id);
    profile.totalPoints += achievement.points;
    profile.experience += achievement.points;

    // Ajouter la récompense
    _userRewards[userId] = (_userRewards[userId] ?? [])
      ..add(
        Reward(
          id: 'achievement_${achievement.id}',
          name: achievement.name,
          type: RewardType.points,
          value: achievement.points.toDouble(),
          description: achievement.description,
        ),
      );

    notifyListeners();
    debugPrint(
      'AdvancedGamificationService: Achievement ${achievement.name} attribué à $userId',
    );
  }

  /// Attribue une récompense de défi
  Future<void> _awardChallengeReward(String userId, Challenge challenge) async {
    final profile = _userProfiles[userId]!;
    profile.completedChallenges.add(challenge.id);

    _userRewards[userId] = (_userRewards[userId] ?? [])..add(challenge.reward);

    notifyListeners();
    debugPrint(
      'AdvancedGamificationService: Récompense de défi ${challenge.name} attribuée à $userId',
    );
  }

  /// Attribue une récompense de montée de niveau
  void _awardLevelUpReward(String userId, int level) {
    final reward = Reward(
      id: 'level_up_$level',
      name: 'Montée de Niveau $level',
      type: RewardType.badge,
      value: level.toDouble(),
      description: 'Félicitations! Vous êtes maintenant niveau $level',
    );

    _userRewards[userId] = (_userRewards[userId] ?? [])..add(reward);

    debugPrint(
      'AdvancedGamificationService: Récompense de niveau $level attribuée à $userId',
    );
  }

  /// Met à jour le streak
  void _updateStreak(UserGamingProfile profile, DateTime orderDate) {
    final today = DateTime.now();
    final lastOrder = profile.lastOrderDate;

    if (lastOrder == null) {
      profile.streak = 1;
    } else {
      final daysDifference = today.difference(lastOrder).inDays;

      if (daysDifference == 1) {
        profile.streak++;
      } else if (daysDifference > 1) {
        profile.streak = 1;
      }
    }

    profile.lastOrderDate = orderDate;
  }

  /// Met à jour les classements
  void _updateLeaderboards(String userId, UserGamingProfile profile) {
    for (final leaderboard in _leaderboards) {
      final existingEntry = leaderboard.entries.firstWhere(
        (entry) => entry.userId == userId,
        orElse: () => LeaderboardEntry(userId: userId, value: 0, rank: 0),
      );

      switch (leaderboard.metric) {
        case LeaderboardMetric.orders:
          existingEntry.value = profile.statistics.totalOrders;
          break;
        case LeaderboardMetric.points:
          existingEntry.value = profile.totalPoints;
          break;
        case LeaderboardMetric.socialShares:
          existingEntry.value = profile.statistics.socialShares;
          break;
        case LeaderboardMetric.money:
          existingEntry.value = profile.statistics.totalSpent.round();
          break;
      }

      if (!leaderboard.entries.any((entry) => entry.userId == userId)) {
        leaderboard.entries.add(existingEntry);
      }

      // Trier et mettre à jour les rangs
      leaderboard.entries.sort((a, b) => b.value.compareTo(a.value));
      for (int i = 0; i < leaderboard.entries.length; i++) {
        leaderboard.entries[i].rank = i + 1;
      }
    }
  }

  /// Compte les commandes d'une catégorie
  int _countCategoryOrders(String userId, String category) {
    // Simulation - dans une vraie app, ceci viendrait de la base de données
    return Random().nextInt(20);
  }

  /// Obtient les commandes hebdomadaires
  int _getWeeklyOrders(String userId) {
    // Simulation - dans une vraie app, ceci viendrait de la base de données
    return Random().nextInt(7);
  }

  /// Obtient le profil de jeu d'un utilisateur
  UserGamingProfile? getUserProfile(String userId) {
    return _userProfiles[userId];
  }

  /// Obtient les récompenses d'un utilisateur
  List<Reward> getUserRewards(String userId) {
    return _userRewards[userId] ?? [];
  }

  /// Obtient les achievements disponibles
  List<Achievement> getAvailableAchievements(String userId) {
    final profile = _userProfiles[userId];
    if (profile == null) return [];

    return _achievements
        .where((achievement) => !profile.achievements.contains(achievement.id))
        .toList();
  }

  /// Obtient les défis actifs
  List<Challenge> getActiveChallenges(String userId) {
    final profile = _userProfiles[userId];
    if (profile == null) return [];

    return _challenges
        .where(
          (challenge) =>
              challenge.isActive &&
              !profile.completedChallenges.contains(challenge.id),
        )
        .toList();
  }

  /// Obtient un classement
  Leaderboard? getLeaderboard(String leaderboardId) {
    return _leaderboards.firstWhere(
      (lb) => lb.id == leaderboardId,
      orElse: () => throw Exception('Classement non trouvé'),
    );
  }
}

class UserGamingProfile {
  final String userId;
  int totalPoints;
  int level;
  int experience;
  final List<String> badges;
  final List<String> achievements;
  final List<String> completedChallenges;
  int streak;
  DateTime? lastOrderDate;
  UserStatistics statistics;

  UserGamingProfile({
    required this.userId,
    required this.totalPoints,
    required this.level,
    required this.experience,
    List<String>? badges,
    List<String>? achievements,
    List<String>? completedChallenges,
    required this.streak,
    this.lastOrderDate,
    required this.statistics,
  }) : badges = badges ?? [],
       achievements = achievements ?? [],
       completedChallenges = completedChallenges ?? [];
}

class UserStatistics {
  int totalOrders;
  double totalSpent;
  String favoriteCategory;
  int averageOrderTime;
  int socialShares;
  int groupOrders;

  UserStatistics({
    required this.totalOrders,
    required this.totalSpent,
    required this.favoriteCategory,
    required this.averageOrderTime,
    required this.socialShares,
    required this.groupOrders,
  });
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final AchievementCategory category;
  final AchievementRarity rarity;
  final int points;
  final Map<String, dynamic> requirements;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.rarity,
    required this.points,
    required this.requirements,
  });
}

class Challenge {
  final String id;
  final String name;
  final String description;
  final ChallengeType type;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic> requirements;
  final Reward reward;
  final bool isActive;

  Challenge({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.requirements,
    required this.reward,
    required this.isActive,
  });
}

class Leaderboard {
  final String id;
  final String name;
  final String description;
  final LeaderboardType type;
  final LeaderboardMetric metric;
  final List<LeaderboardEntry> entries;

  Leaderboard({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.metric,
    required this.entries,
  });
}

class LeaderboardEntry {
  final String userId;
  int value;
  int rank;

  LeaderboardEntry({
    required this.userId,
    required this.value,
    required this.rank,
  });
}

class Reward {
  final String id;
  final String name;
  final RewardType type;
  final double value;
  final String description;

  Reward({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    required this.description,
  });
}

enum AchievementCategory { order, food, time, social, loyalty, speed, money }

enum AchievementRarity { common, uncommon, rare, epic, legendary }

enum ChallengeType { daily, weekly, monthly, special }

enum LeaderboardType { daily, weekly, monthly, allTime }

enum LeaderboardMetric { orders, points, socialShares, money }

enum RewardType { points, discount, badge, item, experience }
