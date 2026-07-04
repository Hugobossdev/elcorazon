import 'package:flutter/material.dart';

class GamificationService extends ChangeNotifier {
  int _currentPoints = 125;
  int _currentLevel = 2;
  int _totalOrders = 8;
  int _streakDays = 5;
  double _levelProgress = 0.6;
  
  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _rewards = [];

  // Getters
  int get currentPoints => _currentPoints;
  int get currentLevel => _currentLevel;
  int get totalOrders => _totalOrders;
  int get streakDays => _streakDays;
  double get levelProgress => _levelProgress;
  List<Map<String, dynamic>> get achievements => _achievements;
  List<Map<String, dynamic>> get challenges => _challenges;
  List<Map<String, dynamic>> get rewards => _rewards;

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

  void initialize() {
    _loadAchievements();
    _loadChallenges();
    _loadRewards();
  }

  void _loadAchievements() {
    _achievements = [
      {
        'id': 1,
        'title': 'Premier Pas',
        'description': 'Faire votre première commande',
        'icon': '🎯',
        'points': 10,
        'isUnlocked': true,
        'unlockedAt': DateTime.now().subtract(const Duration(days: 7)),
      },
      {
        'id': 2,
        'title': 'Habitué',
        'description': 'Faire 5 commandes',
        'icon': '🏆',
        'points': 25,
        'isUnlocked': true,
        'unlockedAt': DateTime.now().subtract(const Duration(days: 3)),
      },
      {
        'id': 3,
        'title': 'Explorateur',
        'description': 'Essayer 10 plats différents',
        'icon': '🗺️',
        'points': 50,
        'isUnlocked': false,
        'progress': 7,
        'target': 10,
      },
      {
        'id': 4,
        'title': 'Série de Victoires',
        'description': 'Commander 7 jours consécutifs',
        'icon': '🔥',
        'points': 75,
        'isUnlocked': false,
        'progress': 5,
        'target': 7,
      },
      {
        'id': 5,
        'title': 'Critique Culinaire',
        'description': 'Laisser 20 avis',
        'icon': '⭐',
        'points': 100,
        'isUnlocked': false,
        'progress': 3,
        'target': 20,
      },
      {
        'id': 6,
        'title': 'Champion El Corazón',
        'description': 'Atteindre le niveau 5',
        'icon': '👑',
        'points': 200,
        'isUnlocked': false,
        'progress': 2,
        'target': 5,
      },
    ];
  }

  void _loadChallenges() {
    _challenges = [
      {
        'id': 1,
        'title': 'Défi Weekend',
        'description': 'Commandez 3 fois ce weekend',
        'icon': '🎯',
        'reward': 50,
        'progress': 1,
        'target': 3,
        'endDate': DateTime.now().add(const Duration(days: 2)),
        'isActive': true,
      },
      {
        'id': 2,
        'title': 'Découverte Culinaire',
        'description': 'Essayez 2 nouveaux plats cette semaine',
        'icon': '🍽️',
        'reward': 30,
        'progress': 0,
        'target': 2,
        'endDate': DateTime.now().add(const Duration(days: 5)),
        'isActive': true,
      },
      {
        'id': 3,
        'title': 'Partageur',
        'description': 'Partagez l\'app avec 3 amis',
        'icon': '👥',
        'reward': 100,
        'progress': 1,
        'target': 3,
        'endDate': DateTime.now().add(const Duration(days: 7)),
        'isActive': true,
      },
    ];
  }

  void _loadRewards() {
    _rewards = [
      {
        'id': 1,
        'title': 'Boisson Gratuite',
        'description': 'Une boisson de votre choix offerte',
        'icon': '🥤',
        'cost': 50,
        'category': 'Boisson',
        'isAvailable': true,
      },
      {
        'id': 2,
        'title': 'Frites Gratuites',
        'description': 'Portion de frites offerte',
        'icon': '🍟',
        'cost': 75,
        'category': 'Accompagnement',
        'isAvailable': true,
      },
      {
        'id': 3,
        'title': '10% de Réduction',
        'description': 'Sur votre prochaine commande',
        'icon': '💰',
        'cost': 100,
        'category': 'Réduction',
        'isAvailable': true,
      },
      {
        'id': 4,
        'title': 'Burger Gratuit',
        'description': 'Un burger de votre choix offert',
        'icon': '🍔',
        'cost': 150,
        'category': 'Plat Principal',
        'isAvailable': true,
      },
      {
        'id': 5,
        'title': '20% de Réduction',
        'description': 'Sur votre prochaine commande',
        'icon': '🎁',
        'cost': 200,
        'category': 'Réduction',
        'isAvailable': true,
      },
      {
        'id': 6,
        'title': 'Menu Complet Gratuit',
        'description': 'Un menu complet offert',
        'icon': '🍽️',
        'cost': 300,
        'category': 'Menu',
        'isAvailable': _currentPoints >= 300,
      },
    ];
  }

