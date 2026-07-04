import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import '../models/user.dart';
import 'geocoding_service.dart';

class SupabaseRealtimeService extends ChangeNotifier {
  static final SupabaseRealtimeService _instance =
      SupabaseRealtimeService._internal();
  factory SupabaseRealtimeService() => _instance;
  SupabaseRealtimeService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  bool _isConnected = false;
  String? _currentUserId;

  // Stream controllers pour les différents types d'événements
  final StreamController<Order> _orderUpdatesController =
      StreamController<Order>.broadcast();
  final StreamController<Map<String, dynamic>> _deliveryLocationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _notificationController =
      StreamController<String>.broadcast();

  // Getters pour les addStreams
  Stream<Order> get orderUpdates => _orderUpdatesController.stream;
  Stream<Map<String, dynamic>> get deliveryLocationUpdates =>
      _deliveryLocationController.stream;
  Stream<String> get notifications => _notificationController.stream;

  // État de connexion
  bool get isConnected => _isConnected;

  // Liste des commandes suivies
  final Map<String, Order> _trackedOrders = {};
  Map<String, Order> get trackedOrders => Map.unmodifiable(_trackedOrders);

  // Liste des livreurs actifs
  final Map<String, Map<String, dynamic>> _activeDeliveries = {};
  Map<String, Map<String, dynamic>> get activeDeliveries =>
      Map.unmodifiable(_activeDeliveries);

