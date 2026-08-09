/// Message de discussion, tel que l'écran l'affiche.
///
/// Modèle de vue local, et non un doublon d'entité : le socle ne porte pas de
/// domaine « discussion ». Le transport, lui, vient bien de lui —
/// `ChatService` ouvre un `RealtimeChannel` et compose ces objets à partir des
/// trames reçues.
///
/// Ce que le relais transmet d'un message, et rien de plus : un texte, un
/// horodatage et le côté d'où il vient. Le lot 3 a retiré `toJson`,
/// `fromJson`, `imageUrl` et le type de message — aucun n'avait d'appelant, et
/// le dernier laissait croire qu'on pouvait marquer un message « système »
/// alors que le relais n'en connaît pas.
class Message {
  Message({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isFromDriver,
  });

  /// Numéro de séquence de la trame — le relais n'attribue pas d'identifiant.
  final String id;
  final String orderId;

  /// Le rôle tient lieu d'identité : le relais ne diffuse aucun identifiant
  /// d'utilisateur.
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;

  /// De quel côté placer la bulle.
  final bool isFromDriver;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Message(id: $id, content: $content, timestamp: $timestamp)';
}
