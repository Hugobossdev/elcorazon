import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _assignmentJson({
  String id = 'assign-1',
  String status = 'offered',
  Map<String, dynamic>? courierFee,
}) {
  return {
    'id': id,
    'order': 'order-1',
    'order_reference': 'EC000001',
    'restaurant_name': 'El Corazón',
    'pickup_location': {'lat': 6.1725, 'lon': 1.2314},
    'delivery_address_line': 'Rue des Cocotiers',
    'delivery_landmark': 'Face à la pharmacie',
    'delivery_location': {'lat': 6.1319, 'lon': 1.2255},
    'recipient_name': 'Ama K.',
    'recipient_phone': '+22890000000',
    'courier': {
      'id': 'courier-1',
      'full_name': 'Kofi A.',
      'avatar': null,
      'vehicle_type': 'moto',
      'rating_average': '4.75',
      'rating_count': 12,
    },
    'status': status,
    'allowed_transitions': status == 'offered'
        ? ['accepted', 'cancelled', 'declined']
        : ['picked_up'],
    'courier_fee': courierFee,
    'offered_at': '2026-07-29T10:00:00Z',
    'accepted_at': status == 'offered' ? null : '2026-07-29T10:01:00Z',
    'picked_up_at': null,
    'delivered_at': null,
    'decline_reason': '',
    'created_at': '2026-07-29T10:00:00Z',
    'updated_at': '2026-07-29T10:00:00Z',
  };
}

Map<String, dynamic> _courierJson({bool isOnline = false, String verification = 'approved'}) {
  return {
    'id': 'courier-1',
    'full_name': 'Kofi A.',
    'email': 'kofi@example.test',
    'restaurant': 'el-corazon-lome',
    'verification_status': verification,
    'verification_notes': '',
    'verified_at': '2026-07-20T08:00:00Z',
    'vehicle_type': 'moto',
    'vehicle_plate': 'TG-1234',
    'is_online': isOnline,
    // L1 : le serveur décide de l'éligibilité. Le test la met délibérément en
    // désaccord avec `is_online` pour vérifier que le client la lit au lieu de
    // la recalculer.
    'can_accept_orders': false,
    'last_location': {'lat': 6.14, 'lon': 1.22},
    'last_location_at': '2026-07-29T09:59:00Z',
    'deliveries_completed': 42,
    'deliveries_cancelled': 1,
    'rating_average': '4.80',
    'rating_count': 30,
    'total_earnings': {'amount': '125000', 'currency': 'XOF'},
    'created_at': '2026-07-01T08:00:00Z',
    'updated_at': '2026-07-29T09:59:00Z',
  };
}

/// Simule `/delivery/*`.
class _FakeServer implements HttpClientAdapter {
  final List<String> requests = [];
  final List<Map<String, dynamic>> bodies = [];
  final List<Map<String, dynamic>> queries = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    queries.add(Map<String, dynamic>.from(options.queryParameters));
    if (options.data is Map) {
      bodies.add(Map<String, dynamic>.from(options.data as Map));
    }

    if (options.path.endsWith('/delivery/me/online/')) {
      final asked = (options.data as Map)['is_online'] as bool;
      return _json(_courierJson(isOnline: asked), 200);
    }

    if (options.path.endsWith('/delivery/me/')) {
      return _json(_courierJson(), 200);
    }

    if (options.path.endsWith('/accept/')) {
      return _json(
        _assignmentJson(
          status: 'accepted',
          courierFee: {'amount': '750', 'currency': 'XOF'},
        ),
        200,
      );
    }

    if (options.path.endsWith('/decline/')) {
      return _json(_assignmentJson(status: 'declined'), 200);
    }

    if (options.path.endsWith('/status/')) {
      final target = (options.data as Map)['status'] as String;
      return _json(_assignmentJson(status: target), 200);
    }

