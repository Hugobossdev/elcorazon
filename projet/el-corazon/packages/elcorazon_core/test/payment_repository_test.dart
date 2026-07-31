import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _transactionJson({String status = 'processing'}) {
  return {
    'id': 'txn-1',
    'order': 'order-1',
    'provider': 'paydunya',
    'provider_reference': 'SBX-ABC123',
    'amount': {'amount': '3000', 'currency': 'XOF'},
    'status': status,
    'completed_at': status == 'completed' ? '2026-07-28T12:05:00Z' : null,
    'failure_reason': status == 'failed' ? 'Fonds insuffisants' : '',
    'created_at': '2026-07-28T12:00:00Z',
    'updated_at': '2026-07-28T12:00:00Z',
  };
}

Map<String, dynamic> _shareJson({
  String id = 'share-1',
  String name = 'Ama',
  String amount = '1500',
  String status = 'pending',
}) {
  return {
    'id': id,
    'display_name': name,
    'phone': '+22890111111',
    'amount': {'amount': amount, 'currency': 'XOF'},
    'status': status,
    'share_token': 'tok-$id',
    'created_at': '2026-07-28T12:00:00Z',
  };
}

Map<String, dynamic> _splitJson() {
  return {
    'id': 'split-1',
    'order': 'order-1',
    'order_reference': 'EC000001',
    'total_amount': {'amount': '3000', 'currency': 'XOF'},
    'status': 'pending',
    'shares': [
      _shareJson(status: 'paid'),
      _shareJson(id: 'share-2', name: 'Kodjo'),
    ],
    'created_at': '2026-07-28T12:00:00Z',
  };
}

/// Simule `/payments/*`.
class _FakeServer implements HttpClientAdapter {
  final List<Object?> bodies = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/payments/order-1/initiate/') && options.method == 'POST') {
      return ResponseBody.fromString(
        jsonEncode({
          'transaction': _transactionJson(),
          'checkout_url': 'https://sandbox.elcorazon.app/checkout/txn-1',
          'instructions': 'Bac à sable : confirmez par une notification signée.',
        }),
        201,
        headers: _jsonHeaders,
      );
    }

    if (options.path.contains('/payments/order-1/split/')) {
      bodies.add(options.data);
      return ResponseBody.fromString(
        jsonEncode(_splitJson()),
        options.method == 'POST' ? 201 : 200,
        headers: _jsonHeaders,
      );
    }

    if (options.path.contains('/payments/shares/tok-share-1/')) {
      if (options.method == 'POST') {
        return ResponseBody.fromString(
          jsonEncode({
            'share': _shareJson(),
            'checkout_url': 'https://sandbox.elcorazon.app/checkout/share-1',
            'instructions': 'Composez #144#.',
          }),
          201,
          headers: _jsonHeaders,
        );
      }
      return ResponseBody.fromString(jsonEncode(_shareJson()), 200, headers: _jsonHeaders);
    }

    if (options.path.contains('/payments/transactions/') && options.method == 'GET') {
      return ResponseBody.fromString(
        jsonEncode({
          'count': 1,
          'next': null,
          'previous': null,
          'results': [_transactionJson(status: 'completed')],
        }),
        200,
        headers: _jsonHeaders,
      );
    }

    throw UnimplementedError('Route non simulée : ${options.method} ${options.path}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PaymentRepository repository;
  late _FakeServer server;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    );
    repository = PaymentRepository(apiClient: apiClient);
  });

  group('PaymentRepository', () {
    test('initiate mappe la transaction et l\'instruction de paiement', () async {
      final checkout = await repository.initiate('order-1');

      expect(checkout.checkoutUrl, 'https://sandbox.elcorazon.app/checkout/txn-1');
      expect(checkout.transaction.status, 'processing');
      expect(checkout.transaction.amount.amountMinor, 3000);
    });

    test('getTransactions mappe l\'historique filtré par commande', () async {
      final transactions = await repository.getTransactions(orderId: 'order-1');

      expect(transactions, hasLength(1));
      expect(transactions.single.isCompleted, isTrue);
    });
  });

  group('PaymentRepository — partage', () {
    test('createSplit envoie les convives sans montant quand la part est égale', () async {
      await repository.createSplit(
        orderId: 'order-1',
        participants: const [
          SplitParticipantInput(displayName: 'Ama'),
          SplitParticipantInput(displayName: 'Kodjo', phone: '+22890111112'),
        ],
      );

      final body = server.bodies.last! as Map<String, dynamic>;
      final participants = body['participants']! as List<dynamic>;
      expect(participants, hasLength(2));
      // Aucun montant déclaré : le serveur répartit sans perdre d'unité mineure.
      expect((participants.first as Map)['amount'], isNull);
      expect((participants.last as Map)['phone'], '+22890111112');
    });

    test('un convive sans compte est accepté', () {
      const invite = SplitParticipantInput(displayName: 'Voisin');

      expect(invite.toJson().containsKey('user'), isFalse);
    });

    test('getSplit agrège ce qui est déjà réglé', () async {
      final split = await repository.getSplit('order-1');

      expect(split.shares, hasLength(2));
      expect(split.paidCount, 1);
      expect(split.paidAmount.amountMinor, 1500);
      expect(split.totalAmount.amountMinor, 3000);
    });

    test('getShare lit une part par son jeton, sans compte', () async {
      final share = await repository.getShare('tok-share-1');

      expect(share.displayName, 'Ama');
      expect(share.amount.amountMinor, 1500);
      expect(share.isPaid, isFalse);
    });

    test('payShare ouvre le règlement sans solder la part', () async {
      final checkout = await repository.payShare('tok-share-1');

      expect(checkout.checkoutUrl, 'https://sandbox.elcorazon.app/checkout/share-1');
      // La part reste `pending` : seul le webhook du prestataire la solde.
      expect(checkout.share.isPaid, isFalse);
    });
  });
}
