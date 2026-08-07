import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _ticketJson({String id = 'ticket-1', String status = 'open'}) {
  return {
    'id': id,
    'category': 'delivery',
    'subject': 'Commande jamais arrivée',
    'description': 'Le livreur ne s\'est pas présenté.',
    'attachments': <String>[],
    'status': status,
    'resolution': '',
    'resolved_at': null,
    'created_at': '2026-07-28T12:00:00Z',
  };
}

/// Simule `/support/*`, y compris la pagination du fil de messages : c'est le
/// seul endroit du contrat où deux pages sont réellement plausibles.
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
    requests.add('${options.method} ${options.uri.path}${_query(options)}');
    if (options.data != null) {
      bodies.add(options.data);
    }

    final path = options.uri.path;

    if (path.endsWith('/support/tickets/') && options.method == 'GET') {
      final status = options.uri.queryParameters['status'];
      return _json({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [_ticketJson(status: status ?? 'open')],
      }, 200,);
    }

    if (path.endsWith('/support/tickets/') && options.method == 'POST') {
      return _json(_ticketJson(), 201);
    }

    if (path.endsWith('/support/tickets/ticket-1/messages/') && options.method == 'GET') {
      final page = options.uri.queryParameters['page'];
      if (page == null) {
        return _json({
          'count': 2,
          'next': 'http://test.local/api/v1/support/tickets/ticket-1/messages/?page=2',
          'previous': null,
          'results': [_messageJson('message-1', 'customer', 'Bonjour, où est ma commande ?')],
        }, 200,);
      }
      return _json({
        'count': 2,
        'next': null,
        'previous': null,
        'results': [_messageJson('message-2', 'staff', 'Nous regardons cela tout de suite.')],
      }, 200,);
    }

    if (path.endsWith('/support/tickets/ticket-1/messages/') && options.method == 'POST') {
      return _json(_messageJson('message-3', 'customer', 'Merci.'), 201);
    }

    if (path.endsWith('/support/complaints/') && options.method == 'POST') {
      return _json({
        'id': 'complaint-1',
        'order': 'order-1',
        'kind': 'quality',
        'subject': 'Plat froid',
        'description': 'Le plat est arrivé froid.',
        'photos': ['https://minio.local/photo.jpg'],
        'status': 'pending',
        'resolution': '',
        'created_at': '2026-07-28T12:05:00Z',
      }, 201,);
    }

    if (path.endsWith('/support/returns/') && options.method == 'POST') {
      return _json({
        'id': 'return-1',
        'order': 'order-1',
        'reason': 'Article manquant',
        'items': ['Tacos poulet'],
        'refund_amount': {'amount': '2500', 'currency': 'XOF'},
        'status': 'pending',
        'created_at': '2026-07-28T12:10:00Z',
      }, 201,);
    }

    if (path.endsWith('/support/returns/') && options.method == 'GET') {
      return _json({'count': 0, 'next': null, 'previous': null, 'results': <dynamic>[]}, 200);
    }

    throw UnimplementedError('Route non simulée : ${options.method} $path');
  }

  Map<String, dynamic> _messageJson(String id, String userType, String content) {
    return {
      'id': id,
      'ticket': 'ticket-1',
      'author': {'id': 'user-1', 'full_name': 'Awa K.', 'user_type': userType},
      'content': content,
      'created_at': '2026-07-28T12:01:00Z',
    };
  }

  String _query(RequestOptions options) {
    final query = options.uri.query;
    return query.isEmpty ? '' : '?$query';
  }

  ResponseBody _json(Map<String, dynamic> body, int status) {
    return ResponseBody.fromString(jsonEncode(body), status, headers: _jsonHeaders);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late SupportRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    );
    repository = SupportRepository(apiClient: apiClient);
  });

  group('SupportRepository', () {
    test('getTickets mappe la liste et n\'envoie aucun identifiant client', () async {
      final tickets = await repository.getTickets();

      expect(tickets, hasLength(1));
      expect(tickets.single.category, 'delivery');
      expect(tickets.single.status, 'open');
      // Le cloisonnement est celui du serveur : rien dans la requête ne
      // désigne l'utilisateur, contrairement au `.eq('user_id', ...)` Supabase.
      expect(server.requests.single, 'GET /api/v1/support/tickets/');
    });

    test('getTickets passe le filtre de statut au serveur', () async {
      await repository.getTickets(status: 'resolved');

      expect(server.requests.single, 'GET /api/v1/support/tickets/?status=resolved');
    });

    test('openTicket envoie la catégorie telle quelle et mappe le ticket créé', () async {
      final ticket = await repository.openTicket(
        category: 'delivery',
        subject: 'Commande jamais arrivée',
        description: 'Le livreur ne s\'est pas présenté.',
      );

      expect(ticket.id, 'ticket-1');
      expect(server.bodies.single, containsPair('category', 'delivery'));
      expect(server.bodies.single, containsPair('attachments', <String>[]));
    });

    test('getMessages suit la pagination jusqu\'au bout', () async {
      final messages = await repository.getMessages('ticket-1');

      expect(messages, hasLength(2));
      expect(messages.first.author.isFromSupport, isFalse);
      expect(messages.last.author.isFromSupport, isTrue);
      expect(server.requests, [
        'GET /api/v1/support/tickets/ticket-1/messages/',
        'GET /api/v1/support/tickets/ticket-1/messages/?page=2',
      ]);
    });

    test('reply poste le seul contenu du message', () async {
      final message = await repository.reply(ticketId: 'ticket-1', content: 'Merci.');

      expect(message.id, 'message-3');
      expect(server.bodies.single, {'content': 'Merci.'});
    });

    test('fileComplaint désigne la commande, jamais son propriétaire', () async {
      final complaint = await repository.fileComplaint(
        orderId: 'order-1',
        kind: 'quality',
        subject: 'Plat froid',
        description: 'Le plat est arrivé froid.',
        photos: const ['https://minio.local/photo.jpg'],
      );

      expect(complaint.status, 'pending');
      final body = server.bodies.single! as Map<String, dynamic>;
      expect(body['order'], 'order-1');
      expect(body.containsKey('user'), isFalse);
    });

    test('requestReturn envoie un montant en unité mineure et en chaîne', () async {
      final demande = await repository.requestReturn(
        orderId: 'order-1',
        reason: 'Article manquant',
        items: const ['Tacos poulet'],
        refundAmount: const Money(amountMinor: 2500, currency: 'XOF'),
      );

      expect(demande.refundAmount.amountMinor, 2500);
      expect(demande.status, 'pending');
      final body = server.bodies.single! as Map<String, dynamic>;
      expect(body['refund_amount'], {'amount': '2500', 'currency': 'XOF'});
    });

    test('getReturns rend une liste vide sans erreur', () async {
      expect(await repository.getReturns(), isEmpty);
    });
  });
}
