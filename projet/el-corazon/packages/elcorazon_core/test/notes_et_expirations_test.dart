import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Notes internes (commande, client) et dates d'expiration des pièces livreur.
///
/// Trois exigences du cahier des charges que l'état des fonctionnalités cochait
/// ou croyait faites, et qu'aucune route ne portait.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _noteJson(String contenu) => {
      'id': 'note-1',
      'author_name': 'Awa K.',
      'content': contenu,
      'created_at': '2026-09-19T09:00:00Z',
    };

Map<String, dynamic> _dossierJson({String? permisExpireLe}) => {
      'id': 'livreur-1',
      'full_name': 'Kodjo M.',
      'email': 'kodjo@example.com',
      'restaurant': 'el-corazon-lome',
      'verification_status': 'approved',
      'vehicle_type': 'motorcycle',
      'is_online': false,
      'can_accept_orders': true,
      'deliveries_completed': 0,
      'deliveries_cancelled': 0,
      'rating_average': '0.00',
      'rating_count': 0,
      'licence_document_expires_on': permisExpireLe,
      'created_at': '2026-09-01T09:00:00Z',
      'updated_at': '2026-09-01T09:00:00Z',
    };

class _FakeServer implements HttpClientAdapter {
  final List<String> requests = [];
  final List<Object?> bodies = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    bodies.add(options.data);
    final Object corps;
    if (options.path.endsWith('/notes/') && options.method == 'GET') {
      corps = [_noteJson('Client rappelé.')];
    } else if (options.path.endsWith('/notes/')) {
      corps = _noteJson((options.data as Map)['content'] as String);
    } else {
      corps = _dossierJson(
        permisExpireLe: (options.data as Map?)?['licence_document_expires_on'] as String?,
      );
    }
    return ResponseBody.fromString(jsonEncode(corps), 200, headers: _jsonHeaders);
  }
}

ApiClient _client(_FakeServer server) => ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  group('Notes internes', () {
    test('celles d’une commande se lisent sous /orders/manage/', () async {
      final server = _FakeServer();

      final notes = await ManagedOrderRepository(apiClient: _client(server)).notes('commande-1');

      expect(server.requests.single, 'GET /orders/manage/commande-1/notes/');
      expect(notes.single.authorName, 'Awa K.');
    });

    test('celles d’un client s’ajoutent sous /administration/', () async {
      final server = _FakeServer();

      final note = await AdministrationRepository(apiClient: _client(server)).addCustomerNote(
        customerId: 'client-1',
        content: 'Litige ouvert.',
      );

      expect(server.requests.single, 'POST /administration/customers/client-1/notes/');
      expect(server.bodies.single, {'content': 'Litige ouvert.'});
      expect(note.content, 'Litige ouvert.');
    });
  });

  group('Expiration des pièces', () {
    test('la date part en jour civil, sans heure ni fuseau', () async {
      // Une date d'expiration est un jour, pas un instant : l'envoyer en UTC
      // la ferait reculer d'un jour à l'ouest de Greenwich.
      final server = _FakeServer();

      final dossier = await ManagedCourierRepository(apiClient: _client(server)).setVerification(
        courierId: 'livreur-1',
        status: 'approved',
        licenceDocumentExpiresOn: DateTime(2027, 3),
      );

      expect((server.bodies.single! as Map)['licence_document_expires_on'], '2027-03-01');
      expect(dossier.licenceDocumentExpiresOn, DateTime(2027, 3));
    });

    test('la prochaine échéance est la plus proche des dates connues', () {
      final dossier = CourierProfile.fromJson({
        ..._dossierJson(permisExpireLe: '2027-03-01'),
        'id_document_expires_on': '2026-12-31',
      });

      expect(dossier.prochaineExpiration, DateTime(2026, 12, 31));
    });

    test('un serveur antérieur au champ se lit sans date', () {
      final dossier = CourierProfile.fromJson(_dossierJson()..remove('licence_document_expires_on'));

      expect(dossier.prochaineExpiration, isNull);
    });
  });
}
