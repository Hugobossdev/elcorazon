import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _menuItemJson({required String id, required String name, int sortOrder = 0}) {
  return {
    'id': id,
    'restaurant': 'el-corazon-lome',
    'category': 'burgers',
    'category_name': 'Burgers',
    'name': name,
    'slug': name.toLowerCase(),
    'description': 'Un délicieux $name',
    'image': null,
    'price': {'amount': '2500', 'currency': 'XOF'},
    'preparation_minutes': 10,
    'allergens': <String>[],
    'dietary_tags': <String>[],
    'is_available': true,
    'is_popular': false,
    'vip_exclusive': false,
    'rating_average': '4.50',
    'rating_count': 3,
    'sort_order': sortOrder,
  };
}

Map<String, dynamic> _reviewJson({
  String id = 'review-1',
  int rating = 5,
  bool verified = false,
}) {
  return {
    'id': id,
    'menu_item': 'item-1',
    'user': {'id': 'user-1', 'full_name': 'Awa K.', 'avatar': null},
    'rating': rating,
    'title': 'Excellent',
    'comment': 'Rien à redire.',
    'is_verified_purchase': verified,
    'helpful_count': 0,
    'created_at': '2026-07-28T12:00:00Z',
    'updated_at': '2026-07-28T12:00:00Z',
  };
}

/// Simule deux pages de résultats paginés (`StandardPagination`, ADR-009) pour
/// vérifier que [CatalogRepository.getMenuItems] suit bien `next` jusqu'à
/// épuisement au lieu de ne renvoyer que la première page.
class _FakeServer implements HttpClientAdapter {
  int itemsCallCount = 0;
  final List<Object?> bodies = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.data != null) {
      bodies.add(options.data);
    }

    if (options.path.contains('/catalog/reviews/')) {
      if (options.method == 'POST') {
        return ResponseBody.fromString(
          jsonEncode(_reviewJson(id: 'review-2', rating: 4, verified: true)),
          201,
          headers: _jsonHeaders,
        );
      }
      return ResponseBody.fromString(
        jsonEncode({
          'count': 1,
          'next': null,
          'previous': null,
          'results': [_reviewJson()],
        }),
        200,
        headers: _jsonHeaders,
      );
    }

    if (options.path.contains('/catalog/categories/')) {
      return ResponseBody.fromString(
        jsonEncode([
          {
            'id': 'cat-1',
            'restaurant': 'el-corazon-lome',
            'name': 'Burgers',
            'slug': 'burgers',
            'emoji': '🍔',
            'description': '',
            'sort_order': 0,
          },
        ]),
        200,
        headers: _jsonHeaders,
      );
    }

    if (options.path.contains('/catalog/items/item-1/')) {
      return ResponseBody.fromString(
        jsonEncode(_menuItemJson(id: 'item-1', name: 'Cheeseburger')),
        200,
        headers: _jsonHeaders,
      );
    }

    if (options.path.contains('/catalog/items/')) {
      itemsCallCount++;
      if (options.path.contains('page=2')) {
        return ResponseBody.fromString(
          jsonEncode({
            'count': 2,
            'next': null,
            'previous': 'http://test.local/api/v1/catalog/items/',
            'results': [_menuItemJson(id: 'item-2', name: 'Double Cheese', sortOrder: 1)],
          }),
          200,
          headers: _jsonHeaders,
        );
      }
      return ResponseBody.fromString(
        jsonEncode({
          'count': 2,
          'next': 'http://test.local/api/v1/catalog/items/?page=2',
          'previous': null,
          'results': [_menuItemJson(id: 'item-1', name: 'Cheeseburger')],
        }),
        200,
        headers: _jsonHeaders,
      );
    }

    throw UnimplementedError('Route non simulée : ${options.path}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late CatalogRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    );
    repository = CatalogRepository(apiClient: apiClient);
  });

  group('CatalogRepository', () {
    test('getCategories mappe la réponse non paginée', () async {
      final categories = await repository.getCategories(restaurantSlug: 'el-corazon-lome');

      expect(categories, hasLength(1));
      expect(categories.single.slug, 'burgers');
      expect(categories.single.emoji, '🍔');
    });

    test('getMenuItems suit `next` et concatène toutes les pages', () async {
      final items = await repository.getMenuItems(restaurantSlug: 'el-corazon-lome');

      expect(items.map((i) => i.id), ['item-1', 'item-2']);
      expect(server.itemsCallCount, 2);
      expect(items.first.price.amountMinor, 2500);
      expect(items.first.price.toMajorUnits(), 2500.0);
    });

    test('getMenuItem récupère la forme détail par id', () async {
      final item = await repository.getMenuItem('item-1');

      expect(item.name, 'Cheeseburger');
      expect(item.categoryName, 'Burgers');
    });

    test('getReviews mappe les avis d\'un article', () async {
      final reviews = await repository.getReviews('item-1');

      expect(reviews.single.rating, 5);
      expect(reviews.single.author.fullName, 'Awa K.');
      expect(reviews.single.isVerifiedPurchase, isFalse);
    });

    test('submitReview n\'envoie pas is_verified_purchase et lit celui du serveur', () async {
      final review = await repository.submitReview(
        menuItemId: 'item-1',
        rating: 4,
        title: 'Excellent',
        comment: 'Rien à redire.',
      );

      // Le client ne sait pas — et n'a plus à deviner — si l'achat est
      // vérifié : le serveur le calcule et le renvoie (S1).
      expect(review.isVerifiedPurchase, isTrue);
      final body = server.bodies.single! as Map<String, dynamic>;
      expect(body['rating'], 4);
      expect(body.containsKey('is_verified_purchase'), isFalse);
      expect(body.containsKey('user'), isFalse);
    });
  });
}
