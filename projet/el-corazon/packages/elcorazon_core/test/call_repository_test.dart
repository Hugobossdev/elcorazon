import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _callJson({
  String id = 'call-1',
  String status = 'ringing',
  String kind = 'voice',
  int duration = 0,
}) {
  return {
    'id': id,
    'order': 'order-1',
    'kind': kind,
    'status': status,
    'caller': 'user-client',
    'caller_name': 'Ama Koffi',
    'callee': 'user-livreur',
    'callee_name': 'Kodjo Mensah',
    // Dérivé de l'appel côté serveur (`call-{uuid7}`), jamais de la commande.
    'channel_name': 'call-$id',
    'answered_at': status == 'ringing' ? null : '2026-09-02T12:00:05Z',
    'ended_at': status == 'ended' || status == 'missed' || status == 'declined'
        ? '2026-09-02T12:01:00Z'
        : null,
    'duration_seconds': duration,
    'created_at': '2026-09-02T12:00:00Z',
  };
}

/// Simule `/calls/*`.
class _FakeServer implements HttpClientAdapter {
  final List<String> requests = [];
  final List<Map<String, dynamic>?> bodies = [];

  /// Nombre de pages d'historique rendues — sert à prouver que la relecture
  /// d'un appel ne pagine rien.
  int historyPages = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    bodies.add(options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null);

    // Le routage se fait sur le **composant chemin**, comme le ferait un vrai
    // serveur. C'est ce qui rend la pagination fidèle : le `next` de Django est
    // une URL **absolue** (`http://…/api/v1/calls/?page=2`), que Dio emploie
    // telle quelle. Comparer `options.path` en entier ferait manquer la
    // deuxième page à cette simulation — et le test se serait alors trompé sur
    // le compte du dépôt.
    final chemin = Uri.parse(options.path).path;

    if (chemin.contains('/calls/orders/')) {
      final kind = (options.data as Map)['kind'] as String;
      return _json(_callJson(kind: kind), 201);
    }
    if (chemin.endsWith('/accept/')) {
      return _json(_callJson(status: 'accepted'), 200);
    }
    if (chemin.endsWith('/decline/')) {
      return _json(_callJson(status: 'declined'), 200);
    }
    if (chemin.endsWith('/end/')) {
      return _json(_callJson(status: 'ended', duration: 55), 200);
    }
    if (chemin.endsWith('/rtc-token/')) {
      return _json(
        {
          'channel_name': 'call-call-1',
          'token': '006-jeton-signe-par-le-serveur',
          'uid': 2,
          'app_id': 'app-agora',
          'expires_in': 3600,
        },
        200,
      );
    }
    if (chemin.endsWith('/calls/')) {
      historyPages++;
      if (historyPages == 1) {
        return _json(
          {
            'count': 2,
            'next': 'http://test.local/api/v1/calls/?page=2',
            'previous': null,
            'results': [_callJson(status: 'ended', duration: 42)],
          },
          200,
        );
      }
      return _json(
        {
          'count': 2,
          'next': null,
          'previous': null,
          'results': [_callJson(id: 'call-2', status: 'missed')],
        },
        200,
      );
    }
    if (chemin.contains('/calls/')) {
      final id = chemin.split('/calls/').last.replaceAll('/', '');
      return _json(_callJson(id: id), 200);
    }

