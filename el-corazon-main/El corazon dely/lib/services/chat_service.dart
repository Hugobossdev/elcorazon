import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message.dart';
import 'database_service.dart';

/// Service de chat en temps réel utilisant Supabase Realtime
class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Map des canaux actifs par orderId
  final Map<String, RealtimeChannel> _activeChannels = {};
  
  // Map des contrôleurs de stream par orderId
  final Map<String, StreamController<List<Message>>> _messageStreams = {};
  
  // Cache des messages par orderId
  final Map<String, List<Message>> _messagesCache = {};
  
  // État de connexion par orderId
  final Map<String, bool> _connectionStatus = {};
  
  // Indicateurs de frappe
  final Map<String, Timer> _typingTimers = {};
  final Map<String, bool> _typingStatus = {};

  bool _isInitialized = false;
  String? _currentUserId;

  bool get isInitialized => _isInitialized;
  String? get currentUserId => _currentUserId;

  /// Initialise le service de chat
  Future<void> initialize({String? userId}) async {
    if (_isInitialized && _currentUserId == userId) {
      debugPrint('✅ ChatService: Déjà initialisé');
      return;
    }

    try {
      _currentUserId = userId;
      _isInitialized = true;
      notifyListeners();
      debugPrint('✅ ChatService: Service initialisé pour l\'utilisateur: $userId');
    } catch (e) {
      debugPrint('❌ ChatService: Erreur d\'initialisation - $e');
      _isInitialized = false;
    }
  }

  /// Charge les messages existants pour une commande
  Future<List<Message>> loadMessages(String orderId) async {
    try {
      // Charger depuis la base de données
      final messagesData = await _databaseService.getMessages(orderId);
      
      final messages = messagesData.map((data) {
        return Message(
          id: data['id'] as String,
          orderId: data['order_id'] as String,
          senderId: data['sender_id'] as String,
          senderName: data['sender_name'] as String? ?? 'Utilisateur',
          content: data['content'] as String,
          timestamp: DateTime.parse(
            data['created_at'] as String? ?? 
            data['timestamp'] as String? ?? 
            DateTime.now().toIso8601String()
          ),
          isFromDriver: data['is_from_driver'] as bool? ?? false,
          imageUrl: data['image_url'] as String?,
          type: MessageType.values.firstWhere(
            (e) => e.name == (data['type'] as String? ?? 'text'),
            orElse: () => MessageType.text,
          ),
        );
      }).toList();

      // Mettre en cache
      _messagesCache[orderId] = messages;
      
      debugPrint('✅ ChatService: ${messages.length} messages chargés pour la commande $orderId');
      return messages;
    } catch (e) {
      debugPrint('❌ ChatService: Erreur chargement messages - $e');
      return [];
    }
  }

  /// S'abonne aux messages en temps réel pour une commande
  Stream<List<Message>> subscribeToMessages(String orderId) {
    // Si un stream existe déjà, le retourner
    if (_messageStreams.containsKey(orderId)) {
      return _messageStreams[orderId]!.stream;
    }

    // Créer un nouveau stream controller
    final controller = StreamController<List<Message>>.broadcast();
    _messageStreams[orderId] = controller;

    // Charger les messages existants
    loadMessages(orderId).then((messages) {
      if (!controller.isClosed) {
        controller.add(messages);
      }
    });

    // S'abonner aux changements en temps réel
    _subscribeToRealtime(orderId);

    return controller.stream;
  }

  /// S'abonne aux changements en temps réel via Supabase
  void _subscribeToRealtime(String orderId) {
    // Si déjà abonné, ne pas réabonner
    if (_activeChannels.containsKey(orderId)) {
      debugPrint('⚠️ ChatService: Déjà abonné à la commande $orderId');
      return;
    }

    try {
      // Créer un canal unique pour cette commande
      final channelName = 'messages_$orderId';
      final channel = _supabase.channel(channelName);

      // Écouter les insertions de nouveaux messages
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'order_id',
          value: orderId,
        ),
        callback: (payload) {
          debugPrint('✅ ChatService: Nouveau message reçu pour $orderId');
          _handleNewMessage(orderId, payload.newRecord);
        },
      );

      // Écouter les mises à jour de messages (pour les indicateurs de lecture, etc.)
      channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'order_id',
          value: orderId,
        ),
        callback: (payload) {
          debugPrint('✅ ChatService: Message mis à jour pour $orderId');
          _handleMessageUpdate(orderId, payload.newRecord);
        },
      );

      // S'abonner au canal
      channel.subscribe((status, [error]) {
        _connectionStatus[orderId] = status == RealtimeSubscribeStatus.subscribed;
        notifyListeners();

        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('✅ ChatService: Abonné avec succès à $orderId');
        } else if (status == RealtimeSubscribeStatus.closed) {
          debugPrint('⚠️ ChatService: Canal fermé pour $orderId');
          _connectionStatus[orderId] = false;
          notifyListeners();
        } else if (status == RealtimeSubscribeStatus.channelError) {
          debugPrint('❌ ChatService: Erreur de canal pour $orderId - $error');
          _connectionStatus[orderId] = false;
          notifyListeners();
          
          // Tenter de se reconnecter après 3 secondes
          Future.delayed(const Duration(seconds: 3), () {
            if (_activeChannels.containsKey(orderId)) {
              _unsubscribeFromRealtime(orderId);
              _subscribeToRealtime(orderId);
            }
          });
        }
      });

      _activeChannels[orderId] = channel;
      debugPrint('✅ ChatService: Abonnement initié pour $orderId');
    } catch (e) {
      debugPrint('❌ ChatService: Erreur abonnement Realtime - $e');
      _connectionStatus[orderId] = false;
      notifyListeners();
    }
  }

  /// Gère un nouveau message reçu
  void _handleNewMessage(String orderId, Map<String, dynamic> messageData) {
    try {
      final message = Message(
        id: messageData['id'] as String,
        orderId: messageData['order_id'] as String,
        senderId: messageData['sender_id'] as String,
        senderName: messageData['sender_name'] as String? ?? 'Utilisateur',
        content: messageData['content'] as String,
        timestamp: DateTime.parse(
          messageData['created_at'] as String? ?? 
          messageData['timestamp'] as String? ?? 
          DateTime.now().toIso8601String()
        ),
        isFromDriver: messageData['is_from_driver'] as bool? ?? false,
        imageUrl: messageData['image_url'] as String?,
        type: MessageType.values.firstWhere(
          (e) => e.name == (messageData['type'] as String? ?? 'text'),
          orElse: () => MessageType.text,
        ),
      );

      // Ajouter au cache
      if (!_messagesCache.containsKey(orderId)) {
        _messagesCache[orderId] = [];
      }

      // Éviter les doublons
      if (!_messagesCache[orderId]!.any((m) => m.id == message.id)) {
        _messagesCache[orderId]!.add(message);
        
        // Trier par timestamp
        _messagesCache[orderId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Notifier les listeners du stream
        if (_messageStreams.containsKey(orderId) && !_messageStreams[orderId]!.isClosed) {
          _messageStreams[orderId]!.add(List.from(_messagesCache[orderId]!));
        }

        notifyListeners();
        debugPrint('✅ ChatService: Message ajouté au cache: ${message.id}');
      }
    } catch (e) {
      debugPrint('❌ ChatService: Erreur traitement nouveau message - $e');
    }
  }

  /// Gère la mise à jour d'un message
  void _handleMessageUpdate(String orderId, Map<String, dynamic> messageData) {
    try {
      final messageId = messageData['id'] as String;
      
      if (_messagesCache.containsKey(orderId)) {
        final index = _messagesCache[orderId]!.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          // Mettre à jour le message
          final updatedMessage = Message(
            id: messageData['id'] as String,
            orderId: messageData['order_id'] as String,
            senderId: messageData['sender_id'] as String,
            senderName: messageData['sender_name'] as String? ?? 'Utilisateur',
            content: messageData['content'] as String,
            timestamp: DateTime.parse(
              messageData['created_at'] as String? ?? 
              messageData['timestamp'] as String? ?? 
              DateTime.now().toIso8601String()
            ),
            isFromDriver: messageData['is_from_driver'] as bool? ?? false,
            imageUrl: messageData['image_url'] as String?,
            type: MessageType.values.firstWhere(
              (e) => e.name == (messageData['type'] as String? ?? 'text'),
              orElse: () => MessageType.text,
            ),
          );

          _messagesCache[orderId]![index] = updatedMessage;

          // Notifier les listeners
          if (_messageStreams.containsKey(orderId) && !_messageStreams[orderId]!.isClosed) {
            _messageStreams[orderId]!.add(List.from(_messagesCache[orderId]!));
          }

          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ ChatService: Erreur mise à jour message - $e');
    }
  }

  /// Envoie un message
  Future<bool> sendMessage({
    required String orderId,
    required String senderId,
    required String senderName,
    required String content,
    required bool isFromDriver,
    String? imageUrl,
    MessageType type = MessageType.text,
  }) async {
    try {
      // Envoyer le message via DatabaseService
      await _databaseService.sendMessage(
        orderId: orderId,
        senderId: senderId,
        senderName: senderName,
        content: content,
        isFromDriver: isFromDriver,
        imageUrl: imageUrl,
        type: type.name,
      );

      debugPrint('✅ ChatService: Message envoyé avec succès');
      
      // Le message sera automatiquement ajouté via Realtime
      // Mais on peut aussi le recharger immédiatement pour un feedback plus rapide
      await loadMessages(orderId);
      
      return true;
    } catch (e) {
      debugPrint('❌ ChatService: Erreur envoi message - $e');
      return false;
    }
  }

  /// Vérifie l'état de connexion pour une commande
  bool isConnected(String orderId) {
    return _connectionStatus[orderId] ?? false;
  }

  /// Obtient les messages en cache
  List<Message> getCachedMessages(String orderId) {
    return List.from(_messagesCache[orderId] ?? []);
  }

  /// Se désabonne des messages pour une commande
  void unsubscribeFromMessages(String orderId) {
    _unsubscribeFromRealtime(orderId);
    
    // Fermer le stream
    if (_messageStreams.containsKey(orderId)) {
      _messageStreams[orderId]?.close();
      _messageStreams.remove(orderId);
    }

    // Nettoyer le cache (optionnel, on peut garder pour performance)
    // _messagesCache.remove(orderId);
    _connectionStatus.remove(orderId);
    
    debugPrint('✅ ChatService: Désabonné de $orderId');
  }

  /// Se désabonne du canal Realtime
  void _unsubscribeFromRealtime(String orderId) {
    if (_activeChannels.containsKey(orderId)) {
      _activeChannels[orderId]?.unsubscribe();
      _activeChannels.remove(orderId);
      debugPrint('✅ ChatService: Canal Realtime fermé pour $orderId');
    }
  }

  /// Nettoie toutes les souscriptions
  void disposeAll() {
    for (final orderId in _activeChannels.keys.toList()) {
      unsubscribeFromMessages(orderId);
    }
    
    _messagesCache.clear();
    _connectionStatus.clear();
    _typingStatus.clear();
    _typingTimers.clear();
    
    debugPrint('✅ ChatService: Toutes les souscriptions nettoyées');
  }

  /// Réinitialise le service
  void reset() {
    disposeAll();
    _isInitialized = false;
    _currentUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }
}




