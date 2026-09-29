import 'package:admin/screens/admin/reseau/fiche_de_zone_screen.dart';
import 'package:admin/screens/admin/reseau/import_geojson_dialog.dart';
import 'package:admin/screens/admin/reseau/tester_une_adresse_screen.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finalisation des zones, côté Admin : la fiche d'une zone (gestes lus dans
/// la machine à états du serveur, contour entier, horaires, réseau), l'import
/// GeoJSON (vérifier avant de créer) et l'outil « Tester une adresse ».

/// Deux morceaux, dont le premier porte un trou — ce que l'ancien écran
/// réduisait au premier anneau du premier polygone.
const _multi = {
  'type': 'MultiPolygon',
  'coordinates': [
    [
      [
        [1.20, 6.10],
        [1.30, 6.10],
        [1.30, 6.20],
        [1.20, 6.20],
        [1.20, 6.10],
      ],
      [
        [1.24, 6.14],
        [1.26, 6.14],
        [1.26, 6.16],
        [1.24, 6.16],
        [1.24, 6.14],
      ],
    ],
    [
      [
        [1.40, 6.10],
        [1.45, 6.10],
        [1.45, 6.15],
        [1.40, 6.10],
      ],
    ],
  ],
};

eccore.DeliveryZone _zone({
  String statut = 'published',
  List<String> transitions = const ['suspended', 'archived'],
  List<String> chevauchements = const [],
  List<Map<String, dynamic>> horaires = const [],
  String motifSuspension = '',
}) =>
    eccore.DeliveryZone.fromJson({
      'id': 'z1',
      'city': 'ville-1',
      'name': 'Bè',
      'shape': 'polygon',
      'boundary': _multi,
      'base_fee': {'amount': '500', 'currency': 'XOF'},
      'fee_per_km': {'amount': '0', 'currency': 'XOF'},
      'max_distance_km': '10.00',
      'estimated_delivery_minutes': 30,
      'is_active': statut == 'published',
      'status': statut,
      'transitions': transitions,
      'priority': 5,
      'overlaps': chevauchements,
      'opening_hours': horaires,
      'exceptions': const <Map<String, dynamic>>[],
      'created_by': 'Ama Opératrice',
      'created_at': '2026-09-28T10:00:00Z',
      'suspension_reason': motifSuspension,
    });

class _Gestes implements eccore.ZoneLifecycleRepository {
  final actions = <String>[];

  /// Ce que rend le prochain geste ; une [eccore.ApiException] est levée.
  Object? reponse;

  Future<eccore.DeliveryZone> _rendre(String action) async {
    actions.add(action);
    final r = reponse;
    if (r is eccore.ApiException) throw r;
    return r! as eccore.DeliveryZone;
  }

  @override
  Future<eccore.DeliveryZone> suspendre(String zoneId, {required String motif, DateTime? finPrevue}) =>
      _rendre('suspendre $zoneId « $motif » fin=${finPrevue != null}');

  @override
  Future<eccore.DeliveryZone> reactiver(String zoneId) => _rendre('reactiver $zoneId');

  @override
  Future<eccore.DeliveryZone> soumettre(String zoneId) => _rendre('soumettre $zoneId');

  @override
  Future<eccore.DeliveryZone> publier(String zoneId) => _rendre('publier $zoneId');

  @override
  Future<eccore.DeliveryZone> dupliquer(String zoneId, {required String nom}) =>
      _rendre('dupliquer $zoneId « $nom »');

  @override
  Future<eccore.DeliveryZone> relire(String zoneId) => _rendre('relire $zoneId');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

class _Couverture implements eccore.CoverageRepository {
  List<eccore.CuisineDeZone> cuisines = const [];
  Map<String, List<eccore.LivreurDeZone>> livreurs = const {};
  eccore.ApiException? refusLivreurs;

  eccore.RapportDeCouverture? rapport;
  final demandes = <String>[];

  @override
  Future<List<eccore.CuisineDeZone>> cuisinesDe(String zoneId) async => cuisines;

  @override
  Future<Map<String, List<eccore.LivreurDeZone>>> livreursDe(String zoneId) async {
    if (refusLivreurs != null) throw refusLivreurs!;
    return livreurs;
  }

  @override
  Future<eccore.RapportDeCouverture> tester({
    required double latitude,
    required double longitude,
    eccore.Money? sousTotal,
    String? cuisineSlug,
    DateTime? a,
  }) async {
    demandes.add('$latitude,$longitude panier=${sousTotal != null} cuisine=$cuisineSlug');
    return rapport!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

class _Import implements eccore.ZoneImportRepository {
  final actions = <String>[];
  Object? apercu;

  @override
  Future<eccore.ApercuImportZone> previsualiser({
    required String cityId,
    required String nom,
    required Object geojson,
  }) async {
    actions.add('verifier $cityId « $nom » ${(geojson as Map)['type']}');
    final a = apercu;
    if (a is eccore.ApiException) throw a;
    return a! as eccore.ApercuImportZone;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

void main() {
  group('La fiche d’une zone', () {
    Future<_Gestes> monter(
      WidgetTester tester,
      eccore.DeliveryZone zone, {
      bool peutEcrire = true,
      _Couverture? couverture,
    }) async {
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.reset);
      final gestes = _Gestes();
      await tester.pumpWidget(
        MaterialApp(
          home: FicheDeZoneScreen(
            // Une clé par zone : remonter l'écran repart de la zone donnée.
            key: ValueKey(zone),
            zone: zone,
            peutEcrire: peutEcrire,
            gestes: gestes,
            couverture: couverture ?? _Couverture(),
            afficherCarte: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return gestes;
    }

    testWidgets('le contour se lit entier : tous les morceaux, et leurs trous', (tester) async {
      await monter(tester, _zone());

      expect(find.text('2 morceaux · 1 trou'), findsOneWidget);
      expect(find.text('Publiée'), findsOneWidget);
      expect(find.text('Priorité 5'), findsOneWidget);
    });

    testWidgets('les gestes proposés sont ceux que le serveur permet', (tester) async {
      await monter(tester, _zone());

      expect(find.text('Suspendre'), findsOneWidget);
      expect(find.text('Archiver'), findsOneWidget);
      expect(find.text('Publier'), findsNothing);
      expect(find.text('Réactiver'), findsNothing);
      expect(find.text('Soumettre à la revue'), findsNothing);
    });

    testWidgets('un brouillon se soumet, puis une zone en revue se publie', (tester) async {
      final gestes = await monter(
        tester,
        _zone(statut: 'draft', transitions: const ['pending_review', 'archived']),
      );
      expect(find.text('Suspendre'), findsNothing);
      gestes.reponse = _zone(
        statut: 'pending_review',
        transitions: const ['draft', 'published', 'archived'],
      );

      await tester.tap(find.text('Soumettre à la revue'));
      await tester.pumpAndSettle();

      expect(gestes.actions, ['soumettre z1']);
      expect(find.text('En revue'), findsOneWidget);
      expect(find.text('Publier'), findsOneWidget);
      expect(find.text('Renvoyer en brouillon'), findsOneWidget);
    });

    testWidgets('suspendre exige un motif, et l’écran affiche ce que le serveur a écrit',
        (tester) async {
      final gestes = await monter(tester, _zone());
      gestes.reponse = _zone(
        statut: 'suspended',
        transitions: const ['published', 'archived'],
        motifSuspension: 'Inondation',
      );

      await tester.tap(find.text('Suspendre'));
      await tester.pumpAndSettle();
      final confirmer = find.widgetWithText(FilledButton, 'Suspendre');
      expect(tester.widget<FilledButton>(confirmer).onPressed, isNull, reason: 'motif vide');

      await tester.enterText(find.byKey(const Key('motif-suspension')), 'Inondation');
      await tester.pumpAndSettle();
      await tester.tap(confirmer);
      await tester.pumpAndSettle();

      expect(gestes.actions, ['suspendre z1 « Inondation » fin=false']);
      expect(find.text('Suspendue'), findsOneWidget);
      expect(find.textContaining('Suspendue : Inondation'), findsOneWidget);
      expect(find.text('Réactiver'), findsOneWidget);
    });

    testWidgets('une transition refusée (409) montre la phrase du serveur, sans changer le statut',
        (tester) async {
      final gestes = await monter(
        tester,
        _zone(statut: 'suspended', transitions: const ['published', 'archived']),
      );
      gestes.reponse = const eccore.ApiException(
        status: 409,
        code: 'business_rule_violation',
        detail: 'Aucune cuisine active ne dessert cette zone : elle ne peut pas être publiée.',
      );

      await tester.tap(find.text('Réactiver'));
      await tester.pumpAndSettle();

      expect(gestes.actions, ['reactiver z1']);
      expect(find.textContaining('Aucune cuisine active ne dessert'), findsOneWidget);
      expect(find.text('Suspendue'), findsOneWidget);
    });

    testWidgets('sans droit d’écriture, aucun geste n’est proposé', (tester) async {
      await monter(tester, _zone(), peutEcrire: false);

      expect(find.text('Suspendre'), findsNothing);
      expect(find.text('Dupliquer'), findsNothing);
      expect(find.text('Modifier'), findsNothing);
    });

    testWidgets('un chevauchement s’annonce avec la règle de résolution', (tester) async {
      await monter(tester, _zone(chevauchements: const ['Grand Lomé']));

      expect(find.text('Chevauchement détecté'), findsOneWidget);
      expect(find.textContaining('Recouvre : Grand Lomé'), findsOneWidget);
    });

    testWidgets('suspendre prévient que les zones qui la recoupent continuent de livrer',
        (tester) async {
      await monter(tester, _zone(chevauchements: const ['Grand Lomé']));

      await tester.tap(find.text('Suspendre'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('relais-suspension')),
          matching: find.textContaining('Grand Lomé, ces zones continueront de livrer'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sans zone qui la recoupe, pas d’avertissement de relais', (tester) async {
      await monter(tester, _zone());

      await tester.tap(find.text('Suspendre'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('relais-suspension')), findsNothing);
    });

    testWidgets('sans horaires, la zone suit sa cuisine ; avec, ils se lisent par jour',
        (tester) async {
      await monter(tester, _zone());
      expect(find.textContaining('suit les horaires de sa cuisine'), findsOneWidget);

      await monter(
        tester,
        _zone(
          horaires: const [
            {'weekday': 4, 'opens_at': '18:00:00', 'closes_at': '02:00:00'},
          ],
        ),
      );
      expect(find.text('Vendredi 18:00 – 02:00 (lendemain)'), findsOneWidget);
    });

    testWidgets('le réseau vient du serveur ; une flotte refusée (403) reste tue', (tester) async {
      final couverture = _Couverture()
        ..cuisines = const [
          eccore.CuisineDeZone(
            slug: 'el-corazon-lome',
            nom: 'El Corazón Lomé',
            statut: 'active',
            ville: 'Lomé',
            peutCommander: true,
            commandesEnCours: 3,
            distanceM: 0,
          ),
        ]
        ..refusLivreurs = const eccore.ApiException(
          status: 403,
          code: 'permission_denied',
          detail: 'Permission refusée.',
        );
      await monter(tester, _zone(), couverture: couverture);

      expect(find.text('El Corazón Lomé'), findsOneWidget);
      expect(
        find.textContaining('dans la zone · prend des commandes · 3 en cuisine'),
        findsOneWidget,
      );
      expect(find.textContaining('Cuisines et livreurs'), findsNothing, reason: 'pas une panne');
    });

    testWidgets('les livreurs s’affichent sous leur cuisine, avec leur motif', (tester) async {
      final couverture = _Couverture()
        ..cuisines = const [
          eccore.CuisineDeZone(
            slug: 'lome',
            nom: 'Lomé',
            statut: 'active',
            ville: 'Lomé',
            peutCommander: true,
            commandesEnCours: 0,
          ),
        ]
        ..livreurs = const {
          'lome': [
            eccore.LivreurDeZone(id: 'l1', nom: 'Kofi', enLigne: true, eligible: true),
            eccore.LivreurDeZone(
              id: 'l2',
              nom: 'Yao',
              enLigne: false,
              eligible: false,
              motif: 'offline',
            ),
          ],
        };
      await monter(tester, _zone(), couverture: couverture);

      expect(find.text('Kofi — Éligible'), findsOneWidget);
      expect(find.text('Yao — Hors ligne'), findsOneWidget);
    });
  });

  group('L’import GeoJSON', () {
    Future<_Import> ouvrir(WidgetTester tester) async {
      final depot = _Import();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportGeoJsonDialog(villes: const {'ville-1': 'Lomé'}, depot: depot),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('ville-import')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lomé').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('nom-import')), 'Bè');
      await tester.pumpAndSettle();
      return depot;
    }

    FilledButton creer(WidgetTester tester) =>
        tester.widget(find.widgetWithText(FilledButton, 'Créer en brouillon'));

    testWidgets('créer n’est possible qu’après une vérification réussie', (tester) async {
      final depot = await ouvrir(tester);
      await tester.enterText(
        find.byKey(const Key('geojson-import')),
        '{"type": "MultiPolygon", "coordinates": []}',
      );
      await tester.pumpAndSettle();
      expect(creer(tester).onPressed, isNull);

      depot.apercu = const eccore.ApercuImportZone(
        contour: {},
        polygones: 2,
        trous: 1,
        chevauchements: ['Grand Lomé'],
      );
      await tester.tap(find.text('Vérifier'));
      await tester.pumpAndSettle();

      expect(depot.actions, ['verifier ville-1 « Bè » MultiPolygon']);
      expect(find.text('Contour valide : 2 morceau(x), 1 trou(s).'), findsOneWidget);
      expect(find.textContaining('Recouvre : Grand Lomé'), findsOneWidget);
      expect(creer(tester).onPressed, isNotNull);

      // Retoucher le texte périme l'aperçu : il faut revérifier.
      await tester.enterText(
        find.byKey(const Key('geojson-import')),
        '{"type": "Polygon", "coordinates": []}',
      );
      await tester.pumpAndSettle();
      expect(creer(tester).onPressed, isNull);
    });

    testWidgets('un JSON illisible est refusé sans appel au serveur', (tester) async {
      final depot = await ouvrir(tester);
      await tester.enterText(find.byKey(const Key('geojson-import')), 'pas du json');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vérifier'));
      await tester.pumpAndSettle();

      expect(depot.actions, isEmpty);
      expect(find.text('Le texte collé n’est pas du JSON.'), findsOneWidget);
    });

    testWidgets('un contour refusé (400) montre la phrase du serveur', (tester) async {
      final depot = await ouvrir(tester)
        ..apercu = const eccore.ApiException(
          status: 400,
          code: 'validation_error',
          detail: 'Le contour se recoupe lui-même.',
        );
      await tester.enterText(
        find.byKey(const Key('geojson-import')),
        '{"type": "Polygon", "coordinates": []}',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vérifier'));
      await tester.pumpAndSettle();

      expect(depot.actions, hasLength(1));
      expect(find.textContaining('Le contour se recoupe lui-même.'), findsOneWidget);
      expect(creer(tester).onPressed, isNull);
    });
  });

  group('Tester une adresse', () {
    Future<_Couverture> monter(WidgetTester tester, eccore.RapportDeCouverture rapport) async {
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.reset);
      final depot = _Couverture()..rapport = rapport;
      await tester.pumpWidget(MaterialApp(home: TesterUneAdresseScreen(depot: depot)));
      return depot;
    }

    const zoneBe = eccore.ZoneBreve(
      id: 'z1',
      nom: 'Bè',
      statut: 'published',
      priorite: 5,
      ville: 'Lomé',
      surfaceKm2: 12.5,
      rang: 0,
    );

    testWidgets('sans coordonnées, rien ne part au serveur', (tester) async {
      final depot = await monter(
        tester,
        const eccore.RapportDeCouverture(disponible: true, candidates: []),
      );

      await tester.tap(find.text('Tester'));
      await tester.pumpAndSettle();

      expect(depot.demandes, isEmpty);
      expect(find.text('Saisissez une latitude et une longitude.'), findsOneWidget);
    });

    testWidgets('une adresse livrable : zone retenue, candidates, frais et livreurs',
        (tester) async {
      final depot = await monter(
        tester,
        eccore.RapportDeCouverture(
          disponible: true,
          pays: 'Togo',
          ville: 'Lomé',
          zone: zoneBe,
          raisonDuChoix: 'Priorité la plus haute.',
          candidates: const [
            zoneBe,
            eccore.ZoneBreve(
              id: 'z2',
              nom: 'Grand Lomé',
              statut: 'published',
              priorite: 1,
              ville: 'Lomé',
              surfaceKm2: 80,
              rang: 1,
            ),
            eccore.ZoneBreve(
              id: 'z3',
              nom: 'Nuit',
              statut: 'published',
              priorite: 9,
              ville: 'Lomé',
              exclueCar: 'closed',
            ),
          ],
          frais: eccore.Money.fromMajorUnits(500, 'XOF'),
          delaiMinutes: 30,
          livreurs: const [
            eccore.LivreurDeZone(id: 'l1', nom: 'Kofi', enLigne: true, eligible: true),
          ],
        ),
      );

      await tester.enterText(find.byKey(const Key('latitude')), '6,13');
      await tester.enterText(find.byKey(const Key('longitude')), '1.22');
      await tester.enterText(find.byKey(const Key('sous-total')), '4000');
      await tester.tap(find.text('Tester'));
      await tester.pumpAndSettle();

      expect(depot.demandes, ['6.13,1.22 panier=true cuisine=']);
      expect(find.text('Livrable'), findsOneWidget);
      expect(find.text('Bè (Publiée, priorité 5)'), findsOneWidget);
      expect(find.text('Priorité la plus haute.'), findsOneWidget);
      expect(find.text('retenue'), findsOneWidget);
      expect(find.text('concourait'), findsOneWidget);
      expect(find.text('fermée à cette heure'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('✓ Kofi — Éligible'), findsOneWidget);
    });

    testWidgets('une zone suspendue se dit suspendue, pas « hors zone »', (tester) async {
      await monter(
        tester,
        const eccore.RapportDeCouverture(
          disponible: false,
          motif: eccore.MotifIndisponibilite.zoneSuspendue,
          raison: 'Livraison suspendue : inondation.',
          candidates: [],
        ),
      );

      await tester.enterText(find.byKey(const Key('latitude')), '6.13');
      await tester.enterText(find.byKey(const Key('longitude')), '1.22');
      await tester.tap(find.text('Tester'));
      await tester.pumpAndSettle();

      expect(find.text('Non livrable'), findsOneWidget);
      expect(find.textContaining('La zone est suspendue.'), findsOneWidget);
      expect(find.textContaining('inondation'), findsOneWidget);
      expect(find.textContaining('Non visibles pour ce compte'), findsOneWidget);
    });
  });
}
