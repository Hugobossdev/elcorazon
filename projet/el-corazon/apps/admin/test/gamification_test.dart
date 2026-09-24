import 'package:admin/screens/admin/gamification/challenges.dart';
import 'package:admin/screens/admin/gamification/rewards.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/gamification_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Gamification — ce que l'écran affiche et ce qu'il envoie.
///
/// Chaque cas rejoue un défaut vérifié en réel le 21 septembre 2026 :
/// récompenses sans titre et « 0 pts » (clés mal lues), défis créés avec une
/// nature que le serveur refuse, dates d'un défi écrasées à la modification,
/// dialogue fermé avant la réponse du serveur.
const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

eccore.ManagedReward _recompense({String? restaurantId = 'id-lome'}) => eccore.ManagedReward(
      id: 'r1',
      name: '500 F de réduction',
      description: '',
      kind: eccore.RewardKind.discount,
      pointsCost: 100,
      discount: const eccore.Money(amountMinor: 500, currency: 'XOF'),
      validityDays: 30,
      isActive: true,
      restaurantId: restaurantId,
    );

eccore.ManagedChallenge _defi() => eccore.ManagedChallenge(
      id: 'd1',
      title: 'Semaine folle',
      description: '',
      challengeType: eccore.ChallengeKind.weekly,
      conditionType: eccore.AchievementCondition.ordersCount,
      targetValue: 5,
      rewardPoints: 200,
      startsAt: DateTime.utc(2026, 10, 5, 8),
      endsAt: DateTime.utc(2026, 10, 12, 8),
      isActive: true,
    );

class _DepotFactice implements eccore.ManagedGamificationRepository {
  List<eccore.ManagedReward> recompenses = [_recompense()];
  List<eccore.ManagedChallenge> defis = [_defi()];
  final List<String> lectures = [];
  final List<Map<String, Object?>> defisEnvoyes = [];
  eccore.ApiException? refus;

  @override
  eccore.ApiClient get apiClient => throw UnimplementedError();

  @override
  Future<List<eccore.ManagedAchievement>> achievements({bool? isActive}) async {
    lectures.add('succes');
    return const [];
  }

  @override
  Future<List<eccore.ManagedBadge>> badges({bool? isActive}) async {
    lectures.add('badges');
    return const [];
  }

  @override
  Future<List<eccore.ManagedChallenge>> challenges({bool? isActive}) async {
    lectures.add('defis');
    return defis;
  }

  @override
  Future<List<eccore.ManagedReward>> rewards({bool? isActive}) async {
    lectures.add('recompenses');
    return recompenses;
  }

  eccore.ManagedChallenge _defiEnvoye(Map<String, Object?> donnees) {
    defisEnvoyes.add(donnees);
    if (refus != null) throw refus!;
    return eccore.ManagedChallenge(
      id: (donnees['id'] as String?) ?? 'nouveau',
      title: donnees['title']! as String,
      description: '',
      challengeType: donnees['challenge_type']! as String,
      conditionType: donnees['condition_type']! as String,
      targetValue: donnees['target_value']! as int,
      rewardPoints: donnees['reward_points']! as int,
      startsAt: donnees['starts_at']! as DateTime,
      endsAt: donnees['ends_at']! as DateTime,
      isActive: true,
    );
  }

  @override
  Future<eccore.ManagedChallenge> createChallenge({
    required String title,
    required String challengeType,
    required String conditionType,
    required int targetValue,
    required DateTime startsAt,
    required DateTime endsAt,
    String description = '',
    int rewardPoints = 0,
    bool isActive = true,
  }) async =>
      _defiEnvoye({
        'title': title,
        'challenge_type': challengeType,
        'condition_type': conditionType,
        'target_value': targetValue,
        'reward_points': rewardPoints,
        'starts_at': startsAt,
        'ends_at': endsAt,
      });

