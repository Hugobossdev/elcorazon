import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elcora_fast/main.dart' show poserLeConteneurPourTests;
import 'package:elcora_fast/screens/client/delivery_tracking_screen.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/widgets/loading_widget.dart' as etats;

/// Une coupure pendant le suivi, puis le réseau qui revient.
///
/// ## Le défaut que cette suite ferme
///
/// `_errorMessage` n'était **jamais** remis à nul : il n'était écrit que dans
/// le `catch` de la lecture de commande. Or cette lecture se rejoue toutes les
/// dix secondes tant que le canal temps réel n'est pas ouvert — une seule
/// coupure figeait donc l'écran sur sa page d'erreur pour le reste de la
/// livraison, et « Réessayer » n'y changeait rien **même quand la relecture
/// réussissait** : le client voyait une erreur là où son repas avançait.
const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _montant(int mineur) => {'amount': '$mineur', 'currency': 'XOF'};

/// Une commande **en attente** : le serveur ne diffuse pas ce statut
/// (`TRACKABLE_ORDER_STATUSES`), donc aucun canal temps réel ne s'ouvre — c'est
/// l'état le plus courant à l'ouverture de l'écran, juste après le paiement.
Map<String, dynamic> _commandeEnAttente() => {
  'id': 'a1b2c3d4-0000-0000-0000-000000000001',
  'reference': 'EC000065',
  'restaurant': 'el-corazon-lome',
  'restaurant_name': 'El Corazón Lomé',
  'status': 'pending',
  'allowed_transitions': const <String>[],
  'subtotal': _montant(4000),
  'delivery_fee': _montant(500),
  'discount': _montant(0),
  'total': _montant(4500),
  'payment_method': 'cash',
  'delivery_address_line': 'Rue du Commerce',
  'delivery_landmark': '',
  'delivery_location': {'lat': 6.14, 'lon': 1.23},
  'recipient_name': 'Awa',
  'recipient_phone': '+22890000000',
  'placed_at': '2026-09-16T12:00:00Z',
  'created_at': '2026-09-16T12:00:00Z',
  'updated_at': '2026-09-16T12:00:00Z',
};

class _FauxServeur implements HttpClientAdapter {
  bool enPanne = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (enPanne) {
      return ResponseBody.fromString(
        jsonEncode({'detail': 'Le service est momentanément indisponible.'}),
        503,
        headers: _entetesJson,
      );
    }
    if (options.path.contains('/tracking/orders/')) {
      return _json({
        'order': 'a1b2c3d4-0000-0000-0000-000000000001',
        'assignment_status': '',
        'courier': null,
        'last_position': null,
        'estimated_delivery_at': null,
      });
    }
    if (options.path.contains('/orders/')) return _json(_commandeEnAttente());
    return _json(const <String, dynamic>{});
  }

  ResponseBody _json(Object corps) =>
      ResponseBody.fromString(jsonEncode(corps), 200, headers: _entetesJson);
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
  final app = AppService(conteneur);

  setUp(() => serveur.enPanne = false);
  tearDownAll(conteneur.dispose);

  Future<void> ouvrirLeSuivi(WidgetTester tester) async {
    // Une surface de téléphone, et non les 800 × 600 par défaut : cet écran
    // est fait pour être tenu à la main, et le vérifier sur une fenêtre de
    // bureau ne dit rien de ce que le client voit.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppService>.value(
        value: app,
        child: const MaterialApp(
          home: DeliveryTrackingScreen(orderId: 'a1b2c3d4-0000-0000-0000-000000000001'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Démonte l'écran : c'est ce qui annule ses minuteries — et, sur une
  /// commande diffusée, ce qui referme son canal temps réel.
  Future<void> quitter(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('une lecture qui échoue montre le motif du serveur', (tester) async {
    serveur.enPanne = true;

    await ouvrirLeSuivi(tester);

    expect(find.byType(etats.ErrorWidget), findsOneWidget);
    // Le motif du serveur, pas le nom d'une classe Dart : le client qui suit
    // son repas doit savoir s'il faut attendre ou réessayer.
    expect(find.textContaining('serveur'), findsWidgets);

    await quitter(tester);
  });

  testWidgets('la lecture suivante, réussie, efface l’erreur', (tester) async {
    // Le cœur du défaut : l'écran restait sur sa page d'erreur même quand la
    // relecture aboutissait.
    serveur.enPanne = true;
    await ouvrirLeSuivi(tester);
    expect(find.byType(etats.ErrorWidget), findsOneWidget);

    serveur.enPanne = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(etats.ErrorWidget), findsNothing);

    await quitter(tester);
  });

  testWidgets('quitter l’écran n’y laisse aucune minuterie', (tester) async {
    // La relecture périodique bat toutes les dix secondes tant que le canal
    // n'est pas ouvert. Si `dispose` ne l'annulait pas, ce test échouerait sur
    // « A Timer is still pending » — c'est le filet qui garde la sortie propre.
    await ouvrirLeSuivi(tester);

    await quitter(tester);

    expect(find.byType(DeliveryTrackingScreen), findsNothing);
  });
}
