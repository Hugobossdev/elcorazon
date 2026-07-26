import 'package:flutter/foundation.dart';

class GamificationService extends ChangeNotifier {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  bool _isInitialized = false;
  int _userPoints = 0;
  final List<String> _userBadges = [];
  int _currentLevel = 1;
  final List<Map<String, dynamic>> _achievements = [];

  bool get isInitialized => _isInitialized;
  int get userPoints => _userPoints;
  List<String> get userBadges => List.unmodifiable(_userBadges);
  int get currentLevel => _currentLevel;
  List<Map<String, dynamic>> get achievements =>
      List.unmodifiable(_achievements);

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Web-compatible gamification initialization
      _isInitialized = true;
      notifyListeners();
      debugPrint('Web: Gamification service initialized');
    } catch (e) {
      debugPrint('Error initializing Gamification Service: $e');
    }
  }

  Future<void> addPoints(int points, {String? reason}) async {
    _userPoints += points;
    _checkLevelUp();
    notifyListeners();
    debugPrint('Added $points points. Reason: $reason');
  }

  Future<void> awardBadge(String badgeId) async {
    if (!_userBadges.contains(badgeId)) {
      _userBadges.add(badgeId);
      notifyListeners();
      debugPrint('Badge awarded: $badgeId');
    }
  }

  void _checkLevelUp() {
    int newLevel = (_userPoints / 1000).floor() + 1;
    if (newLevel > _currentLevel) {
      _currentLevel = newLevel;
      debugPrint('Level up! New level: $_currentLevel');
    }
  }

  Future<void> completeAchievement(String achievementId) async {
    if (!_achievements.any((a) => a['id'] == achievementId)) {
      _achievements.add({
        'id': achievementId,
        'completedAt': DateTime.now(),
        'points': 100,
      });
      await addPoints(100, reason: 'Achievement: $achievementId');
    }
  }

  Map<String, dynamic> getUserStats() {
    return {
      'points': _userPoints,
      'level': _currentLevel,
      'badges': _userBadges.length,
      'achievements': _achievements.length,
      'nextLevelPoints': (_currentLevel * 1000) - _userPoints,
    };
  }
}