  @override
  Future<eccore.ManagedChallenge> updateChallenge({
    required String challengeId,
    String? title,
    String? description,
    String? challengeType,
    String? conditionType,
    int? targetValue,
    int? rewardPoints,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? isActive,
  }) async =>
      _defiEnvoye({
        'id': challengeId,
        'title': title,
        'challenge_type': challengeType,
        'condition_type': conditionType,
        'target_value': targetValue,
        'reward_points': rewardPoints,
        'starts_at': startsAt,
        'ends_at': endsAt,
      });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_canalStockage, (call) async => null);
  final conteneur = ProviderContainer();
  AdminAuthService(conteneur);
  tearDownAll(conteneur.dispose);

  GamificationService service(_DepotFactice depot, {Set<String> droits = const {}}) =>
      GamificationService(depot: depot, peut: droits.contains);

  group('Lecture des catalogues', () {
    test('un catalogue non autorisé n’est pas demandé', () async {
      final depot = _DepotFactice();
      final gamification = service(depot, droits: {'loyalty.read'});

      await gamification.refresh();

      expect(depot.lectures, ['recompenses']);
      expect(gamification.recompenses.single.name, '500 F de réduction');
    });

    test('l’échec d’un catalogue n’efface pas les autres', () async {
      final depot = _DepotFactice()..recompenses = [];
      final gamification = GamificationService(
        depot: _DepotQuiRefuseLesDefis(depot),
        peut: (_) => true,
      );

      await gamification.refresh();

      expect(gamification.echecDe(CatalogueDeFidelisation.defis)?.message, contains('interdit'));
      expect(gamification.echecDe(CatalogueDeFidelisation.recompenses), isNull);
    });
  });

  Future<void> monter(WidgetTester tester, GamificationService gamification, Widget onglet) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await gamification.refresh();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GamificationService>.value(value: gamification),
          ChangeNotifierProvider<RestaurantScopeService>(
            create: (_) => RestaurantScopeService.avecLecture(() async => [_lome()])..resolve(),
          ),
          ChangeNotifierProvider<AdminAuthService>.value(value: AdminAuthService()),
        ],
        child: MaterialApp(home: Scaffold(body: onglet)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('une récompense s’affiche avec son nom, son coût et son établissement', (tester) async {
    // Le défaut : l'onglet lisait `title` et `cost`, et affichait « » et « 0 pts ».
    final depot = _DepotFactice();
    await monter(tester, service(depot, droits: {'loyalty.read'}), const RewardsTab());

    expect(find.text('500 F de réduction'), findsOneWidget);
    expect(find.text('100 pts'), findsOneWidget);
    expect(find.text('El Corazón Lomé'), findsOneWidget);
    expect(find.textContaining('500'), findsWidgets);
    // Sans `loyalty.write`, aucun geste d'écriture n'est offert.
    expect(find.text('Nouvelle récompense'), findsNothing);
  });

  testWidgets('modifier un défi garde sa fenêtre et envoie une nature valide', (tester) async {
    final depot = _DepotFactice();
    final gamification = service(depot, droits: {'gamification.read', 'gamification.write'});
    await monter(tester, gamification, const ChallengesTab());

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final envoye = depot.defisEnvoyes.single;
    // Les dates du défi, et non « maintenant → +7 jours ».
    expect((envoye['starts_at']! as DateTime).toUtc(), DateTime.utc(2026, 10, 5, 8));
    expect((envoye['ends_at']! as DateTime).toUtc(), DateTime.utc(2026, 10, 12, 8));
    expect(eccore.ChallengeKind.values, contains(envoye['challenge_type']));
    expect(find.text('Défi enregistré.'), findsOneWidget);
  });

  testWidgets('un refus du serveur garde le dialogue ouvert et le dit', (tester) async {
    final depot = _DepotFactice()
      ..refus = const eccore.ApiException(
        status: 400,
        code: 'invalid',
        detail: 'La fin du défi doit être postérieure à son début.',
        errors: {
          'ends_at': ['La fin du défi doit être postérieure à son début.'],
        },
      );
    await monter(
      tester,
      service(depot, droits: {'gamification.read', 'gamification.write'}),
      const ChallengesTab(),
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Toujours là, avec la raison du serveur, et la saisie intacte.
    expect(find.text('Modifier le défi'), findsOneWidget);
    expect(find.textContaining('postérieure à son début'), findsWidgets);
    expect(find.text('Défi enregistré.'), findsNothing);
  });
}

/// Refuse la lecture des défis, pour vérifier l'isolement des catalogues.
class _DepotQuiRefuseLesDefis extends _DepotFactice {
  _DepotQuiRefuseLesDefis(_DepotFactice modele) {
    recompenses = modele.recompenses;
  }

  @override
  Future<List<eccore.ManagedChallenge>> challenges({bool? isActive}) async {
    throw const eccore.ApiException(status: 403, code: 'permission_denied', detail: 'Accès interdit.');
  }
}
