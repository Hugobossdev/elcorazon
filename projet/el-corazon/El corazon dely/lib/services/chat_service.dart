import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/message.dart';

/// Conversation livreur ↔ client sur `ws/orders/{id}/chat/` (Phase 6).
///
/// Pendant de `ChatService` côté client : même canal, même contrat, mêmes
/// conséquences.
///
/// **Le backend ne persiste pas la conversation** (ADR-008, Phase 1 §5) : le
/// consommateur relaie, il n'écrit nulle part. Il n'y a donc plus d'historique
/// à recharger — [loadMessages] rend ce qui est arrivé depuis l'ouverture du
/// canal, et rien avant. L'implémentation Supabase écrivait dans une table
/// `messages` où l'appelant déclarait lui-même son `sender_id`, son nom et le
/// drapeau `is_from_driver` : un livreur pouvait publier au nom du client, et
/// réciproquement.
///
/// Le serveur estampille l'émetteur (`customer` | `courier`) d'après la
/// connexion authentifiée — c'est ce qui remplace `isFromDriver`.
class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final Map<String, StreamController<List<Message>>> _controllers = {};
  final Map<String, List<Message>> _messages = {};
  final Map<String, eccore.RealtimeChannel> _channels = {};
  final Map<String, StreamSubscription<eccore.RealtimeEvent>> _subscriptions = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// [userId] n'est plus lu : le serveur cloisonne sur le jeton et refuse le
  /// socket à qui n'est ni le client de la commande ni son livreur. Le
  /// paramètre reste pour ne pas casser l'appelant.
  Future<void> initialize({String? userId}) async {
    _isInitialized = true;
    notifyListeners();
  }

  static String _chatWsUrl(String orderId) {
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1';
    final apiUri = Uri.parse(apiBaseUrl);
    return Uri(
      scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
      host: apiUri.host,
      port: apiUri.port,
      path: '/ws/orders/$orderId/chat/',
    ).toString();
  }

  /// Messages reçus depuis l'ouverture du canal. Vide au départ : le serveur
  /// n'a pas d'historique à servir.
  Future<List<Message>> loadMessages(String orderId) async {
    return List.unmodifiable(_messages[orderId] ?? const <Message>[]);
  }

  List<Message> getCachedMessages(String orderId) {
    return List.unmodifiable(_messages[orderId] ?? const <Message>[]);
  }

  Stream<List<Message>> subscribeToMessages(String orderId) {
    final existing = _controllers[orderId];
    if (existing != null) return existing.stream;

    final controller = StreamController<List<Message>>.broadcast();
    _controllers[orderId] = controller;
    _messages[orderId] = [];

    final channel = eccore.RealtimeChannel(
      wsUrl: _chatWsUrl(orderId),
      tokenStorage: eccore.TokenStorage(),
    );
    _channels[orderId] = channel;

    _subscriptions[orderId] = channel.connect().listen((event) {
      if (event.type != 'chat.message') return;

      final payload = event.payload;
      final sender = payload['sender'] as String? ?? '';
      final message = Message(
        id: '${event.seq}',
        orderId: orderId,
        // Le rôle tient lieu d'identité : le relais ne diffuse aucun
        // identifiant d'utilisateur, et l'écran n'a besoin que de savoir de
        // quel côté placer la bulle.
        senderId: sender,
        senderName: sender == 'courier' ? 'Vous' : 'Client',
        content: payload['text'] as String? ?? '',
        timestamp: payload['sent_at'] == null
            ? DateTime.now()
            : DateTime.parse(payload['sent_at'] as String),
        isFromDriver: sender == 'courier',
      );

      _messages[orderId]!.add(message);
      if (!controller.isClosed) {
        controller.add(List.unmodifiable(_messages[orderId]!));
      }
      notifyListeners();
    });

    controller.add(const []);
    return controller.stream;
  }

  /// Publie un message. Ni l'émetteur, ni son nom, ni le drapeau « livreur » ne
  /// voyagent : le serveur les déduit de la connexion.
  Future<bool> sendMessage({
    required String orderId,
    required String content,
    String? senderId,
    String? senderName,
    bool isFromDriver = true,
    String? imageUrl,
    MessageType type = MessageType.text,
  }) async {
    final channel = _channels[orderId];
    if (channel == null) {
      debugPrint('ChatService: canal non ouvert pour la commande $orderId');
      return false;
    }

    try {
      channel.send({'text': content});
      return true;
    } catch (e) {
      debugPrint('ChatService: envoi impossible — $e');
      return false;
    }
  }

  bool isConnected(String orderId) => _channels.containsKey(orderId);

  void unsubscribeFromMessages(String orderId) {
    unawaited(_subscriptions.remove(orderId)?.cancel());
    unawaited(_channels.remove(orderId)?.close());
    _messages.remove(orderId);
    _controllers.remove(orderId)?.close();
  }

  void disposeAll() {
    for (final orderId in _channels.keys.toList()) {
      unsubscribeFromMessages(orderId);
    }
  }

  void reset() {
    disposeAll();
    _isInitialized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }
}
