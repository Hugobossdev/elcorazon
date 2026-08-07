import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _addressJson({
  String id = 'addr-1',
  String label = 'Maison',
  bool isDefault = true,
}) {
  return {
    'id': id,
    'label': label,
    'kind': 'home',
    'recipient_name': '',
    'recipient_phone': '',
    'line1': 'Rue des Cocotiers',
    'line2': '',
    'landmark': '',
    'city': 'city-lome',
    'city_name': 'Lomé',
    'location': {'lat': 6.1319, 'lon': 1.2255},
    'delivery_instructions': '',
    'is_default': isDefault,
    'created_at': '2026-07-28T12:00:00Z',
    'updated_at': '2026-07-28T12:00:00Z',
  };
}

/// Simule `/profiles/addresses/*` — CRUD standard (`ModelViewSet`).
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
    requests.add('${options.method} ${options.path}');

    if (options.path.endsWith('/profiles/addresses/') && options.method == 'GET') {
      return _jsonResponse({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [_addressJson()],
      }, 200,);
    }

    if (options.path.endsWith('/profiles/addresses/') && options.method == 'POST') {
      return _jsonResponse(_addressJson(id: 'addr-2'), 201);
    }

    if (options.path.contains('/addresses/addr-1/') && options.method == 'PATCH') {
      return _jsonResponse(_addressJson(label: 'Bureau'), 200);
    }

    if (options.path.contains('/addresses/addr-1/') && options.method == 'DELETE') {
      return ResponseBody.fromString('', 204);
    }

    throw UnimplementedError('Route non simulée : ${options.method} ${options.path}');
  }

  ResponseBody _jsonResponse(Map<String, dynamic> body, int status) {
    return ResponseBody.fromString(jsonEncode(body), status, headers: _jsonHeaders);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late AddressRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    );
    repository = AddressRepository(apiClient: apiClient);
  });

  const draft = Address(
    label: 'Maison',
    kind: 'home',
    line1: 'Rue des Cocotiers',
    city: 'city-lome',
    latitude: 6.1319,
    longitude: 1.2255,
    isDefault: true,
  );

  group('AddressRepository', () {
    test('list mappe le carnet, coordonnées comprises', () async {
      final addresses = await repository.list();

      expect(addresses, hasLength(1));
      expect(addresses.single.latitude, 6.1319);
      expect(addresses.single.isDefault, isTrue);
    });

    test('create envoie location et renvoie l\'adresse créée', () async {
      final created = await repository.create(draft);

      expect(created.id, 'addr-2');
      expect(server.requests, contains('POST /profiles/addresses/'));
    });

    test('update appelle PATCH sur l\'adresse', () async {
      final updated = await repository.update('addr-1', draft);

      expect(updated.label, 'Bureau');
      expect(server.requests, contains('PATCH /profiles/addresses/addr-1/'));
    });

    test('delete appelle DELETE sur l\'adresse', () async {
      await repository.delete('addr-1');

      expect(server.requests, contains('DELETE /profiles/addresses/addr-1/'));
    });
  });
}
