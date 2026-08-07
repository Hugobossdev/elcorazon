import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _orderJson({String id = 'order-1', String status = 'pending'}) {
  return {
    'id': id,
    'reference': 'EC000001',
    'restaurant': 'el-corazon-lome',
    'restaurant_name': 'El Corazón',
    'status': status,
    'allowed_transitions': ['confirmed', 'cancelled'],
    'subtotal': {'amount': '2500', 'currency': 'XOF'},
    'delivery_fee': {'amount': '500', 'currency': 'XOF'},
    'discount': {'amount': '0', 'currency': 'XOF'},
    'total': {'amount': '3000', 'currency': 'XOF'},
    'payment_method': 'cash',
    'delivery_address_line': 'Rue des Cocotiers',
    'delivery_landmark': '',
    'delivery_location': {'lat': 6.1319, 'lon': 1.2255},
    'recipient_name': 'Cart Test',
    'recipient_phone': '+22890000000',
    'placed_at': '2026-07-28T12:00:00Z',
    'estimated_delivery_at': null,
    'delivered_at': null,
    'cancelled_at': null,
    'cancellation_reason': '',
    'created_at': '2026-07-28T12:00:00Z',
    'updated_at': '2026-07-28T12:00:00Z',
  };
}

/// Simule `/orders/*`.
class _FakeServer implements HttpClientAdapter {
  String? lastIdempotencyKey;
  Object? lastPreviewBody;
  final List<String> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');

    if (options.path.endsWith('/orders/preview/')) {
      lastPreviewBody = options.data;
      final promo = (options.data as Map<String, dynamic>)['promo_code'] as String;
      final remise = promo == 'BIENVENUE' ? 500 : 0;
      return _jsonResponse({
        'subtotal': {'amount': '2500', 'currency': 'XOF'},
        'delivery_fee': {'amount': '700', 'currency': 'XOF'},
        'discount': {'amount': '$remise', 'currency': 'XOF'},
        'total': {'amount': '${3200 - remise}', 'currency': 'XOF'},
        // Un code refusé ne rend pas de promotion : la remise est nulle *et*
        // le code est absent, ce qui les distingue.
        'promotion': remise == 0
            ? null
            : {
                'id': 'promo-1',
                'code': 'BIENVENUE',
                'description': '500 F sur la première commande',
                'kind': 'fixed',
              },
        'is_orderable': true,
      }, 200,);
    }

    if (options.path.endsWith('/orders/') && options.method == 'POST') {
      lastIdempotencyKey = options.headers['Idempotency-Key'] as String?;
      return _jsonResponse(_orderJson(), 201);
    }

    if (options.path.endsWith('/orders/') && options.method == 'GET') {
      return _jsonResponse({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [_orderJson()],
      }, 200,);
    }

    if (options.path.contains('/orders/order-1/cancel/')) {
      return _jsonResponse(_orderJson(status: 'cancelled'), 200);
    }

    if (options.path.contains('/orders/order-1/') && options.method == 'GET') {
      return _jsonResponse(_orderJson(), 200);
    }

    throw UnimplementedError('Route non simulée : ${options.method} ${options.path}');
  }

  ResponseBody _jsonResponse(Map<String, dynamic> body, int status) {
    return ResponseBody.fromString(jsonEncode(body), status, headers: _jsonHeaders);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late OrderRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    );
    repository = OrderRepository(apiClient: apiClient);
  });

  group('OrderRepository', () {
    test('create transmet Idempotency-Key et mappe la commande créée', () async {
      final order = await repository.create(
        restaurantSlug: 'el-corazon-lome',
        addressId: 'addr-1',
        paymentMethod: 'cash',
        idempotencyKey: 'idem-key-123',
      );

      expect(order.status, 'pending');
      expect(order.total.amountMinor, 3000);
      expect(server.lastIdempotencyKey, 'idem-key-123');
    });

    test('list mappe l\'historique', () async {
      final orders = await repository.list();

      expect(orders, hasLength(1));
      expect(orders.single.reference, 'EC000001');
    });

    test('getById récupère la forme détail', () async {
      final order = await repository.getById('order-1');

      expect(order.id, 'order-1');
    });

    test('preview rend la décomposition du serveur sans transmettre de montant', () async {
      final quote = await repository.preview(
        restaurantSlug: 'el-corazon-lome',
        addressId: 'addr-1',
        promoCode: 'BIENVENUE',
      );

      expect(quote.deliveryFee.amountMinor, 700);
      expect(quote.discount.amountMinor, 500);
      expect(quote.total.amountMinor, 2700);
      expect(quote.promotionCode, 'BIENVENUE');
      expect(quote.isOrderable, isTrue);

      // Le panier et ses montants ne montent pas : le serveur les relit
      // (invariants C1/C2).
      expect(server.lastPreviewBody, {
        'restaurant': 'el-corazon-lome',
        'address': 'addr-1',
        'promo_code': 'BIENVENUE',
      });
    });

    test('preview sans adresse n\'envoie pas de champ adresse', () async {
      final quote = await repository.preview(restaurantSlug: 'el-corazon-lome');

      expect((server.lastPreviewBody! as Map).containsKey('address'), isFalse);
      expect(quote.hasPromotion, isFalse);
      expect(quote.isDeliveryFree, isFalse);
    });

    test('cancel appelle POST .../cancel/', () async {
      final order = await repository.cancel('order-1', reason: 'changement d\'avis');

      expect(order.status, 'cancelled');
      expect(server.requests, contains('POST /orders/order-1/cancel/'));
    });
  });
}
