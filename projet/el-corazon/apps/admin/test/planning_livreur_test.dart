import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/echec.dart';
import 'package:admin/screens/admin/driver_schedule_screen.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/driver_schedule_service.dart';

/// Le planning d'un livreur — `/delivery/shifts/`.
///
/// ## Ce que ces cas ferment
///
/// * **Un jour porte plusieurs créneaux.** L'écran n'en montrait qu'un par
///   jour : un livreur de service le midi *et* le soir n'en affichait qu'un,
///   et modifier l'heure lue écrasait ce créneau-là en laissant l'autre,
///   invisible, intact.
/// * **Un refus se dit.** Les écritures rendaient `false` en gardant le motif
///   dans un champ que l'écran n'affichait pas : un créneau refusé — parce
///   qu'il en recouvre un autre — revenait à sa valeur d'avant sans un mot.
/// * **Une lecture refusée n'est pas un planning vide.** Un 403 affichait sept
///   jours sans créneau, ce qui se lit « ce livreur n'est jamais attendu ».
const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _creneauJson({
  required String id,
  int jour = 1,
  String debut = '09:00:00',
  String fin = '12:00:00',
  bool present = true,
}) {
  return {
    'id': id,
    'courier': 'livreur-1',
    'courier_name': 'Kofi A.',
    'day_of_week': jour,
    'start_time': debut,
    'end_time': fin,
    'is_available': present,
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
  };
}

class _Refus {
  const _Refus({required this.code, required this.detail});

  final int code;
  final String detail;
}

class _FauxServeur implements HttpClientAdapter {
  /// Le planning rendu en lecture.
  List<Map<String, dynamic>> creneaux = const [];

  /// Le refus opposé à la lecture, puis celui opposé aux écritures.
  _Refus? refusEnLecture;
  _Refus? refusEnEcriture;

  /// Ce que rend une écriture qui aboutit.
  Map<String, dynamic> enregistre = _creneauJson(id: 'creneau-1');

  final List<String> appels = [];

  void reinitialiser() {
    creneaux = const [];
    refusEnLecture = null;
    refusEnEcriture = null;
    enregistre = _creneauJson(id: 'creneau-1');
    appels.clear();
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    appels.add('${options.method} ${options.path}');
    final enEcriture = options.method != 'GET';
    final refus = enEcriture ? refusEnEcriture : refusEnLecture;

    if (refus != null) {
      return ResponseBody.fromString(
        jsonEncode({
          'type': 'about:blank',
          'title': 'Refus',
          'status': refus.code,
          'detail': refus.detail,
        }),
        refus.code,
        headers: _entetesJson,
      );
    }

    if (options.method == 'DELETE') {
      return ResponseBody.fromString('', 204, headers: _entetesJson);
    }
    if (enEcriture) {
      return ResponseBody.fromString(jsonEncode(enregistre), 200, headers: _entetesJson);
    }
    return ResponseBody.fromString(
      jsonEncode({
        'count': creneaux.length,
        'next': null,
        'previous': null,
        'results': creneaux,
      }),
      200,
      headers: _entetesJson,
    );
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

  setUp(serveur.reinitialiser);
  tearDownAll(conteneur.dispose);

  group('Le planning lu', () {
    test('un jour porte autant de créneaux qu’il en faut, dans l’ordre', () async {
      // Service du soir écrit avant celui du midi : le tri est celui de
      // l'écran, pas celui de la réponse.
      serveur.creneaux = [
        _creneauJson(id: 'soir', debut: '18:00:00', fin: '23:00:00'),
        _creneauJson(id: 'midi'),
      ];
      final planning = DriverScheduleService();

      await planning.loadDriverSchedules('livreur-1');

      final lundi = planning.creneauxDuJour('livreur-1', 1);
      expect(lundi.map((c) => c.id), ['midi', 'soir']);
      expect(planning.echec, isNull);
    });

    test('une lecture refusée ne se lit pas comme un planning vide', () async {
      serveur.refusEnLecture = const _Refus(
        code: 403,
        detail: 'Vous n’avez pas la permission « couriers.read ».',
      );
      final planning = DriverScheduleService();

      await planning.loadDriverSchedules('livreur-1');

      expect(planning.echec?.nature, NatureEchec.autorisation);
      expect(planning.echec?.message, contains('couriers.read'));
      expect(planning.getDriverSchedules('livreur-1'), isEmpty);
    });
  });

  group('Les écritures', () {
    test('un chevauchement refusé remonte avec la phrase du serveur', () async {
      serveur.refusEnEcriture = const _Refus(
        code: 400,
        detail: 'Ce livreur est déjà planifié de 09:00 à 17:00 ce jour-là.',
      );
      final planning = DriverScheduleService();

      await expectLater(
        planning.saveSchedule(
          const DriverSchedule(
            driverId: 'livreur-1',
            dayOfWeek: 1,
            startTime: TimeOfDay(hour: 12, minute: 0),
            endTime: TimeOfDay(hour: 20, minute: 0),
          ),
        ),
        throwsA(
          isA<eccore.ApiException>().having(
            (e) => e.detail,
            'detail',
            contains('déjà planifié'),
          ),
        ),
      );
      // Rien n'est retenu localement : afficher un créneau que le serveur a
      // refusé ferait compter sur une présence qui n'est pas planifiée.
      expect(planning.getDriverSchedules('livreur-1'), isEmpty);
    });

    test('un créneau neuf part en création, un créneau connu en mise à jour', () async {
      final planning = DriverScheduleService();

      await planning.saveSchedule(
        const DriverSchedule(
          driverId: 'livreur-1',
          dayOfWeek: 1,
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 12, minute: 0),
        ),
      );
      expect(serveur.appels.last, 'POST /delivery/shifts/');

      await planning.saveSchedule(
        planning.getDriverSchedules('livreur-1').single.copyWith(
              endTime: const TimeOfDay(hour: 13, minute: 0),
            ),
      );
      // La ligne enregistrée remplace la précédente : elle n'est pas ajoutée à
      // côté, ce qui afficherait deux fois le même créneau.
      expect(serveur.appels.last, 'PATCH /delivery/shifts/creneau-1/');
      expect(planning.getDriverSchedules('livreur-1'), hasLength(1));
    });

    test('une suppression refusée laisse la ligne en place', () async {
      serveur.creneaux = [_creneauJson(id: 'midi')];
      final planning = DriverScheduleService();
      await planning.loadDriverSchedules('livreur-1');

      serveur.refusEnEcriture = const _Refus(
        code: 403,
        detail: 'Vous n’avez pas la permission « couriers.write ».',
      );

      await expectLater(
        planning.deleteSchedule('midi', 'livreur-1'),
        throwsA(isA<eccore.ApiException>()),
      );
      expect(planning.getDriverSchedules('livreur-1'), hasLength(1));
    });
  });