  /// Initialise la connexion Supabase Realtime
  Future<void> initialize(
      {required String userId, required UserRole userRole}) async {
    _currentUserId = userId;

    try {
      // Créer un canal de suivi pour cet utilisateur
      _channel = _supabase
          .channel('user_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: _handleOrderChange,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'delivery_locations',
            callback: _handleDeliveryLocationChange,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: _handleNotificationChange,
          )
          .subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _isConnected = true;
          notifyListeners();
          debugPrint('SupabaseRealtimeService: Connexion établie');
        } else if (status == RealtimeSubscribeStatus.closed) {
          _isConnected = false;
          notifyListeners();
          debugPrint('SupabaseRealtimeService: Connexion fermée');
        } else if (status == RealtimeSubscribeStatus.channelError) {
          _isConnected = false;
          notifyListeners();
          debugPrint('SupabaseRealtimeService: Erreur de canal - $error');
        }
      });

      debugPrint('SupabaseRealtimeService: Initialisation terminée');
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Erreur d\'initialisation - $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  /// Gère les changements dans les commandes
  void _handleOrderChange(PostgresChangePayload payload) {
    try {
      debugPrint(
          'SupabaseRealtimeService: Changement de commande - ${payload.eventType}');

      final orderData = payload.newRecord;
      final order = Order.fromMap(Map<String, dynamic>.from(orderData));
      _trackedOrders[order.id] = order;
      _orderUpdatesController.add(order);
    } catch (e) {
      debugPrint(
          'SupabaseRealtimeService: Erreur de traitement de commande - $e');
    }
  }

  /// Gère les changements de position des livreurs
  void _handleDeliveryLocationChange(PostgresChangePayload payload) {
    try {
      debugPrint(
          'SupabaseRealtimeService: Changement de position livreur - ${payload.eventType}');

      final locationData = payload.newRecord;
      final Map<String, dynamic> location =
          Map<String, dynamic>.from(locationData);
      final deliveryId = location['delivery_id'];

      _activeDeliveries[deliveryId] = {
        'deliveryId': deliveryId,
        'latitude': location['latitude'],
        'longitude': location['longitude'],
        'timestamp': DateTime.now().toIso8601String(),
        'orderId': location['order_id'],
      };

      _deliveryLocationController.add(_activeDeliveries[deliveryId]!);
    } catch (e) {
      debugPrint(
          'SupabaseRealtimeService: Erreur de traitement de position - $e');
    }
  }

  /// Gère les notifications
  void _handleNotificationChange(PostgresChangePayload payload) {
    try {
      debugPrint(
          'SupabaseRealtimeService: Notification reçue - ${payload.eventType}');

      final notificationData = payload.newRecord;
      final Map<String, dynamic> notification =
          Map<String, dynamic>.from(notificationData);
      final message = notification['message'] ?? '';
      _notificationController.add(message);
    } catch (e) {
      debugPrint(
          'SupabaseRealtimeService: Erreur de traitement de notification - $e');
    }
  }

  /// Suit une commande spécifique
  Future<void> trackOrder(String orderId) async {
    try {
      await _supabase.from('order_tracking').upsert({
        'order_id': orderId,
        'user_id': _currentUserId,
        'is_tracking': true,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'order_id,user_id');

      debugPrint('SupabaseRealtimeService: Commande suivie - $orderId');
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Erreur de suivi de commande - $e');
    }
  }

  /// Arrête de suivre une commande
  Future<void> untrackOrder(String orderId) async {
    try {
      _trackedOrders.remove(orderId);
      await _supabase
          .from('order_tracking')
          .update({'is_tracking': false})
          .eq('order_id', orderId)
          .eq('user_id', _currentUserId!);

      debugPrint('SupabaseRealtimeService: Arrêt du suivi - $orderId');
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Erreur d\'arrêt de suivi - $e');
    }
  }

  /// Met à jour le statut d'une commande
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _supabase.from('orders').update({
        'status': status.toString().split('.').last,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      debugPrint(
          'SupabaseRealtimeService: Statut mis à jour - $orderId: $status');
    } catch (e) {
      debugPrint(
          'SupabaseRealtimeService: Erreur de mise à jour de statut - $e');
    }
  }

  /// Assigne une livraison à un livreur
  Future<void> assignDelivery(String orderId, String deliveryId) async {
    try {
      await _supabase.from('orders').update({
        'delivery_person_id': deliveryId,
        'status': 'assigned',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      debugPrint(
          'SupabaseRealtimeService: Livraison assignée - $orderId à $deliveryId');
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Erreur d\'assignation - $e');
    }
  }

  /// Accepte une livraison
  Future<void> acceptDelivery(String orderId) async {
    try {
      await _supabase
          .from('orders')
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .eq('delivery_person_id', _currentUserId!);

      debugPrint('SupabaseRealtimeService: Livraison acceptée - $orderId');
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Erreur d\'acceptation - $e');
    }
  }

  /// Marque une commande comme livrée
  Future<void> markAsDelivered(String orderId) async {
    try {
      await _supabase
          .from('orders')
          .update({
            'status': 'delivered',
            'delivered_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .eq('delivery_person_id', _currentUserId!);

      debugPrint(
          'SupabaseRealtimeService: Commande marquée comme livrée - $orderId');
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Erreur de livraison - $e');
    }
  }

  /// Met à jour la position d'un livreur
  Future<void> updateDeliveryLocation(
      String orderId, double latitude, double longitude) async {
    try {
      await _supabase.from('delivery_locations').upsert({
        'order_id': orderId,
        'delivery_id': _currentUserId,
        'latitude': latitude,
        'longitude': longitude,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('SupabaseRealtimeService: Position mise à jour - $orderId');
    } catch (e) {
      debugPrint(
          'SupabaseRealtimeService: Erreur de mise à jour de position - $e');
    }
  }

  /// Envoie une notification à un utilisateur
  Future<void> sendNotification(String targetUserId, String message) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': targetUserId,
        'message': message,
        'from_user_id': _currentUserId,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint(
          'SupabaseRealtimeService: Notification envoyée - $targetUserId');
    } catch (e) {
      debugPrint(
          'SupabaseRealtimeService: Erreur d\'envoi de notification - $e');
    }
  }

  /// Crée une nouvelle commande avec géocodage automatique
  Future<String?> createOrderWithGeocoding(
      Map<String, dynamic> orderData) async {
    try {
      // Géocoder l'adresse de livraison
      final geocodingService = GeocodingService();
      final address = orderData['delivery_address'];
      final coordinates = await geocodingService.geocodeAddress(address);

      if (coordinates != null) {
        orderData['delivery_latitude'] = coordinates.latitude;
        orderData['delivery_longitude'] = coordinates.longitude;
      }

      final response = await _supabase
          .from('orders')
          .insert(orderData)
          .select('id')
          .single();

      final orderId = response['id'] as String;
      debugPrint(
          'SupabaseRealtimeService: Commande créée avec géocodage - $orderId');
      return orderId;
    } catch (e) {
      debugPrint(
          'SupabaseRealtimeService: Erreur de création de commande - $e');
      return null;
    }
  }

  /// Obtient les commandes actives d'un utilisateur
  Future<List<Order>> getUserOrders(String userId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final orders = (response as List)
          .map((orderData) =>
              Order.fromMap(Map<String, dynamic>.from(orderData)))
          .toList();

      debugPrint(
          'SupabaseRealtimeService: Commandes récupérées - ${orders.length}');
      return orders;
    } catch (e) {
      debugPrint(
          'SupabaseRealtimeService: Erreur de récupération des commandes - $e');
      return [];
    }
  }

  /// Ferme la connexion
  Future<void> disconnect() async {
    try {
      if (_channel != null) {
        await _supabase.removeChannel(_channel!);
        _channel = null;
      }

      _isConnected = false;
      _trackedOrders.clear();
      _activeDeliveries.clear();
      notifyListeners();

      debugPrint('SupabaseRealtimeService: Déconnecté');
    } catch (e) {
      debugPrint('SupabaseRealtimeService: Erreur de déconnexion - $e');
    }
  }

  /// Nettoie les ressources
  @override
  void dispose() {
    disconnect();
    _orderUpdatesController.close();
    _deliveryLocationController.close();
    _notificationController.close();
    super.dispose();
  }
}
