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
  final Map<String, RealtimeChannel> _trackedOrderLocationChannels = {};

  // ---- État de connexion ----
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  // Timer pour reconnexion automatique
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

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

  /// Initialisation principale avec l'utilisateur courant.
  ///
  /// On garde la signature attendue par `RealtimeTrackingService` et
  /// `ServiceInitializer`.
  Future<void> initialize({
    required String userId,
    required UserRole userRole,
  }) async {
    if (_isConnected && _reconnectAttempts == 0) {
      debugPrint('SupabaseRealtimeService: Already connected, skipping init');
      return;
    }

    try {
      // Charger les données initiales avant de s'abonner
      await loadInitialData(userId);

      _isConnected = true;
      _reconnectAttempts = 0; // Reset les tentatives de reconnexion
      notifyListeners();

      // Abonnements de base
      _subscribeToOrders(userId);
      _subscribeToNotifications(userId);

      debugPrint(
        'SupabaseRealtimeService: initialized for user $userId, role $userRole',
      );
    } catch (e) {
      debugPrint('SupabaseRealtimeService: error during initialize - $e');
      _isConnected = false;
      _scheduleReconnect(userId);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Souscriptions Realtime basiques
  // ---------------------------------------------------------------------------

  void _subscribeToOrders(String userId) {
    try {
      // Se désabonner de l'ancien canal s'il existe
      _orderChannel?.unsubscribe();

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
              try {
                final order = Order.fromMap(data);
                _trackedOrders[order.id] = order;
                _orderUpdatesController.add(order);
                debugPrint(
                  'SupabaseRealtimeService: Order updated via WebSocket - ${order.id}',
                );
              } catch (e) {
                debugPrint(
                  'SupabaseRealtimeService: error parsing order - $e',
                );
              }
              notifyListeners();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final data = payload.newRecord;
              try {
                final order = Order.fromMap(data);
                _trackedOrders[order.id] = order;
                _orderUpdatesController.add(order);
                debugPrint(
                  'SupabaseRealtimeService: New order created via WebSocket - ${order.id}',
                );
              } catch (e) {
                debugPrint(
                  'SupabaseRealtimeService: error parsing new order - $e',
                );
              }
              notifyListeners();
            },
          )
          .subscribe((status, [error]) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              debugPrint(
                'SupabaseRealtimeService: Successfully subscribed to orders channel',
              );
              _reconnectAttempts = 0; // Reset sur succès
            } else if (status == RealtimeSubscribeStatus.channelError) {
              debugPrint(
                'SupabaseRealtimeService: Error subscribing to orders channel: $error',
              );
              _scheduleReconnect(userId);
            }
          });
    } catch (e) {
      debugPrint('SupabaseRealtimeService: error subscribing to orders - $e');
      _scheduleReconnect(userId);
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

  /// Charge les données initiales avant de s'abonner aux mises à jour
  Future<void> loadInitialData(String userId) async {
    try {
      // Charger les commandes actives de l'utilisateur
      final orders = await getUserOrders(userId);
      for (final order in orders) {
        _trackedOrders[order.id] = order;
        // Charger les dernières positions si la commande est en cours
        if (order.status == OrderStatus.onTheWay ||
            order.status == OrderStatus.pickedUp) {
          await _loadLatestDeliveryLocation(order.id);
        }
      }
      debugPrint(
        'SupabaseRealtimeService: Loaded ${orders.length} initial orders',
      );
    } catch (e) {
      debugPrint(
        'SupabaseRealtimeService: Error loading initial data - $e',
      );
    }
  }

  /// Charge la dernière position de livraison pour une commande
  Future<void> _loadLatestDeliveryLocation(String orderId) async {
    try {
      final response = await _supabase
          .from('delivery_locations')
          .select()
          .eq('order_id', orderId)
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final locationData = {
          'orderId': orderId,
          'latitude': (response['latitude'] as num).toDouble(),
          'longitude': (response['longitude'] as num).toDouble(),
          'timestamp': (response['timestamp'] as String),
          'speed': response['speed'] != null
              ? (response['speed'] as num).toDouble()
              : null,
          'heading': response['heading'] != null
              ? (response['heading'] as num).toDouble()
              : null,
        };
        _deliveryLocationUpdatesController.add(locationData);
      }
    } catch (e) {
      debugPrint(
        'SupabaseRealtimeService: Error loading delivery location - $e',
      );
    }
  }

  Future<void> trackOrder(String orderId) async {
    debugPrint('SupabaseRealtimeService: trackOrder($orderId)');
    
    // S'abonner aux mises à jour de position pour cette commande spécifique
    _subscribeToDeliveryLocation(orderId);
    
    // Charger les données initiales pour cette commande
    await _loadLatestDeliveryLocation(orderId);
  }

  Future<void> untrackOrder(String orderId) async {
    debugPrint('SupabaseRealtimeService: untrackOrder($orderId)');
    
    // Se désabonner du canal de position pour cette commande
    final channel = _trackedOrderLocationChannels.remove(orderId);
    if (channel != null) {
      try {
        await channel.unsubscribe();
      } catch (e) {
        debugPrint(
          'SupabaseRealtimeService: Error unsubscribing from location channel - $e',
        );
      }
    }
    
    _trackedOrders.remove(orderId);
    notifyListeners();
  }

  /// S'abonne aux mises à jour de position pour une commande spécifique
  void _subscribeToDeliveryLocation(String orderId) {
    // Éviter les doublons
    if (_trackedOrderLocationChannels.containsKey(orderId)) {
      return;
    }

    try {
      final channel = _supabase
          .channel('delivery_locations:$orderId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'delivery_locations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_id',
              value: orderId,
            ),
            callback: (payload) {
              final data = payload.newRecord;
              try {
                final locationData = {
                  'orderId': orderId,
                  'latitude': (data['latitude'] as num).toDouble(),
                  'longitude': (data['longitude'] as num).toDouble(),
                  'timestamp': data['timestamp']?.toString() ??
                      DateTime.now().toIso8601String(),
                  'speed': data['speed'] != null
                      ? (data['speed'] as num).toDouble()
                      : null,
                  'heading': data['heading'] != null
                      ? (data['heading'] as num).toDouble()
                      : null,
                  'accuracy': data['accuracy'] != null
                      ? (data['accuracy'] as num).toDouble()
                      : null,
                };
                _activeDeliveries[orderId] = locationData;
                _deliveryLocationUpdatesController.add(locationData);
                debugPrint(
                  'SupabaseRealtimeService: Delivery location updated via WebSocket for order $orderId',
                );
              } catch (e) {
                debugPrint(
                  'SupabaseRealtimeService: Error parsing delivery location - $e',
                );
              }
              notifyListeners();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'delivery_locations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_id',
              value: orderId,
            ),
            callback: (payload) {
              final data = payload.newRecord;
              try {
                final locationData = {
                  'orderId': orderId,
                  'latitude': (data['latitude'] as num).toDouble(),
                  'longitude': (data['longitude'] as num).toDouble(),
                  'timestamp': data['timestamp']?.toString() ??
                      DateTime.now().toIso8601String(),
                  'speed': data['speed'] != null
                      ? (data['speed'] as num).toDouble()
                      : null,
                  'heading': data['heading'] != null
                      ? (data['heading'] as num).toDouble()
                      : null,
                  'accuracy': data['accuracy'] != null
                      ? (data['accuracy'] as num).toDouble()
                      : null,
                };
                _activeDeliveries[orderId] = locationData;
                _deliveryLocationUpdatesController.add(locationData);
              } catch (e) {
                debugPrint(
                  'SupabaseRealtimeService: Error parsing delivery location update - $e',
                );
              }
              notifyListeners();
            },
          )
          .subscribe((status, [error]) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              debugPrint(
                'SupabaseRealtimeService: Successfully subscribed to delivery location for order $orderId',
              );
            } else if (status == RealtimeSubscribeStatus.channelError) {
              debugPrint(
                'SupabaseRealtimeService: Error subscribing to delivery location channel: $error',
              );
            }
          });

      _trackedOrderLocationChannels[orderId] = channel;
    } catch (e) {
      debugPrint(
        'SupabaseRealtimeService: Error subscribing to delivery location - $e',
      );
    }
  }

  /// Planifie une tentative de reconnexion
  void _scheduleReconnect(String userId) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
        'SupabaseRealtimeService: Max reconnect attempts reached, stopping reconnection',
      );
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    
    // Délai exponentiel : 2s, 4s, 8s, 16s, 32s
    final delay = Duration(seconds: 2 * (1 << (_reconnectAttempts - 1)));
    
    debugPrint(
      'SupabaseRealtimeService: Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s',
    );

    _reconnectTimer = Timer(delay, () {
      if (!_isConnected) {
        debugPrint('SupabaseRealtimeService: Attempting to reconnect...');
        // Utiliser le rôle client par défaut pour la reconnexion
        initialize(userId: userId, userRole: UserRole.client);
      }
    });
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      // Utiliser dbValue pour envoyer la valeur snake_case à la base de données
      await _supabase
          .from('orders')
          .update({'status': status.dbValue}).eq('id', orderId);
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
    double longitude, {
    double? speed,
    double? heading,
    double? accuracy,
  }) async {
    try {
      // Essayer d'abord avec delivery_locations (table standard)
      await _supabase.from('delivery_locations').insert({
        'order_id': orderId,
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed,
        'heading': heading,
        'accuracy': accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      }).catchError((error) {
        // Fallback vers order_locations si delivery_locations n'existe pas
        debugPrint(
          'SupabaseRealtimeService: delivery_locations failed, trying order_locations - $error',
        );
        return _supabase.from('order_locations').upsert({
          'order_id': orderId,
          'lat': latitude,
          'lng': longitude,
          'updated_at': DateTime.now().toIso8601String(),
        });
      });

      // L'événement sera automatiquement diffusé via WebSocket
      // Mais on peut aussi l'ajouter manuellement pour compatibilité
      final location = <String, dynamic>{
        'orderId': orderId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'speed': speed,
        'heading': heading,
        'accuracy': accuracy,
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
      final response = await _supabase
          .from('orders')
          .insert(orderData)
          .select('id')
          .single();
      return response['id']?.toString();
    } catch (e) {
      debugPrint(
          'SupabaseRealtimeService: createOrderWithGeocoding error - $e',);
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
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      await _orderChannel?.unsubscribe();
    } catch (_) {}
    try {
      await _notificationChannel?.unsubscribe();
    } catch (_) {}

    // Se désabonner de tous les canaux de position
    for (final channel in _trackedOrderLocationChannels.values) {
      try {
        await channel.unsubscribe();
      } catch (_) {}
    }
    _trackedOrderLocationChannels.clear();

    _orderChannel = null;
    _notificationChannel = null;
    _isConnected = false;

    _trackedOrders.clear();
    _activeDeliveries.clear();

    notifyListeners();
    
    debugPrint('SupabaseRealtimeService: Disconnected');
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
