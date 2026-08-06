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

Map<String, dynamic> _zoneJson({Object? franco = const {'amount': '12000', 'currency': 'XOF'}}) {
  return {
    'id': 'zone-centre',
    'city': 'city-lome',
    'name': 'Centre-ville',
    'boundary': null,
    'base_fee': {'amount': '600', 'currency': 'XOF'},
    'fee_per_km': {'amount': '150', 'currency': 'XOF'},
    'free_delivery_threshold': franco,
    'min_order_amount': null,
    'max_distance_km': '12.00',
    'estimated_delivery_minutes': 35,
    'is_active': true,
    'created_at': '2026-08-05T10:00:00Z',
    'updated_at': '2026-08-05T10:00:00Z',
  };
}

Map<String, dynamic> _cityJson({
  String id = 'city-lome',
  String name = 'Lomé',
  bool isActive = true,
}) {
  return {
    'id': id,
    'country': 'TG',
    'name': name,
    'slug': name.toLowerCase(),
    'centroid': {'lat': 6.1319, 'lon': 1.2255},
    'is_active': isActive,
    'created_at': '2026-08-05T10:00:00Z',
    'updated_at': '2026-08-05T10:00:00Z',
  };
}

class _FakeServer implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  /// Deux pages de villes : la pagination de DRF est réelle
  /// (`PAGE_SIZE=20`), et ne suivre que la première tronquerait les noms de
  /// villes sur un déploiement multi-pays.
  bool paginerLesVilles = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (options.path.contains('/geography/manage/cities/')) {
      final deuxiemePage = options.path.contains('page=2');
      return ResponseBody.fromString(
        jsonEncode({
          'count': paginerLesVilles ? 2 : 1,
          'next': paginerLesVilles && !deuxiemePage
              ? 'http://test.local/api/v1/geography/manage/cities/?page=2'
              : null,
          'previous': null,
          'results': [
            if (deuxiemePage)
              _cityJson(id: 'city-kara', name: 'Kara', isActive: false)
            else
              _cityJson(),
          ],
        }),
        200,
        headers: _jsonHeaders,
      );
    }

    if (options.path.contains('/geography/manage/zones/')) {
      if (options.method == 'GET') {
        return ResponseBody.fromString(
          jsonEncode({
            'count': 1,
            'next': null,
            'previous': null,
            'results': [_zoneJson()],
          }),
          200,
          headers: _jsonHeaders,
        );
      }
      return ResponseBody.fromString(jsonEncode(_zoneJson()), 200, headers: _jsonHeaders);
    }

    throw UnimplementedError('Route non simulée : ${options.method} ${options.path}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late ManagedGeographyRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    );
    repository = ManagedGeographyRepository(apiClient: apiClient);
  });

  Map<String, dynamic> dernierCorps() =>
      server.requests.last.data as Map<String, dynamic>;

  group('Lecture des zones', () {
    test('le barème complet remonte, seuils compris', () async {
      final zones = await repository.zones();

      expect(zones, hasLength(1));
      expect(zones.single.freeDeliveryThreshold!.amountMinor, 12000);
      expect(zones.single.baseFee.amountMinor, 600);
      expect(zones.single.maxDistanceKm, 12.0);
    });

    test('les zones inactives ne sont pas filtrées côté client', () async {
      await repository.zones();

      // Sans quoi désactiver une zone la ferait disparaître de l'écran qui
      // sert à la rouvrir.
      expect(server.requests.last.queryParameters.containsKey('is_active'), isFalse);
    });
  });

  group('Lecture des villes', () {
    test('la ville est nommée, avec son pays en code ISO', () async {
      final villes = await repository.cities();

      expect(villes, hasLength(1));
      expect(villes.single.id, 'city-lome');
      expect(villes.single.name, 'Lomé');
      // `SlugRelatedField(slug_field="iso_code")` : le pays voyage en code, pas
      // en clé primaire.
      expect(villes.single.countryIsoCode, 'TG');
      expect(villes.single.isActive, isTrue);
    });

    test('les villes fermées remontent aussi', () async {
      server.paginerLesVilles = true;

      final villes = await repository.cities();

      // Sans quoi les zones d'une ville fermée s'afficheraient sous un
      // intitulé de repli, dans l'écran même qui sert à les rouvrir.
      expect(villes.map((ville) => ville.name), ['Lomé', 'Kara']);
      expect(villes.last.isActive, isFalse);
    });

    test('la pagination est suivie jusqu’au bout', () async {
      server.paginerLesVilles = true;

      expect(await repository.cities(), hasLength(2));
      expect(
        server.requests.where((r) => r.path.contains('manage/cities')),
        hasLength(2),
      );
    });

    test('aucun filtre n’est envoyé par défaut', () async {
      await repository.cities();

      expect(server.requests.last.queryParameters.containsKey('is_active'), isFalse);
    });
  });

  group('Seuil de franco', () {
    test('un seuil posé part en unité mineure', () async {
      await repository.updateZone(
        zoneId: 'zone-centre',
        freeDeliveryThreshold: Money.fromMajorUnits(15000, 'XOF'),
      );

      expect(dernierCorps()['free_delivery_threshold'], {
        'amount': '15000',
        'currency': 'XOF',
      });
    });

    test('retirer le seuil envoie un null explicite', () async {
      await repository.updateZone(
        zoneId: 'zone-centre',
        clearFreeDeliveryThreshold: true,
      );

      final corps = dernierCorps();
      expect(corps.containsKey('free_delivery_threshold'), isTrue);
      expect(corps['free_delivery_threshold'], isNull);
    });

    test('ne pas y toucher n’envoie pas le champ', () async {
      await repository.updateZone(zoneId: 'zone-centre', name: 'Centre');

      final corps = dernierCorps();
      expect(corps.containsKey('free_delivery_threshold'), isFalse);
      expect(corps['name'], 'Centre');
    });

    test('poser et retirer dans le même appel est refusé', () {
      expect(
        () => repository.updateZone(
          zoneId: 'zone-centre',
          freeDeliveryThreshold: Money.fromMajorUnits(15000, 'XOF'),
          clearFreeDeliveryThreshold: true,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Autres champs du barème', () {
    test('la modification est partielle : seuls les champs fournis partent', () async {
      await repository.updateZone(
        zoneId: 'zone-centre',
        name: 'Centre-ville',
        baseFee: Money.fromMajorUnits(700, 'XOF'),
        estimatedDeliveryMinutes: 40,
        isActive: false,
      );

      expect(dernierCorps(), {
        'name': 'Centre-ville',
        'base_fee': {'amount': '700', 'currency': 'XOF'},
        'estimated_delivery_minutes': 40,
        'is_active': false,
      });
    });

    test('le minimum de commande se retire aussi', () async {
      await repository.updateZone(zoneId: 'zone-centre', clearMinOrderAmount: true);

      final corps = dernierCorps();
      expect(corps.containsKey('min_order_amount'), isTrue);
      expect(corps['min_order_amount'], isNull);
    });
  });
}
