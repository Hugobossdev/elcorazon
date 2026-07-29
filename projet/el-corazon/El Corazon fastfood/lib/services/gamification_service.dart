import 'dart:async';

import 'package:flutter/material.dart';
import 'package:elcora_fast/models/loyalty_reward.dart';
import 'package:elcora_fast/models/loyalty_transaction.dart';
import 'package:elcora_fast/repositories/django_gamification_repository.dart';
import 'package:elcora_fast/repositories/django_loyalty_repository.dart';
import 'package:elcora_fast/repositories/django_order_repository.dart';
import 'package:elcora_fast/services/database_service.dart';

/// Centralise la logique de fidélité (points, récompenses, historique) et de
/// badges (Django, Phase 6) ; achievements/défis restent simulés côté client
/// (aucun écran ne les affiche — voir `_loadAchievements`/`_loadChallenges`).
class GamificationService extends ChangeNotifier {
  static final GamificationService _instance = GamificationService._internal();

  factory GamificationService() => _instance;

  GamificationService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final DjangoLoyaltyRepository _loyaltyRepository = DjangoLoyaltyRepository();
  final DjangoGamificationRepository _gamificationRepository = DjangoGamificationRepository();

  int _currentPoints = 0;
  int _currentLevel = 1;
  int _totalOrders = 0;
  int _streakDays = 0;
  double _levelProgress = 0.0;

  String? _currentUserId;
  String? _currentAuthUserId;
  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _challenges = [];
  List<LoyaltyReward> _rewards = [];
  List<Map<String, dynamic>> _badges = [];
  List<LoyaltyTransaction> _transactions = [];
  final Set<String> _pendingRewardIds = <String>{};

  bool _isInitialized = false;

  // Getters
  int get currentPoints => _currentPoints;
  int get currentLevel => _currentLevel;
  int get totalOrders => _totalOrders;
  int get streakDays => _streakDays;
  double get levelProgress => _levelProgress;
  List<Map<String, dynamic>> get achievements => _achievements;
  List<Map<String, dynamic>> get challenges => _challenges;
  List<LoyaltyReward> get rewards => List.unmodifiable(_rewards);
  List<LoyaltyReward> get availableRewards => _rewards
      .where((reward) => reward.isActive && _currentPoints >= reward.cost)
      .toList(growable: false);
  List<Map<String, dynamic>> get badges => _badges;
  List<LoyaltyTransaction> get transactions => List.unmodifiable(_transactions);
  bool get isInitialized => _isInitialized;
  bool isRewardBeingProcessed(String rewardId) =>
      _pendingRewardIds.contains(rewardId);

  void reset() {
    _currentPoints = 0;
    _currentLevel = 1;
    _totalOrders = 0;
    _streakDays = 0;
    _levelProgress = 0.0;
    _currentUserId = null;
    _currentAuthUserId = null;
    _achievements = [];
    _challenges = [];
    _rewards = [];
    _badges = [];
    _transactions = [];
    _pendingRewardIds.clear();
    _isInitialized = false;
    notifyListeners();
  }

  String get currentLevelTitle {
    switch (_currentLevel) {
      case 1:
        return 'Gourmand Débutant 🍔';
      case 2:
        return 'Amateur de Saveurs 🍕';
      case 3:
        return 'Connaisseur Culinaire 🍖';
      case 4:
        return 'Expert Gastronome 🥘';
      case 5:
        return 'Maître El Corazón 👑';
      default:
        return 'Légende Culinaire 🌟';
    }
  }

