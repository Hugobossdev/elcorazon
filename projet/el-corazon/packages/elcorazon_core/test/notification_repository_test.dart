import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _notificationJson({
  String id = 'notif-1',
  String kind = 'order_status',
  bool isRead = false,
}) {
  return {
    'id': id,
    'kind': kind,
    'title': 'Votre commande est en route',
    'body': 'Le livreur vient de récupérer votre commande.',
    'data': {'order_id': 'order-1'},
    'is_read': isRead,
    'read_at': isRead ? '2026-07-28T12:30:00Z' : null,
    'created_at': '2026-07-28T12:00:00Z',
  };
}

/// Simule `/notifications/*`, avec deux pages pour l'historique.
class _FakeServer implements HttpClientAdapter {
  final List<String> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final query = options.uri.query;
    requests.add('${options.method} $path${query.isEmpty ? '' : '?$query'}');

    if (path.endsWith('/notifications/unread-count/')) {
      return _json({'unread': 3}, 200);
    }

    if (path.endsWith('/notifications/read-all/')) {
      return ResponseBody.fromString('', 204, headers: _jsonHeaders);
    }

    if (path.endsWith('/notifications/notif-1/read/')) {
      return _json(_notificationJson(isRead: true), 200);
    }

    if (path.endsWith('/notifications/')) {
      final kind = options.uri.queryParameters['kind'];
      if (options.uri.queryParameters['page'] == '2') {
        return _json({
          'count': 2,
          'next': null,
          'previous': null,
          'results': [_notificationJson(id: 'notif-2', isRead: true)],
        }, 200,);
      }
      return _json({
        'count': 2,
        'next': 'http://test.local/api/v1/notifications/?page=2',
        'previous': null,
        'results': [_notificationJson(kind: kind ?? 'order_status')],
      }, 200,);
    }

    throw UnimplementedError('Route non simulée : ${options.method} $path');
  }

  ResponseBody _json(Map<String, dynamic> body, int status) {
    return ResponseBody.fromString(jsonEncode(body), status, headers: _jsonHeaders);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late NotificationRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    );
    repository = NotificationRepository(apiClient: apiClient);
  });

  group('NotificationRepository', () {
    test('getNotifications suit la pagination et mappe la charge utile', () async {
      final notifications = await repository.getNotifications();

      expect(notifications, hasLength(2));
      expect(notifications.first.data['order_id'], 'order-1');
      expect(notifications.first.isRead, isFalse);
      expect(notifications.last.readAt, isNotNull);
      expect(server.requests, [
        'GET /api/v1/notifications/',
        'GET /api/v1/notifications/?page=2',
      ]);
    });

    test('getNotifications filtre par genre côté serveur', () async {
      final notifications = await repository.getNotifications(kind: 'marketing');

      expect(notifications.first.kind, 'marketing');
      expect(server.requests.first, 'GET /api/v1/notifications/?kind=marketing');
    });

    test('getUnreadCount lit la route dédiée, pas la liste paginée', () async {
      expect(await repository.getUnreadCount(), 3);
      expect(server.requests.single, 'GET /api/v1/notifications/unread-count/');
    });

    test('markRead rend la notification lue', () async {
      final notification = await repository.markRead('notif-1');

      expect(notification.isRead, isTrue);
      expect(notification.readAt, isNotNull);
    });

    test('markAllRead accepte une réponse 204 sans corps', () async {
      await repository.markAllRead();

      expect(server.requests.single, 'POST /api/v1/notifications/read-all/');
    });

    test('asRead conserve la première date de lecture', () {
      final deja = AppNotification.fromJson(_notificationJson(isRead: true));
      final relue = deja.asRead(DateTime.utc(2026, 7, 29));

      expect(relue.readAt, DateTime.parse('2026-07-28T12:30:00Z'));
    });
  });
}
