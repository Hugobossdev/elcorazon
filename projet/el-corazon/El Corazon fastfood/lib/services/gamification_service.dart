import 'dart:async';

import 'package:flutter/material.dart';
import 'package:elcora_fast/models/loyalty_reward.dart';
import 'package:elcora_fast/models/loyalty_transaction.dart';
import 'package:elcora_fast/repositories/django_gamification_repository.dart';
import 'package:elcora_fast/repositories/django_loyalty_repository.dart';
import 'package:elcora_fast/repositories/django_order_repository.dart';

/// Centralise la logique de fidélité (points, récompenses, historique) et de
/// badges (Django, Phase 6) ; achievements/défis restent simulés côté client
/// (aucun écran ne les affiche — voir `_loadAchievements`/`_loadChallenges`).
class GamificationService extends ChangeNotifier {
  static final GamificationService _instance = GamificationService._internal();

  factory GamificationService() => _instance;

  GamificationService._internal();

  final DjangoLoyaltyRepository _loyaltyRepository = DjangoLoyaltyRepository();
  final DjangoGamificationRepository _gamificationRepository = DjangoGamificationRepository();

  int _currentPoints = 0;
  int _currentLevel = 1;
  int _totalOrders = 0;
  int _streakDays = 0;
  double _levelProgress = 0.0;

  String? _currentUserId;
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

  /// [userId] n'est plus qu'un marqueur de changement de compte : toutes les
  /// lectures sont cloisonnées par le jeton côté serveur, aucune ne prend
  /// d'identifiant. L'ancienne version résolvait un profil Supabase pour
  /// obtenir deux identifiants (table et auth) qui n'ont plus de sens ici.
  Future<void> initialize({String? userId, bool forceRefresh = false}) async {
    final previousUserId = _currentUserId;
    _currentUserId = userId ?? _currentUserId;

    await _refreshLoyaltyBalance();

    final hasSameIds = previousUserId == _currentUserId;

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
        _loadTransactions(),
      ]);

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing GamificationService: $e');
    }
  }

  /// Charge les statistiques utilisateur depuis la base de données
  Future<void> _loadUserStats() async {
    try {
      await _refreshLoyaltyBalance();

      // Les commandes vivent désormais dans Django (Phase 6) — le total et la
      // séquence de commandes restent des métriques de gamification (G1, pas
      // migré), mais leur source de données doit suivre.
      final orders = await DjangoOrderRepository().getUserOrders(_currentUserId ?? '');
      _totalOrders = orders.length;
      _streakDays = _calculateStreakDays(
        orders.map((order) => {'created_at': order.createdAt.toIso8601String()}).toList(),
      );
    } catch (e) {
      debugPrint('Error loading user stats: $e');
    }
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

  /// Succès et défis viennent de Django, **progression comprise**.
  ///
  /// La progression n'est plus recalculée ni écrite ici : le serveur la tient
  /// (`apps/gamification`), et la mettait déjà à jour à la livraison d'une
  /// commande. Le client la lisait *et* l'écrivait, ce qui laissait déclarer
  /// n'importe quel succès débloqué — et encaisser les points associés.
  Future<void> _loadAchievements() async {
    try {
      _achievements = await _gamificationRepository.getAchievements();
    } catch (e) {
      debugPrint('Error loading achievements: $e');
      _achievements = [];
    }
  }

  Future<void> _loadChallenges() async {
    try {
      _challenges = await _gamificationRepository.getChallenges();
    } catch (e) {
      debugPrint('Error loading challenges: $e');
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

  Future<void> _loadTransactions() async {
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
      await _loadTransactions();
    } catch (e) {
      debugPrint('Error refreshing transactions after redemption: $e');
    }

    _pendingRewardIds.remove(reward.id);
    _checkLevelUp();
    notifyListeners();
    return true;
  }

  // Notifications simulées
  void _showLevelUpNotification() {
    debugPrint('🆙 Félicitations! Vous avez atteint le niveau $_currentLevel!');
  }

  /// Une commande vient d'être passée : rien n'est décidé ici.
  ///
  /// Points, progression des succès et des défis sont crédités par le serveur
  /// à la **livraison** (`apps/loyalty/receivers.py`), pas à la création. Cette
  /// méthode ne fait donc que redemander l'état au serveur — avancer les
  /// compteurs localement afficherait une progression que le backend ne
  /// confirmerait pas, et la ferait « reculer » au rafraîchissement suivant.
  void onOrderPlaced(double orderValue) {
    unawaited(refresh());
  }

  /// Relit points, statistiques, succès et défis.
  Future<void> refresh() async {
    await _loadUserStats();
    await Future.wait([_loadAchievements(), _loadChallenges(), _loadBadges()]);
    notifyListeners();
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
