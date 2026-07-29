import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Simule une seule page de `/geography/cities/` (déploiement mono-pays).
class _FakeServer implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/geography/cities/')) {
      return ResponseBody.fromString(
        jsonEncode({
          'count': 1,
          'next': null,
          'previous': null,
          'results': [
            {'id': 'city-lome', 'name': 'Lomé', 'slug': 'lome'},
          ],
        }),
        200,
        headers: _jsonHeaders,
      );
    }

    throw UnimplementedError('Route non simulée : ${options.path}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GeographyRepository.getCities mappe la liste des villes', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: _FakeServer(),
    );
    final repository = GeographyRepository(apiClient: apiClient);

    final cities = await repository.getCities();

    expect(cities, hasLength(1));
    expect(cities.single.slug, 'lome');
  });
}
