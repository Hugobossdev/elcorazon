import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ce dépôt apporte au back-office : **qui porte quelle commande**.
///
/// L'information n'existait nulle part côté personnel. `Order` ne la porte pas
/// et ne la portera pas — `apps.orders` ne dépend pas d'`apps.delivery` — si
/// bien que trois écrans affichaient un livreur vide sans que rien n'échoue.
/// Les tests portent donc sur le rapprochement commande → livreur, et sur le
/// tri entre la course vivante et celles qui ont été refusées avant elle.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _assignmentJson({
  required String id,
  required String orderId,
  required String status,
  String courierId = 'courier-1',
  String courierName = 'Kofi A.',
}) {
  return {
    'id': id,
    'order': orderId,
    'order_reference': 'EC000001',
    'restaurant_name': 'El Corazón',
    'pickup_location': {'lat': 6.1725, 'lon': 1.2314},
    'delivery_address_line': 'Rue des Cocotiers',
    'delivery_landmark': '',
    'delivery_location': {'lat': 6.1319, 'lon': 1.2255},
    'recipient_name': 'Ama K.',
    'recipient_phone': '+22890000000',
    'courier': {
      'id': courierId,
      'full_name': courierName,
      'avatar': null,
      'vehicle_type': 'moto',
      'rating_average': '4.75',
      'rating_count': 12,
    },
    'status': status,
    'allowed_transitions': const <String>[],
    'courier_fee': null,
    'offered_at': '2026-07-29T10:00:00Z',
    'accepted_at': null,
    'picked_up_at': null,
    'delivered_at': null,
    'decline_reason': '',
    'created_at': '2026-07-29T10:00:00Z',
    'updated_at': '2026-07-29T10:00:00Z',
  };
}

/// Simule `/delivery/manage/assignments/`, pagination comprise : c'est la seule
/// façon de vérifier que le dépôt suit `next` au lieu de s'arrêter à la
/// première page — un back-office qui ne verrait que les vingt premières
/// courses afficherait « sans livreur » sur toutes les autres.
class _FakeServer implements HttpClientAdapter {
  _FakeServer({this.paginee = false});

  final bool paginee;
  final List<String> requests = [];
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

    if (options.method != 'GET' || !options.path.contains('/delivery/manage/assignments/')) {
      throw UnimplementedError('Route non simulée : ${options.method} ${options.path}');
    }

    final orderFiltre = options.queryParameters['order'] as String?;
    final page2 = options.path.contains('page=2');

    if (page2) {
      return _json({
        'count': 3,
        'next': null,
        'previous': null,
        'results': [
          _assignmentJson(
            id: 'assign-3',
            orderId: 'order-2',
            status: 'on_the_way',
            courierId: 'courier-2',
            courierName: 'Ama D.',
          ),
        ],
      });
    }

    final toutes = [
      // Une course refusée **avant** la course vivante de la même commande :
      // le dépôt doit rendre la seconde, pas la première trouvée.
      _assignmentJson(id: 'assign-0', orderId: 'order-1', status: 'declined'),
      _assignmentJson(id: 'assign-1', orderId: 'order-1', status: 'accepted'),
    ];
    final results = orderFiltre == null
        ? toutes
        : toutes.where((ligne) => ligne['order'] == orderFiltre).toList();

    return _json({
      'count': results.length,
      'next': paginee && orderFiltre == null
          ? 'http://test.local/api/v1/delivery/manage/assignments/?page=2'
          : null,
      'previous': null,
      'results': results,
    });
  }

  ResponseBody _json(Map<String, dynamic> body) =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: _jsonHeaders);
}

ManagedAssignmentRepository _depot(_FakeServer server) {
  return ManagedAssignmentRepository(
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

  group('Qui porte cette commande', () {
    test('la course vivante est celle qui est rendue, pas la première venue', () async {
      final server = _FakeServer();

      final course = await _depot(server).activeFor('order-1');

      expect(course, isNotNull);
      expect(course!.id, 'assign-1');
      expect(course.courier.fullName, 'Kofi A.');
    });

    test('le filtre part au serveur plutôt que de tout charger', () async {
      final server = _FakeServer();

      await _depot(server).activeFor('order-1');

      expect(server.queries.single['order'], 'order-1');
    });

    test('une commande sans course rend null, et non une erreur', () async {
      final server = _FakeServer();

      expect(await _depot(server).activeFor('order-inconnue'), isNull);
    });
  });

  group('Les courses vivantes du périmètre', () {
    test('sont rangées par commande, les terminées écartées', () async {
      final server = _FakeServer(paginee: true);

      final parCommande = await _depot(server).activeByOrder();

      expect(parCommande.keys, containsAll(['order-1', 'order-2']));
      expect(parCommande['order-1']!.id, 'assign-1');
      expect(parCommande['order-2']!.courier.fullName, 'Ama D.');
    });

    test('la pagination est suivie jusqu’au bout', () async {
      final server = _FakeServer(paginee: true);

      await _depot(server).activeByOrder();

      expect(server.requests.length, 2);
    });
  });
}
