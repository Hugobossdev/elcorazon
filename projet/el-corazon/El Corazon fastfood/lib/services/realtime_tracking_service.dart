import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/user.dart';
import 'package:elcora_fast/repositories/django_order_repository.dart';
import 'package:elcora_fast/services/supabase_realtime_service.dart';
import 'package:elcora_fast/services/geocoding_service.dart';

/// Suivi de commande — Phase 6 : `orderUpdates`/`deliveryLocationUpdates`
/// viennent désormais de `ws/orders/{id}/tracking/` (backend Django,
/// `apps/tracking/consumers.py`) au lieu de Supabase Realtime. Le reste de ce
/// service (statuts admin, position livreur, notifications, création de
/// commande, géocodage) sert d'autres écrans/rôles ou est déjà supplanté par
/// une tranche précédente — inchangé, toujours sur `SupabaseRealtimeService`/
/// `GeocodingService`.
class RealtimeTrackingService extends ChangeNotifier {
  static final RealtimeTrackingService _instance =
      RealtimeTrackingService._internal();
  factory RealtimeTrackingService() => _instance;
  RealtimeTrackingService._internal();

  final SupabaseRealtimeService _supabaseService = SupabaseRealtimeService();
  final GeocodingService _geocodingService = GeocodingService();

  eccore.RealtimeChannel? _channel;
  StreamSubscription<eccore.RealtimeEvent>? _channelSubscription;
  final _orderUpdatesController = StreamController<Order>.broadcast();
  final _deliveryLocationUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isConnected = false;

  // Position actuelle du livreur
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // Suivi de commande (Django, Phase 6)
  Stream<Order> get orderUpdates => _orderUpdatesController.stream;
  Stream<Map<String, dynamic>> get deliveryLocationUpdates =>
      _deliveryLocationUpdatesController.stream;

  // Hors scope de cette tranche — toujours Supabase
  Stream<String> get notifications => _supabaseService.notifications;
  Map<String, Order> get trackedOrders => _supabaseService.trackedOrders;
  Map<String, Map<String, dynamic>> get activeDeliveries =>
      _supabaseService.activeDeliveries;

  bool get isConnected => _isConnected;

  /// Marque le service prêt à suivre des commandes. Contrairement à
  /// l'ancienne connexion Supabase (globale), l'état de connexion réel est
  /// désormais par commande suivie (`trackOrder`), pas ici.
  Future<void> initialize({
    required String userId,
    required UserRole userRole,
  }) async {
    _isConnected = true;
    notifyListeners();
  }

  String _trackingWsUrl(String orderId) {
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1';
    final apiUri = Uri.parse(apiBaseUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: apiUri.host,
      port: apiUri.port,
      path: '/ws/orders/$orderId/tracking/',
    ).toString();
  }

  /// Suit une commande spécifique — `ws/orders/{id}/tracking/` (Django).
  Future<void> trackOrder(String orderId) async {
    await _channelSubscription?.cancel();
    await _channel?.close();

    final channel = eccore.RealtimeChannel(
      wsUrl: _trackingWsUrl(orderId),
      tokenStorage: eccore.TokenStorage(),
    );
    _channel = channel;

    _channelSubscription = channel.connect().listen((event) async {
      switch (event.type) {
        case 'order.status':
          // Le message ne porte que ce qu'il faut à la diffusion (statut,
          // raison) — pas la commande entière ; on la relit pour rester
          // cohérent avec ce que l'écran affiche déjà.
          final order = await DjangoOrderRepository().getOrderById(orderId);
          if (order != null) {
            _orderUpdatesController.add(order);
          }
          break;
        case 'tracking.position':
          // `speed`/`heading` ne sont pas relayés par ce canal côté serveur
          // (voir `apps/tracking/consumers.py OrderTrackingConsumer`) — le
          // livreur les émet, mais la diffusion ne les porte pas.
          final payload = event.payload;
          _deliveryLocationUpdatesController.add({
            'orderId': orderId,
            'latitude': (payload['lat'] as num).toDouble(),
            'longitude': (payload['lon'] as num).toDouble(),
            'timestamp': DateTime.parse(payload['recorded_at'] as String),
            'speed': null,
            'heading': null,
          });
          break;
      }
    });
  }

  /// Arrête de suivre une commande
  Future<void> untrackOrder(String orderId) async {
    await _channelSubscription?.cancel();
    await _channel?.close();
    _channel = null;
    _channelSubscription = null;
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
    await _channelSubscription?.cancel();
    await _channel?.close();
    _isConnected = false;

    notifyListeners();

    debugPrint('RealtimeTrackingService: Déconnecté');
  }

  /// Nettoie les ressources
  @override
  void dispose() {
    disconnect();
    _orderUpdatesController.close();
    _deliveryLocationUpdatesController.close();
    super.dispose();
  }
}
