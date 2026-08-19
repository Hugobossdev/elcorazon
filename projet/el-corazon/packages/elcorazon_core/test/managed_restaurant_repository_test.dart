import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _restaurantJson({
  String id = 'rest-1',
  String name = 'El Corazón — Lomé',
  String slug = 'el-corazon-lome',
  double lat = 6.1319,
  double lon = 1.2255,
  bool isActive = true,
  bool acceptsOrders = true,
}) {
  return {
    'id': id,
    'name': name,
    'slug': slug,
    'description': 'Cuisine latine',
    'zone': 'zone-1',
    'address': 'Boulevard du 13 Janvier',
    'location': {'lat': lat, 'lon': lon},
    'phone': '+22890000000',
    'email': 'lome@elcorazon.test',
    'cover_image': null,
    'currency': 'XOF',
    'timezone': 'Africa/Lome',
    'is_active': isActive,
    'accepts_orders': acceptsOrders,
    'default_preparation_minutes': 20,
    'created_at': '2026-07-31T10:00:00Z',
    'updated_at': '2026-07-31T10:00:00Z',
  };
}

class _FakeServer implements HttpClientAdapter {
  _FakeServer({this.pages = 1});

  /// Nombre de pages que la route rendra.
  final int pages;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (options.path.contains('/restaurants/manage/')) {
      final page = int.tryParse(options.uri.queryParameters['page'] ?? '1') ?? 1;
      final derniere = page >= pages;

      return ResponseBody.fromString(
        jsonEncode({
          'count': pages,
          'next': derniere
              ? null
              : 'http://test.local/api/v1/restaurants/manage/?page=${page + 1}',
          'previous': null,
          'results': [
            _restaurantJson(
              id: 'rest-$page',
              slug: page == 1 ? 'el-corazon-lome' : 'el-corazon-kara',
              isActive: page == 1,
            ),
          ],
        }),
        200,
        headers: _jsonHeaders,
      );
    }

    throw UnimplementedError('Route non simulée : ${options.path}');
  }
}

ManagedRestaurantRepository _repository(_FakeServer server) {
  return ManagedRestaurantRepository(
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

  group('ManagedRestaurantRepository', () {
    test('list rend le périmètre du compte, sans le lui demander', () async {
      // Aucun filtre n'est envoyé : le périmètre est une décision du serveur,
      // pas un paramètre du client. C'est tout l'écart avec la constante
      // `el-corazon-lome` que le back-office portait.
      final server = _FakeServer();

      final etablissements = await _repository(server).list();

      expect(etablissements, hasLength(1));
      expect(server.requests.single.uri.queryParameters, isEmpty);
    });

    test('la position est lue dans le bon sens', () async {
      // `LocationField` rend `{"lat": …, "lon": …}` justement parce que
      // PostGIS attend `Point(x=lon, y=lat)` : inverser les deux placerait un
      // restaurant de Lomé au large de la Somalie.
      final etablissement = (await _repository(_FakeServer()).list()).single;

      expect(etablissement.latitude, closeTo(6.1319, 1e-9));
      expect(etablissement.longitude, closeTo(1.2255, 1e-9));
    });

    test('un établissement suspendu reste dans la liste', () async {
      // Le masquer le rendrait irrécupérable depuis l'écran qui sert à le
      // rouvrir.
      final etablissements = await _repository(_FakeServer(pages: 2)).list();

      expect(etablissements.map((e) => e.slug), [
        'el-corazon-lome',
        'el-corazon-kara',
      ]);
      expect(etablissements.last.isActive, isFalse);
    });

    test('list suit la pagination jusqu’au bout', () async {
      final server = _FakeServer(pages: 3);

      final etablissements = await _repository(server).list();

      expect(etablissements, hasLength(3));
      expect(server.requests, hasLength(3));
    });
  });
}
