import 'dart:convert';

import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/marketing_service.dart';
import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Programmer et déprogrammer depuis le service de l'écran des campagnes.
///
/// Le cas qui compte est la course avec le battement : la campagne part au
/// moment où l'on clique. Le serveur refuse (409) ; l'écran doit alors
/// montrer « Envoyée », et non laisser un bouton qui échouera à chaque clic.
const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _campagne(String statut) => {
      'id': 'c-1',
      'title': '−20 % ce midi',
      'body': 'Jusqu’à 14 h.',
      'audience': 'all_customers',
      'audience_label': 'Tous les clients',
      'segment_days': 30,
      'status': statut,
      'scheduled_at': statut == 'scheduled' ? '2026-09-21T18:00:00Z' : null,
      'sent_at': statut == 'sent' ? '2026-09-21T18:02:00Z' : null,
      'recipient_count': statut == 'sent' ? 120 : 0,
      'created_by_email': 'siege@elcorazon.test',
      'created_at': '2026-09-20T08:00:00Z',
      'updated_at': '2026-09-20T08:00:00Z',
    };

class _FauxServeur implements HttpClientAdapter {
  /// L'état de la campagne côté serveur.
  String etat = 'scheduled';

  /// Refuser les gestes en 409, comme quand la campagne vient de partir.
  bool partieEntreTemps = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ResponseBody json(Object corps, [int statut = 200]) =>
        ResponseBody.fromString(jsonEncode(corps), statut, headers: _entetesJson);

    if (options.method == 'POST' && partieEntreTemps) {
      etat = 'sent';
      return json(
        {
          'code': 'business_rule_violation',
          'detail': 'Seule une campagne programmée s’annule.',
        },
        409,
      );
    }
    if (options.path.endsWith('/unschedule/')) {
      etat = 'draft';
      return json(_campagne(etat));
    }
    if (options.path.endsWith('/schedule/')) {
      etat = 'scheduled';
      return json(_campagne(etat));
    }
    if (options.path == '/notifications/campaigns/') {
      return json({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [_campagne(etat)],
      });
    }
    return json(_campagne(etat));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_canalStockage, (call) async => null);

  final serveur = _FauxServeur();
  final conteneur = ProviderContainer(
    overrides: [
      eccore.apiClientProvider.overrideWithValue(
        eccore.ApiClient(
          baseUrl: 'https://exemple.test/api/v1',
          tokenStorage: eccore.TokenStorage(),
          testAdapter: serveur,
        ),
      ),
    ],
  );
  AdminAuthService(conteneur);
  tearDownAll(conteneur.dispose);

  setUp(() {
    serveur
      ..etat = 'scheduled'
      ..partieEntreTemps = false;
  });

  test('annuler la programmation rend un brouillon', () async {
    final sut = MarketingService();
    await sut.refresh();

    final ok = await sut.unscheduleCampaign('c-1');

    expect(ok, isTrue);
    expect(sut.campaigns.single.isDraft, isTrue);
    expect(sut.scheduled, isEmpty);
    expect(sut.error, isNull);
  });

  test('partie entre-temps : le refus est dit, et la campagne relue « Envoyée »', () async {
    final sut = MarketingService();
    await sut.refresh();
    serveur.partieEntreTemps = true;

    final ok = await sut.unscheduleCampaign('c-1');

    expect(ok, isFalse);
    expect(sut.error, contains('programmée'));
    // Sans la relecture, l'écran gardait « Programmée » et son bouton
    // « Annuler la programmation », qui échouait à chaque clic.
    expect(sut.campaigns.single.isSent, isTrue);
  });

  test('programmer un brouillon le fait passer « Programmée »', () async {
    serveur.etat = 'draft';
    final sut = MarketingService();
    await sut.refresh();

    final ok = await sut.scheduleCampaign('c-1', DateTime.utc(2026, 9, 21, 18));

    expect(ok, isTrue);
    expect(sut.campaigns.single.isScheduled, isTrue);
  });
}
