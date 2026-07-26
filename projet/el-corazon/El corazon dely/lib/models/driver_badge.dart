class DriverBadge {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String? criteria;
  final DateTime createdAt;

  DriverBadge({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.criteria,
    required this.createdAt,
  });

  factory DriverBadge.fromMap(Map<String, dynamic> map) {
    return DriverBadge(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      iconUrl: map['icon_url'],
      criteria: map['criteria'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'criteria': criteria,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

