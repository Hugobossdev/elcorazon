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

/// Préférences telles que le serveur les rend. Les régimes et allergènes
/// **sont** dans la réponse : le contrat les porte, et le test s'assure que le
/// client les ignore sans s'y casser.
Map<String, dynamic> _prefsJson({
  bool push = true,
  bool email = true,
}) {
  return {
    'dietary_restrictions': <String>['halal'],
    'allergens': <String>['arachide'],
    'marketing_push_enabled': push,
    'marketing_email_enabled': email,
    'preferred_language': 'fr',
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
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

    if (options.method == 'PATCH') {
      final envoye = options.data as Map<String, dynamic>;
      return ResponseBody.fromString(
        jsonEncode(
          _prefsJson(
            push: envoye['marketing_push_enabled'] as bool,
            email: envoye['marketing_email_enabled'] as bool,
          ),
        ),
        200,
        headers: _jsonHeaders,
      );
    }

    return ResponseBody.fromString(jsonEncode(_prefsJson()), 200, headers: _jsonHeaders);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late PreferencesRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    repository = PreferencesRepository(
      apiClient: ApiClient(
        baseUrl: 'http://test.local/api/v1',
        tokenStorage: TokenStorage(),
        testAdapter: server,
      ),
    );
  });

  group('Lecture', () {
    test('la ressource est singulière — pas d’identifiant dans l’URL', () async {
      await repository.read();

      expect(server.requests.single.path, contains('/profiles/preferences/'));
      expect(server.requests.single.method, 'GET');
    });

    test('les consentements sont lus tels que le serveur les rend', () async {
      final prefs = await repository.read();

      expect(prefs.marketingPushEnabled, isTrue);
      expect(prefs.marketingEmailEnabled, isTrue);
    });

    test('un champ absent vaut accepté, jamais refusé', () {
      // Une réponse d'un serveur plus ancien ne doit pas se lire comme un
      // refus : cela ferait taire une communication que personne n'a coupée,
      // et le client verrait un interrupteur éteint qu'il n'a pas touché.
      final prefs = CustomerPreferences.fromJson(const {});

      expect(prefs.marketingPushEnabled, isTrue);
      expect(prefs.marketingEmailEnabled, isTrue);
    });
  });

  group('Écriture', () {
    test('couper les notifications part en PATCH sur la ressource', () async {
      await repository.update(
        const CustomerPreferences(
          marketingPushEnabled: false,
          marketingEmailEnabled: true,
        ),
      );

      final requete = server.requests.single;
      expect(requete.method, 'PATCH');
      expect((requete.data as Map)['marketing_push_enabled'], isFalse);
    });

    test('le corps ne porte que les consentements', () async {
      // Partiel, et c'est ce qui protège les régimes et les allergènes : ils
      // vivent dans la même ressource, et un corps complet les remettrait à
      // leur valeur par défaut — c'est-à-dire les effacerait.
      await repository.update(
        const CustomerPreferences(
          marketingPushEnabled: false,
          marketingEmailEnabled: false,
        ),
      );

      final corps = server.requests.single.data as Map<String, dynamic>;
      expect(corps.keys, unorderedEquals(['marketing_push_enabled', 'marketing_email_enabled']));
      expect(corps.containsKey('allergens'), isFalse);
      expect(corps.containsKey('dietary_restrictions'), isFalse);
    });

    test('l’état rendu est celui du serveur, pas celui qu’on espérait', () async {
      final retenues = await repository.update(
        const CustomerPreferences(
          marketingPushEnabled: false,
          marketingEmailEnabled: false,
        ),
      );

      expect(retenues.marketingPushEnabled, isFalse);
      expect(retenues.marketingEmailEnabled, isFalse);
    });
  });

  test('copyWith ne touche que ce qu’on lui nomme', () {
    const depart = CustomerPreferences(
      marketingPushEnabled: true,
      marketingEmailEnabled: false,
    );

    final apres = depart.copyWith(marketingPushEnabled: false);

    expect(apres.marketingPushEnabled, isFalse);
    expect(apres.marketingEmailEnabled, isFalse);
  });
}
