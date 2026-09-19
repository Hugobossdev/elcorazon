import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les sorties d'argent instruites par le back-office.
///
/// `WithdrawalService.settle` n'avait aucun appelant : une demande de retrait
/// débitait les gains du livreur et restait en attente pour toujours. Ces tests
/// gardent le contrat du dépôt qui l'appelle enfin — ce qu'il envoie, et ce
/// qu'il lit.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _retraitJson({String status = 'pending', String reference = ''}) => {
      'id': 'retrait-1',
      'courier': 'livreur-1',
      'courier_name': 'Kodjo Mensah',
      'courier_phone': '+22890000001',
      'restaurant': 'el-corazon-lome',
      'restaurant_name': 'El Corazón Lomé',
      'amount': {'amount': '4000', 'currency': 'XOF'},
      'status': status,
      'provider_reference': reference,
      'failure_reason': '',
      'processed_by_name': status == 'pending' ? null : 'Awa K.',
      'completed_at': status == 'completed' ? '2026-09-18T10:00:00Z' : null,
      'created_at': '2026-09-18T09:00:00Z',
      'updated_at': '2026-09-18T09:00:00Z',
    };

class _FakeServer implements HttpClientAdapter {
  final List<String> requests = [];
  final List<Map<String, dynamic>> queries = [];
  final List<Object?> bodies = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    queries.add(Map<String, dynamic>.from(options.queryParameters));
    bodies.add(options.data);

    final Object corps;
    if (options.path.endsWith('/settle/') && options.path.contains('withdrawals')) {
      final ref = (options.data as Map)['provider_reference'] as String;
      corps = _retraitJson(status: 'completed', reference: ref);
    } else if (options.path.endsWith('/reject/')) {
      corps = _retraitJson(status: 'failed');
    } else if (options.path.endsWith('/settle/')) {
      corps = {
        'id': 'rb-1',
        'order': 'commande-1',
        'order_reference': 'EC000042',
        'restaurant_name': 'El Corazón Lomé',
        'customer_name': 'Ama K.',
        'customer_phone': null,
        'transaction': 'txn-1',
        'provider': 'cash',
        'amount': {'amount': '1000', 'currency': 'XOF'},
        'reason': 'Plat manquant',
        'status': 'completed',
        'requested_by_name': 'Awa K.',
        'completed_at': '2026-09-18T10:00:00Z',
        'created_at': '2026-09-18T09:00:00Z',
      };
    } else if (options.path.contains('withdrawals')) {
      corps = {
        'count': 1,
        'next': null,
        'previous': null,
        'results': [_retraitJson()],
      };
    } else {
      corps = {'count': 0, 'next': null, 'previous': null, 'results': <Object>[]};
    }
    return ResponseBody.fromString(jsonEncode(corps), 200, headers: _jsonHeaders);
  }
}

ManagedPayoutRepository _depot(_FakeServer server) => ManagedPayoutRepository(
      apiClient: ApiClient(
        baseUrl: 'http://test.local/api/v1',
        tokenStorage: TokenStorage(),
        testAdapter: server,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  test('la liste « à verser » filtre côté serveur', () async {
    // Filtrer une page déjà reçue ne répondrait que pour ses cinquante lignes.
    final server = _FakeServer();

    final page = await _depot(server).withdrawals(status: StatutVersement.enAttente);

    expect(server.queries.single['status'], 'pending');
    final retrait = page.results.single;
    expect(retrait.aInstruire, isTrue);
    expect(retrait.amount.amountMinor, 4000);
    expect(retrait.courierPhone, '+22890000001');
    expect(retrait.processedByName, isNull);
  });

  test('constater envoie la référence du virement, et lit la signature', () async {
    final server = _FakeServer();

    final solde = await _depot(server).settleWithdrawal(
      withdrawalId: 'retrait-1',
      providerReference: 'PD-VIR-42',
    );

    expect(server.requests.single, 'POST /payments/manage/withdrawals/retrait-1/settle/');
    expect(server.bodies.single, {'provider_reference': 'PD-VIR-42'});
    expect(solde.status, StatutVersement.verse);
    expect(solde.aInstruire, isFalse);
    expect(solde.processedByName, 'Awa K.');
  });

  test('refuser envoie le motif', () async {
    final server = _FakeServer();

    final refuse = await _depot(server).rejectWithdrawal(
      withdrawalId: 'retrait-1',
      reason: 'Numéro invalide',
    );

    expect(server.bodies.single, {'reason': 'Numéro invalide'});
    expect(refuse.status, StatutVersement.refuse);
  });

  test('un remboursement rendu au comptoir se constate sans référence', () async {
    // Une chaîne vide envoyée serait une référence vide jointe au motif.
    final server = _FakeServer();

    final rembourse = await _depot(server).settleRefund(refundId: 'rb-1', providerReference: '  ');

    expect(server.bodies.single, isEmpty);
    expect(rembourse.aVerser, isFalse);
    expect(rembourse.provider, 'cash');
  });

  test('un statut inconnu s’affiche tel quel', () {
    expect(StatutVersement.libelle('pending'), 'À verser');
    expect(StatutVersement.libelle('inedit'), 'inedit');
  });
}
