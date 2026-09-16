import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le réseau de cuisines, vu du socle : ce que les trois applications lisent.
///
/// * une cuisine fermée dit **jusqu'à quand**, par la phrase du serveur ;
/// * une commande garde sa géographie figée, et la supervision filtre dessus ;
/// * un livreur lit ce qu'il doit encaisser, où il roule, et ce qu'il porte ;
/// * tout reste lisible d'un serveur antérieur, qui ne rend aucun de ces champs.

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class _Serveur implements HttpClientAdapter {
  _Serveur(this.corps);

  final Object corps;
  final List<RequestOptions> requetes = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requetes.add(options);
    return ResponseBody.fromString(
      jsonEncode(corps),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

ApiClient _client(_Serveur serveur) => ApiClient(
  baseUrl: 'http://test.local/api/v1',
  tokenStorage: TokenStorage(),
  testAdapter: serveur,
);

Map<String, dynamic> _cuisine({
  bool canOrderNow = false,
  String code = 'kitchen_closed',
  String? reopensAt = '2026-09-15T11:00:00+00:00',
  String reopensLabel = 'demain à 11 h 00',
}) => {
  'id': 'r1',
  'name': 'El Corazón Cocody',
  'slug': 'el-corazon-cocody',
  'location': {'lat': 5.36, 'lon': -3.99},
  'city': 'Abidjan',
  'city_slug': 'abidjan',
  'country': 'CI',
  'currency': 'XOF',
  'is_open': false,
  'accepts_orders': true,
  'can_order_now': canOrderNow,
  'unavailable_code': canOrderNow ? '' : code,
  'unavailable_reason': canOrderNow ? '' : 'La cuisine est fermée pour le moment.',
  'is_temporarily_closed': code == 'kitchen_temporarily_closed',
  'reopens_at': reopensAt,
  'reopens_label': reopensLabel,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  group('la cuisine fermée dit jusqu\'à quand', () {
    test('fermée hors horaires : « Fermé — réouverture demain à 11 h 00 »', () {
      final cuisine = Restaurant.fromJson(_cuisine());

      expect(cuisine.reopensAt, DateTime.utc(2026, 9, 15, 11));
      expect(cuisine.statusLabel, 'Fermé — réouverture demain à 11 h 00');
    });

    test('fermeture exceptionnelle', () {
      final cuisine = Restaurant.fromJson(
        _cuisine(code: MotifIndisponibilite.cuisineFermeeExceptionnellement),
      );

      expect(cuisine.isTemporarilyClosed, isTrue);
      expect(cuisine.statusLabel, 'Fermé exceptionnellement — réouverture demain à 11 h 00');
    });

    test('ouverte, et sans réouverture connue', () {
      expect(Restaurant.fromJson(_cuisine(canOrderNow: true)).statusLabel, 'Ouvert');
      expect(
        Restaurant.fromJson(_cuisine(reopensAt: null, reopensLabel: '')).statusLabel,
        'Fermé',
      );
      expect(
        Restaurant.fromJson(_cuisine(code: MotifIndisponibilite.cuisineEnPause)).statusLabel,
        'Commandes en pause',
      );
    });

    test('un serveur antérieur reste lisible', () {
      final ancien = Map<String, dynamic>.of(_cuisine())
        ..remove('reopens_at')
        ..remove('reopens_label')
        ..remove('is_temporarily_closed');

      final cuisine = Restaurant.fromJson(ancien);

      expect(cuisine.reopensAt, isNull);
      expect(cuisine.isTemporarilyClosed, isFalse);
      expect(cuisine.statusLabel, 'Fermé');
    });
  });

  group('supervision et rapport réseau', () {
    test('les filtres pays, ville et zone partent sous les noms du serveur', () async {
      final serveur = _Serveur({'count': 0, 'next': null, 'previous': null, 'results': <Object>[]});
      final depot = ManagedOrderRepository(apiClient: _client(serveur));

      await depot.listPage(
        countryIsoCode: 'CI',
        citySlug: 'abidjan',
        deliveryZoneId: 'zone-cocody',
        restaurantSlug: 'el-corazon-cocody',
      );
      await depot.listPage(countryIsoCode: '', citySlug: '');

      expect(serveur.requetes.first.queryParameters, containsPair('country__iso_code', 'CI'));
      expect(serveur.requetes.first.queryParameters, containsPair('city__slug', 'abidjan'));
      expect(serveur.requetes.first.queryParameters, containsPair('delivery_zone', 'zone-cocody'));
      // « Tous » vaut une valeur vide : elle n'est pas envoyée.
      expect(serveur.requetes.last.queryParameters.containsKey('country__iso_code'), isFalse);
      expect(serveur.requetes.last.queryParameters.containsKey('city__slug'), isFalse);
    });

    test('le rapport réseau se lit par étage', () async {
      final serveur = _Serveur([
        {
          'key': 'z1',
          'name': 'Cocody',
          'city': 'Abidjan',
          'country': 'CI',
          'currency': 'XOF',
          'orders_count': 4,
          'in_progress_count': 1,
          'delivered_count': 2,
          'cancelled_count': 1,
          'revenue_minor': 16800,
        },
      ]);
      final depot = ReportingRepository(apiClient: _client(serveur));

      final lignes = await depot.network(
        start: DateTime(2026, 9),
        end: DateTime(2026, 9, 30),
        level: 'zone',
        countryIsoCode: 'CI',
      );

      expect(serveur.requetes.single.path, endsWith('/analytics/reports/network/'));
      expect(serveur.requetes.single.queryParameters, containsPair('level', 'zone'));
      expect(serveur.requetes.single.queryParameters, containsPair('country', 'CI'));
      expect(lignes.single.name, 'Cocody');
      expect(lignes.single.revenueMinor, 16800);
      expect(lignes.single.cancellationRate, 0.25);
    });

    test('la commande garde sa géographie figée', () {
      final json = {
        'id': 'o1',
        'reference': 'EC000001',
        'restaurant': 'el-corazon-cocody',
        'restaurant_name': 'El Corazón Cocody',
        'country': 'CI',
        'city': 'Abidjan',
        'city_slug': 'abidjan',
        'delivery_zone': 'z1',
        'delivery_zone_name': 'Cocody',
        'status': 'pending',
        'allowed_transitions': <String>[],
        'subtotal': {'amount': '7400', 'currency': 'XOF'},
        'delivery_fee': {'amount': '1000', 'currency': 'XOF'},
        'discount': {'amount': '0', 'currency': 'XOF'},
        'total': {'amount': '8400', 'currency': 'XOF'},
        'payment_method': 'cash',
        'delivery_address_line': 'Riviera 2',
        'delivery_location': {'lat': 5.37, 'lon': -3.98},
        'recipient_name': 'Awa',
        'recipient_phone': '+2250700000099',
        'placed_at': '2026-09-14T12:00:00Z',
        'created_at': '2026-09-14T12:00:00Z',
        'updated_at': '2026-09-14T12:00:00Z',
      };

      final commande = Order.fromJson(json);
      final ancienne = Order.fromJson(
        Map<String, dynamic>.of(json)
          ..remove('country')
          ..remove('delivery_zone')
          ..remove('delivery_zone_name'),
      );

      expect(commande.countryIsoCode, 'CI');
      expect(commande.deliveryZoneId, 'z1');
      expect(commande.deliveryZoneName, 'Cocody');
      expect(ancienne.deliveryZoneId, isNull);
      expect(ancienne.deliveryZoneName, isEmpty);
    });
  });

  group('le livreur', () {
    Map<String, dynamic> course({Map<String, dynamic> extra = const {}}) => {
      'id': 'a1',
      'order': 'o1',
      'order_reference': 'EC000001',
      'restaurant_name': 'El Corazón Cocody',
      'pickup_location': {'lat': 5.36, 'lon': -3.99},
      'delivery_address_line': 'Riviera 2',
      'delivery_location': {'lat': 5.37, 'lon': -3.98},
      'recipient_name': 'Awa',
      'recipient_phone': '',
      'courier': {
        'id': 'c1',
        'full_name': 'Kouassi',
        'vehicle_type': 'motorcycle',
        'rating_average': '0.00',
        'rating_count': 0,
      },
      'status': 'offered',
      'allowed_transitions': ['accepted', 'declined'],
      'offered_at': '2026-09-14T12:00:00Z',
      'created_at': '2026-09-14T12:00:00Z',
      'updated_at': '2026-09-14T12:00:00Z',
      ...extra,
    };

    test('ce qu\'il encaisse, où il roule, ce qu\'il porte', () {
      final affectation = Assignment.fromJson(
        course(
          extra: {
            'delivery_instructions': 'Portail vert',
            'delivery_zone_name': 'Cocody',
            'city_name': 'Abidjan',
            'payment_method': 'cash',
            'order_total': {'amount': '8400', 'currency': 'XOF'},
            'amount_to_collect': {'amount': '8400', 'currency': 'XOF'},
            'items': [
              {'name': 'Poulet braisé', 'quantity': 2, 'options': ['Fort'], 'notes': ''},
            ],
          },
        ),
      );

      expect(affectation.collectsCash, isTrue);
      expect(affectation.amountToCollect!.amountMinor, 8400);
      expect(affectation.deliveryZoneName, 'Cocody');
      expect(affectation.deliveryInstructions, 'Portail vert');
      expect(affectation.items.single.label, '2 × Poulet braisé (Fort)');
    });

    test('une course d\'un serveur antérieur reste lisible, sans rien à encaisser', () {
      final affectation = Assignment.fromJson(course());

      expect(affectation.collectsCash, isFalse);
      expect(affectation.items, isEmpty);
      expect(affectation.deliveryZoneName, isEmpty);
    });

    test('les zones du dossier, et leur affectation', () async {
      final dossier = {
        'id': 'c1',
        'full_name': 'Kouassi',
        'email': 'k@elcorazon.test',
        'restaurant': 'el-corazon-cocody',
        'service_zones': [
          {'id': 'z1', 'name': 'Cocody'},
        ],
        'verification_status': 'approved',
        'vehicle_type': 'motorcycle',
        'is_online': true,
        'can_accept_orders': true,
        'deliveries_completed': 0,
        'deliveries_cancelled': 0,
        'rating_average': '0.00',
        'rating_count': 0,
        'created_at': '2026-09-14T12:00:00Z',
        'updated_at': '2026-09-14T12:00:00Z',
      };
      final serveur = _Serveur(dossier);
      final depot = ManagedCourierRepository(apiClient: _client(serveur));

      final profil = await depot.setServiceZones(courierId: 'c1', zoneIds: ['z1']);

      expect(serveur.requetes.single.path, endsWith('/delivery/couriers/c1/zones/'));
      expect(serveur.requetes.single.data, {
        'zones': ['z1'],
      });
      expect(profil.serviceZones.single.name, 'Cocody');
    });
  });

  group('fermetures exceptionnelles', () {
    test('la création part en UTC, avec son motif', () async {
      final serveur = _Serveur({
        'id': 'f1',
        'restaurant': 'r1',
        'restaurant_name': 'El Corazón Cocody',
        'starts_at': '2026-12-25T00:00:00Z',
        'ends_at': '2026-12-26T00:00:00Z',
        'reason': 'Noël',
        'is_current': false,
        'created_at': '2026-09-14T12:00:00Z',
      });
      final depot = ManagedKitchenClosureRepository(apiClient: _client(serveur));

      final fermeture = await depot.create(
        restaurantId: 'r1',
        debut: DateTime(2026, 12, 25),
        fin: DateTime(2026, 12, 26),
        reason: '  Noël ',
      );

      final corps = serveur.requetes.single.data as Map<String, dynamic>;
      // **Heure murale**, sans fuseau : c'est le serveur qui la situe dans
      // celui de la cuisine. Envoyer un instant absolu — ce que faisait le
      // back-office depuis l'horloge du poste — fermait Douala à une heure du
      // matin quand le siège de Lomé saisissait minuit.
      expect(corps['starts_at_local'], '2026-12-25T00:00:00');
      expect(corps.containsKey('starts_at'), isFalse);
      expect(corps['reason'], 'Noël');
      expect(fermeture.reason, 'Noël');
      expect(fermeture.isPastAt(DateTime.utc(2026, 12, 27)), isTrue);
      expect(fermeture.isPastAt(DateTime.utc(2026, 12, 25, 12)), isFalse);
    });
  });
}
