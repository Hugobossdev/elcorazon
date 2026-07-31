import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

const _hostId = '11111111-1111-1111-1111-111111111111';
const _guestId = '22222222-2222-2222-2222-222222222222';

Map<String, dynamic> _groupCartJson({
  String status = 'open',
  bool acceptsContributions = true,
  String? order,
}) {
  return {
    'id': 'cart-1',
    'code': 'ABC123',
    'title': 'Déjeuner du bureau',
    'status': status,
    'restaurant': 'el-corazon-lome',
    'restaurant_name': 'El Corazón Lomé',
    'host': _hostId,
    'host_name': 'Ama Koffi',
    'closes_at': '2026-07-31T12:30:00Z',
    'accepts_contributions': acceptsContributions,
    'order': order,
    'members': [
      {'id': _hostId, 'full_name': 'Ama Koffi', 'joined_at': '2026-07-31T11:00:00Z'},
      {'id': _guestId, 'full_name': 'Kodjo Mensah', 'joined_at': '2026-07-31T11:05:00Z'},
    ],
    'lines': [
      {
        'id': 'line-1',
        'member': _hostId,
        'member_name': 'Ama Koffi',
        'menu_item': 'item-1',
        'name': 'Burger Corazón',
        'image': null,
        'quantity': 2,
        'notes': 'Sans oignon',
        'options': [
          {
            'id': 'option-1',
            'name': 'À point',
            'price_delta': {'amount': '0', 'currency': 'XOF'},
            'group': 'Cuisson',
          },
        ],
        'unit_price': {'amount': '3500', 'currency': 'XOF'},
        'total': {'amount': '7000', 'currency': 'XOF'},
        'is_orderable': true,
        'unavailable_reason': '',
      },
      {
        'id': 'line-2',
        'member': _guestId,
        'member_name': 'Kodjo Mensah',
        'menu_item': 'item-2',
        'name': 'Salade Corazón',
        'image': null,
        'quantity': 1,
        'notes': '',
        'options': <dynamic>[],
        'unit_price': {'amount': '2000', 'currency': 'XOF'},
        'total': {'amount': '2000', 'currency': 'XOF'},
        'is_orderable': false,
        'unavailable_reason': 'Article épuisé',
      },
    ],
    'per_member': [
      {
        'member': _hostId,
        'total': {'amount': '7000', 'currency': 'XOF'},
      },
      {
        'member': _guestId,
        'total': {'amount': '2000', 'currency': 'XOF'},
      },
    ],
    'currency': 'XOF',
    'subtotal': {'amount': '9000', 'currency': 'XOF'},
    'is_orderable': false,
    'updated_at': '2026-07-31T11:10:00Z',
  };
}

Map<String, dynamic> _orderJson() {
  return {
    'id': 'order-1',
    'reference': 'EC000042',
    'restaurant': 'el-corazon-lome',
    'restaurant_name': 'El Corazón Lomé',
    'status': 'pending',
    'allowed_transitions': ['confirmed', 'cancelled'],
    'subtotal': {'amount': '9000', 'currency': 'XOF'},
    'delivery_fee': {'amount': '500', 'currency': 'XOF'},
    'discount': {'amount': '0', 'currency': 'XOF'},
    'total': {'amount': '9500', 'currency': 'XOF'},
    'payment_method': 'mobile_money',
    'delivery_address_line': 'Rue du Commerce, Lomé',
    'delivery_landmark': '',
    'delivery_location': {'lat': 6.1319, 'lon': 1.2255},
    'recipient_name': 'Ama Koffi',
    'recipient_phone': '+22890111111',
    'placed_at': '2026-07-31T11:15:00Z',
    'estimated_delivery_at': null,
    'delivered_at': null,
    'cancelled_at': null,
    'cancellation_reason': '',
    'created_at': '2026-07-31T11:15:00Z',
    'updated_at': '2026-07-31T11:15:00Z',
  };
}

