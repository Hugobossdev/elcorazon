import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _pingJson() {
  return {
    'id': 'ping-1',
    'point': {'lat': 6.1319, 'lon': 1.2255},
    'accuracy_m': 8.5,
    'speed_mps': 4.2,
    'heading_deg': 120.0,
    'recorded_at': '2026-07-29T10:05:00Z',
    'received_at': '2026-07-29T10:05:02Z',
  };
}

/// Simule `/tracking/*`. [sampledOut] rend le 202 de l'échantillonnage.
class _FakeServer implements HttpClientAdapter {
  _FakeServer({this.sampledOut = false});

  final bool sampledOut;
  final List<String> requests = [];
  final List<Map<String, dynamic>> bodies = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    if (options.data is Map) {
      bodies.add(Map<String, dynamic>.from(options.data as Map));
    }

    if (options.path.endsWith('/pings/')) {
      if (sampledOut) {
        return ResponseBody.fromString('', 202, headers: _jsonHeaders);
      }
      return _json(_pingJson(), 201);
    }

    if (options.path.contains('/tracking/orders/order-1/')) {
      return _json({
        'order': 'order-1',
        'assignment_status': 'on_the_way',
        'courier': {
          'id': 'courier-1',
          'full_name': 'Kofi A.',
          'avatar': null,
          'vehicle_type': 'moto',
          'rating_average': '4.75',
          'rating_count': 12,
        },
        'last_position': _pingJson(),
        'estimated_delivery_at': '2026-07-29T10:25:00Z',
      }, 200);
    }

    if (options.path.contains('/tracking/orders/order-sans-livreur/')) {
      return _json({
        'order': 'order-sans-livreur',
        'assignment_status': '',
        'courier': <String, dynamic>{},
        'last_position': null,
        'estimated_delivery_at': null,
      }, 200);
    }

    throw UnimplementedError('Route non simulée : ${options.method} ${options.path}');
  }

  ResponseBody _json(Map<String, dynamic> body, int status) {
    return ResponseBody.fromString(jsonEncode(body), status, headers: _jsonHeaders);
  }
}

TrackingRepository _repositoryFor(_FakeServer server) {
  return TrackingRepository(
    apiClient: ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  group('TrackingRepository — émission de position', () {
    test('sendPing n\'envoie ni la course ni le livreur dans le corps', () async {
      final server = _FakeServer();
      final repository = _repositoryFor(server);

      await repository.sendPing(
        assignmentId: 'assign-1',
        latitude: 6.1319,
        longitude: 1.2255,
        recordedAt: DateTime.utc(2026, 7, 29, 10, 5),
        accuracyMeters: 8.5,
      );

      expect(server.requests, contains('POST /tracking/assignments/assign-1/pings/'));
      // L3 — l'émetteur vient du jeton et la course de l'URL. Les voir
      // apparaître ici signifierait que n'importe qui peut écrire le suivi de
      // n'importe qui.
      final body = server.bodies.single;
      expect(body.containsKey('courier'), isFalse);
      expect(body.containsKey('assignment'), isFalse);
      expect(body['point'], {'lat': 6.1319, 'lon': 1.2255});
    });

    test('sendPing horodate en UTC ISO 8601, quel que soit le fuseau de l\'appareil', () async {
      final server = _FakeServer();
      final repository = _repositoryFor(server);

      await repository.sendPing(
        assignmentId: 'assign-1',
        latitude: 6.1319,
        longitude: 1.2255,
        recordedAt: DateTime.utc(2026, 7, 29, 10, 5).toLocal(),
      );

      expect(server.bodies.single['recorded_at'], '2026-07-29T10:05:00.000Z');
    });

    test('sendPing mappe le relevé persisté (201)', () async {
      final repository = _repositoryFor(_FakeServer());

      final ping = await repository.sendPing(
        assignmentId: 'assign-1',
        latitude: 6.1319,
        longitude: 1.2255,
        recordedAt: DateTime.utc(2026, 7, 29, 10, 5),
      );

      expect(ping, isNotNull);
      expect(ping!.latitude, 6.1319);
      expect(ping.speedMetersPerSecond, 4.2);
      // Horodatage appareil et horodatage serveur restent distincts.
      expect(ping.recordedAt.isBefore(ping.receivedAt), isTrue);
    });

    test('un relevé écarté par l\'échantillonnage (202) rend null, pas une erreur', () async {
      final repository = _repositoryFor(_FakeServer(sampledOut: true));

      final ping = await repository.sendPing(
        assignmentId: 'assign-1',
        latitude: 6.1319,
        longitude: 1.2255,
        recordedAt: DateTime.utc(2026, 7, 29, 10, 5),
      );

      expect(ping, isNull);
    });
  });

  group('TrackingRepository — suivi client', () {
    test('forOrder mappe la position et le livreur', () async {
      final repository = _repositoryFor(_FakeServer());

      final tracking = await repository.forOrder('order-1');

      expect(tracking.hasCourier, isTrue);
      expect(tracking.assignmentStatus, 'on_the_way');
      expect(tracking.lastPosition?.longitude, 1.2255);
      expect(tracking.estimatedDeliveryAt, isNotNull);
    });

    test('une commande sans course rend un suivi vide, pas une erreur', () async {
      final repository = _repositoryFor(_FakeServer());

      final tracking = await repository.forOrder('order-sans-livreur');

      expect(tracking.hasCourier, isFalse);
      expect(tracking.lastPosition, isNull);
      expect(tracking.courier, isEmpty);
    });
  });
}
