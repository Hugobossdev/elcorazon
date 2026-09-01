import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/main.dart' show apiClient;

/// Gamification contre le backend Django (Phase 6) — badges, succès et défis.
///
/// **Lecture seule, et c'est le fond du sujet.** La progression et le
/// déblocage sont calculés par le serveur à la livraison d'une commande ; le
/// client les lit. L'implémentation Supabase écrivait `user_achievements`,
/// `user_challenges` et le solde de points depuis le téléphone : n'importe qui
/// pouvait se déclarer tous les succès débloqués et se créditer les points
/// correspondants.
class DjangoGamificationRepository {
  DjangoGamificationRepository() : _gamification = eccore.GamificationRepository(apiClient: apiClient);

  final eccore.GamificationRepository _gamification;

  /// Forme `Map` déjà consommée par `GamificationService`/`rewards_screen.dart`
  /// — pas de nouveau modèle local, `isUnlocked`/`unlockedAt` viennent
  /// directement de Django, plus jamais recalculés côté client.
  /// Succès du catalogue, avec la progression de l'appelant.
  Future<List<Map<String, dynamic>>> getAchievements() async {
    final achievements = await _gamification.getAchievements();
    return achievements
        .map(
          (achievement) => {
            'id': achievement.id,
            'title': achievement.name,
            'description': achievement.description,
            'icon': achievement.icon,
            'points': achievement.pointsReward,
            'target': achievement.conditionValue,
            'criteria': achievement.conditionType,
            'progress': achievement.progress,
            'isUnlocked': achievement.isUnlocked,
            'unlockedAt': achievement.unlockedAt,
          },
        )
        .toList();
  }

  /// Défis **en cours** — le serveur écarte ceux qui sont passés ou à venir.
  Future<List<Map<String, dynamic>>> getChallenges() async {
    final challenges = await _gamification.getChallenges();
    return challenges
        .map(
          (challenge) => {
            'id': challenge.id,
            'title': challenge.title,
            'description': challenge.description,
            // Vide, comme le rendent `achievement.icon` et `badge.icon`
            // quand le serveur n'en publie pas : le contrat `Challenge` ne
            // porte pas d'icône, et la fabriquer ici — c'était `'🎯'` —
            // inventait une donnée. Aucun écran ne lit cette clé.
            'icon': '',
            'reward': challenge.rewardPoints,
            'target': challenge.targetValue,
            'criteria': challenge.challengeType,
            'progress': challenge.progress,
            'isActive': true,
            'isCompleted': challenge.isCompleted,
            'startDate': challenge.startsAt,
            'endDate': challenge.endsAt,
            'completedAt': null,
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getBadges() async {
    final badges = await _gamification.getBadges();
    return badges
        .map(
          (badge) => {
            'id': badge.id,
            'title': badge.title,
            'description': badge.description,
            'icon': badge.icon,
            'target': badge.pointsRequired,
            'isUnlocked': badge.isUnlocked,
            'unlockedAt': badge.unlockedAt,
          },
        )
        .toList();
  }
}
