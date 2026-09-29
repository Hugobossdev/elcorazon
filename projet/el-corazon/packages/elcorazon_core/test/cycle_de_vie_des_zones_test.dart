import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cycle de vie, horaires, contour complet et outil de couverture (2026-09-28).
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _zone({String status = 'draft'}) => {
      'id': 'zone-1',
      'city': 'ville-1',
      'restaurant': null,
      'name': 'Bè',
      'shape': 'administrative',
      'boundary': {
        'type': 'MultiPolygon',
        'coordinates': [
          [
            [
              [1.10, 6.00],
              [1.35, 6.00],
              [1.35, 6.25],
              [1.10, 6.00],
            ],
            [
              [1.22, 6.12],
              [1.23, 6.12],
              [1.23, 6.14],
              [1.22, 6.12],
            ],
          ],
          [
            [
              [1.40, 6.00],
              [1.45, 6.00],
              [1.45, 6.10],
              [1.40, 6.00],
            ],
          ],
        ],
      },
      'base_fee': {'amount': '500', 'currency': 'XOF'},
      'fee_per_km': {'amount': '0', 'currency': 'XOF'},
      'max_distance_km': '10.00',
      'estimated_delivery_minutes': 30,
      'status': status,
      'transitions': status == 'draft' ? ['archived', 'pending_review'] : <String>[],
      'is_active': status == 'published',
      'priority': 2,
      'overlaps': ['Centre'],
      'opening_hours': [
        {'weekday': 4, 'opens_at': '20:00:00', 'closes_at': '02:00:00'},
      ],
      'exceptions': [
        {
          'id': 'exc-1',
          'kind': 'closed',
          'starts_at': '2026-10-01T00:00:00Z',
          'ends_at': '2026-10-02T00:00:00Z',
          'reason': 'Fête',
          'created_at': '2026-09-28T10:00:00Z',
        },
      ],
      'created_by': 'Ama',
      'published_by': null,
      'suspension_reason': '',
    };

class _Serveur implements HttpClientAdapter {
  final List<String> requetes = [];
  final List<Object?> corps = [];

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
    if (options.method == 'DELETE') return ResponseBody.fromString('', 204);
    if (options.path.endsWith('/schedule/')) {
      return _json({'hours': (options.data as Map)['hours']});
    }
    if (options.path.endsWith('/coverage-test/')) {
      return _json({
        'available': false,
        'unavailable_code': 'zone_closed',
        'reason': 'Fermée',
        'zone': null,
        'selection_reason': 'Aucune zone applicable ne livre ce point à cet instant.',
        'candidates': [
          {
            'id': 'z',
            'name': 'Centre',
            'status': 'published',
            'priority': 0,
            'city': 'Lomé',
            'restaurant': null,
            'surface_km2': 3.2,
            'rank': 0,
            'excluded_because': 'closed',
            'reopens_at': '2026-10-01T11:00:00Z',
          },
        ],
        'kitchen': {
          'slug': 'lome',
          'name': 'El Corazón',
          'status': 'active',
          'can_order_now': true,
          'unavailable_code': null,
          'active_orders': 4,
        },
        'couriers': [
          {'id': 'l', 'name': 'Kofi', 'is_online': false, 'eligible': false, 'reason': 'offline'},
        ],
        'nearest_zone': null,
      });
    }
    return _json(_zone(status: 'pending_review'));
  }

  ResponseBody _json(Map<String, dynamic> body) =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: _jsonHeaders);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Serveur serveur;
  late ApiClient client;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
    serveur = _Serveur();
    client = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: serveur,
    );
  });

  group('La fiche relue', () {
    test('tout le MultiPolygon, trous compris — pas seulement le premier anneau', () {
      final zone = DeliveryZone.fromJson(_zone());

      expect(zone.polygones, hasLength(2));
      expect(zone.polygones.first, hasLength(2), reason: 'un extérieur et un trou');
      expect(zone.polygones.first[1].first, const GeoPoint(6.12, 1.22));
      expect(zone.estComplexe, isTrue);
      // L'éditeur, lui, ne rouvre que le premier anneau.
      expect(zone.sommets, hasLength(3));
    });

    test('statut, transitions permises, horaires et traçabilité', () {
      final zone = DeliveryZone.fromJson(_zone());

      expect(zone.status, StatutZone.brouillon);
      expect(zone.peutPasserA(StatutZone.enRevue), isTrue);
      expect(zone.peutPasserA(StatutZone.publiee), isFalse);
      expect(zone.priority, 2);
      expect(zone.overlaps, ['Centre']);
      expect(zone.horaires.single.ouvre, '20:00');
      expect(zone.horaires.single.franchitMinuit, isTrue);
      expect(zone.exceptions.single.estUneFermeture, isTrue);
      expect(zone.createdBy, 'Ama');
    });

    test('un serveur antérieur au cycle de vie : le statut se déduit de is_active', () {
      final ancienne = Map<String, dynamic>.from(_zone())
        ..remove('status')
        ..['is_active'] = false;

      expect(DeliveryZone.fromJson(ancienne).status, StatutZone.suspendue);
    });
  });

  group('Les gestes', () {
    test('adressés au bon préfixe, avec le motif et la fin annoncée', () async {
      final ville = ZoneLifecycleRepository.ville(apiClient: client);
      final cuisine = ZoneLifecycleRepository.cuisine(apiClient: client);

      await ville.soumettre('zone-1');
      await cuisine.suspendre('zone-1', motif: 'Coupure', finPrevue: DateTime.utc(2026, 10));
      await ville.dupliquer('zone-1', nom: 'Bè bis');

      expect(serveur.requetes, [
        'POST /geography/manage/zones/zone-1/submit/',
        'POST /restaurants/manage/zones/zone-1/suspend/',
        'POST /geography/manage/zones/zone-1/duplicate/',
      ]);
      expect(
        serveur.corps[1],
        {'reason': 'Coupure', 'expected_end_at': '2026-10-01T00:00:00.000Z'},
      );
    });

    test('la semaine part entière, en PUT', () async {
      final horaires = await ZoneLifecycleRepository.ville(apiClient: client).ecrireHoraires(
        'zone-1',
        const [HoraireDeZone(jour: 0, ouvre: '11:00', ferme: '22:00')],
      );

      expect(serveur.requetes.single, 'PUT /geography/manage/zones/zone-1/schedule/');
      expect(horaires.single.ferme, '22:00');
    });
  });

  test('le rapport de couverture se lit tel que le serveur le rend', () async {
    final rapport =
        await CoverageRepository(apiClient: client).tester(latitude: 6.13, longitude: 1.22);

    expect(serveur.corps.single, {'lat': 6.13, 'lon': 1.22});
    expect(rapport.disponible, isFalse);
    expect(rapport.motif, MotifIndisponibilite.zoneFermee);
    expect(rapport.candidates.single.exclueCar, 'closed');
    expect(rapport.cuisine!.commandesEnCours, 4);
    expect(LivreurDeZone.libelleMotif(rapport.livreurs!.single.motif), 'Hors ligne');
  });
}
