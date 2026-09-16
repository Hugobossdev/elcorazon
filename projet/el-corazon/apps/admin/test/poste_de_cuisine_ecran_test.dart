import 'dart:convert';

import 'package:admin/screens/kitchen/kitchen_screen.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/dashboard_realtime_service.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'aide_commande.dart';

/// Le poste de cuisine à l'écran — ses trois états, et ce qu'il montre.
///
/// ## Ce que l'écran ne montrait pas
///
/// Il lisait la fenêtre de supervision, qui ne porte pas les lignes : chaque
/// carte affichait « 3 article(s) ». Un poste de cuisine qui ne dit pas ce
/// qu'il faut préparer n'a pas d'usage — c'était le défaut le plus visible de
/// la vague précédente.
///
/// Il confondait aussi la panne et le service calme : `refresh()` avalait les
/// erreurs, si bien que le bandeau prévu pour les afficher ne pouvait jamais
/// apparaître.
const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

class _FauxServeur implements HttpClientAdapter {
  List<Map<String, dynamic>> file = const [];
  bool enPanne = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (enPanne && options.path.contains('/orders/manage/kitchen/')) {
      return ResponseBody.fromString(
        jsonEncode({'detail': 'Le service est momentanément indisponible.'}),
        503,
        headers: _entetesJson,
      );
    }
    final lignes = options.path.contains('/orders/manage/kitchen/') ? file : const [];
    return ResponseBody.fromString(
      jsonEncode({'count': lignes.length, 'next': null, 'previous': null, 'results': lignes}),
      200,
      headers: _entetesJson,
    );
  }
}

eccore.ManagedRestaurant _cuisineDeLome() => const eccore.ManagedRestaurant(
  id: 'id-lome',
  name: 'El Corazón Lomé',
  slug: 'el-corazon-lome',
  zoneId: 'z',
  address: 'Lomé',
  latitude: 6.13,
  longitude: 1.22,
  currency: 'XOF',
  timezone: 'Africa/Lome',
  status: eccore.RestaurantLifecycle.active,
  isActive: true,
  acceptsOrders: true,
  defaultPreparationMinutes: 20,
);

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

  setUp(() {
    serveur
      ..file = const []
      ..enPanne = false;
  });
  tearDownAll(conteneur.dispose);

  Future<void> ouvrirLePoste(WidgetTester tester) async {
    final temsReel = DashboardRealtimeService.pourTests();
    addTearDown(temsReel.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => OrderManagementService()),
          ChangeNotifierProvider<DashboardRealtimeService>.value(value: temsReel),
        ],
        child: MaterialApp(home: KitchenScreen(restaurant: _cuisineDeLome())),
      ),
    );
    // Deux passes : la première monte l'écran, la seconde laisse la lecture du
    // poste aboutir.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('il montre les plats, pas un nombre d’articles', (tester) async {
    serveur.file = [
      commandeCuisineJson(
        reference: 'EC000123',
        lignes: [
          ligneCuisineJson(
            nom: 'Burger Corazón',
            options: ['À point'],
            note: 'Sans oignons',
          ),
          ligneCuisineJson(nom: 'Jus de bissap', quantite: 1),
        ],
      ),
    ];

    await ouvrirLePoste(tester);

    expect(find.text('EC000123'), findsOneWidget);
    expect(find.text('Burger Corazón'), findsOneWidget);
    expect(find.text('Jus de bissap'), findsOneWidget);
    // Les options décident du contenu de l'assiette ; la remarque aussi.
    expect(find.text('À point'), findsOneWidget);
    expect(find.text('Sans oignons'), findsOneWidget);
    // Le repli qui tenait lieu de contenu n'a plus lieu d'être.
    expect(find.textContaining('article(s)'), findsNothing);
  });

  testWidgets('un service calme affiche des colonnes vides, sans erreur', (tester) async {
    await ouvrirLePoste(tester);

    expect(find.text('Confirmées'), findsOneWidget);
    expect(find.text('En préparation'), findsOneWidget);
    expect(find.textContaining('Liste non rafraîchie'), findsNothing);
  });

  testWidgets('une panne se voit, avec de quoi réessayer', (tester) async {
    // Le bandeau existait déjà ; il ne pouvait jamais s'afficher, parce que le
    // service avalait l'erreur avant que l'écran ne la voie.
    serveur.enPanne = true;

    await ouvrirLePoste(tester);

    expect(find.textContaining('Liste non rafraîchie'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('la panne ne fait pas disparaître le service en cours', (tester) async {
    serveur.file = [commandeCuisineJson(reference: 'EC000200')];
    await ouvrirLePoste(tester);
    expect(find.text('EC000200'), findsOneWidget);

    serveur.enPanne = true;
    await tester.tap(find.byTooltip('Actualiser'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // La commande reste : en plein service, un poste qui se vide sur une
    // coupure de trois secondes est pire qu'un poste périmé qui le dit.
    expect(find.text('EC000200'), findsOneWidget);
    expect(find.textContaining('Liste non rafraîchie'), findsOneWidget);
  });
}
