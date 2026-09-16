import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Simule le serveur : 401 tant que le jeton présenté n'est pas le dernier
/// émis par `/auth/token/refresh/`, succès sinon. Le délai sur le
/// rafraîchissement rend la fenêtre de course observable — sans lui, deux
/// appels concurrents pourraient se résoudre l'un après l'autre sans jamais
/// se chevaucher, et le test ne prouverait rien.
class _FakeServer implements HttpClientAdapter {
  int refreshCalls = 0;
  bool refreshShouldFail = false;
  // Délibérément différent du jeton stocké par `setUp` (`expired-token`) :
  // c'est ce décalage qui simule un jeton expiré côté serveur.
  String currentToken = 'server-side-valid-token';

  /// En-tête `Authorization` vu sur le dernier appel à `/auth/login/`, et
  /// nombre de fois que la route a été appelée. `null` signifie « aucun
  /// en-tête », ce que le test attend.
  String? lastLoginAuthorization;
  int loginCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/auth/token/refresh/')) {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      if (refreshShouldFail) {
        return ResponseBody.fromString(
          jsonEncode({'code': 'token_not_valid', 'detail': 'Jeton invalide.'}),
          401,
          headers: _jsonHeaders,
        );
      }
      currentToken = 'valid-token-$refreshCalls';
      return ResponseBody.fromString(
        jsonEncode({'access': currentToken, 'refresh': 'refresh-token-$refreshCalls'}),
        200,
        headers: _jsonHeaders,
      );
    }

    // Le serveur réel répond 401 à des identifiants faux (`AuthenticationFailed`,
    // `backend/apps/accounts/views.py`) — c'est ce 401-là que l'intercepteur ne
    // doit pas confondre avec un jeton d'accès expiré.
    if (options.path.contains('/auth/login/')) {
      loginCalls++;
      lastLoginAuthorization = options.headers['Authorization'] as String?;
      return ResponseBody.fromString(
        jsonEncode({'code': 'authentication_failed', 'detail': 'Identifiants invalides.'}),
        401,
        headers: _jsonHeaders,
      );
    }

    if (options.path.contains('/protected')) {
      final authorization = options.headers['Authorization'] as String?;
      if (authorization == 'Bearer $currentToken') {
        return ResponseBody.fromString(jsonEncode({'ok': true}), 200, headers: _jsonHeaders);
      }
      return ResponseBody.fromString(
        jsonEncode({'code': 'not_authenticated', 'detail': 'Jeton expiré.'}),
        401,
        headers: _jsonHeaders,
      );
    }

    // La panne du 2026-09-13 : Django rend sa page d'erreur HTML sur un
    // `ProgrammingError` (migration non appliquée), en 500.
    if (options.path.contains('/panne-html')) {
      return ResponseBody.fromString(
        '<!DOCTYPE html><title>ProgrammingError at /api/v1/restaurants/</title>',
        500,
        headers: {
          Headers.contentTypeHeader: ['text/html; charset=utf-8'],
        },
      );
    }

    // Un préfixe `/api/v1` oublié : le serveur répond 404 en HTML.
    if (options.path.contains('/route-html')) {
      return ResponseBody.fromString(
        '<h1>Not Found</h1>',
        404,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      );
    }

    if (options.path.contains('/injoignable')) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Connection refused',
      );
    }

    throw UnimplementedError('Route non simulée : ${options.path}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureStorageBacking;
  late TokenStorage tokenStorage;
  late _FakeServer server;
  late ApiClient apiClient;

  setUp(() async {
    secureStorageBacking = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
      // `MethodCall.arguments` est `dynamic` : on le type une fois ici plutôt
      // que d'indexer un `dynamic` à chaque branche.
      final arguments = call.arguments as Map<Object?, Object?>;
      switch (call.method) {
        case 'read':
          return secureStorageBacking[arguments['key']];
        case 'write':
          secureStorageBacking[arguments['key']! as String] =
              arguments['value']! as String;
          return null;
        case 'delete':
          secureStorageBacking.remove(arguments['key']);
          return null;
        default:
          return null;
      }
    });

    tokenStorage = TokenStorage();
    await tokenStorage.saveTokens(accessToken: 'expired-token', refreshToken: 'refresh-token-0');

    server = _FakeServer();
    apiClient = ApiClient(baseUrl: 'http://test.local', tokenStorage: tokenStorage, testAdapter: server);
  });

  group('ApiClient — rafraîchissement sur 401', () {
    test('une requête isolée est rejouée après rafraîchissement', () async {
      final response = await apiClient.get('/protected');

      expect(response.statusCode, 200);
      expect(server.refreshCalls, 1);
      expect(await tokenStorage.getAccessToken(), 'valid-token-1');
    });

    test('deux requêtes 401 concurrentes ne déclenchent qu\'un seul rafraîchissement', () async {
      // C'est le comportement qui justifie le verrou single-flight : sans
      // lui, chacune des deux verrait le même jeton expiré et tenterait son
      // propre rafraîchissement — le second échouerait, le refresh token
      // étant à usage unique côté serveur (rotation).
      final results = await Future.wait([
        apiClient.get('/protected'),
        apiClient.get('/protected'),
        apiClient.get('/protected'),
      ]);

      expect(results.every((r) => r.statusCode == 200), isTrue);
      expect(server.refreshCalls, 1);
    });

    test('un rafraîchissement qui échoue efface les jetons et remonte session_expired', () async {
      server.refreshShouldFail = true;

      await expectLater(
        apiClient.get('/protected'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'session_expired')),
      );

      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
    });
  });

  group('ApiClient — routes ouvertes', () {
    test('un échec de connexion remonte son vrai motif, pas session_expired', () async {
      // Le piège : `/auth/login/` répond 401 pour des identifiants faux. Traité
      // comme un jeton expiré, il déclenchait un rafraîchissement et masquait
      // « Identifiants invalides » derrière « Votre session a expiré ».
      await expectLater(
        apiClient.post('/auth/login/', data: {'email': 'a@b.c', 'password': 'faux'}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'authentication_failed')
              .having((e) => e.status, 'status', 401),
        ),
      );

      expect(server.refreshCalls, 0);
      expect(server.loginCalls, 1, reason: 'la requête ne doit pas être rejouée');
      // Un mot de passe mal saisi ne doit pas coûter la session en cours.
      expect(await tokenStorage.getRefreshToken(), 'refresh-token-0');
    });

    test('aucun jeton stocké n\'est joint à la connexion', () async {
      // Django authentifie avant d'appliquer `AllowAny` : un jeton périmé
      // présenté ici ferait répondre 401 avant même que la vue ne lise les
      // identifiants — la reconnexion deviendrait impossible.
      await expectLater(
        apiClient.post('/auth/login/', data: {'email': 'a@b.c', 'password': 'faux'}),
        throwsA(isA<ApiException>()),
      );

      expect(server.lastLoginAuthorization, isNull);
    });
  });

  group('ApiClient — une réponse reçue n’est jamais une panne réseau', () {
    // Le 2026-09-13, l'annuaire rendait 500 en page HTML. Le client l'a
    // rapporté `network_error`, puis « aucun restaurant en service » : on a
    // cherché du côté du Wi-Fi un défaut qui était dans le schéma de la base.

    test('un 500 en HTML garde son statut et se dit erreur serveur', () async {
      final erreur = await apiClient
          .get('/panne-html')
          .then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);

      expect(erreur, isNotNull);
      expect(erreur!.status, 500);
      expect(erreur.code, 'server_error');
      expect(erreur.isNetworkError, isFalse);
      expect(erreur.isServerError, isTrue);
      expect(ApiFailure.of(erreur), ApiFailure.server);
    });

    test('un 404 en HTML garde son statut', () async {
      final erreur = await apiClient
          .get('/route-html')
          .then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);

      expect(erreur!.status, 404);
      expect(erreur.isNetworkError, isFalse);
      expect(ApiFailure.of(erreur), ApiFailure.notFound);
    });

    test('sans réponse, c’est une panne réseau', () async {
      final erreur = await apiClient
          .get('/injoignable')
          .then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);

      expect(erreur!.status, 0);
      expect(erreur.code, 'network_error');
      expect(ApiFailure.of(erreur), ApiFailure.network);
    });
  });
}
