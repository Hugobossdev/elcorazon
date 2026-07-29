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

/// Simule `/payments/*`.
class _FakeServer implements HttpClientAdapter {
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

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: _FakeServer(),
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
}
