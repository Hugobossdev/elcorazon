import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _rewardJson({String id = 'reward-1'}) {
  return {
    'id': id,
    'name': '500 F de réduction',
    'description': '500 F CFA de réduction sur votre prochaine commande.',
    'kind': 'discount',
    'points_cost': 100,
    'discount': {'amount': '500', 'currency': 'XOF'},
    'validity_days': 30,
    'restaurant': 'el-corazon-lome',
  };
}

Map<String, dynamic> _planJson({String id = 'plan-vip'}) {
  return {
    'id': id,
    'name': 'VIP Premium',
    'description': 'Livraison offerte et articles exclusifs.',
    'price': {'amount': '5000', 'currency': 'XOF'},
    'billing_period_days': 30,
  };
}

Map<String, dynamic> _subscriptionJson({
  String id = 'sub-1',
  String status = 'active',
  String start = '2026-07-01T00:00:00Z',
  String end = '2126-08-01T00:00:00Z',
}) {
  return {
    'id': id,
    'plan': _planJson(),
    'status': status,
    'auto_renew': true,
    'current_period_start': start,
    'current_period_end': end,
    'cancelled_at': null,
    'created_at': start,
  };
}

/// Simule `/loyalty/*`.
class _FakeServer implements HttpClientAdapter {
  final List<String> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');

    if (options.path.endsWith('/loyalty/account/')) {
      return _jsonResponse({
        'balance': 120,
        'lifetime_earned': 300,
        'lifetime_spent': 180,
        'last_activity_at': '2026-07-28T12:00:00Z',
      }, 200);
    }

    if (options.path.endsWith('/loyalty/rewards/')) {
      return _jsonResponse({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [_rewardJson()],
      }, 200);
    }

    if (options.path.endsWith('/loyalty/entries/')) {
      return _jsonResponse({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [
          {
            'id': 'entry-1',
            'kind': 'earned',
            'delta': 20,
            'balance_after': 120,
            'description': 'Commande EC000001 livrée',
            'order': 'order-1',
            'created_at': '2026-07-28T12:00:00Z',
          },
        ],
      }, 200);
    }

    if (options.path.endsWith('/loyalty/plans/')) {
      return _jsonResponse({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [_planJson()],
      }, 200);
    }

    if (options.path.endsWith('/loyalty/subscriptions/subscribe/') && options.method == 'POST') {
      return _jsonResponse({
        'subscription': _subscriptionJson(status: 'pending'),
        'checkout_url': 'https://paydunya.test/checkout/abc',
        'instructions': null,
      }, 201);
    }

    if (options.path.endsWith('/loyalty/subscriptions/sub-1/cancel/') && options.method == 'POST') {
      return _jsonResponse(_subscriptionJson(status: 'cancelled'), 200);
    }

    if (options.path.endsWith('/loyalty/subscriptions/')) {
      return _jsonResponse({
        'count': 2,
        'next': null,
        'previous': null,
        'results': [
          // Périmé : période close l'an dernier.
          _subscriptionJson(
            id: 'sub-0',
            status: 'expired',
            start: '2025-06-01T00:00:00Z',
            end: '2025-07-01T00:00:00Z',
          ),
          _subscriptionJson(),
        ],
      }, 200);
    }

    if (options.path.contains('/loyalty/rewards/reward-1/redeem/') && options.method == 'POST') {
      return _jsonResponse({
        'redemption': {
          'id': 'redemption-1',
          'reward': _rewardJson(),
          'points_spent': 100,
          'promotion_code': 'FID-ABC123',
          'created_at': '2026-07-28T12:10:00Z',
        },
        'promotion': null,
        'balance': 20,
      }, 201);
    }

    throw UnimplementedError('Route non simulée : ${options.method} ${options.path}');
  }

  ResponseBody _jsonResponse(Map<String, dynamic> body, int status) {
    return ResponseBody.fromString(jsonEncode(body), status, headers: _jsonHeaders);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late LoyaltyRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    );
    repository = LoyaltyRepository(apiClient: apiClient);
  });

  group('LoyaltyRepository', () {
    test('getAccount mappe le solde', () async {
      final account = await repository.getAccount();

      expect(account.balance, 120);
      expect(account.lifetimeEarned, 300);
    });

    test('getRewards mappe le catalogue', () async {
      final rewards = await repository.getRewards();

      expect(rewards, hasLength(1));
      expect(rewards.single.kind, 'discount');
      expect(rewards.single.discount.amountMinor, 500);
    });

    test('getEntries mappe le journal', () async {
      final entries = await repository.getEntries();

      expect(entries, hasLength(1));
      expect(entries.single.kind, 'earned');
      expect(entries.single.delta, 20);
    });

    test('redeem envoie un corps vide et mappe la rédemption', () async {
      final redemption = await repository.redeem('reward-1');

      expect(redemption.promotionCode, 'FID-ABC123');
      expect(redemption.pointsSpent, 100);
      expect(server.requests, contains('POST /loyalty/rewards/reward-1/redeem/'));
    });

    test('getPlans mappe le catalogue des plans', () async {
      final plans = await repository.getPlans();

      expect(plans, hasLength(1));
      expect(plans.single.name, 'VIP Premium');
      expect(plans.single.price.amountMinor, 5000);
      expect(plans.single.billingPeriodDays, 30);
    });

    test("getSubscriptions mappe l'historique", () async {
      final subscriptions = await repository.getSubscriptions();

      expect(subscriptions, hasLength(2));
      expect(subscriptions.first.status, 'expired');
      expect(subscriptions.last.plan.name, 'VIP Premium');
    });

    test('getCurrentSubscription ignore une période close', () async {
      final current = await repository.getCurrentSubscription();

      expect(current, isNotNull);
      expect(current!.id, 'sub-1');
    });

    test("un abonnement pending n'ouvre aucun droit", () {
      final pending = Subscription.fromJson(_subscriptionJson(status: 'pending'));

      expect(pending.isCurrent, isFalse);
    });

    test("un abonnement résilié garde ses droits jusqu'au terme payé", () {
      final cancelled = Subscription.fromJson(_subscriptionJson(status: 'cancelled'));

      expect(cancelled.isCurrent, isTrue);
    });

    test("subscribe n'envoie que le plan", () async {
      final result = await repository.subscribe('plan-vip');

      expect(result.subscription.status, 'pending');
      expect(result.checkoutUrl, 'https://paydunya.test/checkout/abc');
      expect(server.requests, contains('POST /loyalty/subscriptions/subscribe/'));
    });

    test("cancelSubscription mappe l'abonnement résilié", () async {
      final cancelled = await repository.cancelSubscription('sub-1');

      expect(cancelled.status, 'cancelled');
      expect(server.requests, contains('POST /loyalty/subscriptions/sub-1/cancel/'));
    });
  });
}
