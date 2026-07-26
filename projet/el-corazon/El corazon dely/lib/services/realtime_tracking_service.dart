import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/order.dart';
import '../models/user.dart';
import 'supabase_realtime_service.dart';
import 'geocoding_service.dart';

class RealtimeTrackingService extends ChangeNotifier {
  static final RealtimeTrackingService _instance =
      RealtimeTrackingService._internal();
  factory RealtimeTrackingService() => _instance;
  RealtimeTrackingService._internal();

  final SupabaseRealtimeService _supabaseService = SupabaseRealtimeService();
  final GeocodingService _geocodingService = GeocodingService();
  Timer? _locationUpdateTimer;

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
  Future<void> initialize(
      {required String userId, required UserRole userRole}) async {
    try {
      // Initialiser le service Supabase
      await _supabaseService.initialize(userId: userId, userRole: userRole);

      notifyListeners();

      // Si c'est un livreur, démarrer le suivi GPS
      if (userRole == UserRole.delivery) {
        await _startLocationTracking();
      }

      debugPrint('RealtimeTrackingService: Connexion établie');
    } catch (e) {
      debugPrint('RealtimeTrackingService: Erreur de connexion - $e');
      notifyListeners();
    }
  }

  /// Démarre le suivi GPS pour les livreurs
  Future<void> _startLocationTracking() async {
    // Vérifier les permissions GPS
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('RealtimeTrackingService: Service de localisation désactivé');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint(
            'RealtimeTrackingService: Permission de localisation refusée');
        return;
      }
    }

    // Démarrer le timer de mise à jour de position
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _updateLocation();
    });

    // Première mise à jour immédiate
    await _updateLocation();
  }

  /// Met à jour la position actuelle
  Future<void> _updateLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Envoyer la position au serveur Supabase
      // Note: Il faudrait avoir un orderId actif pour mettre à jour la position
      // Pour l'instant, on stocke juste la position
      debugPrint('RealtimeTrackingService: Position mise à jour');
    } catch (e) {
      debugPrint('RealtimeTrackingService: Erreur de localisation - $e');
    }
  }

  /// Suit une commande spécifique
  Future<void> trackOrder(String orderId) async {
    await _supabaseService.trackOrder(orderId);
  }

  /// Arrête de suivre une commande
  Future<void> untrackOrder(String orderId) async {
    await _supabaseService.untrackOrder(orderId);
  }

  /// Met à jour le statut d'une commande (pour les admins)
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _supabaseService.updateOrderStatus(orderId, status);
  }

  /// Assigne une livraison à un livreur (pour les admins)
  Future<void> assignDelivery(String orderId, String deliveryId) async {
    await _supabaseService.assignDelivery(orderId, deliveryId);
  }

  /// Accepte une livraison (pour les livreurs)
  Future<void> acceptDelivery(String orderId) async {
    await _supabaseService.acceptDelivery(orderId);
  }

  /// Marque une commande comme livrée
  Future<void> markAsDelivered(String orderId) async {
    await _supabaseService.markAsDelivered(orderId);
  }

  /// Met à jour la position de livraison
  Future<void> updateDeliveryLocation(
      String orderId, double latitude, double longitude) async {
    await _supabaseService.updateDeliveryLocation(orderId, latitude, longitude);
  }

  /// Envoie une notification à un utilisateur spécifique
  Future<void> sendNotification(String targetUserId, String message) async {
    await _supabaseService.sendNotification(targetUserId, message);
  }

  /// Crée une nouvelle commande avec géocodage automatique
  Future<String?> createOrderWithGeocoding(
      Map<String, dynamic> orderData) async {
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
    _locationUpdateTimer?.cancel();
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
