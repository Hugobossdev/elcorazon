import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Zones propres à une cuisine (lot 1) : la forme envoyée, le contour relu, et
/// les quatre gestes du dépôt.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _zoneJson({String id = 'zone-1', String shape = 'polygon'}) => {
      'id': id,
      'city': 'ville-1',
      'restaurant': 'el-corazon-lome',
      'name': 'Tokoin',
      'shape': shape,
      'boundary': {
        'type': 'MultiPolygon',
        'coordinates': [
          [
            [
              [1.20, 6.10],
              [1.26, 6.10],
              [1.26, 6.16],
              [1.20, 6.10],
            ],
          ],
        ],
      },
      'center': shape == 'circle' ? {'lat': 6.13, 'lon': 1.22} : null,
      'radius_meters': shape == 'circle' ? 3000 : null,
      'base_fee': {'amount': '500', 'currency': 'XOF'},
      'fee_per_km': {'amount': '0', 'currency': 'XOF'},
      'max_distance_km': '10.00',
      'estimated_delivery_minutes': 30,
      'is_active': true,
    };

class _Serveur implements HttpClientAdapter {
  final List<String> requetes = [];
  final List<Object?> corps = [];
  final List<Map<String, dynamic>> parametres = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requetes.add('${options.method} ${options.path}');
    corps.add(options.data);
    parametres.add(Map<String, dynamic>.from(options.queryParameters));

    if (options.method == 'DELETE') return ResponseBody.fromString('', 204);
    if (options.method == 'GET') {
      // Deux pages : la seconde ne doit pas être oubliée.
      final premiere = !options.path.contains('page=2');
      return _json({
        'count': 2,
        'next': premiere ? 'http://test.local/api/v1/restaurants/manage/zones/?page=2' : null,
        'previous': null,
        'results': [_zoneJson(id: premiere ? 'zone-1' : 'zone-2')],
      });
    }
    return _json(_zoneJson(shape: (options.data as Map)['shape'] as String? ?? 'polygon'));
  }

  ResponseBody _json(Map<String, dynamic> body) =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: _jsonHeaders);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Serveur serveur;
  late RestaurantZoneRepository depot;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
    serveur = _Serveur();
    depot = RestaurantZoneRepository(
      apiClient: ApiClient(
        baseUrl: 'http://test.local/api/v1',
        tokenStorage: TokenStorage(),
        testAdapter: serveur,
      ),
    );
  });

  group('La forme envoyée', () {
    test('un polygone part en [longitude, latitude], sans refermer l’anneau', () {
      const forme = ZonePolygonale([GeoPoint(6.10, 1.20), GeoPoint(6.10, 1.26), GeoPoint(6.16, 1.26)]);

      expect(forme.versJson(), {
        'shape': 'polygon',
        'polygon_coordinates': [
          [1.20, 6.10],
          [1.26, 6.10],
          [1.26, 6.16],
        ],
      });
      expect(forme.estFerme, isTrue);
      expect(const ZonePolygonale([GeoPoint(6.1, 1.2), GeoPoint(6.1, 1.3)]).estFerme, isFalse);
    });

    test('un cercle part avec son centre et son rayon', () {
      const forme = ZoneCirculaire(centre: GeoPoint(6.13, 1.22), rayonMetres: 3000);

      expect(forme.versJson(), {
        'shape': 'circle',
        'center': {'lat': 6.13, 'lon': 1.22},
        'radius_meters': 3000,
      });
    });
  });

  group('Le contour relu', () {
    test('les sommets se relisent en latitude/longitude, sans le point de fermeture', () {
      final zone = DeliveryZone.fromJson(_zoneJson());

      expect(zone.sommets, const [GeoPoint(6.10, 1.20), GeoPoint(6.10, 1.26), GeoPoint(6.16, 1.26)]);
      expect(zone.restaurantSlug, 'el-corazon-lome');
      expect(zone.estCirculaire, isFalse);
    });

    test('un cercle se relit avec son centre et son rayon', () {
      final zone = DeliveryZone.fromJson(_zoneJson(shape: 'circle'));

      expect(zone.estCirculaire, isTrue);
      expect(zone.center, const GeoPoint(6.13, 1.22));
      expect(zone.radiusMeters, 3000);
    });
  });

  group('Le dépôt', () {
    test('lit toutes les pages, filtrées sur la cuisine', () async {
      final zones = await depot.zonesDe('el-corazon-lome');

      expect(zones.map((z) => z.id), ['zone-1', 'zone-2']);
      expect(serveur.parametres.first['restaurant__slug'], 'el-corazon-lome');
    });

    test('crée avec la forme, la cuisine et la ville', () async {
      await depot.creer(
        restaurantSlug: 'el-corazon-lome',
        cityId: 'ville-1',
        nom: 'Tokoin',
        forme: const ZoneCirculaire(centre: GeoPoint(6.13, 1.22), rayonMetres: 3000),
        forfait: Money.fromMajorUnits(500, 'XOF'),
        parKm: Money.fromMajorUnits(0, 'XOF'),
        distanceMaxKm: 10,
        dureeEstimeeMinutes: 30,
      );

      expect(serveur.requetes.last, 'POST /restaurants/manage/zones/');
      final envoye = serveur.corps.last! as Map;
      expect(envoye['restaurant'], 'el-corazon-lome');
      expect(envoye['shape'], 'circle');
      expect(envoye['radius_meters'], 3000);
    });

    test('une modification n’envoie que ce qu’on change', () async {
      await depot.modifier('zone-1', active: false);

      expect(serveur.requetes.last, 'PATCH /restaurants/manage/zones/zone-1/');
      expect(serveur.corps.last, {'is_active': false});
    });

    test('supprime par la fiche de la zone', () async {
      await depot.supprimer('zone-1');

      expect(serveur.requetes.last, 'DELETE /restaurants/manage/zones/zone-1/');
    });
  });
}