    throw UnimplementedError('Route non simulée : ${options.method} ${options.path}');
  }

  ResponseBody _json(Map<String, dynamic> body, int status) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: _jsonHeaders);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late CallRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    repository = CallRepository(
      apiClient: ApiClient(
        baseUrl: 'http://test.local/api/v1',
        tokenStorage: TokenStorage(),
        testAdapter: server,
      ),
    );
  });

  group('Placer un appel', () {
    test('ne déclare ni destinataire ni canal', () async {
      // Le cœur du contrat : le serveur désigne l'autre partie à partir de la
      // course de la commande. L'implémentation Supabase acceptait un
      // `receiver_id` du client — n'importe quel compte pouvait faire sonner
      // n'importe quel autre.
      await repository.place(orderId: 'order-1');

      expect(server.requests.last, 'POST /calls/orders/order-1/');
      expect(server.bodies.last, {'kind': 'voice'});
      expect(server.bodies.last!.containsKey('receiver_id'), isFalse);
      expect(server.bodies.last!.containsKey('channel'), isFalse);
    });

    test('le type d\'appel voyage, et lui seul', () async {
      await repository.place(orderId: 'order-1', kind: 'video');

      expect(server.bodies.last, {'kind': 'video'});
    });

    test('le canal rendu est celui de l\'appel, pas celui de la commande', () async {
      final appel = await repository.place(orderId: 'order-1');

      // `call-…` et non `order_…` : un canal composé sur l'identifiant de
      // commande laissait rejoindre la conversation de n'importe quelle
      // commande connue, et rouvrait la même pièce à chaque rappel.
      expect(appel.channelName, startsWith('call-'));
      expect(appel.channelName, isNot(contains('order-1')));
      expect(appel.isRinging, isTrue);
      expect(appel.isActive, isTrue);
    });
  });

  group('Répondre, refuser, raccrocher', () {
    test('accept rend l\'appel en cours', () async {
      final appel = await repository.accept('call-1');

      expect(server.requests.last, 'POST /calls/call-1/accept/');
      expect(appel.status, 'accepted');
      expect(appel.isActive, isTrue);
      expect(appel.answeredAt, isNotNull);
    });

    test('decline rend un appel terminé', () async {
      final appel = await repository.decline('call-1');

      expect(appel.status, 'declined');
      expect(appel.isActive, isFalse);
      expect(appel.endedAt, isNotNull);
    });

    test('end rend la durée figée par le serveur', () async {
      // La durée n'est pas recalculée côté client : c'est le serveur qui la
      // fige au raccrochage, et une soustraction refaite à l'écran dériverait
      // de sa valeur.
      final appel = await repository.end('call-1');

      expect(appel.status, 'ended');
      expect(appel.durationSeconds, 55);
    });
  });

  group('Jeton RTC', () {
    test('vient du serveur, avec le uid qu\'il attribue', () async {
      final acces = await repository.rtcCredentials('call-1');

      expect(server.requests.last, 'GET /calls/call-1/rtc-token/');
      expect(acces.token, isNotEmpty);
      // `1` pour l'appelant, `2` pour le destinataire. L'app dérivait cet
      // entier d'un `hashCode` tronqué, qui peut entrer en collision — et deux
      // participants au même uid s'expulsent du canal.
      expect(acces.uid, 2);
      expect(acces.channelName, 'call-call-1');
      expect(acces.expiresIn, 3600);
    });

    test('ne rend jamais le certificat Agora', () async {
      // Il signe les jetons et ne quitte pas le serveur. L'app l'embarquait
      // dans son `.env`, donc dans un binaire distribué : l'extraire suffisait
      // à fabriquer des jetons pour n'importe quel canal.
      final response = await repository.rtcCredentials('call-1');

      expect(response.appId, 'app-agora');
      // `RtcCredentials` n'a pas de champ de certificat — c'est vérifié par la
      // compilation ; ce que ce test garde, c'est l'intention.
      expect(
        RtcCredentials.fromJson({
          'channel_name': 'c',
          'token': 't',
          'uid': 1,
          'app_id': 'a',
          'expires_in': 1,
          'app_certificate': 'ne-doit-pas-etre-lu',
        }).appId,
        'a',
      );
    });
  });

  group('Relecture', () {
    test('getById lit une seule ligne, sans paginer l\'historique', () async {
      // C'est ce qu'on fait sur chaque sonnerie. Parcourir `history()` pour
      // retrouver un appel — ce que faisait l'app cliente — pagine l'historique
      // entier au moment précis où la latence compte le plus, et coûte de plus
      // en plus cher à mesure que le compte accumule des appels.
      final appel = await repository.getById('call-7');

      expect(server.requests, ['GET /calls/call-7/']);
      expect(server.historyPages, 0);
      expect(appel.id, 'call-7');
    });

    test('history suit la pagination jusqu\'au bout', () async {
      final appels = await repository.history();

      expect(appels, hasLength(2));
      expect(server.historyPages, 2);
      expect(appels.first.durationSeconds, 42);
      expect(appels.last.status, 'missed');
    });
  });
}
