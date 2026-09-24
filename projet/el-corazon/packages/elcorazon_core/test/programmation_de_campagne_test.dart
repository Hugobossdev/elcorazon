import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Programmer une campagne — `POST /notifications/campaigns/{id}/schedule/`.
///
/// Le serveur savait dater un envoi depuis le 20 septembre ; aucune
/// application ne l'appelait, et une campagne programmée s'affichait
/// « Brouillon » : le modèle ne connaissait que deux états.
const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _campagne({String statut = 'draft', String? programmeeA}) => {
      'id': 'campagne-1',
      'title': '−20 % ce midi',
      'body': 'Jusqu’à 14 h.',
      'audience': 'all_customers',
      'audience_label': 'Tous les clients',
      'segment_days': 30,
      'status': statut,
      'scheduled_at': programmeeA,
      'sent_at': null,
      'recipient_count': 0,
      'created_by_email': 'siege@elcorazon.test',
      'created_at': '2026-09-20T08:00:00Z',
      'updated_at': '2026-09-20T08:00:00Z',
    };

class _FauxServeur implements HttpClientAdapter {
  final List<String> appels = [];
  final List<Object?> corps = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    appels.add('${options.method} ${options.path}');
    corps.add(options.data);
    final reponse = options.path.endsWith('/schedule/')
        ? _campagne(statut: 'scheduled', programmeeA: '2026-09-21T18:00:00Z')
        : _campagne();
    return ResponseBody.fromString(jsonEncode(reponse), 200, headers: _entetesJson);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FauxServeur serveur;
  late CampaignRepository depot;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canalStockage, (call) async => null);
    serveur = _FauxServeur();
    depot = CampaignRepository(
      apiClient: ApiClient(
        baseUrl: 'http://test.local/api/v1',
        tokenStorage: TokenStorage(),
        testAdapter: serveur,
      ),
    );
  });

  group('Le modèle', () {
    test('une campagne programmée n’est ni un brouillon ni envoyée', () {
      final campagne = Campaign.fromJson(
        _campagne(statut: 'scheduled', programmeeA: '2026-09-21T18:00:00Z'),
      );

      expect(campagne.isScheduled, isTrue);
      expect(campagne.isDraft, isFalse);
      expect(campagne.isSent, isFalse);
      expect(campagne.scheduledAt, DateTime.utc(2026, 9, 21, 18));
    });

    test('un brouillon n’a pas d’heure d’envoi', () {
      final campagne = Campaign.fromJson(_campagne());

      expect(campagne.scheduledAt, isNull);
      expect(campagne.isScheduled, isFalse);
    });
  });

  group('Le dépôt', () {
    test('programmer envoie l’instant en UTC, fuseau compris', () async {
      // 19 h à UTC+1 : le serveur doit lire 18 h UTC, pas 19 h « sans fuseau ».
      final instant = DateTime.parse('2026-09-21T19:00:00+01:00');

      final campagne = await depot.schedule('campagne-1', at: instant);

      expect(serveur.appels.single, 'POST /notifications/campaigns/campagne-1/schedule/');
      expect(
        (serveur.corps.single! as Map)['scheduled_at'],
        '2026-09-21T18:00:00.000Z',
      );
      expect(campagne.isScheduled, isTrue);
    });

    test('déprogrammer vise sa propre route, sans corps', () async {
      final campagne = await depot.unschedule('campagne-1');

      expect(serveur.appels.single, 'POST /notifications/campaigns/campagne-1/unschedule/');
      expect(campagne.isDraft, isTrue);
    });
  });
}
