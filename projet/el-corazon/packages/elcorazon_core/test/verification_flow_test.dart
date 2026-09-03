import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Un jeton d'accès **bien formé** et non expiré.
///
/// `TokenStorage.hasValidAccessToken` décode le JWT : une chaîne quelconque le
/// ferait répondre « invalide », et la restauration de session sauterait
/// l'appel à `/auth/me/` que ces tests cherchent justement à observer. La
/// signature n'est pas vérifiée côté client — seule la forme et `exp` comptent.
String _jwt({required bool expired}) {
  String segment(Map<String, dynamic> payload) =>
      base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');

  final exp = DateTime.now().add(Duration(hours: expired ? -1 : 1)).millisecondsSinceEpoch ~/ 1000;
  return '${segment({'alg': 'RS256'})}.${segment({'sub': 'u-1', 'exp': exp})}.signature';
}

Map<String, dynamic> _userJson({
  String userType = 'courier',
  String? emailVerifiedAt,
  bool isActive = true,
}) {
  return {
    'id': 'user-1',
    'email': 'yao@elcorazon.test',
    'phone': '+22890111222',
    'full_name': 'Yao Agbeko',
    'user_type': userType,
    'avatar': null,
    'is_active': isActive,
    'permissions': <String>[],
    'email_verified_at': emailVerifiedAt,
    'phone_verified_at': null,
    'last_seen_at': '2026-09-01T10:00:00Z',
    'created_at': '2026-09-01T09:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
  };
}

/// Simule les routes de création, vérification et reprise de compte.
///
/// Elle reproduit trois comportements du serveur qui ne sont pas des détails,
/// et sans lesquels les tests ne prouveraient rien :
///
/// * `/delivery/apply/` rend **201 sans jeton** ;
/// * `/auth/verify/` refuse en **400 `invalid_verification_code`** tout ce qui
///   n'est pas le bon code, sans jamais dire pourquoi ;
/// * `/auth/verify/resend/` et `/auth/password/reset/` rendent **202** que
///   l'adresse existe ou non.
class _FakeServer implements HttpClientAdapter {
  _FakeServer({this.userType = 'courier'});

  final String userType;

  final List<String> requests = [];
  final List<Map<String, dynamic>> bodies = [];
  final List<String?> authorizations = [];

  static const bonCode = '123456';
  String? emailVerifiedAt;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    authorizations.add(options.headers['Authorization'] as String?);
    if (options.data is Map) {
      bodies.add(Map<String, dynamic>.from(options.data as Map));
    }

    if (options.path.endsWith('/delivery/apply/')) {
      return _json(
        {
          'email': 'yao@elcorazon.test',
          'expires_at': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
          'retry_after': 60,
          'code_length': 6,
          'verification_status': 'pending',
          'detail': 'Votre compte est créé.',
        },
        201,
      );
    }

    if (options.path.endsWith('/auth/verify/resend/') ||
        options.path.endsWith('/auth/password/reset/')) {
      return _json(
        {
          'email': (options.data as Map)['email'],
          'expires_at': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
          'retry_after': 60,
          'code_length': 6,
          'detail': 'Si un compte correspond à cette adresse, un code vient d\'y être envoyé.',
        },
        202,
      );
    }

    if (options.path.endsWith('/auth/verify/') ||
        options.path.endsWith('/auth/password/reset/confirm/')) {
      if ((options.data as Map)['code'] != bonCode) {
        return _json(
          {
            'type': 'https://api.elcorazon.app/errors/invalid-verification-code',
            'title': 'Code de vérification refusé',
            'status': 400,
            'code': 'invalid_verification_code',
            'detail': 'Ce code est incorrect ou n\'est plus valable. Demandez-en un nouveau.',
          },
          400,
        );
      }
      emailVerifiedAt = '2026-09-02T12:00:00Z';
      return _json(
        {
          'access': _jwt(expired: false),
          'refresh': 'refresh-neuf',
          'user': _userJson(userType: userType, emailVerifiedAt: emailVerifiedAt),
        },
        200,
      );
    }

    if (options.path.endsWith('/auth/login/')) {
      return _json(
        {
          'access': _jwt(expired: false),
          'refresh': 'refresh-neuf',
          'user': _userJson(userType: userType, emailVerifiedAt: emailVerifiedAt),
        },
        200,
      );
    }

    if (options.path.endsWith('/auth/me/')) {
      return _json(_userJson(userType: userType, emailVerifiedAt: emailVerifiedAt), 200);
    }

