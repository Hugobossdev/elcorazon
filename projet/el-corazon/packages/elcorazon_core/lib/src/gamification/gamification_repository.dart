import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/gamification/achievement.dart';
import 'package:elcorazon_core/src/gamification/badge.dart';
import 'package:elcorazon_core/src/gamification/challenge.dart';

/// Accès à `/api/v1/gamification/*` — voir
/// `backend/apps/gamification/{serializers,views}.py`. Entièrement en
/// lecture seule : rien ne se débloque depuis l'API, le déblocage est un
/// effet de bord serveur de la livraison d'une commande.
class GamificationRepository {
  GamificationRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<Badge>> getBadges() async {
    final badges = <Badge>[];
    String? path = '/gamification/badges/';

    while (path != null) {
      final response = await apiClient.get(path);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      badges.addAll(results.map((json) => Badge.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
    }

    return badges;
  }

  Future<List<Achievement>> getAchievements() async {
    final achievements = <Achievement>[];
    String? path = '/gamification/achievements/';

    while (path != null) {
      final response = await apiClient.get(path);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      achievements.addAll(results.map((json) => Achievement.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
    }

    return achievements;
  }

  Future<List<Challenge>> getChallenges() async {
    final challenges = <Challenge>[];
    String? path = '/gamification/challenges/';

    while (path != null) {
      final response = await apiClient.get(path);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      challenges.addAll(results.map((json) => Challenge.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
    }

    return challenges;
  }
}
