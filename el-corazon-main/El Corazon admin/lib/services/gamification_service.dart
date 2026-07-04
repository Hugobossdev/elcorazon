import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GamificationService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _badges = [];
  List<Map<String, dynamic>> _loyaltyRewards = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get achievements => _achievements;
  List<Map<String, dynamic>> get challenges => _challenges;
  List<Map<String, dynamic>> get badges => _badges;
  List<Map<String, dynamic>> get loyaltyRewards => _loyaltyRewards;
  bool get isLoading => _isLoading;
  String? get error => _error;

  GamificationService() {
    // Ne pas charger automatiquement dans le constructeur
    // Le chargement sera déclenché par initialize()
  }

  /// Charger toutes les données de gamification
  Future<void> _loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadAchievements(),
        _loadChallenges(),
        _loadBadges(),
        _loadLoyaltyRewards(),
      ]);
    } catch (e) {
      _error = e.toString();
      debugPrint('GamificationService: Erreur chargement - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les achievements
  Future<void> _loadAchievements() async {
    try {
      final response = await _supabase
          .from('achievements')
          .select('*')
          .order('created_at', ascending: false);

      _achievements = (response as List).map((data) {
        return {
          'id': data['id'],
          'name': data['name'],
          'description': data['description'],
          'icon': data['icon'],
          'points_reward': data['points_reward'] ?? 0,
          'badge_reward': data['badge_reward'],
          'condition_type': data['condition_type'],
          'condition_value': data['condition_value'],
          'is_active': data['is_active'] ?? true,
          'created_at': data['created_at'],
        };
      }).toList();

      debugPrint('GamificationService: ${_achievements.length} achievements chargés');
    } catch (e) {
      debugPrint('GamificationService: Erreur chargement achievements - $e');
      _achievements = [];
    }
  }

  /// Charger les challenges
  Future<void> _loadChallenges() async {
    try {
      final response = await _supabase
          .from('challenges')
          .select('*')
          .order('created_at', ascending: false);

      _challenges = (response as List).map((data) {
        return {
          'id': data['id'],
          'title': data['title'],
          'description': data['description'],
          'challenge_type': data['challenge_type'],
          'target_value': data['target_value'],
          'reward_points': data['reward_points'] ?? 0,
          'reward_discount': data['reward_discount'] ?? 0.0,
          'start_date': data['start_date'],
          'end_date': data['end_date'],
          'is_active': data['is_active'] ?? true,
          'created_at': data['created_at'],
        };
      }).toList();

      debugPrint('GamificationService: ${_challenges.length} challenges chargés');
    } catch (e) {
      debugPrint('GamificationService: Erreur chargement challenges - $e');
      _challenges = [];
    }
  }

  /// Charger les badges
  Future<void> _loadBadges() async {
    try {
      final response = await _supabase
          .from('badges')
          .select('*')
          .order('points_required', ascending: true);

      _badges = (response as List).map((data) {
        return {
          'id': data['id'],
          'title': data['title'],
          'description': data['description'],
          'icon': data['icon'] ?? '🏅',
          'points_required': data['points_required'] ?? 0,
          'criteria': data['criteria'] ?? 'points',
          'is_active': data['is_active'] ?? true,
          'created_at': data['created_at'],
        };
      }).toList();

      debugPrint('GamificationService: ${_badges.length} badges chargés');
    } catch (e) {
      debugPrint('GamificationService: Erreur chargement badges - $e');
      _badges = [];
    }
  }

  /// Charger les récompenses de fidélité
  Future<void> _loadLoyaltyRewards() async {
    try {
      final response = await _supabase
          .from('loyalty_rewards')
          .select('*')
          .order('cost', ascending: true);

      _loyaltyRewards = (response as List).map((data) {
        return {
          'id': data['id'],
          'title': data['title'],
          'description': data['description'],
          'cost': data['cost'],
          'reward_type': data['reward_type'],
          'value': data['value'],
          'is_active': data['is_active'] ?? true,
          'created_at': data['created_at'],
        };
      }).toList();

      debugPrint('GamificationService: ${_loyaltyRewards.length} récompenses chargées');
    } catch (e) {
      debugPrint('GamificationService: Erreur chargement récompenses - $e');
      _loyaltyRewards = [];
    }
  }

  // =====================================================
  // GESTION DES ACHIEVEMENTS
  // =====================================================

  /// Créer un achievement
  Future<Map<String, dynamic>?> createAchievement({
    required String name,
    required String description,
    required String icon,
    int pointsReward = 0,
    String? badgeReward,
    required String conditionType,
    required int conditionValue,
    bool isActive = true,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Vérifier que le nom n'existe pas déjà
      final existing = await _supabase
          .from('achievements')
          .select('id')
          .eq('name', name)
          .maybeSingle();

      if (existing != null) {
        _error = 'Un achievement avec ce nom existe déjà';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final response = await _supabase
          .from('achievements')
          .insert({
            'name': name,
            'description': description,
            'icon': icon,
            'points_reward': pointsReward,
            'badge_reward': badgeReward,
            'condition_type': conditionType,
            'condition_value': conditionValue,
            'is_active': isActive,
          })
          .select()
          .single();

      final achievement = Map<String, dynamic>.from(response);
      _achievements.insert(0, achievement);

      _isLoading = false;
      notifyListeners();
      return achievement;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('GamificationService: Erreur création achievement - $e');
      return null;
    }
  }

  /// Mettre à jour un achievement
  Future<bool> updateAchievement(String id, Map<String, dynamic> updates) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Vérifier l'unicité du nom si modifié
      if (updates.containsKey('name')) {
        final existing = await _supabase
            .from('achievements')
            .select('id')
            .eq('name', updates['name'])
            .neq('id', id)
            .maybeSingle();

        if (existing != null) {
          _error = 'Un achievement avec ce nom existe déjà';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      await _supabase.from('achievements').update(updates).eq('id', id);

      await _loadAchievements();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('GamificationService: Erreur mise à jour achievement - $e');
      return false;
    }
  }

  /// Supprimer un achievement
  Future<bool> deleteAchievement(String id) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.from('achievements').delete().eq('id', id);
      _achievements.removeWhere((a) => a['id'] == id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('GamificationService: Erreur suppression achievement - $e');
      return false;
    }
  }

  // =====================================================
  // GESTION DES CHALLENGES
  // =====================================================

  /// Créer un challenge
  Future<Map<String, dynamic>?> createChallenge({
    required String title,
    required String description,
    required String challengeType,
    required int targetValue,
    int rewardPoints = 0,
    double rewardDiscount = 0.0,
    required DateTime startDate,
    required DateTime endDate,
    bool isActive = true,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase
          .from('challenges')
          .insert({
            'title': title,
            'description': description,
            'challenge_type': challengeType,
            'target_value': targetValue,
            'reward_points': rewardPoints,
            'reward_discount': rewardDiscount,
            'start_date': startDate.toIso8601String(),
            'end_date': endDate.toIso8601String(),
            'is_active': isActive,
          })
          .select()
          .single();

      final challenge = Map<String, dynamic>.from(response);
      _challenges.insert(0, challenge);

      _isLoading = false;
      notifyListeners();
      return challenge;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('GamificationService: Erreur création challenge - $e');
      return null;
    }
  }

  /// Mettre à jour un challenge
  Future<bool> updateChallenge(String id, Map<String, dynamic> updates) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.from('challenges').update(updates).eq('id', id);
      await _loadChallenges();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('GamificationService: Erreur mise à jour challenge - $e');
      return false;
    }
  }

  /// Supprimer un challenge
  Future<bool> deleteChallenge(String id) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.from('challenges').delete().eq('id', id);
      _challenges.removeWhere((c) => c['id'] == id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('GamificationService: Erreur suppression challenge - $e');
      return false;
    }
  }

  // =====================================================
  // GESTION DES BADGES
  // =====================================================

  /// Créer un badge
  Future<Map<String, dynamic>?> createBadge({
    required String title,
    String? description,
    String icon = '🏅',
    int pointsRequired = 0,
    String criteria = 'points',
    bool isActive = true,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase
          .from('badges')
          .insert({
            'title': title,
            'description': description,
            'icon': icon,
            'points_required': pointsRequired,
            'criteria': criteria,
            'is_active': isActive,
          })
          .select()
          .single();

      final badge = Map<String, dynamic>.from(response);
      _badges.add(badge);
      _badges.sort((a, b) => (a['points_required'] as int).compareTo(b['points_required'] as int));

      _isLoading = false;
      notifyListeners();
      return badge;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('GamificationService: Erreur création badge - $e');
      return null;
    }
  }

  /// Mettre à jour un badge
  Future<bool> updateBadge(String id, Map<String, dynamic> updates) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.from('badges').update(updates).eq('id', id);
      await _loadBadges();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('GamificationService: Erreur mise à jour badge - $e');
      return false;
    }
  }

  /// Supprimer un badge
  Future<bool> deleteBadge(String id) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.from('badges').delete().eq('id', id);
      _badges.removeWhere((b) => b['id'] == id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('GamificationService: Erreur suppression badge - $e');
      return false;
    }
  }

  // =====================================================
  // GESTION DES RÉCOMPENSES DE FIDÉLITÉ
  // =====================================================

  /// Créer une récompense de fidélité
  Future<Map<String, dynamic>?> createLoyaltyReward({
    required String title,
    String? description,
    required int cost,
    required String rewardType,
    double? value,
    bool isActive = true,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Générer un ID unique pour la récompense
      // Utiliser un format similaire aux récompenses existantes: loyalty_<type>_<timestamp>
      final rewardId = 'loyalty_${rewardType}_${DateTime.now().millisecondsSinceEpoch}';
      
      final response = await _supabase
          .from('loyalty_rewards')
          .insert({
            'id': rewardId,
            'title': title,
            'description': description,
            'cost': cost,
            'reward_type': rewardType,
            'value': value,
            'is_active': isActive,
          })
          .select()
          .single();

      final reward = Map<String, dynamic>.from(response);
      _loyaltyRewards.add(reward);
      _loyaltyRewards.sort((a, b) => (a['cost'] as int).compareTo(b['cost'] as int));

      _isLoading = false;
      notifyListeners();
      return reward;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('GamificationService: Erreur création récompense - $e');
      return null;
    }
  }

  /// Mettre à jour une récompense de fidélité
  Future<bool> updateLoyaltyReward(String id, Map<String, dynamic> updates) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.from('loyalty_rewards').update(updates).eq('id', id);
      await _loadLoyaltyRewards();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('GamificationService: Erreur mise à jour récompense - $e');
      return false;
    }
  }

  /// Supprimer une récompense de fidélité
  Future<bool> deleteLoyaltyReward(String id) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.from('loyalty_rewards').delete().eq('id', id);
      _loyaltyRewards.removeWhere((r) => r['id'] == id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('GamificationService: Erreur suppression récompense - $e');
      return false;
    }
  }

  // =====================================================
  // STATISTIQUES ET ANALYTICS
  // =====================================================

  /// Obtenir les statistiques de gamification pour un utilisateur
  Future<Map<String, dynamic>> getUserGamificationStats(String userId) async {
    try {
      // Récupérer les achievements de l'utilisateur
      final userAchievements = await _supabase
          .from('user_achievements')
          .select('*, achievements(*)')
          .eq('user_id', userId);

      // Récupérer les challenges de l'utilisateur
      final userChallenges = await _supabase
          .from('user_challenges')
          .select('*, challenges(*)')
          .eq('user_id', userId);

      // Récupérer les badges de l'utilisateur
      final userBadges = await _supabase
          .from('user_badges')
          .select('*, badges(*)')
          .eq('user_id', userId);

      // Récupérer les transactions de fidélité
      final transactions = await _supabase
          .from('loyalty_transactions')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Récupérer les récompenses échangées
      final redemptions = await _supabase
          .from('reward_redemptions')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final unlockedAchievements = (userAchievements as List)
          .where((ua) => ua['is_unlocked'] == true)
          .length;

      final completedChallenges = (userChallenges as List)
          .where((uc) => uc['is_completed'] == true)
          .length;

      final unlockedBadges = (userBadges as List)
          .where((ub) => ub['is_unlocked'] == true)
          .length;

      final totalPointsEarned = (transactions as List)
          .where((t) => t['transaction_type'] == 'earn')
          .fold<int>(0, (sum, t) => sum + (t['points'] as int? ?? 0));

      final totalPointsRedeemed = (transactions as List)
          .where((t) => t['transaction_type'] == 'redeem')
          .fold<int>(0, (sum, t) => sum + (t['points'] as int? ?? 0));

      return {
        'unlocked_achievements': unlockedAchievements,
        'total_achievements': _achievements.length,
        'completed_challenges': completedChallenges,
        'active_challenges': (userChallenges as List)
            .where((uc) => uc['is_completed'] == false)
            .length,
        'unlocked_badges': unlockedBadges,
        'total_badges': _badges.length,
        'total_points_earned': totalPointsEarned,
        'total_points_redeemed': totalPointsRedeemed,
        'total_redemptions': redemptions.length,
      };
    } catch (e) {
      debugPrint('GamificationService: Erreur stats utilisateur - $e');
      return {};
    }
  }

  /// Obtenir les statistiques globales de gamification
  Future<Map<String, dynamic>> getGlobalGamificationStats() async {
    try {
      // Compter les utilisateurs avec des achievements
      final usersWithAchievements = await _supabase
          .from('user_achievements')
          .select('user_id')
          .eq('is_unlocked', true);

      // Compter les utilisateurs avec des challenges
      final usersWithChallenges = await _supabase
          .from('user_challenges')
          .select('user_id')
          .eq('is_completed', true);

      // Compter les utilisateurs avec des badges
      final usersWithBadges = await _supabase
          .from('user_badges')
          .select('user_id')
          .eq('is_unlocked', true);

      // Compter les transactions de fidélité
      final totalTransactions = await _supabase
          .from('loyalty_transactions')
          .select('id');

      // Compter les récompenses échangées
      final totalRedemptions = await _supabase
          .from('reward_redemptions')
          .select('id');

      return {
        'total_achievements': _achievements.length,
        'active_achievements': _achievements.where((a) => a['is_active'] == true).length,
        'total_challenges': _challenges.length,
        'active_challenges': _challenges.where((c) => c['is_active'] == true).length,
        'total_badges': _badges.length,
        'active_badges': _badges.where((b) => b['is_active'] == true).length,
        'total_loyalty_rewards': _loyaltyRewards.length,
        'active_loyalty_rewards': _loyaltyRewards.where((r) => r['is_active'] == true).length,
        'users_with_achievements': (usersWithAchievements as List).toSet().length,
        'users_with_challenges': (usersWithChallenges as List).toSet().length,
        'users_with_badges': (usersWithBadges as List).toSet().length,
        'total_transactions': (totalTransactions as List).length,
        'total_redemptions': (totalRedemptions as List).length,
      };
    } catch (e) {
      debugPrint('GamificationService: Erreur stats globales - $e');
      return {};
    }
  }

  /// Rafraîchir toutes les données
  Future<void> refresh() async {
    await _loadAll();
  }

  /// Initialiser le service
  Future<void> initialize() async {
    await _loadAll();
  }
}
