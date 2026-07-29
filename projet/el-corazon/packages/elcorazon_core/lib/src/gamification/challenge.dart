/// Défi en cours — miroir de `ChallengeSerializer`. Le serveur ne renvoie que
/// les défis actifs dont la fenêtre (`starts_at`/`ends_at`) couvre l'instant
/// présent — un défi passé ou à venir n'a rien à consulter pour le client.
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.challengeType,
    required this.targetValue,
    required this.rewardPoints,
    required this.startsAt,
    required this.endsAt,
    required this.progress,
    required this.isCompleted,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      challengeType: json['challenge_type'] as String,
      targetValue: json['target_value'] as int,
      rewardPoints: json['reward_points'] as int,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      progress: json['progress'] as int,
      isCompleted: json['is_completed'] as bool,
    );
  }

  final String id;
  final String title;
  final String description;
  final String challengeType;
  final int targetValue;
  final int rewardPoints;
  final DateTime startsAt;
  final DateTime endsAt;
  final int progress;
  final bool isCompleted;
}
