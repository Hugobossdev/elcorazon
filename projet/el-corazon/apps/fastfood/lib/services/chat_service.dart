import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


/// Conversation client ↔ livreur sur `ws/orders/{id}/chat/` (Phase 6).
///
/// **Le backend ne persiste pas la conversation** (ADR-008, Phase 1 §5) : le
/// consommateur relaie, il n'écrit nulle part. Conséquence directe et voulue —
/// il n'y a plus d'historique à recharger, et [getMessageStream] ne rend que ce
/// qui est arrivé depuis l'ouverture du canal. L'implémentation Supabase
/// écrivait dans une table `messages` que le client alimentait lui-même, en y
/// déclarant son propre `sender_id` et son `sender_name`.
///
/// L'émetteur n'est plus un champ du message : le serveur le déduit de la
/// connexion authentifiée et le renvoie en `sender` (`customer` | `courier`).
class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final Map<String, StreamController<List<eccore.ChatMessage>>> _messageControllers = {};
  final Map<String, List<eccore.ChatMessage>> _messages = {};
  final Map<String, eccore.RealtimeChannel> _channels = {};
  final Map<String, StreamSubscription<eccore.RealtimeEvent>> _subscriptions = {};

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    _isConnected = true;
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

  /// Flux de la conversation d'une commande. La liste part vide : le serveur
  /// n'a pas d'historique à servir.
  Stream<List<eccore.ChatMessage>> getMessageStream(String orderId) {
    // `close_sinks` ne sait pas suivre un contrôleur rangé dans une `Map` puis
    // fermé par une autre méthode : il exige la fermeture dans la fonction qui
    // l'ouvre, ce qui est impossible ici — le flux doit survivre à l'appel pour
    // que l'écran s'y abonne. La fermeture a bien lieu, dans [disconnect], que
    // [dispose] appelle. Le vrai défaut que ce lint désignait — les contrôleurs
    // n'étaient effectivement jamais fermés — est corrigé là-bas.
    // ignore: close_sinks
    final existing = _messageControllers[orderId];
    if (existing != null) return existing.stream;

    // ignore: close_sinks
    final controller = StreamController<List<eccore.ChatMessage>>.broadcast();
    _messageControllers[orderId] = controller;
    _messages[orderId] = [];

    final channel = eccore.RealtimeChannel(
      wsUrl: _chatWsUrl(orderId),
      tokenStorage: eccore.TokenStorage(),
    );
    _channels[orderId] = channel;

    _subscriptions[orderId] = channel.connect().listen((event) {
      if (event.type != 'chat.message') return;

      // Le socle lit la charge utile : c'est un contrat de serveur, pas une
      // forme propre à cette application.
      final message = eccore.ChatMessage.fromPayload(event.payload);

      _messages[orderId]!.add(message);
      if (!controller.isClosed) {
        controller.add(List.unmodifiable(_messages[orderId]!));
      }
    });

    controller.add(const []);
    return controller.stream;
  }

  /// Publie un message sur la conversation. Rend `false` si le canal n'a pas
  /// été ouvert par [getMessageStream].
  Future<bool> sendMessage({required String orderId, required String message}) async {
    final channel = _channels[orderId];
    if (channel == null) {
      eccore.Journal.trace('ChatService: canal non ouvert pour la commande $orderId');
      return false;
    }

    try {
      channel.send({'text': message});
      return true;
    } catch (e) {
      eccore.Journal.trace('ChatService: envoi impossible — $e');
      return false;
    }
  }

  /// Referme tout : abonnements, canaux, et **les contrôleurs de flux**.
  ///
  /// Ces derniers manquaient. `disconnect()` vidait `_subscriptions`,
  /// `_channels` et `_messages` mais laissait `_messageControllers` intact et
  /// ouvert, ce qui avait deux conséquences. Les `StreamController` fuyaient,
  /// d'abord — c'est ce que signalait `close_sinks`. Surtout, un second appel à
  /// [getMessageStream] pour la même commande retrouvait le contrôleur resté en
  /// place et rendait son flux, alors que le canal qui l'alimentait, lui, avait
  /// bien été fermé : la conversation se rouvrait muette, définitivement.
  ///
  /// Les abonnements sont annulés avant la fermeture des contrôleurs, sans quoi
  /// un message en vol pourrait être publié sur un contrôleur déjà clos.
  Future<void> disconnect() async {
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    for (final channel in _channels.values) {
      await channel.close();
    }
    for (final controller in _messageControllers.values) {
      await controller.close();
    }
    _subscriptions.clear();
    _channels.clear();
    _messageControllers.clear();
    _messages.clear();
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    // `dispose()` est synchrone par contrat de `ChangeNotifier` : on ne peut pas
    // attendre `disconnect()`. Les fermetures qu'il déclenche sont engagées
    // immédiatement, ce qui suffit — plus rien ne référence le service après.
    disconnect();
    super.dispose();
  }
}
