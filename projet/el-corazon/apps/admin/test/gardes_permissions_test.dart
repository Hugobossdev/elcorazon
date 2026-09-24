import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:admin/screens/admin/category_management_screen.dart';
import 'package:admin/screens/admin/driver_schedule_screen.dart';
import 'package:admin/screens/admin/fermetures_exceptionnelles.dart';
import 'package:admin/screens/admin/settings_screen.dart';
import 'package:admin/screens/admin/zone_selection_tab.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/category_management_service.dart';
import 'package:admin/services/delivery_zone_service.dart';
import 'package:admin/services/driver_schedule_service.dart';
import 'package:admin/services/opening_hours_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';

/// Ce que le back-office **présente**, selon les droits du compte — ADR-005.
///
/// ## Pourquoi ces cas existent
///
/// Rien ici n'est une sécurité : le serveur vérifie chaque permission sur
/// chaque route, et c'est lui qui refuse. Ce qui se vérifie ici est la
/// promesse : un écran qui offre « Supprimer » à qui ne peut pas supprimer
/// fait remplir un formulaire, poser une question au client, ou annoncer un
/// geste — avant de rendre un 403 que l'opérateur lit comme une panne.
///
/// L'audit du 21 septembre 2026 avait relevé quarante écrans dans ce cas. Ces
/// cas-ci couvrent les trois familles corrigées le 23 : le catalogue
/// (`catalog.write`), l'exploitation d'une cuisine (`restaurants.operate`) et
/// la flotte (`couriers.write`).
const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

class _ServeurMuet implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'DELETE') {
      return ResponseBody.fromString('', 204, headers: _entetesJson);
    }
    // Une zone ouverte : sans elle, l'écran des zones n'a aucun interrupteur
    // dont on puisse vérifier qu'il se manipule — ou non.
    if (options.path.contains('geography/manage/zones')) {
      return ResponseBody.fromString(
        jsonEncode({
          'count': 1,
          'next': null,
          'previous': null,
          'results': [_zoneOuverte],
        }),
        200,
        headers: _entetesJson,
      );
    }
    // Une page vide : ces cas portent sur les **gestes offerts**, pas sur le
    // contenu. Un écran vide les montre tout aussi bien.
    return ResponseBody.fromString(
      jsonEncode({'count': 0, 'next': null, 'previous': null, 'results': <dynamic>[]}),
      200,
      headers: _entetesJson,
    );
  }
}

const _zoneOuverte = {
  'id': 'zone-be',
  'city': 'ville-lome',
  'name': 'Bè',
  'boundary': null,
  'base_fee': {'amount': '500', 'currency': 'XOF'},
  'fee_per_km': {'amount': '100', 'currency': 'XOF'},
  'free_delivery_threshold': null,
  'min_order_amount': null,
  'max_distance_km': '8.00',
  'estimated_delivery_minutes': 30,
  'is_active': true,
};

