/// Ticket de support — miroir de `SupportTicketSerializer`
/// (`backend/apps/support/serializers.py`). Entièrement en lecture : le client
/// ouvre un ticket et y répond, mais `status`, `resolution` et `resolved_at`
/// se décident depuis le back-office.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    required this.createdAt,
    this.attachments = const [],
    this.resolution = '',
    this.resolvedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as String,
      category: json['category'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String,
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      status: json['status'] as String,
      resolution: json['resolution'] as String? ?? '',
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;

  /// `order` | `payment` | `account` | `delivery` | `other` (`TicketCategory`
  /// côté serveur — il n'existe pas de catégorie « général »).
  final String category;
  final String subject;
  final String description;
  final List<String> attachments;

  /// `open` | `in_progress` | `resolved` | `closed` (`TicketStatus`).
  final String status;
  final String resolution;
  final DateTime? resolvedAt;
  final DateTime createdAt;
}

/// Auteur d'un message — miroir de `AuthorSerializer`. `userType` dit de quel
/// côté du fil il parle : le serveur n'a qu'un champ `author`, pas un couple
/// `user_id`/`admin_id` comme l'ancien schéma Supabase.
class MessageAuthor {
  const MessageAuthor({required this.id, required this.fullName, required this.userType});

  factory MessageAuthor.fromJson(Map<String, dynamic> json) {
    return MessageAuthor(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      userType: json['user_type'] as String,
    );
  }

  final String id;
  final String fullName;

  /// `customer` | `courier` | `staff` | `admin` (`UserType` côté serveur).
  final String userType;

  /// Vrai dès que l'auteur n'est pas le client — c'est ce que l'affichage du
  /// fil a besoin de savoir, et rien d'autre.
  bool get isFromSupport => userType != 'customer';
}

/// Message du fil d'un ticket — miroir de `SupportMessageSerializer`.
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.author,
    required this.content,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as String,
      ticketId: json['ticket'] as String,
      author: MessageAuthor.fromJson(json['author'] as Map<String, dynamic>),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String ticketId;
  final MessageAuthor author;
  final String content;
  final DateTime createdAt;
}
