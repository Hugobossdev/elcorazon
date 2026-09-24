import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elcora_fast/main.dart' show poserLeConteneurPourTests;
import 'package:elcora_fast/screens/client/payment_screen.dart';

/// L'écran de paiement mobile money, contre un serveur simulé.
///
/// Trois engagements du contrat client, vérifiés sur l'écran lui-même :
///
/// * « paiement réussi » ne s'affiche **jamais** avant que le serveur ait lu
///   l'encaissement — la transaction, pas le retour du client ;
/// * il s'affiche quand le serveur la dit encaissée ;
/// * passé le délai de sondage, le client peut relancer la vérification — il
///   restait jusqu'ici devant « Toujours en attente », et l'écran ne se
///   redessinait même pas à l'échéance.
const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};
const _commandeId = 'a1b2c3d4-0000-0000-0000-000000000042';

Map<String, dynamic> _montant(int mineur) => {'amount': '$mineur', 'currency': 'XOF'};

Map<String, dynamic> _commande() => {
      'id': _commandeId,
      'reference': 'EC000042',
      'restaurant': 'el-corazon-lome',
      'restaurant_name': 'El Corazón Lomé',
      'status': 'pending',
      'allowed_transitions': const <String>[],
      'subtotal': _montant(4000),
      'delivery_fee': _montant(500),
      'discount': _montant(0),
      'total': _montant(4500),
      'payment_method': 'mobile_money',
      'delivery_address_line': 'Rue du Commerce',
      'delivery_landmark': '',
      'delivery_location': {'lat': 6.14, 'lon': 1.23},
      'recipient_name': 'Awa',
      'recipient_phone': '+22890000000',
      'placed_at': '2026-09-24T12:00:00Z',
      'created_at': '2026-09-24T12:00:00Z',
      'updated_at': '2026-09-24T12:00:00Z',
    };

Map<String, dynamic> _transaction(String statut) => {
      'id': 'txn-42',
      'order': _commandeId,
      'provider': 'paydunya',
      'provider_reference': 'SBX-42',
      'amount': _montant(4500),
      'status': statut,
      'completed_at': statut == 'completed' ? '2026-09-24T12:03:00Z' : null,
      'failure_reason': '',
      'created_at': '2026-09-24T12:00:00Z',
      'updated_at': '2026-09-24T12:00:00Z',
    };

class _FauxServeur implements HttpClientAdapter {
  /// Ce que le prestataire a fait savoir au serveur, tel que `/transactions/`
  /// le rend.
  String statut = 'processing';
  int lectures = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/initiate/')) {
      return _json({
        'transaction': _transaction('processing'),
        'checkout_url': 'https://sandbox.test/checkout/txn-42',
        'instructions': 'Validez la demande reçue sur votre téléphone.',
      }, 201,);
    }
    if (options.path.contains('/payments/transactions/')) {
      lectures++;
      return _json({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [_transaction(statut)],
      });
    }
    if (options.path.contains('/orders/')) return _json(_commande());
    return _json(const <String, dynamic>{});
  }

  ResponseBody _json(Object corps, [int code = 200]) =>
      ResponseBody.fromString(jsonEncode(corps), code, headers: _entetesJson);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_canalStockage, (call) async => null);
  SharedPreferences.setMockInitialValues(const {});

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
      eccore.expectedUserTypeProvider.overrideWithValue(eccore.UserAccountType.customer),
    ],
  );
  poserLeConteneurPourTests(conteneur);
  tearDownAll(conteneur.dispose);

  setUp(() {
    serveur
      ..statut = 'processing'
      ..lectures = 0;
  });

  Future<void> ouvrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: PaymentScreen(orderId: _commandeId)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Démonte l'écran : c'est ce qui annule son sondage.
  Future<void> fermer(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('tant que le serveur n’a rien encaissé, rien n’est annoncé réglé', (tester) async {
    await ouvrir(tester);
    await tester.pump(const Duration(seconds: 10));

    expect(serveur.lectures, greaterThan(0), reason: 'la transaction est bien relue');
    expect(find.text('Paiement confirmé'), findsNothing);
    expect(find.text('Confirmez sur votre téléphone'), findsOneWidget);

    await fermer(tester);
  });

  testWidgets('l’encaissement lu sur le serveur, et lui seul, confirme', (tester) async {
    await ouvrir(tester);
    serveur.statut = 'completed';
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('Paiement confirmé'), findsOneWidget);

    // L'écran se referme de lui-même deux secondes plus tard.
    await tester.pump(const Duration(seconds: 3));
    await fermer(tester);
  });

  testWidgets('passé le délai, la vérification se relance à la demande', (tester) async {
    await ouvrir(tester);
    await tester.pump(const Duration(minutes: 2, seconds: 4));

    expect(find.text('Toujours en attente'), findsOneWidget);
    final avant = serveur.lectures;

    serveur.statut = 'completed';
    await tester.tap(find.text('Vérifier à nouveau'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(serveur.lectures, greaterThan(avant));
    expect(find.text('Paiement confirmé'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await fermer(tester);
  });
}
