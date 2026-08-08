/// Message échangé sur `ws/orders/{id}/chat/` — miroir de la charge utile que
/// publie `tracking/consumers.py` sous le type `chat.message`.
///
/// Trois champs, et c'est tout ce que le canal transporte :
/// `{"sender": "client", "text": "…", "sent_at": "…"}`.
///
/// L'**émetteur est un rôle**, pas une personne. Le serveur le prend sur la
/// connexion authentifiée à l'ouverture du socket, jamais dans le message :
/// personne ne peut écrire au nom d'un autre. L'application n'a besoin que de
/// cela pour placer la bulle du bon côté.
class ChatMessage {
  const ChatMessage({
    required this.sender,
    required this.text,
    required this.sentAt,
  });

  /// Depuis la charge utile d'un `RealtimeEvent` de type `chat.message`.
  ///
  /// Tolérante : un message mal formé devient un message vide plutôt que de
  /// faire tomber la conversation. Une bulle vide se voit, une exception dans
  /// un flux se perd.
  factory ChatMessage.fromPayload(
    Map<String, dynamic> payload, {
    DateTime? recuLe,
  }) {
    final sentAt = payload['sent_at'];

    return ChatMessage(
      sender: payload['sender'] as String? ?? '',
      text: payload['text'] as String? ?? '',
      sentAt: sentAt is String
          ? DateTime.tryParse(sentAt) ?? (recuLe ?? DateTime.now())
          : (recuLe ?? DateTime.now()),
    );
  }

  /// Le **rôle** de l'émetteur : `client`, `courier`, `staff`.
  final String sender;

  final String text;

  /// L'heure que le serveur a horodatée, ou l'heure de réception à défaut.
  final DateTime sentAt;
}
