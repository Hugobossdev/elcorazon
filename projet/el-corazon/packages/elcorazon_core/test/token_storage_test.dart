import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// `jwt_decoder` ne vérifie jamais la signature (ce n'est pas son rôle, ni
/// celui du client) : un jeton non signé suffit à exercer la lecture du
/// payload et le contrôle d'expiration.
String _fakeJwt({required int expiresInSeconds}) {
  String segment(Map<String, Object?> data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');

  final exp = DateTime.now().add(Duration(seconds: expiresInSeconds)).millisecondsSinceEpoch ~/ 1000;
  return '${segment({
        'alg': 'none',
      })}.${segment({
        'sub': 'user-1',
        'exp': exp,
      })}.';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> backing;
  late TokenStorage storage;

  setUp(() {
    backing = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'read':
          return backing[call.arguments['key']];
        case 'write':
          backing[call.arguments['key'] as String] = call.arguments['value'] as String;
          return null;
        case 'delete':
          backing.remove(call.arguments['key']);
          return null;
        default:
          return null;
      }
    });
    storage = TokenStorage();
  });

  group('TokenStorage', () {
    test('sauvegarde puis relit le couple de jetons', () async {
      await storage.saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

      expect(await storage.getAccessToken(), 'access-1');
      expect(await storage.getRefreshToken(), 'refresh-1');
    });

    test('clearTokens efface les deux jetons', () async {
      await storage.saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');
      await storage.clearTokens();

      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test('un jeton valide et non expiré est reconnu', () async {
      await storage.saveTokens(
        accessToken: _fakeJwt(expiresInSeconds: 900),
        refreshToken: 'refresh-1',
      );

      expect(await storage.hasValidAccessToken(), isTrue);
    });

    test('un jeton expiré est rejeté', () async {
      await storage.saveTokens(
        accessToken: _fakeJwt(expiresInSeconds: -60),
        refreshToken: 'refresh-1',
      );

      expect(await storage.hasValidAccessToken(), isFalse);
    });

    test('aucun jeton stocké → invalide', () async {
      expect(await storage.hasValidAccessToken(), isFalse);
    });
  });
}
