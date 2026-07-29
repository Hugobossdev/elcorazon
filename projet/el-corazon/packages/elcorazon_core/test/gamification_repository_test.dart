import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Simule `/gamification/*`.
class _FakeServer implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/gamification/badges/')) {
      return _paginated([
        {
          'id': 'badge-1',
          'title': 'Premier pas',
          'description': 'Gagnez vos 50 premiers points.',
          'icon': '🌱',
          'points_required': 50,
          'is_unlocked': false,
          'unlocked_at': null,
        },
      ]);
    }

    if (options.path.endsWith('/gamification/achievements/')) {
      return _paginated([
        {
          'id': 'achievement-1',
          'name': 'Premier repas',
          'description': 'Passez votre première commande.',
          'icon': '🍔',
          'condition_type': 'orders',
          'condition_value': 1,
          'points_reward': 20,
          'progress': 0,
          'is_unlocked': false,
          'unlocked_at': null,
        },
      ]);
    }

    if (options.path.endsWith('/gamification/challenges/')) {
      return _paginated([
        {
          'id': 'challenge-1',
          'title': 'Défi du mois',
          'description': '3 commandes ce mois-ci.',
          'challenge_type': 'orders',
          'target_value': 3,
          'reward_points': 30,
          'starts_at': '2026-07-01T00:00:00Z',
          'ends_at': '2026-07-31T23:59:59Z',
          'progress': 1,
          'is_completed': false,
        },
      ]);
    }

    throw UnimplementedError('Route non simulée : ${options.path}');
  }

  ResponseBody _paginated(List<Map<String, dynamic>> results) {
    return ResponseBody.fromString(
      jsonEncode({'count': results.length, 'next': null, 'previous': null, 'results': results}),
      200,
      headers: _jsonHeaders,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GamificationRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: _FakeServer(),
    );
    repository = GamificationRepository(apiClient: apiClient);
  });

  group('GamificationRepository', () {
    test('getBadges mappe le catalogue', () async {
      final badges = await repository.getBadges();

      expect(badges, hasLength(1));
      expect(badges.single.pointsRequired, 50);
      expect(badges.single.isUnlocked, isFalse);
    });

    test('getAchievements mappe le catalogue', () async {
      final achievements = await repository.getAchievements();

      expect(achievements, hasLength(1));
      expect(achievements.single.conditionType, 'orders');
    });

    test('getChallenges mappe les défis en cours', () async {
      final challenges = await repository.getChallenges();

      expect(challenges, hasLength(1));
      expect(challenges.single.progress, 1);
      expect(challenges.single.isCompleted, isFalse);
    });
  });
}
