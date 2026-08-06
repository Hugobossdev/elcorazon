import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _optionJson(String id, String name, String delta, String group) {
  return {
    'id': id,
    'name': name,
    'price_delta': {'amount': delta, 'currency': 'XOF'},
    'group': group,
  };
}

Map<String, dynamic> _lineJson({
  String quantity = '1',
  String notes = '',
  List<Map<String, dynamic>> options = const [],
}) {
  final supplements = options.fold<int>(
    0,
    (sum, option) =>
        sum + int.parse((option['price_delta'] as Map<String, dynamic>)['amount'] as String),
  );
  final unit = 2500 + supplements;
  return {
    'id': 'line-1',
    'menu_item': 'item-1',
    'name': 'Cheeseburger',
    'image': null,
    'quantity': int.parse(quantity),
    'notes': notes,
    'options': options,
    'unit_price': {'amount': unit.toString(), 'currency': 'XOF'},
    'total': {'amount': (unit * int.parse(quantity)).toString(), 'currency': 'XOF'},
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

/// Catalogue minimal du serveur simulé — c'est lui qui connaît le nom et le
/// supplément d'une option, jamais le client (invariant C1).
const _catalogue = {
  'option-bacon': ['Bacon', '500', 'Suppléments'],
  'option-cuisson': ['À point', '0', 'Cuisson'],
};

/// Simule `/carts/el-corazon-lome/*` : chaque route renvoie le panier entier
/// après écriture, comme le fait `CartViewSet._rendered` côté serveur.
class _FakeServer implements HttpClientAdapter {
  final List<String> requests = [];

  /// Corps du dernier POST de ligne — pour vérifier ce que le client envoie.
  Map<String, dynamic>? lastAddLineBody;

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
      lastAddLineBody = body;

      // Le serveur ne renvoie pas les identifiants reçus tels quels : il les
      // résout au catalogue et rend nom, groupe et supplément.
      final selected = (body['options'] as List<dynamic>? ?? const [])
          .map((id) => _catalogue[id]!)
          .toList();

      return _jsonResponse(
        _cartJson(
          lines: [
            _lineJson(
              quantity: body['quantity'].toString(),
              notes: body['notes'] as String,
              options: [
                for (var index = 0; index < selected.length; index++)
                  _optionJson(
                    (body['options'] as List<dynamic>)[index] as String,
                    selected[index][0],
                    selected[index][1],
                    selected[index][2],
                  ),
              ],
            ),
          ],
        ),
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

    test('addLine sans option envoie une liste vide', () async {
      final cart = await repository.addLine(
        restaurantSlug: 'el-corazon-lome',
        menuItemId: 'item-1',
        quantity: 2,
        notes: 'Sans oignon',
      );

      expect(cart.lines.single.quantity, 2);
      expect(cart.lines.single.options, isEmpty);
      expect(server.lastAddLineBody!['options'], isEmpty);
      expect(server.requests, contains('POST /carts/el-corazon-lome/lines/'));
    });

    test('addLine transmet les identifiants d’options retenus', () async {
      await repository.addLine(
        restaurantSlug: 'el-corazon-lome',
        menuItemId: 'item-1',
        quantity: 1,
        optionIds: const ['option-bacon', 'option-cuisson'],
      );

      // Des identifiants, et rien d'autre : ni nom ni supplément. Le prix
      // d'une option se décide au serveur (invariant C1) ; l'envoyer d'ici
      // laisserait le client fixer ce qu'il paie.
      expect(server.lastAddLineBody!['options'], ['option-bacon', 'option-cuisson']);
      expect(server.lastAddLineBody!.containsKey('price'), isFalse);
    });

    test('les options rendues portent le prix et le groupe du serveur', () async {
      final cart = await repository.addLine(
        restaurantSlug: 'el-corazon-lome',
        menuItemId: 'item-1',
        quantity: 1,
        optionIds: const ['option-bacon'],
      );

      final line = cart.lines.single;
      expect(line.options.single.name, 'Bacon');
      expect(line.options.single.groupName, 'Suppléments');
      expect(line.options.single.priceDelta.amountMinor, 500);
      // 2 500 de base + 500 de supplément : c'est le serveur qui l'a fait.
      expect(line.unitPrice.amountMinor, 3000);
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
