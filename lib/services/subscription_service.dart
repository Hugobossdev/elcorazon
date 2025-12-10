import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:elcora_fast/models/subscription.dart';
import 'package:elcora_fast/config/api_config.dart';

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  Subscription? _currentSubscription;
  bool _isLoading = false;

  Subscription? get currentSubscription => _currentSubscription;
  bool get isLoading => _isLoading;

  /// Get user's active subscription
  Future<Subscription?> getUserSubscription(String userId) async {
    _setLoading(true);
    try {
      final response = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (response != null) {
        _currentSubscription = Subscription.fromJson(response);
        notifyListeners();
        return _currentSubscription;
      }

      _currentSubscription = null;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('SubscriptionService: Error getting subscription: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Create or update subscription
  Future<Subscription?> createSubscription({
    required String userId,
    required String subscriptionType,
    required int mealsPerWeek,
    required double monthlyPrice,
  }) async {
    _setLoading(true);
    try {
      final now = DateTime.now();
      final periodEnd = subscriptionType == 'weekly'
          ? now.add(const Duration(days: 7))
          : DateTime(now.year, now.month + 1, now.day);

      final subscriptionData = {
        'user_id': userId,
        'subscription_type': subscriptionType,
        'meals_per_week': mealsPerWeek,
        'monthly_price': monthlyPrice,
        'price_per_meal': monthlyPrice / (mealsPerWeek * 4), // Approximate
        'current_period_start': now.toIso8601String(),
        'current_period_end': periodEnd.toIso8601String(),
        'status': 'active',
        'meals_used_this_period': 0,
        'auto_renew': true,
      };

      // Check if subscription exists
      final existing = await _supabase
          .from('subscriptions')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      final result = existing != null
          ? await _supabase
              .from('subscriptions')
              .update(subscriptionData)
              .eq('id', existing['id'])
              .select()
              .single()
          : await _supabase
              .from('subscriptions')
              .insert(subscriptionData)
              .select()
              .single();

      _currentSubscription = Subscription.fromJson(result);
      notifyListeners();
      return _currentSubscription;
    } catch (e) {
      debugPrint('SubscriptionService: Error creating subscription: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Use a meal from subscription
  Future<bool> useSubscriptionMeal(String orderId) async {
    if (_currentSubscription == null) {
      debugPrint('SubscriptionService: No active subscription');
      return false;
    }

    if (!_currentSubscription!.canUseMeal) {
      debugPrint(
        'SubscriptionService: Cannot use meal - no meals remaining or inactive',
      );
      return false;
    }

    try {
      // Call backend API to use subscription meal
      final backendUrl = ApiConfig.backendUrl;
      final response = await http.post(
        Uri.parse(
          '$backendUrl/api/subscriptions/${_currentSubscription!.id}/use',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'order_id': orderId}),
      );

      if (response.statusCode == 200) {
        // Update local subscription
        _currentSubscription = _currentSubscription!.copyWith(
          mealsUsedThisPeriod: _currentSubscription!.mealsUsedThisPeriod + 1,
        );
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('SubscriptionService: Error using subscription meal: $e');

      // Fallback: update directly in Supabase
      try {
        final updated = await _supabase
            .from('subscriptions')
            .update({
              'meals_used_this_period':
                  _currentSubscription!.mealsUsedThisPeriod + 1,
            })
            .eq('id', _currentSubscription!.id)
            .select()
            .single();

        _currentSubscription = Subscription.fromJson(updated);
        notifyListeners();

        // Record subscription order
        await _supabase.from('subscription_orders').insert({
          'subscription_id': _currentSubscription!.id,
          'order_id': orderId,
          'meal_count': 1,
        });

        return true;
      } catch (e2) {
        debugPrint('SubscriptionService: Error in fallback: $e2');
      }

      return false;
    }
  }

  /// Cancel subscription
  Future<bool> cancelSubscription() async {
    if (_currentSubscription == null) return false;

    try {
      final result = await _supabase
          .from('subscriptions')
          .update({
            'status': 'cancelled',
            'auto_renew': false,
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentSubscription!.id)
          .select()
          .single();

      _currentSubscription = Subscription.fromJson(result);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('SubscriptionService: Error cancelling subscription: $e');
      return false;
    }
  }

  /// Pause subscription
  Future<bool> pauseSubscription() async {
    if (_currentSubscription == null) return false;

    try {
      final result = await _supabase
          .from('subscriptions')
          .update({
            'status': 'paused',
          })
          .eq('id', _currentSubscription!.id)
          .select()
          .single();

      _currentSubscription = Subscription.fromJson(result);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('SubscriptionService: Error pausing subscription: $e');
      return false;
    }
  }

  /// Resume subscription
  Future<bool> resumeSubscription() async {
    if (_currentSubscription == null) return false;

    try {
      final result = await _supabase
          .from('subscriptions')
          .update({
            'status': 'active',
          })
          .eq('id', _currentSubscription!.id)
          .select()
          .single();

      _currentSubscription = Subscription.fromJson(result);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('SubscriptionService: Error resuming subscription: $e');
      return false;
    }
  }

  /// Check if subscription can be renewed
  Future<bool> checkAndRenewSubscription() async {
    if (_currentSubscription == null) return false;

    // Check if subscription period has ended
    if (_currentSubscription!.currentPeriodEnd.isBefore(DateTime.now())) {
      if (_currentSubscription!.autoRenew) {
        // Renew subscription
        final now = DateTime.now();
        final periodEnd = _currentSubscription!.subscriptionType == 'weekly'
            ? now.add(const Duration(days: 7))
            : DateTime(now.year, now.month + 1, now.day);

        try {
          final result = await _supabase
              .from('subscriptions')
              .update({
                'current_period_start': now.toIso8601String(),
                'current_period_end': periodEnd.toIso8601String(),
                'meals_used_this_period': 0,
                'status': 'active',
              })
              .eq('id', _currentSubscription!.id)
              .select()
              .single();

          _currentSubscription = Subscription.fromJson(result);
          notifyListeners();
          return true;
        } catch (e) {
          debugPrint('SubscriptionService: Error renewing subscription: $e');
        }
      } else {
        // Mark as expired
        await _supabase
            .from('subscriptions')
            .update({'status': 'expired'}).eq('id', _currentSubscription!.id);

        _currentSubscription = null;
        notifyListeners();
      }
    }

    return false;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Refresh subscription data
  Future<void> refreshSubscription(String userId) async {
    await getUserSubscription(userId);
  }
}
