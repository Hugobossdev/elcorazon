import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';

class SupabaseRealtimeService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _driversChannel;

  // Canaux pour le suivi individuel des commandes
  final Map<String, RealtimeChannel> _trackedOrderChannels = {};

  // Streams pour les mises à jour de commandes
  final _orderUpdatesController = StreamController<Order>.broadcast();
  Stream<Order> get orderUpdates => _orderUpdatesController.stream;

  // Streams pour les mises à jour de localisation de livraison
  final _deliveryLocationUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get deliveryLocationUpdates =>
      _deliveryLocationUpdatesController.stream;

  // Streams pour les notifications
  final _notificationsController = StreamController<String>.broadcast();
  Stream<String> get notifications => _notificationsController.stream;

  // Cache des commandes suivies
  final Map<String, Order> _trackedOrders = {};
  Map<String, Order> get trackedOrders => Map.unmodifiable(_trackedOrders);

  void initialize() {
    _subscribeToAllOrders();
    _subscribeToDriversStatus();
  }

  void _subscribeToAllOrders() {
    try {
      _ordersChannel = _supabase
          .channel('admin:orders')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              debugPrint('Admin: Order update: ${payload.eventType}');
              notifyListeners();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to all orders: $e');
    }
  }

  void _subscribeToDriversStatus() {
    try {
      _driversChannel = _supabase
          .channel('admin:drivers')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'drivers',
            callback: (payload) {
              debugPrint('Admin: Driver status update: ${payload.newRecord}');
              notifyListeners();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to drivers: $e');
    }
  }

  /// Suit une commande spécifique et émet les mises à jour via le stream
  Future<void> trackOrder(String orderId) async {
    if (_trackedOrderChannels.containsKey(orderId)) {
      debugPrint('SupabaseRealtimeService: Order $orderId already tracked');
      return;
    }

    try {
      // Récupérer la commande initiale
      try {
        final response =
            await _supabase.from('orders').select().eq('id', orderId).single();

        try {
          final order = Order.fromMap(response);
          _trackedOrders[orderId] = order;
          _orderUpdatesController.add(order);
        } catch (e) {
          debugPrint('SupabaseRealtimeService: Error parsing order - $e');
        }
      } catch (e) {
        debugPrint(
            'SupabaseRealtimeService: Error fetching initial order - $e');
      }

      // Créer un canal pour suivre cette commande spécifique
      final channel = _supabase
          .channel('admin:order:$orderId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: orderId,
            ),
            callback: (payload) {
              debugPrint(
                  'SupabaseRealtimeService: Order $orderId update: ${payload.eventType}');

              try {
                final order = Order.fromMap(payload.newRecord);
                _trackedOrders[orderId] = order;
                _orderUpdatesController.add(order);
                notifyListeners();
              } catch (e) {
                debugPrint(
                    'SupabaseRealtimeService: Error parsing order update - $e');
              }
            },
          )
          .subscribe();

      _trackedOrderChannels[orderId] = channel;
      debugPrint('SupabaseRealtimeService: Now tracking order $orderId');
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Error tracking order $orderId - $e');
    }
  }

  /// Arrête de suivre une commande
  Future<void> untrackOrder(String orderId) async {
    final channel = _trackedOrderChannels.remove(orderId);
    if (channel != null) {
      try {
        await channel.unsubscribe();
        _trackedOrders.remove(orderId);
        debugPrint('SupabaseRealtimeService: Stopped tracking order $orderId');
        notifyListeners();
      } catch (e) {
        debugPrint(
            'SupabaseRealtimeService: Error untracking order $orderId - $e');
      }
    }
  }

  /// Met à jour le statut d'une commande
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': status.dbValue}).eq('id', orderId);
      debugPrint(
          'SupabaseRealtimeService: Updated order $orderId status to ${status.dbValue}');
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Error updating order status - $e');
      rethrow;
    }
  }

  /// Assigne une livraison à un livreur
  Future<void> assignDelivery(String orderId, String deliveryId) async {
    try {
      await _supabase
          .from('orders')
          .update({'delivery_person_id': deliveryId}).eq('id', orderId);
      debugPrint(
          'SupabaseRealtimeService: Assigned order $orderId to delivery $deliveryId');
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Error assigning delivery - $e');
      rethrow;
    }
  }

  /// Accepte une livraison (pour les livreurs)
  Future<void> acceptDelivery(String orderId) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': OrderStatus.pickedUp.dbValue}).eq('id', orderId);
      debugPrint('SupabaseRealtimeService: Delivery $orderId accepted');
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Error accepting delivery - $e');
      rethrow;
    }
  }

  /// Marque une commande comme livrée
  Future<void> markAsDelivered(String orderId) async {
    await updateOrderStatus(orderId, OrderStatus.delivered);
  }

  /// Met à jour la position de livraison
  Future<void> updateDeliveryLocation(
      String orderId, double latitude, double longitude) async {
    try {
      await _supabase.from('order_locations').upsert({
        'order_id': orderId,
        'lat': latitude,
        'lng': longitude,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint(
          'SupabaseRealtimeService: Updated location for order $orderId');
    } catch (e) {
      debugPrint(
          'SupabaseRealtimeService: Error updating delivery location - $e');
      rethrow;
    }
  }

  /// Envoie une notification à un utilisateur
  Future<void> sendNotification(String targetUserId, String message) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': targetUserId,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('SupabaseRealtimeService: Sent notification to $targetUserId');
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Error sending notification - $e');
      rethrow;
    }
  }

  /// Crée une nouvelle commande avec géocodage automatique
  Future<String?> createOrderWithGeocoding(
      Map<String, dynamic> orderData) async {
    try {
      final response = await _supabase
          .from('orders')
          .insert(orderData)
          .select('id')
          .single();
      return response['id']?.toString();
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Error creating order - $e');
      return null;
    }
  }

  /// Obtient les commandes d'un utilisateur
  Future<List<Order>> getUserOrders(String userId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((e) => Order.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Error getting user orders - $e');
      return [];
    }
  }

  /// Déconnecte tous les canaux
  Future<void> disconnect() async {
    // Déconnecter tous les canaux de commandes suivies
    for (final entry in _trackedOrderChannels.entries) {
      try {
        await entry.value.unsubscribe();
      } catch (e) {
        debugPrint(
            'SupabaseRealtimeService: Error unsubscribing from ${entry.key} - $e');
      }
    }
    _trackedOrderChannels.clear();
    _trackedOrders.clear();

    // Déconnecter les canaux généraux
    try {
      await _ordersChannel?.unsubscribe();
    } catch (e) {
      debugPrint(
          'SupabaseRealtimeService: Error unsubscribing from orders channel - $e');
    }
    try {
      await _driversChannel?.unsubscribe();
    } catch (e) {
      debugPrint(
          'SupabaseRealtimeService: Error unsubscribing from drivers channel - $e');
    }

    _ordersChannel = null;
    _driversChannel = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(disconnect());
    _orderUpdatesController.close();
    _deliveryLocationUpdatesController.close();
    _notificationsController.close();
    super.dispose();
  }
}
