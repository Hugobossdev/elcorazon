import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// La lecture **par page** des commandes de supervision.
///
/// [ManagedOrderRepository.list] suit `next` jusqu'au bout et rend tout : c'est
/// le bon choix pour un total à calculer, et le mauvais pour un tableau à
/// afficher. À dix mille commandes, l'écran de supervision émettait cinq cents
/// requêtes avant sa première ligne.
///
/// Ce qui est vérifié ici est ce qu'un test de « ça marche » manquerait : que
/// les filtres partent **au serveur** (et non appliqués après coup sur une page
/// déjà réduite), et que `next` soit rejoué tel quel — une URL reconstruite à
/// partir d'un numéro de page perdrait les filtres de la requête d'origine, et
/// la page 2 ne suivrait plus la page 1.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _orderJson(String id, {String status = 'preparing'}) => {
      'id': id,
      'reference': 'EC${id.padLeft(6, '0')}',
      'restaurant': 'el-corazon-lome',
      'restaurant_name': 'El Corazón Lomé',
      'status': status,
      'allowed_transitions': const <String>[],
      'subtotal': {'amount': '4000', 'currency': 'XOF'},
      'delivery_fee': {'amount': '500', 'currency': 'XOF'},
      'discount': {'amount': '0', 'currency': 'XOF'},
      'total': {'amount': '4500', 'currency': 'XOF'},
      'payment_method': 'mobile_money',
      'delivery_address_line': 'Rue du Commerce',
      'delivery_landmark': '',
      'delivery_location': {'lat': 6.13, 'lon': 1.22},
      'recipient_name': 'Ama',
      'recipient_phone': '+22890000000',
      'placed_at': '2026-08-08T12:00:00Z',
      'estimated_delivery_at': null,
      'delivered_at': null,
      'cancelled_at': null,
      'cancellation_reason': '',
      'created_at': '2026-08-08T12:00:00Z',
      'updated_at': '2026-08-08T12:00:00Z',
    };

class _FakeServer implements HttpClientAdapter {
  final List<String> paths = [];
  final List<Map<String, dynamic>> queries = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    queries.add(Map<String, dynamic>.from(options.queryParameters));

    final page2 = options.path.contains('page=2');
    final corps = {
      'count': 25,
      'next': page2
          ? null
          : 'http://test.local/api/v1/orders/manage/?page=2&status=preparing',
      'previous':
          page2 ? 'http://test.local/api/v1/orders/manage/?status=preparing' : null,
      'results': [
        for (var i = 0; i < (page2 ? 5 : 20); i++) _orderJson('${page2 ? 20 + i : i}'),
      ],
    };
    return ResponseBody.fromString(jsonEncode(corps), 200, headers: _jsonHeaders);
  }
}

ManagedOrderRepository _depot(_FakeServer server) => ManagedOrderRepository(
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

  group('Une page', () {
    test('est lue en UNE requête, pas en suivant next jusqu’au bout', () async {
      final server = _FakeServer();

      final page = await _depot(server).listPage(status: 'preparing');

      expect(server.paths, hasLength(1));
      expect(page.results, hasLength(20));
    });

    test('porte le total de la sélection, pas celui de la page', () async {
      // C'est ce qu'on affiche à côté de « page 2 sur 17 » : le déduire du
      // nombre de lignes reçues donnerait toujours « 20 ».
      final page = await _depot(_FakeServer()).listPage();

      expect(page.count, 25);
      expect(page.hasNext, isTrue);
      expect(page.hasPrevious, isFalse);
    });

    test('transmet les filtres au serveur', () async {
      final server = _FakeServer();

      await _depot(server).listPage(
        status: 'ready',
        search: 'Konaté',
        restaurantSlug: 'el-corazon-lome',
        placedFrom: DateTime.utc(2026, 8, 3),
        pageSize: 50,
      );

      final requete = server.queries.single;
      expect(requete['status'], 'ready');
      expect(requete['search'], 'Konaté');
      expect(requete['restaurant__slug'], 'el-corazon-lome');
      expect(requete['page_size'], 50);
      expect(requete['placed_at__gte'], startsWith('2026-08-03'));
    });

    test('une recherche vide n’est pas envoyée', () async {
      // `?search=` vide ferait filtrer sur la chaîne vide côté serveur ; ne
      // rien envoyer est ce qui veut dire « pas de recherche ».
      final server = _FakeServer();

      await _depot(server).listPage(search: '   ');

      expect(server.queries.single.containsKey('search'), isFalse);
    });
  });

  group('La page suivante', () {
    test('rejoue l’URL du serveur, filtres compris', () async {
      final server = _FakeServer();
      final premiere = await _depot(server).listPage(status: 'preparing');

      final seconde = await _depot(server).pageAt(premiere.next!);

      // L'URL rendue par le serveur porte déjà `status=preparing` : c'est ce
      // qui garantit que la page 2 suit bien la page 1.
      expect(server.paths.last, contains('status=preparing'));
      expect(seconde.results, hasLength(5));
      expect(seconde.hasNext, isFalse);
      expect(seconde.hasPrevious, isTrue);
    });
  });

  group('list() reste ce qu’elle était', () {
    test('suit next jusqu’au bout — pour ce qui doit être complet', () async {
      // La pagination n'a rien retiré : les compteurs et les écrans qui
      // raisonnent sur l'ensemble continuent d'appeler `list()`.
      final server = _FakeServer();

      final tout = await _depot(server).list(status: 'preparing');

      expect(server.paths.length, 2);
      expect(tout, hasLength(25));
    });
  });
}
