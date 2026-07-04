/// Modèle de notification pour l'application
class NotificationModel {
  final int id;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationPriority priority;
  final String? payload;
  final DateTime createdAt;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.priority,
    this.payload,
    required this.createdAt,
    required this.isRead,
  });

  /// Créer une copie avec des modifications
  NotificationModel copyWith({
    int? id,
    String? title,
    String? body,
    NotificationType? type,
    NotificationPriority? priority,
    String? payload,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Convertir en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.toString(),
      'priority': priority.toString(),
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  /// Créer depuis JSON
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => NotificationType.general,
      ),
      priority: NotificationPriority.values.firstWhere(
        (e) => e.toString() == json['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      payload: json['payload'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'NotificationModel(id: $id, title: $title, type: $type, isRead: $isRead)';
  }
}

/// Types de notifications
enum NotificationType {
  general,
  order,
  delivery,
  promotion,
  reminder,
  reward,
  system,
}

/// Priorités de notifications
enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

