import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _lineJson({String quantity = '1', String notes = ''}) {
  return {
    'id': 'line-1',
    'menu_item': 'item-1',
    'name': 'Cheeseburger',
    'image': null,
    'quantity': int.parse(quantity),
    'notes': notes,
    'options': <dynamic>[],
    'unit_price': {'amount': '2500', 'currency': 'XOF'},
    'total': {'amount': (2500 * int.parse(quantity)).toString(), 'currency': 'XOF'},
    'is_orderable': true,
    'unavailable_reason': '',
  };
}

Map<String, dynamic> _cartJson({List<Map<String, dynamic>> lines = const []}) {
  final total = lines.fold<int>(
    0,
    (sum, line) => sum + int.parse((line['total'] as Map<String, dynamic>)['amount'] as String),
  );
  return {
    'id': 'cart-1',
    'restaurant': 'el-corazon-lome',
    'restaurant_name': 'El Corazón',
    'currency': 'XOF',
    'lines': lines,
    'subtotal': {'amount': total.toString(), 'currency': 'XOF'},
    'is_orderable': lines.isNotEmpty,
    'updated_at': '2026-07-28T12:00:00Z',
  };
}

/// Simule `/carts/el-corazon-lome/*` : chaque route renvoie le panier entier
/// après écriture, comme le fait `CartViewSet._rendered` côté serveur.
class _FakeServer implements HttpClientAdapter {
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

    if (options.path.endsWith('/carts/el-corazon-lome/lines/') && options.method == 'POST') {
      final bytes = requestStream == null ? <int>[] : await _readAll(requestStream);
      final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return _jsonResponse(
        _cartJson(lines: [_lineJson(quantity: body['quantity'].toString(), notes: body['notes'] as String)]),
        201,
      );
    }

    if (options.path.contains('/lines/line-1/') && options.method == 'PATCH') {
      return _jsonResponse(_cartJson(lines: [_lineJson(quantity: '3')]), 200);
    }

    if (options.path.contains('/lines/line-1/') && options.method == 'DELETE') {
      return _jsonResponse(_cartJson(), 200);
    }

    if (options.path.endsWith('/carts/el-corazon-lome/lines/') && options.method == 'DELETE') {
      return _jsonResponse(_cartJson(), 200);
    }

    if (options.path.endsWith('/carts/el-corazon-lome/') && options.method == 'GET') {
      return _jsonResponse(_cartJson(lines: [_lineJson()]), 200);
    }

    throw UnimplementedError('Route non simulée : ${options.method} ${options.path}');
  }

  static Future<List<int>> _readAll(Stream<Uint8List> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  ResponseBody _jsonResponse(Map<String, dynamic> body, int status) {
    return ResponseBody.fromString(jsonEncode(body), status, headers: _jsonHeaders);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late CartRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    );
    repository = CartRepository(apiClient: apiClient);
  });

  group('CartRepository', () {
    test('getCart mappe le panier et ses lignes', () async {
      final cart = await repository.getCart(restaurantSlug: 'el-corazon-lome');

      expect(cart.restaurantSlug, 'el-corazon-lome');
      expect(cart.lines, hasLength(1));
      expect(cart.lines.single.unitPrice.amountMinor, 2500);
      expect(cart.subtotal.amountMinor, 2500);
    });

    test('addLine envoie toujours options: [] et renvoie le panier mis à jour', () async {
      final cart = await repository.addLine(
        restaurantSlug: 'el-corazon-lome',
        menuItemId: 'item-1',
        quantity: 2,
        notes: 'Sans oignon',
      );

      expect(cart.lines.single.quantity, 2);
      expect(server.requests, contains('POST /carts/el-corazon-lome/lines/'));
    });

    test('setQuantity appelle PATCH sur la ligne', () async {
      final cart = await repository.setQuantity(
        restaurantSlug: 'el-corazon-lome',
        lineId: 'line-1',
        quantity: 3,
      );

      expect(cart.lines.single.quantity, 3);
      expect(server.requests, contains('PATCH /carts/el-corazon-lome/lines/line-1/'));
    });

    test('removeLine appelle DELETE sur la ligne', () async {
      await repository.removeLine(restaurantSlug: 'el-corazon-lome', lineId: 'line-1');

      expect(server.requests, contains('DELETE /carts/el-corazon-lome/lines/line-1/'));
    });

    test('clear appelle DELETE sur la collection de lignes', () async {
      final cart = await repository.clear(restaurantSlug: 'el-corazon-lome');

      expect(cart.lines, isEmpty);
      expect(server.requests, contains('DELETE /carts/el-corazon-lome/lines/'));
    });
  });
}
