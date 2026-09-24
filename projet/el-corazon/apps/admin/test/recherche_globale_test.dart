import 'dart:convert';

import 'package:admin/screens/admin/global_search_screen.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/client_management_service.dart';
import 'package:admin/services/driver_management_service.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// La recherche globale du back-office.
///
/// ## Les défauts que cette suite ferme
///
/// * Décocher un filtre levait `Unsupported operation` : l'ensemble des
///   filtres était la liste constante `SearchCategory.values`.
/// * Un client trouvé ouvrait la liste de **tous** les clients, où il fallait
///   le retrouver à la main.
/// * Une panne de la recherche s'affichait « Aucun résultat trouvé ».
const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
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
    ResponseBody json(Object corps, [int statut = 200]) =>
        ResponseBody.fromString(jsonEncode(corps), statut, headers: _entetesJson);

    final chemin = options.path;
    if (chemin.endsWith('/search/')) {
      if (enPanne) {
        return ResponseBody.fromString(
          jsonEncode({'title': 'Erreur', 'status': 500, 'detail': 'Service indisponible.'}),
          500,
          headers: {
            Headers.contentTypeHeader: ['application/problem+json'],
          },
        );
      }
      return json([
        {'kind': 'customer', 'id': 'client-1', 'title': 'Kofi Mensah', 'subtitle': 'kofi@exemple.tg'},
        {'kind': 'courier', 'id': 'livreur-1', 'title': 'Kofi Livreur', 'subtitle': 'Moto'},
      ]);
    }
    if (chemin.endsWith('/administration/customers/client-1/notes/')) return json(<dynamic>[]);
    if (chemin.endsWith('/administration/customers/client-1/')) {
      return json({
        'id': 'client-1',
        'email': 'kofi@exemple.tg',
        'phone': '+22890000000',
        'full_name': 'Kofi Mensah',
        'avatar': null,
        'is_active': true,
        'email_verified_at': null,
        'phone_verified_at': null,
        'last_seen_at': null,
        'created_at': '2026-09-01T10:00:00Z',
        'updated_at': '2026-09-01T10:00:00Z',
      });
    }
    if (chemin.endsWith('/analytics/reports/customers/client-1/')) {
      return json({
        'orders_count': 7,
        'orders_delivered': 6,
        'orders_cancelled': 1,
        'total_spent': {'amount': '42000', 'currency': 'XOF'},
        'average_basket': {'amount': '7000', 'currency': 'XOF'},
        'first_order_at': null,
        'last_order_at': null,
        'addresses_count': 2,
        'loyalty_balance': 120,
        'loyalty_lifetime_earned': 300,
      });
    }
    return json({'detail': 'Introuvable.'}, 404);
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
  final auth = AdminAuthService(conteneur);

  setUp(() => serveur.enPanne = false);
  tearDownAll(conteneur.dispose);

  Future<void> ouvrirLaRecherche(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AdminAuthService>.value(value: auth),
          ChangeNotifierProvider(create: (_) => OrderManagementService()),
          ChangeNotifierProvider(create: (_) => ClientManagementService()),
          ChangeNotifierProvider(create: (_) => DriverManagementService()),
        ],
        child: const MaterialApp(home: GlobalSearchScreen()),
      ),
    );
  }

  Future<void> chercher(WidgetTester tester, String texte) async {
    await tester.enterText(find.byType(TextField), texte);
    await tester.pumpAndSettle();
  }

  testWidgets('en deçà de trois caractères, l’écran dit ce qui manque', (tester) async {
    await ouvrirLaRecherche(tester);
    await chercher(tester, 'ko');

    expect(find.text('Encore 1 caractère…'), findsOneWidget);
    expect(find.text('Aucun résultat trouvé'), findsNothing);
  });

  testWidgets('décocher un filtre masque sa famille, sans lever', (tester) async {
    await ouvrirLaRecherche(tester);
    await chercher(tester, 'kofi');
    expect(find.text('Kofi Mensah'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Clients'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Kofi Mensah'), findsNothing);
    expect(find.text('Kofi Livreur'), findsOneWidget);
  });

  testWidgets('tout décocher ne se lit pas comme une recherche vaine', (tester) async {
    await ouvrirLaRecherche(tester);
    await chercher(tester, 'kofi');

    for (final filtre in ['Commandes', 'Produits', 'Clients', 'Livreurs']) {
      await tester.tap(find.widgetWithText(FilterChip, filtre));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('catégories décochées'), findsOneWidget);
  });

  testWidgets('un client trouvé ouvre sa fiche, pas la liste', (tester) async {
    await ouvrirLaRecherche(tester);
    await chercher(tester, 'kofi');

    await tester.tap(find.text('Kofi Mensah'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Kofi Mensah')),
      findsOneWidget,
    );
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('une panne se dit, avec de quoi réessayer', (tester) async {
    serveur.enPanne = true;
    await ouvrirLaRecherche(tester);
    await chercher(tester, 'kofi');

    expect(find.text('Recherche impossible'), findsOneWidget);
    expect(find.text('Aucun résultat trouvé'), findsNothing);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
