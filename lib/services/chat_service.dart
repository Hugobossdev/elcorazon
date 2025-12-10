import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:elcora_fast/models/chat_message.dart';
import 'package:elcora_fast/config/api_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;
  String? _currentToken;

  // Streams for messages
  final Map<String, StreamController<List<ChatMessage>>> _messageControllers =
      {};
  final Map<String, List<ChatMessage>> _messagesCache = {};
  final Map<String, bool> _typingUsers = {};

  // Stream for typing indicators
  final StreamController<Map<String, bool>> _typingController =
      StreamController<Map<String, bool>>.broadcast();

  Stream<Map<String, bool>> get typingStream => _typingController.stream;

  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;

  /// Initialize Socket.IO connection
  Future<void> initialize({String? userId, String? token}) async {
    if (_isConnected && _currentUserId == userId) {
      debugPrint('ChatService: Already connected');
      return;
    }

    try {
      _currentUserId = userId;
      _currentToken = token;

      // Get backend URL from config
      final backendUrl = ApiConfig.backendUrl;

      debugPrint('ChatService: Connecting to $backendUrl');

      _socket = IO.io(
        backendUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(5)
            .build(),
      );

      // Connection events
      _socket!.onConnect((_) {
        debugPrint('ChatService: Socket connected');
        _isConnected = true;
        _authenticate();
        notifyListeners();
      });

      _socket!.onDisconnect((_) {
        debugPrint('ChatService: Socket disconnected');
        _isConnected = false;
        notifyListeners();
      });

      _socket!.onConnectError((error) {
        debugPrint('ChatService: Connection error: $error');
        _isConnected = false;
        notifyListeners();
      });

      // Authentication response
      _socket!.on('authenticated', (data) {
        debugPrint('ChatService: Authenticated: $data');
        _isConnected = true;
        notifyListeners();
      });

      _socket!.on('auth_error', (data) {
        debugPrint('ChatService: Auth error: $data');
        _isConnected = false;
        notifyListeners();
      });

      // Message events
      _socket!.on('new_message', (data) {
        debugPrint('ChatService: New message received: $data');
        _handleNewMessage(data);
      });

      _socket!.on('user_typing', (data) {
        debugPrint('ChatService: User typing: $data');
        final roomId = data['roomId'] as String?;
        if (roomId != null) {
          _typingUsers[roomId] = true;
          _typingController.add(Map.from(_typingUsers));

          // Clear typing indicator after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            _typingUsers[roomId] = false;
            _typingController.add(Map.from(_typingUsers));
          });
        }
      });

      _socket!.on('messages_read', (data) {
        debugPrint('ChatService: Messages read: $data');
        final roomId = data['roomId'] as String?;
        if (roomId != null) {
          _markMessagesAsRead(roomId);
        }
      });

      _socket!.on('error', (data) {
        debugPrint('ChatService: Error: $data');
      });

      // Connect
      _socket!.connect();
    } catch (e) {
      debugPrint('ChatService: Error initializing: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  /// Authenticate with Socket.IO server
  void _authenticate() {
    if (_currentUserId != null && _currentToken != null) {
      _socket?.emit('authenticate', {
        'userId': _currentUserId,
        'token': _currentToken,
      });
    }
  }

  /// Get or create chat room for an order
  Future<ChatRoom?> getChatRoom(String orderId) async {
    try {
      // Try to get existing room
      final response = await _supabase
          .from('chat_rooms')
          .select(
              '*, client:users!chat_rooms_client_id_fkey(id, name, profile_image), delivery:users!chat_rooms_delivery_id_fkey(id, name, profile_image)')
          .eq('order_id', orderId)
          .maybeSingle();

      if (response != null) {
        return ChatRoom.fromJson(response);
      }

      // Room doesn't exist, it will be created automatically when delivery is assigned
      return null;
    } catch (e) {
      debugPrint('ChatService: Error getting chat room: $e');
      return null;
    }
  }

  /// Get messages for a room
  Future<List<ChatMessage>> getMessages(String roomId) async {
    try {
      // Check cache first
      if (_messagesCache.containsKey(roomId)) {
        return _messagesCache[roomId]!;
      }

      // Fetch from Supabase
      final response = await _supabase
          .from('chat_messages')
          .select(
              '*, sender:users!chat_messages_sender_id_fkey(id, name, profile_image)')
          .eq('room_id', roomId)
          .order('created_at', ascending: true);

      final messages = (response as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();

      _messagesCache[roomId] = messages;
      return messages;
    } catch (e) {
      debugPrint('ChatService: Error getting messages: $e');
      return [];
    }
  }

  /// Send a message
  Future<bool> sendMessage({
    required String roomId,
    required String message,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    if (!_isConnected) {
      debugPrint('ChatService: Not connected, cannot send message');
      return false;
    }

    try {
      _socket?.emit('send_message', {
        'roomId': roomId,
        'message': message,
        'messageType': messageType,
        'mediaUrl': mediaUrl,
      });

      return true;
    } catch (e) {
      debugPrint('ChatService: Error sending message: $e');
      return false;
    }
  }

  /// Handle new message received
  void _handleNewMessage(dynamic data) {
    try {
      final message = ChatMessage.fromJson(data as Map<String, dynamic>);
      final roomId = message.roomId;

      // Add to cache
      if (!_messagesCache.containsKey(roomId)) {
        _messagesCache[roomId] = [];
      }
      _messagesCache[roomId]!.add(message);

      // Notify listeners
      if (_messageControllers.containsKey(roomId)) {
        _messageControllers[roomId]!.add(List.from(_messagesCache[roomId]!));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('ChatService: Error handling new message: $e');
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String roomId) async {
    if (!_isConnected) return;

    try {
      _socket?.emit('mark_read', {'roomId': roomId});
    } catch (e) {
      debugPrint('ChatService: Error marking messages as read: $e');
    }
  }

  void _markMessagesAsRead(String roomId) {
    if (_messagesCache.containsKey(roomId)) {
      for (var message in _messagesCache[roomId]!) {
        if (message.senderId != _currentUserId) {
          message = message.copyWith(isRead: true, readAt: DateTime.now());
        }
      }
      notifyListeners();
    }
  }

  /// Send typing indicator
  void sendTypingIndicator(String roomId) {
    if (!_isConnected) return;

    try {
      _socket?.emit('typing', {'roomId': roomId});
    } catch (e) {
      debugPrint('ChatService: Error sending typing indicator: $e');
    }
  }

  /// Get message stream for a room
  Stream<List<ChatMessage>> getMessageStream(String roomId) {
    if (!_messageControllers.containsKey(roomId)) {
      _messageControllers[roomId] =
          StreamController<List<ChatMessage>>.broadcast();

      // Load initial messages
      getMessages(roomId).then((messages) {
        _messageControllers[roomId]!.add(messages);
      });
    }

    return _messageControllers[roomId]!.stream;
  }

  /// Disconnect
  Future<void> disconnect() async {
    try {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
      _isConnected = false;
      _currentUserId = null;
      _currentToken = null;
      _messagesCache.clear();
      _messageControllers.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('ChatService: Error disconnecting: $e');
    }
  }

  @override
  void dispose() {
    disconnect();
    _typingController.close();
    for (final controller in _messageControllers.values) {
      controller.close();
    }
    super.dispose();
  }
}
