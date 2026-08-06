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

Map<String, dynamic> _templateJson({
  String id = 'tpl-1',
  String name = 'Extra fromage',
  String groupName = 'Suppléments',
  String amount = '500',
  bool isDefault = false,
}) {
  return {
    'id': id,
    'restaurant': 'el-corazon-lome',
    'name': name,
    'group_name': groupName,
    'price_delta': {'amount': amount, 'currency': 'XOF'},
    'is_default': isDefault,
    'is_active': true,
    'sort_order': 0,
    'created_at': '2026-07-31T10:00:00Z',
    'updated_at': '2026-07-31T10:00:00Z',
  };
}

/// Article tel que le serveur le rend après écriture. `image` porte l'URL
/// **publique** que le stockage a retenue — le client ne la fabrique pas.
Map<String, dynamic> _itemJson({String? image = 'https://cdn.test/products/menu/burger.jpg'}) {
  return {
    'id': 'item-1',
    'restaurant': 'el-corazon-lome',
    'category': 'burgers',
    'category_name': 'Burgers',
    'name': 'Burger Corazón',
    'slug': 'burger-corazon',
    'description': '',
    'image': image,
    'price': {'amount': '3500', 'currency': 'XOF'},
    'preparation_minutes': 15,
    'allergens': <String>[],
    'dietary_tags': <String>[],
    'is_available': true,
    'is_popular': false,
    'vip_exclusive': false,
    'rating_average': '4.5',
    'rating_count': 12,
    'sort_order': 0,
  };
}

class _FakeServer implements HttpClientAdapter {
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

    if (options.path.contains('/apply-template/')) {
      return ResponseBody.fromString(
        jsonEncode({
          'id': 'grp-1',
          'name': 'Suppléments',
          'min_select': 0,
          'max_select': 1,
          'is_required': false,
          'sort_order': 0,
          'options': [
            {
              'id': 'opt-1',
              'name': 'Extra fromage',
              'price_delta': {'amount': '500', 'currency': 'XOF'},
              'is_default': false,
              'is_available': true,
              'sort_order': 0,
            },
          ],
        }),
        201,
        headers: _jsonHeaders,
      );
    }

    if (options.path.contains('/catalog/manage/items/')) {
      return ResponseBody.fromString(
        jsonEncode(_itemJson()),
        200,
        headers: _jsonHeaders,
      );
    }

    if (options.path.contains('/option-templates/')) {
      if (options.method == 'POST') {
        return ResponseBody.fromString(
          jsonEncode(_templateJson(id: 'tpl-2', isDefault: true)),
          201,
          headers: _jsonHeaders,
        );
      }
      return ResponseBody.fromString(
        jsonEncode({
          'count': 1,
          'next': null,
          'previous': null,
          'results': [_templateJson()],
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
  late ManagedCatalogRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    repository = ManagedCatalogRepository(
      apiClient: ApiClient(
        baseUrl: 'http://test.local/api/v1',
        tokenStorage: TokenStorage(),
        testAdapter: server,
      ),
    );
  });

  group('ManagedCatalogRepository — bibliothèque d’options', () {
    test('optionTemplates lit le montant en unité mineure', () async {
      final modeles = await repository.optionTemplates(
        restaurantSlug: 'el-corazon-lome',
      );

      expect(modeles, hasLength(1));
      expect(modeles.single.name, 'Extra fromage');
      expect(modeles.single.groupName, 'Suppléments');
      expect(modeles.single.priceDelta.amountMinor, 500);
      expect(modeles.single.isDefault, isFalse);
    });

    test('createOptionTemplate transmet la présélection', () async {
      final cree = await repository.createOptionTemplate(
        restaurantSlug: 'el-corazon-lome',
        name: 'À point',
        priceDelta: const Money(amountMinor: 0, currency: 'XOF'),
        isDefault: true,
      );

      final corps = server.requests.last.data as Map<String, dynamic>;
      expect(corps['is_default'], isTrue);
      expect(cree.isDefault, isTrue);
    });

    test(
      'applyTemplate n’envoie ni nom ni prix — le serveur copie le modèle',
      () async {
        // Les transmettre ferait d’« appliquer un modèle » un « créer une
        // option quelconque », et la bibliothèque ne garantirait plus rien.
        final groupe = await repository.applyTemplate(
          menuItemId: 'item-1',
          templateId: 'tpl-1',
        );

        final corps = server.requests.last.data as Map<String, dynamic>;
        expect(corps.keys, ['template']);
        expect(corps['template'], 'tpl-1');
        expect(groupe.options.single.name, 'Extra fromage');
        expect(groupe.options.single.priceDelta.amountMinor, 500);
      },
    );

    test('applyTemplate vise un groupe précis quand on le nomme', () async {
      await repository.applyTemplate(
        menuItemId: 'item-1',
        templateId: 'tpl-1',
        groupName: 'Extras',
      );

      final corps = server.requests.last.data as Map<String, dynamic>;
      expect(corps['group_name'], 'Extras');
    });
  });

  group('ManagedCatalogRepository — image d’un article', () {
    test('l’image part en multipart, sur l’article visé', () async {
      await repository.uploadMenuItemImage(
        menuItemId: 'item-1',
        filename: 'burger.jpg',
        bytes: [1, 2, 3, 4],
        contentType: 'image/jpeg',
      );

      final requete = server.requests.last;
      expect(requete.method, 'PATCH');
      expect(requete.path, '/catalog/manage/items/item-1/');
      expect(requete.data, isA<FormData>());

      final corps = requete.data as FormData;
      // Le champ doit s'appeler `image` : c'est le nom de la colonne du
      // sérialiseur, et un autre nom serait ignoré en silence — l'article
      // reviendrait sans photo, sans la moindre erreur.
      expect(corps.files.single.key, 'image');
      expect(corps.files.single.value.filename, 'burger.jpg');
    });

    test('le type de contenu annoncé est transmis', () async {
      await repository.uploadMenuItemImage(
        menuItemId: 'item-1',
        filename: 'burger.png',
        bytes: [1, 2, 3],
        contentType: 'image/png',
      );

      final corps = server.requests.last.data as FormData;
      expect(corps.files.single.value.contentType?.mimeType, 'image/png');
    });

    test('un type de contenu inconnu ne bloque pas l’envoi', () async {
      // `XFile.mimeType` est nul sur certaines plateformes. Le serveur fait de
      // toute façon ouvrir le fichier par Pillow : c'est lui qui tranche, et
      // refuser l'envoi ici priverait d'image sans raison.
      await repository.uploadMenuItemImage(
        menuItemId: 'item-1',
        filename: 'burger.jpg',
        bytes: [1, 2, 3],
      );

      expect(server.requests.last.data, isA<FormData>());
    });

    test('l’URL rendue est celle du serveur', () async {
      final article = await repository.uploadMenuItemImage(
        menuItemId: 'item-1',
        filename: 'burger.jpg',
        bytes: [1, 2, 3],
      );

      expect(article.image, 'https://cdn.test/products/menu/burger.jpg');
    });

    test('retirer l’image envoie un null explicite, en JSON', () async {
      await repository.clearMenuItemImage('item-1');

      final requete = server.requests.last;
      // En multipart, « vide » ne s'exprime pas : un champ absent se lit
      // « ne pas y toucher », et l'image ne partirait jamais.
      expect(requete.data, isNot(isA<FormData>()));

      final corps = requete.data as Map<String, dynamic>;
      expect(corps.containsKey('image'), isTrue);
      expect(corps['image'], isNull);
    });
  });
}
