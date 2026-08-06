import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Simule une seule page de `/geography/cities/` (déploiement mono-pays) et la
/// résolution de zone.
class _FakeServer implements HttpClientAdapter {
  Map<String, dynamic>? lastQuery;

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

    if (options.path.contains('/geography/zones/resolve/')) {
      lastQuery = Map<String, dynamic>.from(options.queryParameters);

      // Hors du Grand Lomé, le serveur répond `200` sans zone — et non `404`.
      final couvert = (options.queryParameters['lat'] as num).toDouble() < 7;
      return ResponseBody.fromString(
        jsonEncode({
          'is_covered': couvert,
          'zone': couvert
              ? {
                  'id': 'zone-centre',
                  'name': 'Centre-ville',
                  // La route publique imbrique la ville entière, là où le
                  // back-office n'en rend que la clé.
                  'city': {
                    'id': 'city-lome',
                    'name': 'Lomé',
                    'slug': 'lome',
                  },
                  'base_fee': {'amount': '600', 'currency': 'XOF'},
                  'fee_per_km': {'amount': '150', 'currency': 'XOF'},
                  'free_delivery_threshold': {'amount': '12000', 'currency': 'XOF'},
                  'min_order_amount': null,
                  'max_distance_km': '12.00',
                  'estimated_delivery_minutes': 35,
                }
              : null,
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

  late _FakeServer server;
  late GeographyRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    );
    repository = GeographyRepository(apiClient: apiClient);
  });

  test('GeographyRepository.getCities mappe la liste des villes', () async {
    final cities = await repository.getCities();

    expect(cities, hasLength(1));
    expect(cities.single.slug, 'lome');
  });

  group('GeographyRepository.resolveZone', () {
    test('rend le barème de la zone qui couvre le point', () async {
      final resolution = await repository.resolveZone(lat: 6.1319, lon: 1.2255);

      expect(resolution.isCovered, isTrue);
      expect(server.lastQuery, {'lat': 6.1319, 'lon': 1.2255});

      final zone = resolution.zone!;
      expect(zone.name, 'Centre-ville');
      // La ville imbriquée ne doit pas finir en identifiant : c'est sa clé qui
      // est retenue, pas la représentation de la map.
      expect(zone.cityId, 'city-lome');
      expect(zone.baseFee.amountMinor, 600);
      expect(zone.feePerKm.amountMinor, 150);
      expect(zone.freeDeliveryThreshold!.amountMinor, 12000);
      expect(zone.minOrderAmount, isNull);
      // `max_distance_km` arrive en chaîne — un `DecimalField` de DRF.
      expect(zone.maxDistanceKm, 12.0);
      expect(zone.estimatedDeliveryMinutes, 35);
    });

    test('rend « non desservi » sans lever d\'exception', () async {
      final resolution = await repository.resolveZone(lat: 12.65, lon: -8.0);

      expect(resolution.isCovered, isFalse);
      expect(resolution.zone, isNull);
    });
  });
}
