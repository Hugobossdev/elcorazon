/// Succès — miroir de `AchievementSerializer`. Le déblocage est un effet de
/// bord de la livraison d'une commande (`apps.gamification.receivers`) —
/// jamais quelque chose que ce repository déclare.
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.conditionType,
    required this.conditionValue,
    required this.pointsReward,
    required this.progress,
    required this.isUnlocked,
    this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '🏆',
      conditionType: json['condition_type'] as String,
      conditionValue: json['condition_value'] as int,
      pointsReward: json['points_reward'] as int,
      progress: json['progress'] as int,
      isUnlocked: json['is_unlocked'] as bool,
      unlockedAt: json['unlocked_at'] == null ? null : DateTime.parse(json['unlocked_at'] as String),
    );
  }

  final String id;
  final String name;
  final String description;
  final String icon;
  final String conditionType;
  final int conditionValue;
  final int pointsReward;
  final int progress;
  final bool isUnlocked;
  final DateTime? unlockedAt;
}