/// Simule `/group-carts/*`.
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

    if (options.path.endsWith('/group-carts/') && options.method == 'GET') {
      return _json([_groupCartJson()], 200);
    }
    if (options.path.endsWith('/group-carts/') && options.method == 'POST') {
      return _json(_groupCartJson(), 201);
    }
    if (options.path.endsWith('/group-carts/join/')) {
      return _json(_groupCartJson(), 200);
    }
    if (options.path.endsWith('/group-carts/cart-1/confirm/')) {
      return _json(_orderJson(), 201);
    }
    if (options.path.endsWith('/group-carts/cart-1/lock/')) {
      return _json(_groupCartJson(status: 'locked', acceptsContributions: false), 200);
    }
    if (options.path.endsWith('/group-carts/cart-1/cancel/')) {
      return _json(_groupCartJson(status: 'cancelled', acceptsContributions: false), 200);
    }
    if (options.path.contains('/group-carts/cart-1/lines')) {
      return _json(_groupCartJson(), options.method == 'POST' ? 201 : 200);
    }
    if (options.path.endsWith('/group-carts/cart-1/')) {
      return _json(_groupCartJson(), 200);
    }

    throw UnimplementedError('Route non simulée : ${options.method} ${options.path}');
  }

  ResponseBody _json(Object body, int status) {
    return ResponseBody.fromString(jsonEncode(body), status, headers: _jsonHeaders);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late GroupCartRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    repository = GroupCartRepository(
      apiClient: ApiClient(
        baseUrl: 'http://test.local/api/v1',
        tokenStorage: TokenStorage(),
        testAdapter: server,
      ),
    );
  });

  group('GroupCartRepository — lecture', () {
    test('list mappe les paniers du participant', () async {
      final carts = await repository.list();

      expect(carts, hasLength(1));
      expect(carts.single.code, 'ABC123');
      expect(carts.single.members, hasLength(2));
      expect(carts.single.lines, hasLength(2));
    });

    test('les totaux viennent du serveur, ils ne sont pas recalculés', () async {
      final cart = await repository.getById('cart-1');

      expect(cart.subtotal.amountMinor, 9000);
      expect(cart.totalFor(_hostId).amountMinor, 7000);
      expect(cart.totalFor(_guestId).amountMinor, 2000);
    });

    test('un participant sans ligne doit zéro, dans la devise du panier', () async {
      final cart = await repository.getById('cart-1');

      final inconnu = cart.totalFor('33333333-3333-3333-3333-333333333333');
      expect(inconnu.amountMinor, 0);
      expect(inconnu.currency, 'XOF');
    });

    test('une ligne non commandable reste visible et porte sa raison', () async {
      final cart = await repository.getById('cart-1');

      final epuisee = cart.lines.firstWhere((line) => !line.isOrderable);
      expect(epuisee.name, 'Salade Corazón');
      expect(epuisee.unavailableReason, 'Article épuisé');
      expect(cart.isOrderable, isFalse);
    });

    test('une option retenue porte son groupe', () async {
      final cart = await repository.getById('cart-1');

      final option = cart.lines.first.options.single;
      expect(option.name, 'À point');
      expect(option.groupName, 'Cuisson');
    });

    test('isHost distingue l\'hôte des invités', () async {
      final cart = await repository.getById('cart-1');

      expect(cart.isHost(_hostId), isTrue);
      expect(cart.isHost(_guestId), isFalse);
    });
  });

  group('GroupCartRepository — écriture', () {
    test('open n\'envoie ni statut ni code', () async {
      await repository.open(restaurantSlug: 'el-corazon-lome', title: 'Déjeuner');

      final body = server.bodies.last! as Map<String, dynamic>;
      expect(body['restaurant'], 'el-corazon-lome');
      expect(body.containsKey('status'), isFalse);
      expect(body.containsKey('code'), isFalse);
    });

    test('addLine n\'envoie pas d\'auteur : il vient du jeton', () async {
      await repository.addLine(
        groupCartId: 'cart-1',
        menuItemId: 'item-1',
        quantity: 2,
        notes: 'Sans oignon',
      );

      final body = server.bodies.last! as Map<String, dynamic>;
      expect(body['menu_item'], 'item-1');
      expect(body['quantity'], 2);
      expect(body.containsKey('member'), isFalse);
      expect(server.requests.last, 'POST /group-carts/cart-1/lines/');
    });

    test('setQuantity et removeLine ciblent la ligne dans son panier', () async {
      await repository.setQuantity(groupCartId: 'cart-1', lineId: 'line-1', quantity: 3);
      expect(server.requests.last, 'PATCH /group-carts/cart-1/lines/line-1/');

      await repository.removeLine(groupCartId: 'cart-1', lineId: 'line-1');
      expect(server.requests.last, 'DELETE /group-carts/cart-1/lines/line-1/');
    });

    test('join envoie le code seul', () async {
      final cart = await repository.join('ABC123');

      expect(cart.id, 'cart-1');
      expect(server.bodies.last, {'code': 'ABC123'});
    });

    test('lock ferme les contributions', () async {
      final cart = await repository.lock('cart-1');

      expect(cart.status, 'locked');
      expect(cart.acceptsContributions, isFalse);
    });

    test('confirm rend la commande née du panier', () async {
      final order = await repository.confirm(
        groupCartId: 'cart-1',
        addressId: 'address-1',
        paymentMethod: 'mobile_money',
      );

      expect(order.reference, 'EC000042');
      expect(order.total.amountMinor, 9500);

      final body = server.bodies.last! as Map<String, dynamic>;
      expect(body['address'], 'address-1');
      expect(body['payment_method'], 'mobile_money');
    });

    test('cancel exige une raison', () async {
      final cart = await repository.cancel(groupCartId: 'cart-1', reason: 'Réunion annulée');

      expect(cart.status, 'cancelled');
      expect(server.bodies.last, {'reason': 'Réunion annulée'});
    });
  });
}
