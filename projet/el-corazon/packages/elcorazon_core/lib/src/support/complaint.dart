/// Réclamation sur une commande — miroir de `ComplaintSerializer`
/// (`backend/apps/support/serializers.py`). Le client désigne une commande ;
/// c'est le serveur qui vérifie qu'elle est bien la sienne.
class Complaint {
  const Complaint({
    required this.id,
    required this.orderId,
    required this.kind,
    required this.subject,
    required this.description,
    required this.status,
    required this.createdAt,
    this.photos = const [],
    this.resolution = '',
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] as String,
      orderId: json['order'] as String,
      kind: json['kind'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String,
      photos: (json['photos'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      status: json['status'] as String,
      resolution: json['resolution'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String orderId;

  /// `quality` | `delivery` | `service` | `other` (`ComplaintKind`).
  final String kind;
  final String subject;
  final String description;
  final List<String> photos;

  /// `pending` | `under_review` | `resolved` | `rejected` (`ComplaintStatus`).
  final String status;
  final String resolution;
  final DateTime createdAt;
}
