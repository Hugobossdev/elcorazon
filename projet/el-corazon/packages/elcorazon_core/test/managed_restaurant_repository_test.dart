import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _restaurantJson({
  String id = 'rest-1',
  String name = 'El Corazón — Lomé',
  String slug = 'el-corazon-lome',
  double lat = 6.1319,
  double lon = 1.2255,
  String status = 'active',
  bool acceptsOrders = true,
}) {
  return {
    'id': id,
    'name': name,
    'slug': slug,
    'description': 'Cuisine latine',
    'zone': 'zone-1',
    'address': 'Boulevard du 13 Janvier',
    'location': {'lat': lat, 'lon': lon},
    'phone': '+22890000000',
    'email': 'lome@elcorazon.test',
    'cover_image': null,
    'currency': 'XOF',
    'timezone': 'Africa/Lome',
    'city': 'Lomé',
    'city_slug': 'lome',
    'country': 'TG',
    'zone_name': 'Lomé — centre',
    'status': status,
    'configuration_gaps': <String>[],
    // Projection de `status` côté serveur, jamais envoyée en écriture.
    'is_active': status == 'active',
    'accepts_orders': acceptsOrders,
    'default_preparation_minutes': 20,
    'orders_count': 42,
    'couriers_count': 3,
    'menu_items_count': 17,
    'created_at': '2026-07-31T10:00:00Z',
    'updated_at': '2026-07-31T10:00:00Z',
  };
}

class _FakeServer implements HttpClientAdapter {
  _FakeServer({this.pages = 1});

  /// Nombre de pages que la route rendra.
  final int pages;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (options.path.contains('/duplicate/')) {
      return ResponseBody.fromString(
        jsonEncode({
          ..._restaurantJson(
            id: 'rest-copie',
            name: 'El Corazón Abidjan',
            slug: 'el-corazon-abidjan',
            status: 'draft',
          ),
          'copied': {'catalog': 12, 'opening_hours': 7},
        }),
        201,
        headers: _jsonHeaders,
      );
    }

    if (options.path.contains('/restaurants/manage/')) {
      final page = int.tryParse(options.uri.queryParameters['page'] ?? '1') ?? 1;
      final derniere = page >= pages;

      return ResponseBody.fromString(
        jsonEncode({
          'count': pages,
          'next': derniere
              ? null
              : 'http://test.local/api/v1/restaurants/manage/?page=${page + 1}',
          'previous': null,
          'results': [
            _restaurantJson(
              id: 'rest-$page',
              slug: page == 1 ? 'el-corazon-lome' : 'el-corazon-kara',
              status: page == 1 ? 'active' : 'inactive',
            ),
          ],
        }),
        200,
        headers: _jsonHeaders,
      );
    }

    throw UnimplementedError('Route non simulée : ${options.path}');
  }
}

