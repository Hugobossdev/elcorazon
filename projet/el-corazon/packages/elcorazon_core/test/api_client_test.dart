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
      switch (call.method) {
        case 'read':
          return secureStorageBacking[call.arguments['key']];
        case 'write':
          secureStorageBacking[call.arguments['key'] as String] = call.arguments['value'] as String;
          return null;
        case 'delete':
          secureStorageBacking.remove(call.arguments['key']);
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
}
