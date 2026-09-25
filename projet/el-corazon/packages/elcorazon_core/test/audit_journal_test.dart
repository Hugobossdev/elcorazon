import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le journal des décisions, lu depuis le back-office.
///
/// Il était écrit et lisible nulle part. Ces tests gardent ce que le dépôt
/// demande — une famille d'actions, une période — et ce qu'une entrée dit de
/// ce qui a changé.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

class _FakeServer implements HttpClientAdapter {
  final List<Map<String, dynamic>> queries = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    queries.add(Map<String, dynamic>.from(options.queryParameters));
    return ResponseBody.fromString(
      jsonEncode({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [
          {
            'id': 'entree-1',
            'actor': 'siege-1',
            'actor_name': 'Awa K.',
            'action': 'role.permissions',
            'target_type': 'role',
            'target_id': 'role-1',
            'target_label': 'Caisse',
            'before': {
              'permissions': ['orders.read'],
            },
            'after': {
              'permissions': ['orders.read', 'orders.refund'],
            },
            'created_at': '2026-09-18T09:00:00Z',
          },
        ],
      }),
      200,
      headers: _jsonHeaders,
    );
  }
}

AuditJournalRepository _depot(_FakeServer server) => AuditJournalRepository(
      apiClient: ApiClient(
        baseUrl: 'http://test.local/api/v1',
        tokenStorage: TokenStorage(),
        testAdapter: server,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  test('une famille part en préfixe, une période en bornes', () async {
    final server = _FakeServer();

    await _depot(server).entries(
      famille: 'staff.',
      depuis: DateTime.utc(2026, 9),
      jusqua: DateTime.utc(2026, 9, 18),
    );

    final requete = server.queries.single;
    expect(requete['action__startswith'], 'staff.');
    expect(requete['created_at__gte'], '2026-09-01T00:00:00.000Z');
    expect(requete['created_at__lte'], isNotNull);
  });

  test('une entrée dit ce qui a changé, et qui l’a changé', () async {
    final page = await _depot(_FakeServer()).entries();

    final entree = page.results.single;
    expect(entree.actorName, 'Awa K.');
    expect(entree.clesModifiees, ['permissions']);
    expect(FamilleAudit.libelle(entree.action), 'Permissions d’un rôle');
  });

  test('ce qui n’a pas bougé n’est pas signalé comme modifié', () {
    final entree = AuditRecord.fromJson({
      'id': 'x',
      'actor_name': null,
      'action': 'restaurant.location',
      'target_type': 'restaurant',
      'target_id': 'r-1',
      'target_label': 'El Corazón Lomé',
      'before': {'location': [1.0, 6.0], 'address': 'Rue A'},
      'after': {'location': [1.1, 6.1], 'address': 'Rue A'},
      'created_at': '2026-09-18T09:00:00Z',
    });

    expect(entree.clesModifiees, ['location']);
    expect(entree.actorName, isNull);
  });

  test('toute action du serveur a un libellé — aucune ne s’affiche brute', () {
    // Le registre `AuditAction` de `backend/common/audit.py`, au 2026-09-25.
    const actionsDuServeur = [
      'restaurant.create', 'restaurant.status', 'restaurant.location', 'restaurant.zone',
      'zone.create', 'zone.boundary', 'zone.tariff', 'zone.activation', 'zone.delete',
      'country.activation',
      'role.permissions', 'staff.roles', 'staff.scope', 'staff.activation', 'staff.password',
      'customer.block', 'review.visibility', 'payout.settle', 'payout.reject',
      'refund.request', 'refund.settle', 'refund.cancel', 'complaint.decision',
      'return.decision', 'ticket.resolution', 'courier.verification',
    ];

    for (final action in actionsDuServeur) {
      expect(FamilleAudit.libelle(action), isNot(action), reason: action);
    }
  });

  test('l’argent qui sort se filtre comme une famille', () {
    expect(FamilleAudit.familles.keys, containsAll(['refund.', 'payout.']));
  });
}