    if (options.path.endsWith('/delivery/assignments/')) {
      final status = options.queryParameters['status'] as String?;
      // Le serveur ne connaît que `exact` sur `status` : une seule étape par
      // requête, ce que reflète cette simulation.
      final results = switch (status) {
        'offered' => [_assignmentJson()],
        'accepted' => [_assignmentJson(id: 'assign-2', status: 'accepted')],
        'picked_up' => [_assignmentJson(id: 'assign-3', status: 'picked_up')],
        'on_the_way' => <Map<String, dynamic>>[],
        _ => [_assignmentJson()],
      };
      return _json({'count': results.length, 'next': null, 'previous': null, 'results': results}, 200);
    }

    if (options.path.contains('/delivery/assignments/assign-1/')) {
      return _json(_assignmentJson(), 200);
    }

    throw UnimplementedError('Route non simulée : ${options.method} ${options.path}');
  }

  ResponseBody _json(Map<String, dynamic> body, int status) {
    return ResponseBody.fromString(jsonEncode(body), status, headers: _jsonHeaders);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late DeliveryRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    );
    repository = DeliveryRepository(apiClient: apiClient);
  });

  group('DeliveryRepository — dossier', () {
    test('me mappe le dossier complet', () async {
      final courier = await repository.me();

      expect(courier.fullName, 'Kofi A.');
      expect(courier.restaurantSlug, 'el-corazon-lome');
      expect(courier.deliveriesCompleted, 42);
      expect(courier.ratingAverage, 4.80);
      expect(courier.totalEarnings?.amountMinor, 125000);
      expect(courier.lastLatitude, 6.14);
    });

    test('setOnline lit can_accept_orders du serveur, ne le déduit pas', () async {
      final courier = await repository.setOnline(isOnline: true);

      expect(courier.isOnline, isTrue);
      // L1 — passer en ligne ne rend pas éligible à soi seul : le serveur tient
      // aussi compte du dossier et de l'activité du compte.
      expect(courier.canAcceptOrders, isFalse);
      expect(server.bodies.last, {'is_online': true});
    });
  });

  group('DeliveryRepository — courses', () {
    test('pendingOffers ne demande que les courses proposées', () async {
      final offers = await repository.pendingOffers();

      expect(offers, hasLength(1));
      expect(offers.single.status, DeliveryStatus.offered);
      expect(offers.single.orderReference, 'EC000001');
      expect(offers.single.pickupLatitude, 6.1725);
      expect(offers.single.deliveryLandmark, 'Face à la pharmacie');
      // Rien n'est dû tant que la course n'est pas acceptée.
      expect(offers.single.courierFee, isNull);
      expect(server.queries.last['status'], 'offered');
    });

    test('activeAssignments interroge chaque étape engagée séparément', () async {
      final active = await repository.activeAssignments();

      expect(
        server.queries.map((query) => query['status']),
        containsAll(<String>['accepted', 'picked_up', 'on_the_way']),
      );
      expect(active.map((assignment) => assignment.id), ['assign-2', 'assign-3']);
      expect(active.every((assignment) => assignment.isActive), isTrue);
    });

    test('accept fige la rémunération rendue par le serveur', () async {
      final assignment = await repository.accept('assign-1');

      expect(assignment.status, DeliveryStatus.accepted);
      expect(assignment.courierFee?.amountMinor, 750);
      expect(assignment.acceptedAt, isNotNull);
      expect(server.requests, contains('POST /delivery/assignments/assign-1/accept/'));
    });

    test('decline transmet le motif', () async {
      final assignment = await repository.decline('assign-1', reason: 'trop loin');

      expect(assignment.status, DeliveryStatus.declined);
      expect(server.bodies.last['reason'], 'trop loin');
    });

    test('transitionTo poste l\'étape visée et rien d\'autre', () async {
      final assignment = await repository.transitionTo('assign-1', DeliveryStatus.pickedUp);

      expect(assignment.status, DeliveryStatus.pickedUp);
      expect(server.requests, contains('POST /delivery/assignments/assign-1/status/'));
      // C4 — le client ne projette jamais le statut de la commande : cette
      // charge ne porte que l'étape de la course.
      expect(server.bodies.last.keys, unorderedEquals(<String>['status', 'reason']));
    });

    test('allowed_transitions vient du serveur, la machine n\'est pas rejouée ici', () async {
      final assignment = await repository.getById('assign-1');

      expect(assignment.allowedTransitions, containsAll(<String>['accepted', 'declined']));
    });
  });
}