ManagedRestaurantRepository _repository(_FakeServer server) {
  return ManagedRestaurantRepository(
    apiClient: ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  group('ManagedRestaurantRepository', () {
    test('list rend le périmètre du compte, sans le lui demander', () async {
      // Aucun filtre n'est envoyé : le périmètre est une décision du serveur,
      // pas un paramètre du client. C'est tout l'écart avec la constante
      // `el-corazon-lome` que le back-office portait.
      final server = _FakeServer();

      final etablissements = await _repository(server).list();

      expect(etablissements, hasLength(1));
      expect(server.requests.single.uri.queryParameters, isEmpty);
    });

    test('la position est lue dans le bon sens', () async {
      // `LocationField` rend `{"lat": …, "lon": …}` justement parce que
      // PostGIS attend `Point(x=lon, y=lat)` : inverser les deux placerait un
      // restaurant de Lomé au large de la Somalie.
      final etablissement = (await _repository(_FakeServer()).list()).single;

      expect(etablissement.latitude, closeTo(6.1319, 1e-9));
      expect(etablissement.longitude, closeTo(1.2255, 1e-9));
    });

    test('un établissement suspendu reste dans la liste', () async {
      // Le masquer le rendrait irrécupérable depuis l'écran qui sert à le
      // rouvrir.
      final etablissements = await _repository(_FakeServer(pages: 2)).list();

      expect(etablissements.map((e) => e.slug), [
        'el-corazon-lome',
        'el-corazon-kara',
      ]);
      expect(etablissements.last.isActive, isFalse);
      // Et son état le dit en clair : « suspendu », et non un booléen faux
      // qui pourrait aussi bien signifier « brouillon ».
      expect(etablissements.last.status, RestaurantLifecycle.inactive);
    });

    test('list suit la pagination jusqu’au bout', () async {
      final server = _FakeServer(pages: 3);

      final etablissements = await _repository(server).list();

      expect(etablissements, hasLength(3));
      expect(server.requests, hasLength(3));
    });

    test('les filtres partent au serveur, pas au client', () async {
      // Filtrer après coup demanderait de tout charger d'abord, et le compteur
      // affiché ne porterait que sur les pages déjà rendues.
      final server = _FakeServer();

      await _repository(server).list(
        countryIsoCode: 'CI',
        citySlug: 'abidjan',
        status: RestaurantLifecycle.active,
        search: 'plateau',
      );

      final parametres = server.requests.first.uri.queryParameters;
      expect(parametres['zone__city__country__iso_code'], 'CI');
      expect(parametres['zone__city__slug'], 'abidjan');
      expect(parametres['status'], 'active');
      expect(parametres['search'], 'plateau');
    });

    test('une recherche vide n’envoie pas de paramètre', () async {
      // Un `search=` vide fait faire au serveur un travail de filtrage qui ne
      // filtre rien.
      final server = _FakeServer();

      await _repository(server).list(search: '   ');

      expect(server.requests.first.uri.queryParameters, isEmpty);
    });

    test('les compteurs d’exploitation sont lus', () async {
      // Comptés par le serveur en une requête annotée. Le tableau de bord
      // précédent téléchargeait les commandes pour les compter à l'écran.
      final etablissements = await _repository(_FakeServer()).list();

      expect(etablissements.single.ordersCount, 42);
      expect(etablissements.single.couriersCount, 3);
      expect(etablissements.single.menuItemsCount, 17);
    });

    test('un contrat sans compteurs rend zéro, pas une erreur', () {
      // La réponse d'une transition de statut rend l'objet sans annotations :
      // l'écran doit montrer « 0 » plutôt que disparaître.
      final sans = Map<String, dynamic>.from(_restaurantJson())
        ..remove('orders_count')
        ..remove('couriers_count')
        ..remove('menu_items_count');

      expect(ManagedRestaurant.fromJson(sans).ordersCount, 0);
    });

    test('duplicate ouvre la copie en brouillon', () async {
      // Hériter d'« en service » publierait une fiche dont personne n'a vérifié
      // l'adresse — et la carte recopiée lui donnerait l'air complète.
      final server = _FakeServer();

      final copie = await _repository(server).duplicate(
        sourceSlug: 'el-corazon-lome',
        name: 'El Corazón Abidjan',
        slug: 'el-corazon-abidjan',
        zoneId: 'zone-ci',
        address: 'Plateau, Abidjan',
        latitude: 5.36,
        longitude: -4.0083,
        phone: '+22507000000',
        sections: const ['general', 'catalog'],
      );

      expect(copie.status, RestaurantLifecycle.draft);
      expect(copie.slug, 'el-corazon-abidjan');
    });

    test('duplicate transmet les sections demandées, et rien d’autre', () async {
      // Commandes, clients et livreurs ne sont copiables par aucune valeur : il
      // n'existe pas de section pour eux côté serveur.
      final server = _FakeServer();

      await _repository(server).duplicate(
        sourceSlug: 'el-corazon-lome',
        name: 'El Corazón Abidjan',
        slug: 'el-corazon-abidjan',
        zoneId: 'zone-ci',
        address: 'Plateau, Abidjan',
        latitude: 5.36,
        longitude: -4.0083,
        phone: '+22507000000',
        sections: const ['catalog'],
      );

      final corps = server.requests.single.data as Map<String, dynamic>;
      expect(corps['sections'], ['catalog']);
      expect(corps['location'], {'lat': 5.36, 'lon': -4.0083});
    });

    test('duplicate sans section duplique la seule identité de marque', () async {
      // Ce n'est pas un cas dégénéré : la succursale aura son propre menu.
      final server = _FakeServer();

      await _repository(server).duplicate(
        sourceSlug: 'el-corazon-lome',
        name: 'El Corazón Abidjan',
        slug: 'el-corazon-abidjan',
        zoneId: 'zone-ci',
        address: 'Plateau, Abidjan',
        latitude: 5.36,
        longitude: -4.0083,
        phone: '+22507000000',
      );

      final corps = server.requests.single.data as Map<String, dynamic>;
      expect(corps['sections'], isEmpty);
    });
  });
}
