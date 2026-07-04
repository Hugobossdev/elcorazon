import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/user.dart';
import 'package:elcora_fast/services/supabase_realtime_service.dart';
import 'package:elcora_fast/services/geocoding_service.dart';
import 'package:elcora_fast/services/socket_service.dart';

class RealtimeTrackingService extends ChangeNotifier {
  static final RealtimeTrackingService _instance =
      RealtimeTrackingService._internal();
  factory RealtimeTrackingService() => _instance;
  RealtimeTrackingService._internal();

  final SupabaseRealtimeService _supabaseService = SupabaseRealtimeService();
  final GeocodingService _geocodingService = GeocodingService();

  // Position actuelle du livreur
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // Getters pour les streams (délégués au service Supabase)
  Stream<Order> get orderUpdates => _supabaseService.orderUpdates;
  Stream<Map<String, dynamic>> get deliveryLocationUpdates =>
      _supabaseService.deliveryLocationUpdates;
  Stream<String> get notifications => _supabaseService.notifications;

  // État de connexion
  bool get isConnected => _supabaseService.isConnected;

  // Liste des commandes suivies
  Map<String, Order> get trackedOrders => _supabaseService.trackedOrders;

  // Liste des livreurs actifs
  Map<String, Map<String, dynamic>> get activeDeliveries =>
      _supabaseService.activeDeliveries;

  /// Initialise la connexion Supabase Realtime
  Future<void> initialize({
    required String userId,
    required UserRole userRole,
  }) async {
    try {
      // Initialiser le service Supabase
      await _supabaseService.initialize(userId: userId, userRole: userRole);

      notifyListeners();

      debugPrint('RealtimeTrackingService: Connexion établie');
    } catch (e) {
      debugPrint('RealtimeTrackingService: Erreur de connexion - $e');
      notifyListeners();
    }
  }

  /// Suit une commande spécifique
  Future<void> trackOrder(String orderId) async {
    // 1. Join Socket.io room for real-time updates (low latency)
    final socketService = SocketService();
    if (socketService.isConnected) {
      socketService.joinRoom('order_$orderId');

      // Listen for driver location updates via Socket.io
      socketService.onDriverLocation((data) {
        if (data != null && data['lat'] != null && data['lng'] != null) {
          final lat = double.tryParse(data['lat'].toString()) ?? 0.0;
          final lng = double.tryParse(data['lng'].toString()) ?? 0.0;

          _currentPosition = Position(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );

          // Notify UI listeners (e.g. Google Map)
          notifyListeners();

          debugPrint('📍 Socket.io: Driver location updated: $lat, $lng');
        }
      });

      socketService.onOrderUpdate((data) {
        debugPrint('🔔 Socket.io: Order status update: $data');
        // Here we could also update the local order status if needed
      });
    }

    // 2. Keep Supabase as fallback/persistence layer
    if (!_supabaseService.isConnected) {
      debugPrint(
        'RealtimeTrackingService: Service Supabase non initialisé, impossible de suivre la commande via Supabase',
      );
      return;
    }
    await _supabaseService.trackOrder(orderId);
  }

  /// Arrête de suivre une commande
  Future<void> untrackOrder(String orderId) async {
    if (!_supabaseService.isConnected) {
      debugPrint(
        'RealtimeTrackingService: Service non initialisé, impossible d\'arrêter le suivi',
      );
      return;
    }
    await _supabaseService.untrackOrder(orderId);
  }

  /// Met à jour le statut d'une commande (pour les admins)
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _supabaseService.updateOrderStatus(orderId, status);
  }

  /// Marque une commande comme livrée
  Future<void> markAsDelivered(String orderId) async {
    await _supabaseService.markAsDelivered(orderId);
  }

  /// Met à jour la position de livraison
  Future<void> updateDeliveryLocation(
    String orderId,
    double latitude,
    double longitude,
  ) async {
    await _supabaseService.updateDeliveryLocation(orderId, latitude, longitude);
  }

  /// Envoie une notification à un utilisateur spécifique
  Future<void> sendNotification(String targetUserId, String message) async {
    await _supabaseService.sendNotification(targetUserId, message);
  }

  /// Crée une nouvelle commande avec géocodage automatique
  Future<String?> createOrderWithGeocoding(
    Map<String, dynamic> orderData,
  ) async {
    return await _supabaseService.createOrderWithGeocoding(orderData);
  }

  /// Obtient les commandes d'un utilisateur
  Future<List<Order>> getUserOrders(String userId) async {
    return await _supabaseService.getUserOrders(userId);
  }

  /// Géocode une adresse
  Future<LatLng?> geocodeAddress(String address) async {
    return await _geocodingService.geocodeAddress(address);
  }

  /// Calcule la distance entre deux points
  double calculateDistance(LatLng point1, LatLng point2) {
    return _geocodingService.calculateDistance(point1, point2);
  }

  /// Calcule le temps de trajet estimé
  Future<int?> calculateTravelTime(LatLng origin, LatLng destination) async {
    return await _geocodingService.calculateTravelTime(origin, destination);
  }

  /// Obtient les directions entre deux points
  Future<List<LatLng>?> getDirections(LatLng origin, LatLng destination) async {
    return await _geocodingService.getDirections(origin, destination);
  }

  /// Ferme la connexion
  Future<void> disconnect() async {
    await _supabaseService.disconnect();

    notifyListeners();

    debugPrint('RealtimeTrackingService: Déconnecté');
  }

  /// Nettoie les ressources
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
