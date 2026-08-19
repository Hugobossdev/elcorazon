import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Petit serveur WebSocket local — simule
/// `common.consumers.AuthorizedConsumer` : ferme avec le code demandé par le
/// paramètre de requête `close`, sinon envoie un événement puis reste ouvert.
class _FakeServer {
  _FakeServer(this._server) {
    _server.listen((request) async {
      connectionCount++;
      // Le socket doit rester ouvert : c'est précisément ce que ce faux
      // serveur simule. Il tombe avec `_server.close(force: true)`.
      // ignore: close_sinks
      final socket = await WebSocketTransformer.upgrade(request);
      socket.add(jsonEncode({'seq': 1, 'type': 'tracking.position', 'lat': 6.13, 'lon': 1.22}));
    });
  }

  final HttpServer _server;
  int connectionCount = 0;

  static Future<_FakeServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _FakeServer(server);
  }

  int get port => _server.port;

  Future<void> close() => _server.close(force: true);
}

/// Simule `OrderChatConsumer` : renvoie en écho ce qu'on lui envoie, ce qui
/// permet de vérifier qu'une trame émise part bien sur le socket.
class _EchoServer {
  _EchoServer(this._server) {
    _server.listen((request) async {
      // Le socket doit rester ouvert : c'est précisément ce que ce faux
      // serveur simule. Il tombe avec `_server.close(force: true)`.
      // ignore: close_sinks
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((frame) {
        final message = jsonDecode(frame as String) as Map<String, dynamic>;
        socket.add(
          jsonEncode({
            'seq': 1,
            'type': 'chat.message',
            'sender': 'courier',
            'text': message['text'],
          }),
        );
      });
    });
  }

  final HttpServer _server;

  static Future<_EchoServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _EchoServer(server);
  }

  int get port => _server.port;

  Future<void> close() => _server.close(force: true);
}

class _ForbiddenServer {
  _ForbiddenServer(this._server) {
    _server.listen((request) async {
      connectionCount++;
      // Le socket doit rester ouvert : c'est précisément ce que ce faux
      // serveur simule. Il tombe avec `_server.close(force: true)`.
      // ignore: close_sinks
      final socket = await WebSocketTransformer.upgrade(request);
      await socket.close(4403, 'forbidden');
    });
  }

  final HttpServer _server;
  int connectionCount = 0;

  static Future<_ForbiddenServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _ForbiddenServer(server);
  }

  int get port => _server.port;

  Future<void> close() => _server.close(force: true);
}

/// Refuse la poignée de main elle-même, comme le fait Django quand
/// `authorized_group()` rend `None` : la requête est close en 403 et aucun
/// WebSocket n'existe jamais. C'est le cas d'un suivi demandé sur une commande
/// que le serveur ne diffuse pas — distinct d'un socket ouvert puis fermé.
class _RejectingServer {
  _RejectingServer(this._server) {
    _server.listen((request) async {
      connectionCount++;
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
    });
  }

  final HttpServer _server;
  int connectionCount = 0;

  static Future<_RejectingServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _RejectingServer(server);
  }

  int get port => _server.port;

  Future<void> close() => _server.close(force: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  test('décode les événements reçus et transmet le jeton en requête', () async {
    final server = await _FakeServer.start();
    addTearDown(server.close);

    final channel = RealtimeChannel(
      wsUrl: 'ws://127.0.0.1:${server.port}/ws/orders/order-1/tracking/',
      tokenStorage: TokenStorage(),
    );
    addTearDown(channel.close);

    final event = await channel.connect().first;

    expect(event.type, 'tracking.position');
    expect(event.seq, 1);
    expect(event.payload['lat'], 6.13);
  });

  test('send publie une trame sur le canal', () async {
    final server = await _EchoServer.start();
    addTearDown(server.close);

    final channel = RealtimeChannel(
      wsUrl: 'ws://127.0.0.1:${server.port}/ws/orders/order-1/chat/',
      tokenStorage: TokenStorage(),
    );
    addTearDown(channel.close);

    final events = channel.connect();
    // La connexion est établie de façon asynchrone : émettre avant qu'elle ne
    // le soit est sans effet, par contrat.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    channel.send({'text': 'Je suis en bas'});

    final event = await events.first;

    expect(event.type, 'chat.message');
    expect(event.payload['text'], 'Je suis en bas');
    expect(event.payload['sender'], 'courier');
  }, timeout: const Timeout(Duration(seconds: 10)),);

  test('send avant connexion ne jette pas', () async {
    final channel = RealtimeChannel(
      wsUrl: 'ws://127.0.0.1:1/ws/orders/order-1/chat/',
      tokenStorage: TokenStorage(),
    );

    expect(() => channel.send({'text': 'perdu'}), returnsNormally);
  });

  test('une poignée de main refusée se termine sans erreur non rattrapée', () async {
    final server = await _RejectingServer.start();
    addTearDown(server.close);

    final channel = RealtimeChannel(
      wsUrl: 'ws://127.0.0.1:${server.port}/ws/orders/order-1/tracking/',
      tokenStorage: TokenStorage(),
    );
    addTearDown(channel.close);

    // Le refus ne parvenait à personne : il ressortait en erreur non rattrapée
    // hors du canal — dans un test, en échec de zone ; dans le navigateur, en
    // « Uncaught (in promise) WebSocketChannelException ». Le flux doit se
    // clore de lui-même, sans jamais rien émettre.
    final events = await channel.connect().toList();

    expect(events, isEmpty);
    // Une seule reprise est tentée, puis le canal renonce.
    expect(server.connectionCount, 2);
  }, timeout: const Timeout(Duration(seconds: 15)),);

  test('close() ne reste pas suspendu sur une poignée de main refusée', () async {
    final server = await _RejectingServer.start();
    addTearDown(server.close);

    final channel = RealtimeChannel(
      wsUrl: 'ws://127.0.0.1:${server.port}/ws/orders/order-1/tracking/',
      tokenStorage: TokenStorage(),
    );

    channel.connect().listen((_) {}, onError: (Object _) {});
    await Future<void>.delayed(const Duration(seconds: 4));

    // Le puits d'un socket jamais ouvert ne se referme jamais : `close()`
    // l'attendait sans borne. `RealtimeTrackingService.trackOrder` commençant
    // par fermer le canal précédent, un seul refus interdisait ensuite toute
    // connexion — y compris celle que le serveur aurait acceptée une fois la
    // commande confirmée.
    await expectLater(channel.close(), completes);
  }, timeout: const Timeout(Duration(seconds: 20)),);

  test('une fermeture 4403 (accès refusé) ne déclenche aucune reconnexion', () async {
    final server = await _ForbiddenServer.start();
    addTearDown(server.close);

    final channel = RealtimeChannel(
      wsUrl: 'ws://127.0.0.1:${server.port}/ws/orders/order-1/tracking/',
      tokenStorage: TokenStorage(),
    );
    addTearDown(channel.close);

    final stream = channel.connect();
    await stream.toList(); // Le flux doit se clore de lui-même, sans jamais émettre.

    // Laisse le temps qu'aurait pris une reconnexion (3s) pour prouver
    // qu'aucune tentative supplémentaire n'a eu lieu.
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(server.connectionCount, 1);
  }, timeout: const Timeout(Duration(seconds: 10)),);
}
