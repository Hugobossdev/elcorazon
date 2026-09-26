import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tailles de produit (lot 2), telles qu'elles voyagent entre le serveur et
/// les applications : lues sur le catalogue, envoyées par identifiant au
/// panier personnel **et** au panier collaboratif — c'est de là que le
/// serveur tire le prix.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Retient le corps de chaque requête, puis refuse : seul l'envoi compte ici.
class _Ecoute implements HttpClientAdapter {
  final List<Map<String, dynamic>> corps = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    corps.add(Map<String, dynamic>.from(options.data as Map));
    return ResponseBody.fromString(
      '{"code":"conflict","detail":"refus d’essai"}',
      409,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

ApiClient _client(_Ecoute ecoute) => ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: ecoute,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  test('le catalogue publie les tailles, avec leur prix absolu', () {
    final article = MenuItem.fromJson({
      'id': 'pizza',
      'restaurant': 'el-corazon-lome',
      'category': 'pizzas',
      'name': 'Pizza Reine',
      'slug': 'pizza-reine',
      'price': {'amount': '2000', 'currency': 'XOF'},
      'is_available': true,
      'is_popular': false,
      'vip_exclusive': false,
      'rating_average': '0.0',
      'rating_count': 0,
      'sort_order': 0,
      'variants': [
        {
          'id': 'g',
          'name': 'Grande',
          'price': {'amount': '3500', 'currency': 'XOF'},
          'is_available': false,
          'sort_order': 2,
        },
      ],
    });

    expect(article.aDesTailles, isTrue);
    expect(article.variants.single.price.amountMinor, 3500);
    expect(article.variants.single.isAvailable, isFalse);
  });

  test('le panier envoie la taille par identifiant, et rien sans taille', () async {
    final ecoute = _Ecoute();
    final depot = CartRepository(apiClient: _client(ecoute));

    for (final taille in ['g', null]) {
      await expectLater(
        depot.addLine(
          restaurantSlug: 'el-corazon-lome',
          menuItemId: 'pizza',
          quantity: 1,
          variantId: taille,
        ),
        throwsA(isA<ApiException>()),
      );
    }

    expect(ecoute.corps.first['variant'], 'g');
    expect(ecoute.corps.last.containsKey('variant'), isFalse);
  });

  test('le panier collaboratif envoie la taille et les options', () async {
    final ecoute = _Ecoute();

    await expectLater(
      GroupCartRepository(apiClient: _client(ecoute)).addLine(
        groupCartId: 'groupe',
        menuItemId: 'pizza',
        optionIds: ['fromage'],
        variantId: 'g',
      ),
      throwsA(isA<ApiException>()),
    );

    expect(ecoute.corps.single['variant'], 'g');
    expect(ecoute.corps.single['options'], ['fromage']);
  });

  test('une ligne du panier collaboratif nomme sa taille', () {
    final ligne = GroupCartLine.fromJson({
      'id': 'l1',
      'member': 'm1',
      'menu_item': 'pizza',
      'quantity': 1,
      'unit_price': {'amount': '3500', 'currency': 'XOF'},
      'total': {'amount': '3500', 'currency': 'XOF'},
      'variant_name': 'Grande',
    });

    expect(ligne.variantName, 'Grande');
  });
}