eccore.ManagedRestaurant _lome() => const eccore.ManagedRestaurant(
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

eccore.CourierProfile _livreur() => eccore.CourierProfile.fromJson({
      'id': 'livreur-1',
      'full_name': 'Kofi A.',
      'email': 'kofi@elcorazon.test',
      'phone': '+22890000000',
      'restaurant': 'el-corazon-lome',
      'verification_status': 'approved',
      'id_document': null,
      'licence_document': null,
      'vehicle_document': null,
      'verification_notes': '',
      'verified_at': null,
      'vehicle_type': 'motorcycle',
      'vehicle_plate': '',
      'is_online': true,
      'can_accept_orders': true,
      'last_location': null,
      'last_location_at': null,
      'deliveries_completed': 0,
      'deliveries_cancelled': 0,
      'rating_average': '0.0',
      'rating_count': 0,
      'total_earnings': null,
      'created_at': '2026-09-01T10:00:00Z',
      'updated_at': '2026-09-07T10:00:00Z',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_canalStockage, (call) async => null);

  final conteneur = ProviderContainer(
    overrides: [
      eccore.apiClientProvider.overrideWithValue(
        eccore.ApiClient(
          baseUrl: 'https://exemple.test/api/v1',
          tokenStorage: eccore.TokenStorage(),
          testAdapter: _ServeurMuet(),
        ),
      ),
    ],
  );
  final auth = AdminAuthService(conteneur);
  SharedPreferences.setMockInitialValues({});

  tearDown(() {
    auth.permissionsDeTest = null;
    auth.siegeDeTest = null;
  });
  tearDownAll(conteneur.dispose);

  Future<void> monter(WidgetTester tester, Widget ecran, List<String> droits) async {
    auth.permissionsDeTest = droits;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AdminAuthService>.value(value: auth),
          ChangeNotifierProvider(create: (_) => CategoryManagementService()),
          ChangeNotifierProvider(create: (_) => DriverScheduleService()),
          // Instance unique de l'application : `.value`, pour que le démontage
          // d'un cas ne la libère pas sous le suivant.
          ChangeNotifierProvider<DeliveryZoneService>.value(value: DeliveryZoneService()),
          ChangeNotifierProvider(create: (_) => OpeningHoursService()),
          ChangeNotifierProvider<RestaurantScopeService>(
            create: (_) => RestaurantScopeService.avecLecture(() async => [_lome()])..resolve(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('fr'), Locale('en')],
          home: ecran,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Le catalogue — catalog.write', () {
    testWidgets('un opérateur qui lit la carte ne se voit pas la tenir', (tester) async {
      // Le rôle « Opérateur » porte `catalog.read` et non `catalog.write` : il
      // consulte la carte sans la changer.
      await monter(tester, const CategoryManagementScreen(), ['catalog.read']);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.textContaining('Lecture seule'), findsOneWidget);
      // Et l'écran vide ne propose pas non plus de créer.
      expect(find.text('Créer une catégorie'), findsNothing);
    });

    testWidgets('un gérant tient la carte', (tester) async {
      await monter(
        tester,
        const CategoryManagementScreen(),
        ['catalog.read', 'catalog.write'],
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.textContaining('Lecture seule'), findsNothing);
    });
  });

  group('L’exploitation d’une cuisine — restaurants.operate', () {
    testWidgets('sans le droit, aucune fermeture ne se pose', (tester) async {
      await monter(
        tester,
        const Scaffold(
          body: FermeturesExceptionnelles(restaurantId: 'r1', nomCuisine: 'Lomé'),
        ),
        ['restaurants.read'],
      );

      expect(find.text('Fermer'), findsNothing);
    });

    testWidgets('le gérant ferme sa cuisine', (tester) async {
      // `restaurants.operate` a été créée le 22 septembre pour ce geste
      // précis : le rôle « Manager » n'avait que `restaurants.read`, et
      // l'écran des horaires lui rendait un 403. Lui donner
      // `restaurants.write` aurait été pire — il aurait pu relever son propre
      // plafond d'ajustement de stock.
      await monter(
        tester,
        const Scaffold(
          body: FermeturesExceptionnelles(restaurantId: 'r1', nomCuisine: 'Lomé'),
        ),
        ['restaurants.read', 'restaurants.operate'],
      );

      expect(find.text('Fermer'), findsOneWidget);
    });

    testWidgets('le siège aussi, avec restaurants.write', (tester) async {
      await monter(
        tester,
        const Scaffold(
          body: FermeturesExceptionnelles(restaurantId: 'r1', nomCuisine: 'Lomé'),
        ),
        ['restaurants.write'],
      );

      expect(find.text('Fermer'), findsOneWidget);
    });
  });

  group('La flotte — couriers.write', () {
    testWidgets('le planning est en lecture seule sans le droit', (tester) async {
      await monter(tester, DriverScheduleScreen(driver: _livreur()), ['couriers.read']);

      expect(find.textContaining('Lecture seule'), findsOneWidget);
      final ajouter = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Ajouter').first,
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        ),
      );
      expect(ajouter.onPressed, isNull);
    });

    testWidgets('avec le droit, les créneaux se posent', (tester) async {
      await monter(
        tester,
        DriverScheduleScreen(driver: _livreur()),
        ['couriers.read', 'couriers.write'],
      );

      expect(find.textContaining('Lecture seule'), findsNothing);
      final ajouter = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Ajouter').first,
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        ),
      );
      expect(ajouter.onPressed, isNotNull);
    });
  });

  // Une zone n'appartient à aucun établissement : l'ouvrir, la fermer ou la
  // tarifer exige `restaurants.write` **et** le siège (`assert_unscoped`).
  // Un gérant voyait les interrupteurs et recevait un 403 à chaque bascule.
  group('Les zones — le siège', () {
    Widget onglet() => const Scaffold(body: ZoneSelectionTab());

    testWidgets('un gérant les lit sans pouvoir les régler', (tester) async {
      auth.siegeDeTest = false;
      await monter(tester, onglet(), ['restaurants.read', 'restaurants.write']);

      expect(find.text('Bè'), findsOneWidget);
      expect(find.textContaining('Lecture seule'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged, isNull);
      expect(find.text('Tout fermer'), findsNothing);
      expect(find.byIcon(Icons.tune), findsNothing);
    });

    testWidgets('le siège les règle', (tester) async {
      auth.siegeDeTest = true;
      await monter(tester, onglet(), ['restaurants.read', 'restaurants.write']);

      expect(find.textContaining('Lecture seule'), findsNothing);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged, isNotNull);
      expect(find.text('Tout fermer'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
    });
  });

  // L'écran s'ouvre à tout le personnel pour « Sécurité », réglage du poste ;
  // les autres onglets lisent le serveur, et ne s'offrent qu'à qui peut lire.
  group('Les paramètres — ce que le compte peut lire', () {
    testWidgets('sans droit sur les établissements, seule la sécurité', (tester) async {
      await monter(tester, const SettingsScreen(), ['orders.read']);

      expect(find.text('Sécurité'), findsWidgets);
      expect(find.text('Zones'), findsNothing);
      expect(find.text('Tarifs'), findsNothing);
      expect(find.text('Horaires'), findsNothing);
      // Le seul onglet est celui qui s'enregistre : le bouton est là.
      expect(find.text('Enregistrer'), findsOneWidget);
    });

    testWidgets('le gérant d’une cuisine règle ses horaires', (tester) async {
      await monter(tester, const SettingsScreen(), ['restaurants.operate']);

      expect(find.text('Horaires'), findsOneWidget);
      expect(find.text('Zones'), findsNothing);
      // Le premier onglet n'est plus « Sécurité » : pas de bouton global.
      expect(find.text('Enregistrer'), findsNothing);
    });

    testWidgets('qui lit les établissements voit les quatre', (tester) async {
      await monter(tester, const SettingsScreen(), ['restaurants.read']);

      for (final titre in ['Zones', 'Tarifs', 'Horaires', 'Sécurité']) {
        expect(find.text(titre), findsOneWidget, reason: titre);
      }
    });
  });
}