  Future<void> initialize({String? userId, bool forceRefresh = false}) async {
    final previousDbId = _currentUserId;
    final previousAuthId = _currentAuthUserId;

    final authUserId = _databaseService.currentUser?.id;
    Map<String, dynamic>? userData;

    if (userId != null) {
      userData = await _databaseService.ensureUserProfileExists(userId: userId);
    }
    if (userData == null && authUserId != null) {
      userData =
          await _databaseService.ensureUserProfileExists(userId: authUserId);
    }

    if (userData != null) {
      _currentUserId = userData['id']?.toString();
      _currentAuthUserId = userData['auth_user_id']?.toString() ?? authUserId;
    } else {
      _currentUserId = previousDbId;
      _currentAuthUserId = authUserId ?? previousAuthId;
    }
    await _refreshLoyaltyBalance();

    final hasSameIds =
        previousDbId == _currentUserId && previousAuthId == _currentAuthUserId;

    if (!hasSameIds) {
      _achievements = [];
      _challenges = [];
      _badges = [];
      _transactions = [];
      _pendingRewardIds.clear();
    }

    if (_isInitialized && !forceRefresh && hasSameIds) {
      return;
    }

    try {
      await _loadUserStats();

      await Future.wait([
        _loadAchievements(),
        _loadChallenges(),
        _loadRewards(),
        _loadBadges(),
        if (_currentUserId != null) _loadTransactions(_currentUserId!),
      ]);

      _syncAchievementProgressFromMetrics();
      _evaluateBadges();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing GamificationService: $e');
    }
  }

  /// Charge les statistiques utilisateur depuis la base de données
  Future<void> _loadUserStats() async {
    try {
      final authId = _currentAuthUserId ?? _currentUserId;
      if (authId != null) {
        final userData =
            await _databaseService.ensureUserProfileExists(userId: authId);
        if (userData != null) {
          _currentUserId = userData['id']?.toString() ?? _currentUserId;
          _currentAuthUserId =
              userData['auth_user_id']?.toString() ?? _currentAuthUserId;
        }
      }
      await _refreshLoyaltyBalance();

      // Les commandes vivent désormais dans Django (Phase 6) — le total et la
      // séquence de commandes restent des métriques de gamification (G1, pas
      // migré), mais leur source de données doit suivre.
      final orders = await DjangoOrderRepository().getUserOrders(
        _currentAuthUserId ?? '',
      );
      _totalOrders = orders.length;
      _streakDays = _calculateStreakDays(
        orders.map((order) => {'created_at': order.createdAt.toIso8601String()}).toList(),
      );
    } catch (e) {
      debugPrint('Error loading user stats: $e');
    }

    _syncAchievementProgressFromMetrics();
    _evaluateBadges();
  }

  /// Recharge `_currentPoints` depuis le vrai solde Django
  /// (`PointsAccount`, hors du modèle `User`) — les points ne sont crédités
  /// qu'à la livraison d'une commande, jamais par ce client.
  Future<void> _refreshLoyaltyBalance() async {
    try {
      _currentPoints = await _loyaltyRepository.getAccountBalance();
      _currentLevel = _calculateLevel(_currentPoints);
      _levelProgress = _calculateLevelProgress(_currentPoints);
    } catch (e) {
      debugPrint('Error loading loyalty balance: $e');
    }
  }

  /// Calcule le niveau basé sur les points
  int _calculateLevel(int points) {
    if (points < 100) return 1;
    if (points < 300) return 2;
    if (points < 600) return 3;
    if (points < 1000) return 4;
    if (points < 1500) return 5;
    return 6 + ((points - 1500) ~/ 500);
  }

  /// Calcule le progrès du niveau
  double _calculateLevelProgress(int points) {
    final level = _calculateLevel(points);
    final currentThreshold = _pointsThresholdForLevel(level);
    final nextThreshold = _pointsThresholdForLevel(level + 1);
    final totalNeeded = (nextThreshold - currentThreshold).clamp(1, 1000000);
    final progressPoints = points - currentThreshold;
    return (progressPoints / totalNeeded).clamp(0.0, 1.0);
  }

  int _pointsThresholdForLevel(int level) {
    if (level <= 1) return 0;
    switch (level) {
      case 2:
        return 100;
      case 3:
        return 300;
      case 4:
        return 600;
      case 5:
        return 1000;
      case 6:
        return 1500;
      default:
        return 1500 + (level - 6) * 500;
    }
  }

  /// Calcule les jours de série
  int _calculateStreakDays(List<dynamic> orders) {
    if (orders.isEmpty) return 0;

    final orderDates = orders.map((order) {
      final orderMap = order as Map<String, dynamic>;
      return DateTime.parse(orderMap['created_at'] as String);
    }).toList()
      ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime currentDate = DateTime.now();

    for (final orderDate in orderDates) {
      final daysDifference = currentDate.difference(orderDate).inDays;
      if (daysDifference == streak) {
        streak++;
        currentDate = orderDate;
      } else {
        break;
      }
    }

    return streak;
  }