  group('À l’écran', () {
    Future<void> ouvrir(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DriverScheduleService()),
            ChangeNotifierProvider<AdminAuthService>.value(value: AdminAuthService()),
          ],
          // Mêmes traductions que l'application : un planning dont les heures
          // se lisent « 9:00 AM » n'est pas celui que l'exploitation ouvre.
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [Locale('fr'), Locale('en')],
            home: DriverScheduleScreen(driver: _livreur()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('les deux services d’une même journée sont visibles', (tester) async {
      serveur.creneaux = [
        _creneauJson(id: 'midi'),
        _creneauJson(id: 'soir', debut: '18:00:00', fin: '23:00:00'),
      ];

      await ouvrir(tester);

      expect(find.textContaining('09:00'), findsOneWidget);
      expect(find.textContaining('18:00'), findsOneWidget);
    });

    testWidgets('sans droit d’écriture, l’écran le dit au lieu de faire semblant',
        (tester) async {
      // Aucune session dans ce test : le compte ne porte donc aucune
      // permission. Les gestes sont inertes, et la raison est écrite — un
      // bouton qui ne réagit pas se lit comme une panne.
      serveur.creneaux = [_creneauJson(id: 'midi')];

      await ouvrir(tester);

      expect(find.textContaining('Lecture seule'), findsOneWidget);
      final ajouter = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Ajouter').first,
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        ),
      );
      expect(ajouter.onPressed, isNull);
    });

    testWidgets('le planning est annoncé comme indicatif', (tester) async {
      // La phrase compte autant que les créneaux : sans elle, un planning vide
      // passe pour une interdiction de travailler.
      await ouvrir(tester);

      expect(find.textContaining('ne conditionne pas les courses'), findsOneWidget);
    });

    testWidgets('une lecture refusée s’affiche comme un refus', (tester) async {
      serveur.refusEnLecture = const _Refus(
        code: 403,
        detail: 'Vous n’avez pas la permission « couriers.read ».',
      );

      await ouvrir(tester);

      expect(find.textContaining('Accès refusé'), findsOneWidget);
      expect(find.textContaining('Aucun créneau planifié'), findsWidgets);
    });
  });
}

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
      'deliveries_completed': 12,
      'deliveries_cancelled': 0,
      'rating_average': '4.8',
      'rating_count': 9,
      'total_earnings': null,
      'created_at': '2026-09-01T10:00:00Z',
      'updated_at': '2026-09-07T10:00:00Z',
    });
