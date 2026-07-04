import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String messageType; // 'text', 'image', 'audio', 'location', 'system'
  final String content;
  final String? mediaUrl;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final ChatUser? sender;

  ChatMessage({
    required this.roomId, required this.senderId, required this.content, String? id,
    this.messageType = 'text',
    this.mediaUrl,
    this.isRead = false,
    this.readAt,
    DateTime? createdAt,
    this.sender,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      // Map order_id (from messages table) to roomId, or use room_id if available
      roomId: (json['room_id'] ?? json['order_id']) as String, 
      senderId: json['sender_id'] as String,
      // Map type (from messages table) to messageType
      messageType: (json['message_type'] ?? json['type']) as String? ?? 'text',
      content: json['content'] as String,
      // Map image_url (from messages table) to mediaUrl
      mediaUrl: (json['media_url'] ?? json['image_url']) as String?,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      sender: json['sender'] != null
          ? ChatUser.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'sender_id': senderId,
      'message_type': messageType,
      'content': content,
      'media_url': mediaUrl,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? messageType,
    String? content,
    String? mediaUrl,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    ChatUser? sender,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      sender: sender ?? this.sender,
    );
  }
}

class ChatUser {
  final String id;
  final String name;
  final String? profileImage;

  ChatUser({
    required this.id,
    required this.name,
    this.profileImage,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] as String,
      name: json['name'] as String,
      profileImage: json['profile_image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profile_image': profileImage,
    };
  }
}

class ChatRoom {
  final String id;
  final String orderId;
  final String clientId;
  final String deliveryId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ChatUser? client;
  final ChatUser? delivery;
  final List<ChatMessage>? messages;
  final int? unreadCount;

  ChatRoom({
    required this.id,
    required this.orderId,
    required this.clientId,
    required this.deliveryId,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.client,
    this.delivery,
    this.messages,
    this.unreadCount,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      clientId: json['client_id'] as String,
      deliveryId: json['delivery_id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      client: json['client'] != null
          ? ChatUser.fromJson(json['client'] as Map<String, dynamic>)
          : null,
      delivery: json['delivery'] != null
          ? ChatUser.fromJson(json['delivery'] as Map<String, dynamic>)
          : null,
      messages: json['messages'] != null
          ? (json['messages'] as List)
              .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList()
          : null,
      unreadCount: json['unread_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'client_id': clientId,
      'delivery_id': deliveryId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