  Future<void> _loadAchievements() async {
    try {
      if (_currentUserId == null) {
        _achievements = [];
        return;
      }

      final response =
          await _databaseService.fetchAchievementsWithProgress(_currentUserId!);

      if (response.isEmpty) {
        debugPrint('GamificationService: Aucun achievement trouvé dans la base de données');
        _achievements = [];
        return;
      }

      _achievements = response.map((data) {
        final unlockedAt = data['unlockedAt'];
        return {
          'id': data['id'],
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'icon': data['icon'] ?? '🏆',
          'points': data['points'] ?? 0,
          'target': data['target'] ?? 1,
          'criteria': data['criteria'] ?? 'orders',
          'progress': (data['progress'] as num?)?.toInt() ?? 0,
          'isUnlocked': data['isUnlocked'] ?? false,
          'unlockedAt': unlockedAt is String
              ? DateTime.tryParse(unlockedAt)
              : unlockedAt as DateTime?,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading achievements: $e');
      // Ne plus utiliser de données par défaut - retourner une liste vide
      _achievements = [];
    }
  }

  Future<void> _loadChallenges() async {
    try {
      if (_currentUserId == null) {
        _challenges = [];
        return;
      }

      final response =
          await _databaseService.fetchChallengesWithProgress(_currentUserId!);

      if (response.isEmpty) {
        debugPrint('GamificationService: Aucun challenge trouvé dans la base de données');
        _challenges = [];
        return;
      }

      _challenges = response.map((data) {
        final endDate = data['endDate'];
        final startDate = data['startDate'];
        final completedAt = data['completedAt'];
        return {
          'id': data['id'],
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'icon': data['icon'] ?? '🎯',
          'reward': data['reward'] ?? 0,
          'target': data['target'] ?? 1,
          'criteria': data['criteria'] ?? 'orders',
          'progress': (data['progress'] as num?)?.toInt() ?? 0,
          'isActive': data['isActive'] ?? true,
          'isCompleted': data['isCompleted'] ?? false,
          'startDate':
              startDate is String ? DateTime.tryParse(startDate) : startDate,
          'endDate': endDate is String ? DateTime.tryParse(endDate) : endDate,
          'completedAt': completedAt is String
              ? DateTime.tryParse(completedAt)
              : completedAt as DateTime?,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading challenges: $e');
      // Ne plus utiliser de données par défaut - retourner une liste vide
      _challenges = [];
    }
  }

  Future<void> _loadRewards() async {
    try {
      _rewards = await _loyaltyRepository.getRewards();
    } catch (e) {
      debugPrint('Error loading rewards: $e');
      _rewards = [];
    }
  }

  int _metricValue(String criteria) {
    switch (criteria) {
      case 'orders':
        return _totalOrders;
      case 'level':
        return _currentLevel;
      case 'points':
        return _currentPoints;
      case 'streak':
        return _streakDays;
      default:
        return 0;
    }
  }

  void _syncAchievementProgressFromMetrics() {
    for (final achievement in _achievements) {
      final criteria = (achievement['criteria'] ?? '').toString();
      final metric = _metricValue(criteria);
      final current = (achievement['progress'] as num?)?.toInt() ?? 0;
      if (metric > current) {
        achievement['progress'] = metric;
        unawaited(_persistAchievement(achievement));
      }
    }
  }

  // Les badges viennent désormais de Django (`isUnlocked`/`unlockedAt` déjà
  // corrects, calculés serveur depuis les points gagnés à vie) — les
  // recalculer ici écraserait cet état par une estimation locale obsolète.
  void _evaluateBadges() {}

  Future<void> _persistAchievement(Map<String, dynamic> achievement) async {
    final userId = _currentUserId;
    if (userId == null) return;

    // Ne pas persister les achievements par défaut (IDs numériques)
    // Seulement persister ceux qui viennent de la base de données (UUIDs)
    final achievementId = achievement['id'];
    if (achievementId == null) return;

    // Vérifier si c'est un UUID valide (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
    final idString = achievementId.toString();
    final isUuid = RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false,)
        .hasMatch(idString);

    if (!isUuid) {
      // C'est un ID numérique par défaut, ne pas persister
      return;
    }

    try {
      await _databaseService.upsertUserAchievement(
        userId: userId,
        achievementId: idString,
        progress: (achievement['progress'] as num?)?.toInt(),
        isUnlocked: achievement['isUnlocked'] == true,
        unlockedAt: achievement['unlockedAt'] as DateTime?,
      );
    } catch (e) {
      debugPrint('Error persisting achievement: $e');
    }
  }

  Future<void> _persistChallengeProgress(
    Map<String, dynamic> challenge,
  ) async {
    final userId = _currentUserId;
    if (userId == null) return;

    // Ne pas persister les challenges par défaut (IDs numériques)
    // Seulement persister ceux qui viennent de la base de données (UUIDs)
    final challengeId = challenge['id'];
    if (challengeId == null) return;

    // Vérifier si c'est un UUID valide (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
    final idString = challengeId.toString();
    final isUuid = RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false,)
        .hasMatch(idString);

    if (!isUuid) {
      // C'est un ID numérique par défaut, ne pas persister
      return;
    }

    try {
      await _databaseService.upsertUserChallenge(
        userId: userId,
        challengeId: idString,
        progress: (challenge['progress'] as num?)?.toInt() ?? 0,
        isCompleted: challenge['isCompleted'] == true,
        completedAt: challenge['completedAt'] as DateTime?,
      );
    } catch (e) {
      debugPrint('Error persisting challenge: $e');
    }
  }

  Future<void> _loadTransactions(String userId) async {
    try {
      _transactions = await _loyaltyRepository.getTransactions();
    } catch (e) {
      debugPrint('Error loading loyalty transactions: $e');
      _transactions = [];
    }
  }

  Future<void> _loadBadges() async {
    try {
      _badges = await _gamificationRepository.getBadges();
      notifyListeners();
    } catch (e) {
      debugPrint('GamificationService._loadBadges: erreur - $e');
      _badges = [];
      notifyListeners();
    }
  }

  /// Recharge les badges depuis la base de données
  /// Utile pour rafraîchir les badges après un déblocage
  Future<void> reloadBadges() async {
    await _loadBadges();
    _evaluateBadges();
  }

  // Ajouter des points
  Future<void> addPoints(
    int points,
    String reason, {
    String? userId,
    Map<String, dynamic>? metadata,
    bool skipAchievementCheck = false,
  }) async {
    if (points == 0) return;

    Map<String, dynamic>? profile;

    final candidates = <String?>[
      userId,
      _currentAuthUserId,
      _currentUserId,
      _databaseService.currentUser?.id,
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      profile =
          await _databaseService.ensureUserProfileExists(userId: candidate);
      if (profile != null) break;
    }

    final effectiveAuthUserId = profile?['auth_user_id']?.toString() ??
        _currentAuthUserId ??
        _databaseService.currentUser?.id;
    final databaseUserId = profile?['id']?.toString() ?? _currentUserId;

    if (profile != null) {
      _currentUserId = databaseUserId;
      _currentAuthUserId =
          profile['auth_user_id']?.toString() ?? _currentAuthUserId;
    }

    _currentPoints += points;
    if (_currentPoints < 0) {
      _currentPoints = 0;
    }
    _currentLevel = _calculateLevel(_currentPoints);
    _levelProgress = _calculateLevelProgress(_currentPoints);

    if (effectiveAuthUserId != null) {
      try {
        await _databaseService.updateUserLoyaltyPoints(
          effectiveAuthUserId,
          _currentPoints,
        );

        final transactionType = points > 0
            ? LoyaltyTransactionType.earn
            : LoyaltyTransactionType.adjustment;

        if (databaseUserId != null) {
          await _databaseService.createLoyaltyTransaction(
            userId: databaseUserId,
            type: transactionType,
            points: points,
            description: reason,
            metadata: metadata,
          );

          await _loadTransactions(databaseUserId);
        }
      } catch (e) {
        debugPrint('Error updating user points in database: $e');
        _transactions = [
          LoyaltyTransaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            userId: databaseUserId ?? effectiveAuthUserId,
            type: points > 0
                ? LoyaltyTransactionType.earn
                : LoyaltyTransactionType.adjustment,
            points: points,
            description: reason,
            createdAt: DateTime.now(),
            metadata: metadata,
          ),
          ..._transactions,
        ];
      }
    }

    _checkLevelUp();
    _evaluateBadges();
    if (!skipAchievementCheck) {
      await _checkAchievements();
    }
    notifyListeners();

    // Afficher une notification de points gagnés
    _showPointsNotification(points, reason);
  }

  // Vérifier si l'utilisateur peut monter de niveau
  void _checkLevelUp() {
    final previousLevel = _currentLevel;
    _currentLevel = _calculateLevel(_currentPoints);
    _levelProgress = _calculateLevelProgress(_currentPoints);
    if (_currentLevel > previousLevel) {
      _showLevelUpNotification();
    }
  }

  // Vérifier les achievements
  Future<void> _checkAchievements() async {
    if (_currentUserId == null) return;

    for (final achievement in _achievements) {
      final isUnlocked = achievement['isUnlocked'] == true;
      if (isUnlocked) continue;

      final target = (achievement['target'] as num?)?.toInt() ?? 0;
      final progress = (achievement['progress'] as num?)?.toInt() ?? 0;

      if (target > 0 && progress >= target) {
        achievement['isUnlocked'] = true;
        achievement['unlockedAt'] = DateTime.now();
        await _persistAchievement(achievement);

        final points = (achievement['points'] as num?)?.toInt() ?? 0;
        if (points > 0) {
          await addPoints(
            points,
            'Achievement: ${achievement['title']}',
            metadata: {'achievementId': achievement['id']},
            skipAchievementCheck: true,
          );
        }
        _showAchievementUnlockedNotification(achievement);
      } else {
        // Sauvegarder le progrès actuel
        unawaited(_persistAchievement(achievement));
      }
    }
  }

  // Échanger des points contre une récompense — délègue entièrement au
  // serveur (C1) : ni le solde ni le coût ne sont recalculés ici, seul
  // Django sait ce qu'il en est après coup.
  Future<bool> redeemReward(LoyaltyReward reward) async {
    if (_pendingRewardIds.contains(reward.id)) {
      return false;
    }

    if (_currentPoints < reward.cost) {
      return false;
    }

    _pendingRewardIds.add(reward.id);
    notifyListeners();

    final success = await _loyaltyRepository.redeem(reward.id);
    if (!success) {
      _pendingRewardIds.remove(reward.id);
      notifyListeners();
      return false;
    }

    await _refreshLoyaltyBalance();

    try {
      await _loadTransactions(_currentUserId ?? '');
    } catch (e) {
      debugPrint('Error refreshing transactions after redemption: $e');
    }

    _pendingRewardIds.remove(reward.id);
    _checkLevelUp();
    notifyListeners();
    return true;
  }

  // Mettre à jour le progrès d'un défi
  void updateChallengeProgress(dynamic challengeId, int progress) {
    final id = challengeId.toString();
    final challengeIndex =
        _challenges.indexWhere((c) => c['id'].toString() == id);
    if (challengeIndex == -1) return;

    final challenge = _challenges[challengeIndex];
    final currentProgress = (challenge['progress'] as num?)?.toInt() ?? 0;
    if (progress <= currentProgress && challenge['isCompleted'] == true) {
      return;
    }

    challenge['progress'] = progress;

    final target = (challenge['target'] as num?)?.toInt() ?? 0;
    if (target > 0 && progress >= target && challenge['isCompleted'] != true) {
      challenge['isCompleted'] = true;
      challenge['isActive'] = false;
      challenge['completedAt'] = DateTime.now();

      final rewardPoints = (challenge['reward'] as num?)?.toInt() ?? 0;
      if (rewardPoints > 0) {
        unawaited(
          addPoints(
            rewardPoints,
            'Défi terminé: ${challenge['title']}',
            metadata: {'challengeId': challenge['id']},
          ),
        );
      }
      _showChallengeCompletedNotification(challenge);
    }

    unawaited(_persistChallengeProgress(challenge));
    notifyListeners();
  }

  // Notifications simulées
  void _showPointsNotification(int points, String reason) {
    debugPrint('🎉 +$points points: $reason');
  }

  void _showLevelUpNotification() {
    debugPrint('🆙 Félicitations! Vous avez atteint le niveau $_currentLevel!');
  }

  void _showAchievementUnlockedNotification(Map<String, dynamic> achievement) {
    debugPrint('🏆 Achievement débloqué: ${achievement['title']}');
  }

  void _showChallengeCompletedNotification(Map<String, dynamic> challenge) {
    debugPrint('✅ Défi terminé: ${challenge['title']}');
  }

  // Événements de gamification
  void onOrderPlaced(double orderValue) {
    // Les points de fidélité ne sont plus ajoutés ici : ils sont crédités par
    // le serveur à la **livraison** de la commande (Django,
    // `apps/loyalty/receivers.py on_order_delivered`), pas à sa création — les
    // ajouter ici les compterait en double avec le crédit serveur et
    // afficherait un solde faux jusqu'au prochain rafraîchissement
    // (`_refreshLoyaltyBalance`).

    // Mettre à jour les statistiques
    _totalOrders++;
    unawaited(_loadUserStats());

    // Mettre à jour les défis
    if (_challenges.isNotEmpty) {
      for (final challenge in _challenges) {
        final criteria = (challenge['criteria'] ?? '').toString();
        if (criteria == 'orders') {
          final newProgress =
              ((challenge['progress'] as num?)?.toInt() ?? 0) + 1;
          updateChallengeProgress(challenge['id'], newProgress);
        }
      }
    }

    _evaluateBadges();
    notifyListeners();
  }

  void onReviewLeft() {
    unawaited(
      addPoints(
        10,
        'Avis laissé',
        metadata: {'event': 'review'},
      ),
    );

    for (final achievement in _achievements) {
      final criteria = (achievement['criteria'] ?? '').toString();
      if (criteria == 'reviews' && achievement['isUnlocked'] != true) {
        achievement['progress'] =
            ((achievement['progress'] as num?)?.toInt() ?? 0) + 1;
        unawaited(_persistAchievement(achievement));
      }
    }

    unawaited(_checkAchievements());
  }

  void onAppShared() {
    unawaited(
      addPoints(
        25,
        'Application partagée',
        metadata: {'event': 'share'},
      ),
    );

    for (final challenge in _challenges) {
      final criteria = (challenge['criteria'] ?? '').toString();
      if (criteria == 'shares') {
        final newProgress = ((challenge['progress'] as num?)?.toInt() ?? 0) + 1;
        updateChallengeProgress(challenge['id'], newProgress);
      }
    }
  }

  void onNewDishTried() {
    unawaited(
      addPoints(
        15,
        'Nouveau plat essayé',
        metadata: {'event': 'new_dish'},
      ),
    );

    for (final challenge in _challenges) {
      final criteria = (challenge['criteria'] ?? '').toString();
      if (criteria == 'dishes') {
        final newProgress = ((challenge['progress'] as num?)?.toInt() ?? 0) + 1;
        updateChallengeProgress(challenge['id'], newProgress);
      }
    }

    for (final achievement in _achievements) {
      final criteria = (achievement['criteria'] ?? '').toString();
      if (criteria == 'dishes' && achievement['isUnlocked'] != true) {
        achievement['progress'] =
            ((achievement['progress'] as num?)?.toInt() ?? 0) + 1;
        unawaited(_persistAchievement(achievement));
      }
    }

    unawaited(_checkAchievements());
  }

  // Obtenir les statistiques pour le profil
  Map<String, dynamic> getUserStats() {
    return {
      'totalPoints': _currentPoints,
      'level': _currentLevel,
      'levelTitle': currentLevelTitle,
      'totalOrders': _totalOrders,
      'streakDays': _streakDays,
      'achievementsUnlocked': _achievements.where((a) {
        return a['isUnlocked'] as bool? ?? false;
      }).length,
      'challengesCompleted': _challenges.where((c) {
        return !(c['isActive'] as bool? ?? true);
      }).length,
    };
  }
}
