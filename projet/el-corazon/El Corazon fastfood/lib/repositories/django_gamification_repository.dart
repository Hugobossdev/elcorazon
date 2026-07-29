import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/main.dart' show apiClient;

/// Gamification contre le backend Django (Phase 6) — badges seulement dans
/// cette tranche (le seul catalogue affiché par un écran,
/// `rewards_screen.dart`). Achievements/défis restent construits dans
/// `elcorazon_core` pour un futur écran, non câblés ici.
class DjangoGamificationRepository {
  DjangoGamificationRepository() : _gamification = eccore.GamificationRepository(apiClient: apiClient);

  final eccore.GamificationRepository _gamification;

  /// Forme `Map` déjà consommée par `GamificationService`/`rewards_screen.dart`
  /// — pas de nouveau modèle local, `isUnlocked`/`unlockedAt` viennent
  /// directement de Django, plus jamais recalculés côté client.
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
