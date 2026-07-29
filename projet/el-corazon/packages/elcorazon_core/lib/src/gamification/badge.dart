/// Badge de fidélité — miroir de `BadgeSerializer`
/// (`backend/apps/gamification/serializers.py`). Adossé aux points gagnés à
/// vie (`PointsAccount.lifetime_earned`), pas au solde courant — un badge ne
/// se retire pas parce que des points ont été dépensés.
class Badge {
  const Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.pointsRequired,
    required this.isUnlocked,
    this.unlockedAt,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '🏅',
      pointsRequired: json['points_required'] as int,
      isUnlocked: json['is_unlocked'] as bool,
      unlockedAt: json['unlocked_at'] == null ? null : DateTime.parse(json['unlocked_at'] as String),
    );
  }

  final String id;
  final String title;
  final String description;
  final String icon;
  final int pointsRequired;
  final bool isUnlocked;
  final DateTime? unlockedAt;
}
