import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:elcorazon_core/src/auth/token_storage.dart';
import 'package:elcorazon_core/src/realtime/realtime_event.dart';

/// Canal temps réel générique (`ws/orders/{id}/tracking/`, `.../chat/`, ...) —
/// voir `backend/common/consumers.py AuthorizedConsumer`. Le jeton d'accès est
/// relu à chaque [connect], jamais figé au constructeur : un rafraîchissement
/// survenu entre deux connexions ne doit pas invalider la suivante.
///
/// Une seule reconnexion automatique est tentée sur coupure — pas de boucle
/// infinie non bornée ; au-delà, le flux se ferme et l'appelant doit rappeler
/// [connect] explicitement. Un refus d'accès (code `4403`,
/// `common.consumers.CLOSE_FORBIDDEN`) n'est jamais retenté : retenter un
/// accès refusé ne le rendrait pas autorisé.
class RealtimeChannel {
  RealtimeChannel({required this.wsUrl, required this.tokenStorage});

  final String wsUrl;
  final TokenStorage tokenStorage;

  static const _reconnectDelay = Duration(seconds: 3);
  static const _forbiddenCloseCode = 4403;

  WebSocketChannel? _socket;
  StreamController<RealtimeEvent>? _controller;
  StreamSubscription<dynamic>? _subscription;
  bool _closedByCaller = false;
  bool _hasRetried = false;

  Stream<RealtimeEvent> connect() {
    _closedByCaller = false;
    _hasRetried = false;
    // Le contrôleur est retenu dans `_controller` et fermé par [close], que
    // `onCancel` câble ici et que `_handleClosure` appelle sur une fermeture
    // définitive. Le lint ne suit pas la fermeture au travers du champ.
    // ignore: close_sinks
    final controller = StreamController<RealtimeEvent>.broadcast(onCancel: close);
    _controller = controller;
    unawaited(_open());
    return controller.stream;
  }

  Future<void> _open() async {
    final token = await tokenStorage.getAccessToken();
    final base = Uri.parse(wsUrl);
    final uri = base.replace(
      queryParameters: {...base.queryParameters, if (token != null && token.isNotEmpty) 'token': token},
    );

    final socket = WebSocketChannel.connect(uri);
    _socket = socket;
    _subscription = socket.stream.listen(
      _onData,
      onError: (_) => _handleClosure(),
      onDone: _handleClosure,
      cancelOnError: true,
    );
  }

  void _onData(dynamic message) {
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      _controller?.add(RealtimeEvent.fromJson(json));
    } catch (_) {
      // Trame illisible — ignorée, ne rompt pas la connexion.
    }
  }

  void _handleClosure() {
    if (_closedByCaller) return;

    final code = _socket?.closeCode;
    if (code == _forbiddenCloseCode || _hasRetried) {
      unawaited(_controller?.close());
      return;
    }

    _hasRetried = true;
    Future.delayed(_reconnectDelay, () {
      if (!_closedByCaller) unawaited(_open());
    });
  }

  /// Publie un message sur le canal — seul `ws/orders/{id}/chat/` en accepte,
  /// les autres consommateurs sont à sens unique et ignorent ce qui remonte.
  ///
  /// Sans effet tant que la connexion n'est pas ouverte : la trame serait
  /// perdue de toute façon, et jeter ici obligerait chaque appelant à
  /// distinguer « pas encore connecté » de « refusé ». L'appelant qui a besoin
  /// de cette certitude attend un premier événement.
  void send(Map<String, dynamic> message) {
    final socket = _socket;
    if (socket == null || _closedByCaller) return;
    socket.sink.add(jsonEncode(message));
  }

  Future<void> close() async {
    _closedByCaller = true;
    await _subscription?.cancel();
    await _socket?.sink.close();
    await _controller?.close();
  }
}
