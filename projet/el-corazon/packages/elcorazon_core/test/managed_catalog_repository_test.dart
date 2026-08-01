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
}