    if (options.path.endsWith('/auth/logout/')) {
      return ResponseBody.fromString('', 204, headers: _jsonHeaders);
    }

    throw UnimplementedError('Route non simulée : ${options.method} ${options.path}');
  }

  ResponseBody _json(Map<String, dynamic> body, int status) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: _jsonHeaders);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late Map<Object?, Object?> stockage;
  late ApiClient apiClient;
  late TokenStorage tokenStorage;

  void monterLeServeur({String userType = 'courier'}) {
    server = _FakeServer(userType: userType);
    tokenStorage = TokenStorage();
    apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: tokenStorage,
      testAdapter: server,
    );
  }

  setUp(() {
    stockage = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
      final arguments = call.arguments as Map<Object?, Object?>;
      switch (call.method) {
        case 'read':
          return stockage[arguments['key']];
        case 'write':
          stockage[arguments['key']] = arguments['value'];
          return null;
        case 'delete':
          stockage.remove(arguments['key']);
          return null;
        default:
          return null;
      }
    });
    monterLeServeur();
  });

  ProviderContainer conteneur({String attendu = UserAccountType.courier}) {
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage),
        apiClientProvider.overrideWithValue(apiClient),
        expectedUserTypeProvider.overrideWithValue(attendu),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Candidature de livreur', () {
    test('n\'ouvre aucune session — aucun jeton n\'est écrit', () async {
      final repository = DeliveryRepository(apiClient: apiClient);

      final recu = await repository.apply(
        const CourierApplication(
          email: 'yao@elcorazon.test',
          password: 'MotDePasseSolide!42',
          fullName: 'Yao Agbeko',
          phone: '+22890111222',
          restaurantSlug: 'el-corazon-lome',
          vehicleType: 'motorcycle',
        ),
      );

      expect(recu.verificationStatus, 'pending');
      expect(recu.challenge.codeLength, 6);
      expect(recu.challenge.retryAfter, 60);
      // Le point du parcours : le compte existe, la session non.
      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
    });

    test('envoie le slug de l\'établissement, pas son nom', () async {
      await DeliveryRepository(apiClient: apiClient).apply(
        const CourierApplication(
          email: 'yao@elcorazon.test',
          password: 'MotDePasseSolide!42',
          fullName: 'Yao Agbeko',
          phone: '+22890111222',
          restaurantSlug: 'el-corazon-lome',
          vehicleType: 'motorcycle',
          vehiclePlate: 'TG-1234',
        ),
      );

      expect(server.bodies.last['restaurant'], 'el-corazon-lome');
      expect(server.bodies.last['vehicle_type'], 'motorcycle');
      expect(server.bodies.last['full_name'], 'Yao Agbeko');
    });

    test('n\'y joint aucun jeton même si le stockage en porte un périmé', () async {
      // Le cas réel : une session livreur expirée, l'application rouverte, une
      // nouvelle candidature. Un `Authorization` périmé ferait répondre 401
      // *avant* que la vue ne voie le formulaire.
      await tokenStorage.saveTokens(
        accessToken: _jwt(expired: true),
        refreshToken: 'vieux-refresh',
      );

      await DeliveryRepository(apiClient: apiClient).apply(
        const CourierApplication(
          email: 'yao@elcorazon.test',
          password: 'MotDePasseSolide!42',
          fullName: 'Yao Agbeko',
          phone: '+22890111222',
          restaurantSlug: 'el-corazon-lome',
          vehicleType: 'motorcycle',
        ),
      );

      expect(server.authorizations.last, isNull);
    });
  });

  group('Vérification du compte', () {
    test('un code valide persiste les jetons et rend le compte vérifié', () async {
      final session = conteneur().read(sessionProvider.notifier);

      final user = await session.verifyAccount(
        email: 'yao@elcorazon.test',
        code: _FakeServer.bonCode,
      );

      expect(user.emailVerifiedAt, isNotNull);
      expect(await tokenStorage.getAccessToken(), isNotEmpty);
      expect(await tokenStorage.getRefreshToken(), 'refresh-neuf');
    });

    test('un code faux laisse le stockage vide', () async {
      final session = conteneur().read(sessionProvider.notifier);

      await expectLater(
        session.verifyAccount(email: 'yao@elcorazon.test', code: '999999'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'invalid_verification_code')
              .having((e) => e.status, 'status', 400),
        ),
      );
      expect(await tokenStorage.getAccessToken(), isNull);
    });

    test('un compte du mauvais type est refusé et ses jetons révoqués', () async {
      // La garde de rôle doit valoir ici comme à la connexion : sans elle, un
      // compte client saisissant son code dans l'app livreur y entrerait.
      monterLeServeur(userType: 'customer');
      final session = conteneur().read(sessionProvider.notifier);

      await expectLater(
        session.verifyAccount(email: 'ama@elcorazon.test', code: _FakeServer.bonCode),
        throwsA(isA<WrongAccountTypeException>()),
      );
      expect(server.requests, contains('POST /auth/logout/'));
      expect(await tokenStorage.getAccessToken(), isNull);
    });

    test('le renvoi rend les durées du serveur sans révéler l\'existence du compte', () async {
      final repository = AuthRepository(apiClient: apiClient, tokenStorage: tokenStorage);

      final challenge = await repository.resendVerificationCode('inconnu@nulle.part');

      expect(challenge.retryAfter, 60);
      expect(challenge.codeLength, 6);
      expect(challenge.detail, contains('Si un compte correspond'));
    });
  });

  group('Mot de passe oublié', () {
    test('la demande de code répond sans dire si le compte existe', () async {
      final repository = AuthRepository(apiClient: apiClient, tokenStorage: tokenStorage);

      final challenge = await repository.requestPasswordReset('inconnu@nulle.part');

      expect(challenge.detail, contains('Si un compte correspond'));
    });

    test('la confirmation ouvre la session avec les jetons neufs', () async {
      final session = conteneur().read(sessionProvider.notifier);

      final user = await session.resetPassword(
        email: 'yao@elcorazon.test',
        code: _FakeServer.bonCode,
        newPassword: 'AutreMotDePasse!77',
      );

      expect(user.userType, UserAccountType.courier);
      expect(await tokenStorage.getRefreshToken(), 'refresh-neuf');
      expect(server.bodies.last['new_password'], 'AutreMotDePasse!77');
    });

    test('un code refusé n\'ouvre pas de session', () async {
      final session = conteneur().read(sessionProvider.notifier);

      await expectLater(
        session.resetPassword(
          email: 'yao@elcorazon.test',
          code: '000000',
          newPassword: 'AutreMotDePasse!77',
        ),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_verification_code')),
      );
      expect(await tokenStorage.getAccessToken(), isNull);
    });
  });

  group('Session', () {
    test('une session valide est restaurée sans reconnexion', () async {
      server.emailVerifiedAt = '2026-09-02T12:00:00Z';
      await tokenStorage.saveTokens(
        accessToken: _jwt(expired: false),
        refreshToken: 'refresh-valide',
      );
      final container = conteneur();

      await container.read(sessionProvider.notifier).restoreSession();

      expect(container.read(sessionProvider).value?.email, 'yao@elcorazon.test');
    });

    test('un compte non vérifié reste connecté — c\'est la porte qui l\'oriente', () async {
      // Le serveur n'oppose pas la vérification à la connexion : les
      // identifiants sont corrects. Refuser ici renverrait le livreur retaper
      // indéfiniment un mot de passe juste.
      await tokenStorage.saveTokens(
        accessToken: _jwt(expired: false),
        refreshToken: 'refresh-valide',
      );
      final container = conteneur();

      await container.read(sessionProvider.notifier).restoreSession();

      final user = container.read(sessionProvider).value;
      expect(user, isNotNull);
      expect(user!.emailVerifiedAt, isNull);
    });

    test('reload relit le compte sans toucher aux jetons', () async {
      await tokenStorage.saveTokens(
        accessToken: _jwt(expired: false),
        refreshToken: 'refresh-valide',
      );
      final container = conteneur();
      await container.read(sessionProvider.notifier).restoreSession();
      expect(container.read(sessionProvider).value?.emailVerifiedAt, isNull);

      // Vérification faite ailleurs — depuis un autre appareil, par exemple.
      server.emailVerifiedAt = '2026-09-02T12:00:00Z';
      await container.read(sessionProvider.notifier).reload();

      expect(container.read(sessionProvider).value?.emailVerifiedAt, isNotNull);
      expect(await tokenStorage.getRefreshToken(), 'refresh-valide');
    });

    test('la déconnexion révoque côté serveur et vide le stockage', () async {
      await tokenStorage.saveTokens(
        accessToken: _jwt(expired: false),
        refreshToken: 'refresh-valide',
      );
      final container = conteneur();
      await container.read(sessionProvider.notifier).restoreSession();

      await container.read(sessionProvider.notifier).logout();

      expect(server.bodies.last, {'refresh': 'refresh-valide'});
      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
      expect(container.read(sessionProvider).value, isNull);
    });
  });
}
