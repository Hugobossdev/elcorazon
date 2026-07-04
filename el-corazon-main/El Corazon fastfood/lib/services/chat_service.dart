import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:elcora_fast/models/chat_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/services/database_service.dart';

class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final DatabaseService _databaseService = DatabaseService();
  bool _isConnected = false; // Tracks if we are "connected" (subscribed to channel)
  String? _currentUserId;

  // Streams for messages
  final Map<String, StreamController<List<ChatMessage>>> _messageControllers =
      {};
  final Map<String, List<ChatMessage>> _messagesCache = {};
  
  // Realtime channels
  final Map<String, RealtimeChannel> _activeChannels = {};

  // Stream for typing indicators (Mocked for now as we removed Socket.IO)
  final StreamController<Map<String, bool>> _typingController =
      StreamController<Map<String, bool>>.broadcast();

  Stream<Map<String, bool>> get typingStream => _typingController.stream;

  bool get isConnected => _isConnected;

  /// Initialize Service
  Future<void> initialize({String? userId, String? token}) async {
    _currentUserId = userId;
    _isConnected = true;
    notifyListeners();
    debugPrint('ChatService: Initialized with Supabase Realtime');
  }

  /// Get or create chat room for an order
  /// In Supabase-only approach, the "room" is just the order context.
  Future<ChatRoom?> getChatRoom(String orderId) async {
    try {
        // We construct a virtual ChatRoom based on the order
        // This keeps compatibility with UI that expects a ChatRoom object
        final order = await _supabase.from('orders').select('*, delivery:users!orders_delivery_person_id_fkey(id, name, profile_image)').eq('id', orderId).maybeSingle();
        
        if (order == null) return null;

        // Fetch client and driver details if needed, but for now we return basic structure
        return ChatRoom(
            id: orderId, // Use orderId as roomId
            orderId: orderId,
            clientId: order['user_id'] as String,
            deliveryId: order['delivery_person_id'] ?? '',
            createdAt: DateTime.parse(order['created_at']),
            updatedAt: DateTime.parse(order['updated_at']),
        );
    } catch (e) {
      debugPrint('ChatService: Error getting chat room: $e');
      return null;
    }
  }

  /// Get messages for a room (which is actually an orderId)
  Future<List<ChatMessage>> getMessages(String roomId) async {
    try {
      // Check cache first
      if (_messagesCache.containsKey(roomId)) {
        return _messagesCache[roomId]!;
      }

      // Fetch from Supabase 'messages' table
      // Note: We are not joining with users table to avoid FK issues with auth.users vs public.users
      // We rely on the denormalized sender_name in the messages table.
      final response = await _supabase
          .from('messages')
          .select() 
          .eq('order_id', roomId) // roomId is used as orderId
          .order('created_at', ascending: true);

      final messages = (response as List).map((m) {
        // Manually construct sender info if not present in join
        final msgMap = Map<String, dynamic>.from(m as Map<String, dynamic>);
        if (msgMap['sender'] == null && msgMap['sender_id'] != null) {
            msgMap['sender'] = {
                'id': msgMap['sender_id'],
                'name': msgMap['sender_name'] ?? 'Utilisateur',
                // profile_image will be null, which is acceptable or can be fetched separately if needed
            };
        }
        return ChatMessage.fromJson(msgMap);
      }).toList();

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
    if (_currentUserId == null) {
      debugPrint('ChatService: User not logged in');
      return false;
    }

    try {
      // IMPORTANT: Toujours utiliser l'auth_user_id de Supabase, pas _currentUserId
      // car _currentUserId pourrait être l'ID de la table users, pas l'auth_user_id
      final authUser = _supabase.auth.currentUser;
      final authUserId = authUser?.id;
      
      if (authUserId == null) {
        debugPrint('ChatService: No auth user ID available');
        debugPrint('ChatService: _currentUserId is $_currentUserId (might be users.id, not auth_user_id)');
        return false;
      }
      
      debugPrint('ChatService: Using auth_user_id: $authUserId');

      // S'assurer que le profil existe dans la table users
      var userProfile = await _databaseService.ensureUserProfileExists(
        userId: authUserId,
      );

      // Si ensureUserProfileExists retourne null, essayer de récupérer le profil directement
      userProfile ??= await _databaseService.getUserProfile(authUserId);

      // Si toujours null, on ne peut pas envoyer le message
      if (userProfile == null) {
        debugPrint('ChatService: User profile not found in users table. Cannot send message.');
        debugPrint('ChatService: Auth user ID: $authUserId');
        return false;
      }

      // Vérifier que l'ID de la table users existe
      final userIdFromTable = userProfile['id'] as String?;
      final authUserIdFromTable = userProfile['auth_user_id'] as String?;
      
      debugPrint('ChatService: User profile found:');
      debugPrint('  - users.id: $userIdFromTable');
      debugPrint('  - users.auth_user_id: $authUserIdFromTable');
      debugPrint('  - Current auth_user_id: $authUserId');
      
      if (userIdFromTable == null || userIdFromTable.isEmpty) {
        debugPrint('ChatService: ERROR - users.id is null or empty! Cannot send message.');
        return false;
      }

      // IMPORTANT: D'après fix_chat_schema.sql ligne 9, messages.sender_id 
      // référence auth.users(id), PAS public.users(id) !
      // sender_id uuid references auth.users(id) not null
      // Donc on doit utiliser l'auth_user_id directement, pas l'ID de public.users
      final senderId = authUserId; // Utiliser auth_user_id car la FK pointe vers auth.users(id)
      final senderName = userProfile['name'] as String? ?? 
                        authUser?.userMetadata?['name'] ?? 
                        'Utilisateur';

      debugPrint('ChatService: Sending message with sender_id (auth.users.id): $senderId, sender_name: $senderName');
      debugPrint('ChatService: Note - sender_id references auth.users(id), not public.users(id)');

      await _supabase.from('messages').insert({
          'order_id': roomId, // roomId is orderId
          'sender_id': senderId, // Utiliser auth_user_id car la FK pointe vers auth.users(id)
          'sender_name': senderName,
          'content': message,
          'type': messageType,
          'image_url': mediaUrl,
          'is_from_driver': false, // Client app
          'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('ChatService: Error sending message: $e');
      // Afficher plus de détails sur l'erreur
      if (e.toString().contains('foreign key constraint')) {
        debugPrint('ChatService: Foreign key constraint violation - sender_id does not exist in users table');
        debugPrint('ChatService: Current user ID: $_currentUserId');
        final authUser = _supabase.auth.currentUser;
        debugPrint('ChatService: Auth user ID: ${authUser?.id}');
      }
      return false;
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String roomId) async {
     // Implement if 'is_read' column exists in messages table
     // await _supabase.from('messages').update({'is_read': true}).eq('order_id', roomId).neq('sender_id', _currentUserId);
  }

  /// Send typing indicator (Mock)
  void sendTypingIndicator(String roomId) {
     // Realtime typing indicators would require a separate broadcast channel
     // Skipping for now to simplify
  }

  /// Get message stream for a room
  Stream<List<ChatMessage>> getMessageStream(String roomId) {
    if (!_messageControllers.containsKey(roomId)) {
      _messageControllers[roomId] =
          StreamController<List<ChatMessage>>.broadcast();

      // Load initial messages
      getMessages(roomId).then((messages) {
        if (!_messageControllers[roomId]!.isClosed) {
            _messageControllers[roomId]!.add(messages);
        }
      });

      // Subscribe to Realtime
      _subscribeToRoom(roomId);
    }

    return _messageControllers[roomId]!.stream;
  }
  
  void _subscribeToRoom(String roomId) {
      if (_activeChannels.containsKey(roomId)) return;

      final channel = _supabase.channel('messages_$roomId');
      channel.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: roomId,
          ),
          callback: (payload) {
              final newRecord = payload.newRecord;
              // We might need to fetch sender info if not included, but for now try to parse
              // Or just reload messages
              debugPrint('ChatService: New message received via Realtime');
              
              // Simplest approach: append if we can parse, or reload
              // Since newRecord won't have the 'sender' relation joined, 
              // we might need to construct a partial ChatMessage or fetch it.
              // Let's just reload for correctness for now, or construct manually.
              
              // Constructing manually to be fast
              final msg = ChatMessage.fromJson(newRecord);
              
              if (!_messagesCache.containsKey(roomId)) {
                  _messagesCache[roomId] = [];
              }
              _messagesCache[roomId]!.add(msg);
              
               if (_messageControllers.containsKey(roomId) && !_messageControllers[roomId]!.isClosed) {
                    _messageControllers[roomId]!.add(List.from(_messagesCache[roomId]!));
               }
          },
      ).subscribe();
      
      _activeChannels[roomId] = channel;
  }

  /// Disconnect
  Future<void> disconnect() async {
      for (final channel in _activeChannels.values) {
          await channel.unsubscribe();
      }
      _activeChannels.clear();
      
      _messagesCache.clear();
      // Don't close controllers as they might be reused or disposed by widgets
      notifyListeners();
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