  // Ajouter des points
  void addPoints(int points, String reason) {
    _currentPoints += points;
    _checkLevelUp();
    _checkAchievements();
    notifyListeners();
    
    // Afficher une notification de points gagnés
    _showPointsNotification(points, reason);
  }

  // Vérifier si l'utilisateur peut monter de niveau
  void _checkLevelUp() {
    int pointsForNextLevel = (_currentLevel * 100);
    if (_currentPoints >= pointsForNextLevel) {
      _currentLevel++;
      _levelProgress = (_currentPoints % 100) / 100.0;
      _showLevelUpNotification();
    } else {
      _levelProgress = (_currentPoints % 100) / 100.0;
    }
  }

  // Vérifier les achievements
  void _checkAchievements() {
    for (var achievement in _achievements) {
      if (!achievement['isUnlocked']) {
        bool shouldUnlock = false;
        
        switch (achievement['id']) {
          case 3: // Explorateur
            achievement['progress'] = 7; // Simulé
            shouldUnlock = achievement['progress'] >= achievement['target'];
            break;
          case 4: // Série de victoires
            achievement['progress'] = _streakDays;
            shouldUnlock = achievement['progress'] >= achievement['target'];
            break;
          case 6: // Champion El Corazón
            achievement['progress'] = _currentLevel;
            shouldUnlock = achievement['progress'] >= achievement['target'];
            break;
        }
        
        if (shouldUnlock) {
          achievement['isUnlocked'] = true;
          achievement['unlockedAt'] = DateTime.now();
          addPoints(achievement['points'], 'Achievement: ${achievement['title']}');
          _showAchievementUnlockedNotification(achievement);
        }
      }
    }
  }

  // Utiliser des points pour une récompense
  bool redeemReward(Map<String, dynamic> reward) {
    final cost = reward['cost'] as int;
    if (_currentPoints >= cost) {
      _currentPoints -= cost;
      notifyListeners();
      return true;
    }
    return false;
  }

  // Mettre à jour le progrès d'un défi
  void updateChallengeProgress(int challengeId, int progress) {
    final challengeIndex = _challenges.indexWhere((c) => c['id'] == challengeId);
    if (challengeIndex != -1) {
      _challenges[challengeIndex]['progress'] = progress;
      
      // Vérifier si le défi est terminé
      if (progress >= _challenges[challengeIndex]['target']) {
        final reward = _challenges[challengeIndex]['reward'];
        addPoints(reward, 'Défi terminé: ${_challenges[challengeIndex]['title']}');
        _challenges[challengeIndex]['isActive'] = false;
        _showChallengeCompletedNotification(_challenges[challengeIndex]);
      }
      
      notifyListeners();
    }
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
    // Points basés sur la valeur de la commande
    int points = (orderValue / 10).round();
    addPoints(points, 'Commande passée');
    
    // Mettre à jour les statistiques
    _totalOrders++;
    _streakDays++; // Simplifié, devrait vérifier les dates réelles
    
    // Mettre à jour les défis
    updateChallengeProgress(1, _challenges[0]['progress'] + 1); // Défi weekend
    
    notifyListeners();
  }

  void onReviewLeft() {
    addPoints(10, 'Avis laissé');
    
    // Mettre à jour le progrès de l'achievement "Critique Culinaire"
    final criticAchievement = _achievements.firstWhere((a) => a['id'] == 5);
    if (!criticAchievement['isUnlocked']) {
      criticAchievement['progress'] = (criticAchievement['progress'] ?? 0) + 1;
    }
  }

  void onAppShared() {
    addPoints(25, 'Application partagée');
    
    // Mettre à jour le défi "Partageur"
    updateChallengeProgress(3, _challenges[2]['progress'] + 1);
  }

  void onNewDishTried() {
    addPoints(15, 'Nouveau plat essayé');
    
    // Mettre à jour les défis et achievements
    updateChallengeProgress(2, _challenges[1]['progress'] + 1);
    
    final explorerAchievement = _achievements.firstWhere((a) => a['id'] == 3);
    if (!explorerAchievement['isUnlocked']) {
      explorerAchievement['progress'] = (explorerAchievement['progress'] ?? 0) + 1;
    }
  }

  // Obtenir les statistiques pour le profil
  Map<String, dynamic> getUserStats() {
    return {
      'totalPoints': _currentPoints,
      'level': _currentLevel,
      'levelTitle': currentLevelTitle,
      'totalOrders': _totalOrders,
      'streakDays': _streakDays,
      'achievementsUnlocked': _achievements.where((a) => a['isUnlocked']).length,
      'challengesCompleted': _challenges.where((c) => !c['isActive']).length,
    };
  }
}