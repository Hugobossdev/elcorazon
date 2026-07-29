/// Notification lisible après coup — miroir de `NotificationSerializer`
/// (`backend/apps/notifications/serializers.py`).
///
/// Nommée `AppNotification` et non `Notification` : le framework Flutter
/// expose déjà une classe `Notification` (l'arbre de notifications de widgets),
/// et l'app importe les deux.
///
/// Une notification est **produite par le serveur, jamais par le client** : il
/// n'existe aucune écriture dans ce contrat en dehors du marquage de lecture.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return AppNotification(
      id: json['id'] as String,
      kind: json['kind'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: data is Map ? Map<String, dynamic>.from(data) : const {},
      isRead: json['is_read'] as bool,
      readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;

  /// `order_status` | `delivery_offer` | `payment` | `account` | `marketing`
  /// (`NotificationKind`). La distinction transactionnel / marketing décide
  /// côté serveur si l'envoi respecte les préférences de l'utilisateur.
  final String kind;
  final String title;
  final String body;

  /// Charge utile minimale, de quoi ouvrir le bon écran — pas une copie de
  /// l'objet métier, qui aura changé d'ici la lecture.
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification asRead(DateTime readAt) {
    return AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      data: data,
      isRead: true,
      readAt: this.readAt ?? readAt,
      createdAt: createdAt,
    );
  }
}
