import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/user.dart';

/// Service centralisant la logique Realtime autour de Supabase.
///
/// IMPORTANT :
/// - L’implémentation ci-dessous fournit toutes les propriétés/méthodes
///   attendues par `RealtimeTrackingService` et `ServiceInitializer`.
/// - Une partie de la logique est volontairement simplifiée / stubée pour
///   éviter de bloquer l’app si le backend Realtime n’est pas totalement prêt.
class SupabaseRealtimeService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _orderChannel;
  RealtimeChannel? _notificationChannel;

  // ---- État de connexion ----
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // ---- Streams exposés (utilisés par RealtimeTrackingService) ----
  final _orderUpdatesController = StreamController<Order>.broadcast();
  final _deliveryLocationUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _notificationsController = StreamController<String>.broadcast();

  Stream<Order> get orderUpdates => _orderUpdatesController.stream;
  Stream<Map<String, dynamic>> get deliveryLocationUpdates =>
      _deliveryLocationUpdatesController.stream;
  Stream<String> get notifications => _notificationsController.stream;

  // ---- Données mises en cache pour le suivi ----
  final Map<String, Order> _trackedOrders = {};
  Map<String, Order> get trackedOrders => _trackedOrders;

  final Map<String, Map<String, dynamic>> _activeDeliveries = {};
  Map<String, Map<String, dynamic>> get activeDeliveries => _activeDeliveries;

  /// Initialisation principale avec l’utilisateur courant.
  ///
  /// On garde la signature attendue par `RealtimeTrackingService` et
  /// `ServiceInitializer`.
  Future<void> initialize({
    required String userId,
    required UserRole userRole,
  }) async {
    if (_isConnected) return;

    try {
      _isConnected = true;
      notifyListeners();

      // Abonnements de base (peuvent être enrichis plus tard)
      _subscribeToOrders(userId);
      _subscribeToNotifications(userId);

      debugPrint(
        'SupabaseRealtimeService: initialized for user $userId, role $userRole',
      );
    } catch (e) {
      debugPrint('SupabaseRealtimeService: error during initialize - $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Souscriptions Realtime basiques
  // ---------------------------------------------------------------------------

  void _subscribeToOrders(String userId) {
    try {
      _orderChannel = _supabase
          .channel('public:orders:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final data = payload.newRecord;
              if (data is Map<String, dynamic>) {
                try {
                  final order = Order.fromMap(data);
                  _trackedOrders[order.id] = order;
                  _orderUpdatesController.add(order);
                } catch (e) {
                  debugPrint(
                    'SupabaseRealtimeService: error parsing order - $e',
                  );
                }
              }
              notifyListeners();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('SupabaseRealtimeService: error subscribing to orders - $e');
    }
  }

  void _subscribeToNotifications(String userId) {
    try {
      _notificationChannel = _supabase
          .channel('public:notifications:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final record = payload.newRecord as Map<String, dynamic>?;
              final message =
                  record?['message']?.toString() ?? 'Nouvelle notification';
              _notificationsController.add(message);
              notifyListeners();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint(
        'SupabaseRealtimeService: error subscribing to notifications - $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Méthodes “API” utilisées par RealtimeTrackingService
  // ---------------------------------------------------------------------------

  Future<void> trackOrder(String orderId) async {
    debugPrint('SupabaseRealtimeService: trackOrder($orderId)');
    // Ici on pourrait appeler une RPC ou mettre à jour un champ en base.
  }

  Future<void> untrackOrder(String orderId) async {
    debugPrint('SupabaseRealtimeService: untrackOrder($orderId)');
    _trackedOrders.remove(orderId);
    notifyListeners();
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': status.name}).eq('id', orderId);
    } catch (e) {
      debugPrint('SupabaseRealtimeService: updateOrderStatus error - $e');
    }
  }

  Future<void> assignDelivery(String orderId, String deliveryId) async {
    try {
      await _supabase
          .from('orders')
          .update({'delivery_person_id': deliveryId}).eq('id', orderId);
    } catch (e) {
      debugPrint('SupabaseRealtimeService: assignDelivery error - $e');
    }
  }

  Future<void> acceptDelivery(String orderId) async {
    debugPrint('SupabaseRealtimeService: acceptDelivery($orderId)');
    // À adapter en fonction de votre schéma (RPC ou update direct).
  }

  Future<void> markAsDelivered(String orderId) async {
    await updateOrderStatus(orderId, OrderStatus.delivered);
  }

  Future<void> updateDeliveryLocation(
    String orderId,
    double latitude,
    double longitude,
  ) async {
    try {
      await _supabase.from('order_locations').upsert({
        'order_id': orderId,
        'lat': latitude,
        'lng': longitude,
        'updated_at': DateTime.now().toIso8601String(),
      });

      final location = <String, dynamic>{
        'order_id': orderId,
        'lat': latitude,
        'lng': longitude,
      };
      _deliveryLocationUpdatesController.add(location);
    } catch (e) {
      debugPrint(
        'SupabaseRealtimeService: updateDeliveryLocation error - $e',
      );
    }
  }

  Future<void> sendNotification(String targetUserId, String message) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': targetUserId,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('SupabaseRealtimeService: sendNotification error - $e');
    }
  }

  Future<String?> createOrderWithGeocoding(
    Map<String, dynamic> orderData,
  ) async {
    try {
      final response =
          await _supabase.from('orders').insert(orderData).select('id').single();
      return response['id']?.toString();
    } catch (e) {
      debugPrint('SupabaseRealtimeService: createOrderWithGeocoding error - $e');
      return null;
    }
  }

  Future<List<Order>> getUserOrders(String userId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at');

      return (response as List<dynamic>)
          .map((e) => Order.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SupabaseRealtimeService: getUserOrders error - $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Nettoyage
  // ---------------------------------------------------------------------------

  Future<void> disconnect() async {
    try {
      await _orderChannel?.unsubscribe();
    } catch (_) {}
    try {
      await _notificationChannel?.unsubscribe();
    } catch (_) {}

    _orderChannel = null;
    _notificationChannel = null;
    _isConnected = false;

    _trackedOrders.clear();
    _activeDeliveries.clear();

    notifyListeners();
  }

  @override
  void dispose() {
    _orderUpdatesController.close();
    _deliveryLocationUpdatesController.close();
    _notificationsController.close();
    // On appelle disconnect pour nettoyer les canaux.
    unawaited(disconnect());
    super.dispose();
  }
}

