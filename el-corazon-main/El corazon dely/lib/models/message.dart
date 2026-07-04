class Message {
  final String id;
  final String orderId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isFromDriver;
  final String? imageUrl;
  final MessageType type;

  Message({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isFromDriver,
    this.imageUrl,
    this.type = MessageType.text,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'is_from_driver': isFromDriver,
      'image_url': imageUrl,
      'type': type.name,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isFromDriver: json['is_from_driver'] as bool,
      imageUrl: json['image_url'] as String?,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Message(id: $id, content: $content, timestamp: $timestamp)';
  }
}

enum MessageType {
  text,
  image,
  location,
  system,
}
