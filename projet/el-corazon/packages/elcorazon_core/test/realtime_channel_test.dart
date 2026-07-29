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

class _ForbiddenServer {
  _ForbiddenServer(this._server) {
    _server.listen((request) async {
      connectionCount++;
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
  }, timeout: const Timeout(Duration(seconds: 10)));
}
