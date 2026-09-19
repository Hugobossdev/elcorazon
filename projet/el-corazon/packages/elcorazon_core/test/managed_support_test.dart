import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le support vu du personnel.
///
/// Les routes du support n'étaient ouvertes qu'aux clients : le back-office ne
/// pouvait ni lire un ticket ni y répondre. Ces tests gardent ce que le dépôt
/// envoie et ce qu'il lit — le fil, les décisions, et ce qui reste possible.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _ticketJson({List<Object> messages = const []}) => {
      'id': 'ticket-1',
      'user': 'client-1',
      'customer_name': 'Ama K.',
      'customer_email': 'ama@example.com',
      'customer_phone': '+22890000002',
      'category': 'payment',
      'subject': 'Débit en double',
      'description': 'Deux débits.',
      'attachments': <String>[],
      'status': 'in_progress',
      'resolution': '',
      'resolved_at': null,
      'messages_count': messages.length,
      'messages': messages,
      'created_at': '2026-09-18T09:00:00Z',
      'updated_at': '2026-09-18T09:00:00Z',
    };

Map<String, dynamic> _messageJson() => {
      'id': 'msg-1',
      'ticket': 'ticket-1',
      'author': {'id': 'agent-1', 'full_name': 'Awa K.', 'user_type': 'staff'},
      'content': 'Nous regardons.',
      'created_at': '2026-09-18T09:05:00Z',
    };

Map<String, dynamic> _retourJson(String status) => {
      'id': 'retour-1',
      'order': 'commande-1',
      'order_reference': 'EC000042',
      'order_total': {'amount': '4500', 'currency': 'XOF'},
      'restaurant_name': 'El Corazón Lomé',
      'customer_name': 'Ama K.',
      'customer_phone': null,
      'reason': 'Boisson manquante',
      'items': ['Bissap'],
      'refund_amount': {'amount': '500', 'currency': 'XOF'},
      'status': status,
      'resolution': '',
      'resolved_at': null,
      'created_at': '2026-09-18T09:00:00Z',
      'updated_at': '2026-09-18T09:00:00Z',
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
    if (options.path.endsWith('/reply/')) {
      corps = _messageJson();
    } else if (options.path == '/support/manage/tickets/ticket-1/') {
      corps = _ticketJson(messages: [_messageJson()]);
    } else if (options.path.contains('/returns/') && options.path.endsWith('/decide/')) {
      corps = _retourJson((options.data as Map)['status'] as String);
    } else {
      corps = {'count': 0, 'next': null, 'previous': null, 'results': <Object>[]};
    }
    return ResponseBody.fromString(
      jsonEncode(corps),
      options.path.endsWith('/reply/') ? 201 : 200,
      headers: _jsonHeaders,
    );
  }
}

ManagedSupportRepository _depot(_FakeServer server) => ManagedSupportRepository(
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

  test('la fiche d’un ticket porte son fil, auteur compris', () async {
    final ticket = await _depot(_FakeServer()).ticket('ticket-1');

    expect(ticket.messages.single.author.userType, 'staff');
    expect(ticket.enSouffrance, isTrue);
    expect(ticket.customerPhone, '+22890000002');
  });

  test('répondre envoie le seul contenu', () async {
    final server = _FakeServer();

    final message = await _depot(server).reply(ticketId: 'ticket-1', content: 'Nous regardons.');

    expect(server.requests.single, 'POST /support/manage/tickets/ticket-1/reply/');
    expect(server.bodies.single, {'content': 'Nous regardons.'});
    expect(message.content, 'Nous regardons.');
  });

  test('un retour ne propose que ce que le serveur acceptera', () async {
    final attente = ManagedReturn.fromJson(_retourJson('pending'));
    final approuve = ManagedReturn.fromJson(_retourJson('approved'));
    final refuse = ManagedReturn.fromJson(_retourJson('rejected'));

    // « Remboursé » ne se pose que sur un retour approuvé, et un refus est
    // définitif — la même table que `RETURN_TRANSITIONS`.
    expect(attente.decisionsPossibles, ['approved', 'rejected']);
    expect(approuve.decisionsPossibles, contains('refunded'));
    expect(refuse.decisionsPossibles, isEmpty);
  });

  test('décider d’un retour envoie statut et réponse', () async {
    final server = _FakeServer();

    final decide = await _depot(server).decideReturn(
      returnId: 'retour-1',
      status: 'rejected',
      resolution: 'La boisson figure au bon de sortie.',
    );

    expect(server.bodies.single, {
      'status': 'rejected',
      'resolution': 'La boisson figure au bon de sortie.',
    });
    expect(decide.status, 'rejected');
  });

  test('le client lit le motif d’un retour refusé', () {
    final retour = ReturnRequest.fromJson({
      'id': 'retour-1',
      'order': 'commande-1',
      'reason': 'Boisson manquante',
      'items': ['Bissap'],
      'refund_amount': {'amount': '500', 'currency': 'XOF'},
      'status': 'rejected',
      'resolution': 'La boisson figure au bon de sortie.',
      'resolved_at': '2026-09-18T10:00:00Z',
      'created_at': '2026-09-18T09:00:00Z',
    });

    expect(retour.resolution, 'La boisson figure au bon de sortie.');
    expect(retour.resolvedAt, isNotNull);
  });

  test('les libellés inconnus restent lisibles tels quels', () {
    expect(StatutSupport.ticket('open'), 'Ouvert');
    expect(StatutSupport.retour('inedit'), 'inedit');
  });
}
