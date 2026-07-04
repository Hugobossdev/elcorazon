class DriverBadge {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String? criteria;
  final DateTime? earnedAt;

  DriverBadge({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.criteria,
    this.earnedAt,
  });

  factory DriverBadge.fromMap(Map<String, dynamic> map) {
    // Gérer le cas où on récupère depuis la table driver_badges ou la vue jointe
    final badgeData = map.containsKey('driver_badges')
        ? map['driver_badges'] as Map<String, dynamic>
        : map;

    return DriverBadge(
      id: badgeData['id'] as String,
      name: badgeData['name'] as String,
      description: badgeData['description'] as String?,
      iconUrl: badgeData['icon_url'] as String?,
      criteria: badgeData['criteria'] as String?,
      earnedAt: map['earned_at'] != null
          ? DateTime.parse(map['earned_at'] as String)
          : null,
    );
  }
}
