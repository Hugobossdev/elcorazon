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

    if (options.path.contains('/geography/reference/')) {
      return ResponseBody.fromString(
        jsonEncode({
          'currencies': [
            {'code': 'EUR', 'exponent': 2},
            {'code': 'XOF', 'exponent': 0},
          ],
          'timezones': [
            'Africa/Abidjan',
            'Africa/Lome',
            'Africa/Porto-Novo',
            'America/New_York',
            'Europe/Paris',
          ],
        }),
        200,
        headers: _jsonHeaders,
      );
    }

    throw UnimplementedError('Route non simulée : ${options.path}');
  }
}

GeographyReferenceRepository _repository(_FakeServer server) {
  return GeographyReferenceRepository(
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

  group('GeographyReference', () {
    test('les devises et les fuseaux viennent du serveur', () async {
      // Ils étaient écrits en dur dans le formulaire d'ouverture de marché :
      // dix fuseaux, une liste de devises à côté. Ouvrir un onzième marché
      // demandait de republier l'application.
      final reference = await _repository(_FakeServer()).fetch();

      expect(reference.currencies.map((d) => d.code), containsAll(['XOF', 'EUR']));
      expect(reference.timezones, contains('Africa/Lome'));
    });

    test("l'exposant dit si le montant se saisit avec des décimales", () async {
      final reference = await _repository(_FakeServer()).fetch();

      final xof = reference.currencies.firstWhere((d) => d.code == 'XOF');
      final eur = reference.currencies.firstWhere((d) => d.code == 'EUR');

      expect(xof.hasSubunit, isFalse);
      expect(eur.hasSubunit, isTrue);
    });

    test('la recherche de fuseau ignore la casse et la ponctuation', () async {
      // « porto novo » doit trouver `Africa/Porto-Novo` : personne ne tape un
      // identifiant IANA à la lettre près dans un champ de recherche.
      final reference = await _repository(_FakeServer()).fetch();

      expect(reference.chercherFuseau('porto novo'), ['Africa/Porto-Novo']);
      expect(reference.chercherFuseau('LOME'), ['Africa/Lome']);
    });

    test('une recherche vide rend tout, sans filtrer', () async {
      final reference = await _repository(_FakeServer()).fetch();

      expect(reference.chercherFuseau(''), hasLength(reference.timezones.length));
    });

    test('la référence vide ne propose rien plutôt que d\'inventer', () {
      // Proposer une devise que le serveur pourrait refuser est précisément le
      // défaut qu'on corrige : avant la première réponse, on ne propose rien.
      expect(GeographyReference.vide.isEmpty, isTrue);
      expect(GeographyReference.vide.currencies, isEmpty);
    });
  });
}
