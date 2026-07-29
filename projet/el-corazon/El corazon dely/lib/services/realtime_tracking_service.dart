import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

import '../models/order.dart';
import 'geocoding_service.dart';

/// Transport temps réel du livreur (Phase 6) — remplace intégralement
/// `SupabaseRealtimeService`, supprimé avec cette tranche.
///
/// Trois flux, et le partage des rôles entre eux est celui du backend, pas une
/// commodité d'implémentation :
///
/// * **`ws/couriers/me/`** — la file des courses proposées. C'est le seul flux
///   où rater un message a un coût métier direct (ADR-008) : une course non vue
///   est un repas qui refroidit. La route ne porte aucun identifiant, le groupe
///   est déduit du jeton — un livreur ne peut pas écouter la file d'un collègue.
/// * **`ws/orders/{id}/tracking/`** — le suivi d'une commande en cours, ouvert à
///   la demande par les écrans de suivi.
/// * **l'émission de position, qui passe par HTTP** et non par le WebSocket :
///   `CourierFeedConsumer` est en lecture seule, rien n'y remonte. Le plan de
///   migration décrivait d'abord l'inverse ; c'est le contrat qui tranche.
///
/// Ce service ne connaît ni les courses ni les repositories : il transporte.
/// [bind] lui fournit les deux gestes qui demandent cette connaissance, et que
/// seul `AppService` peut rendre.
class RealtimeTrackingService extends ChangeNotifier {
  static final RealtimeTrackingService _instance =
      RealtimeTrackingService._internal();
  factory RealtimeTrackingService() => _instance;
  RealtimeTrackingService._internal();

  /// Cadence d'émission attendue par le serveur (`common/throttling.py` :
  /// « un livreur émet toutes les dix secondes »). Inutile d'aller plus vite :
  /// l'échantillonnage écarte tout relevé à moins de `TRACKING_MIN_WRITE_METERS`
  /// du précédent, et le quota répondrait `429`.
  static const _emissionInterval = Duration(seconds: 10);

  final GeocodingService _geocodingService = GeocodingService();

  // --- file des courses proposées (ws/couriers/me/)
  eccore.RealtimeChannel? _feedChannel;
  StreamSubscription<eccore.RealtimeEvent>? _feedSubscription;
  final _courseOffersController = StreamController<eccore.AssignmentOffer>.broadcast();

  // --- suivi d'une commande (ws/orders/{id}/tracking/)
  eccore.RealtimeChannel? _orderChannel;
  StreamSubscription<eccore.RealtimeEvent>? _orderSubscription;
  String? _trackedOrderId;
  final _orderUpdatesController = StreamController<Order>.broadcast();
  final _deliveryLocationUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();

  // --- émission de position
  Timer? _emissionTimer;
  Position? _currentPosition;

  Future<Order?> Function(String orderId)? _readOrder;
  Future<void> Function(Position position)? _reportPosition;

  bool _isFeedConnected = false;

  /// Position du livreur, rafraîchie par la boucle d'émission. Nulle tant que
  /// [startCourierSession] n'a pas obtenu de relevé — un `null` veut donc dire
  /// « pas encore localisé », jamais « immobile ».
  Position? get currentPosition => _currentPosition;

  /// Les courses qu'on me propose, à mesure qu'elles arrivent.
  Stream<eccore.AssignmentOffer> get courseOffers => _courseOffersController.stream;

  Stream<Order> get orderUpdates => _orderUpdatesController.stream;
  Stream<Map<String, dynamic>> get deliveryLocationUpdates =>
      _deliveryLocationUpdatesController.stream;

  /// Vrai quand la file des courses est ouverte. C'est l'état qui compte pour
  /// le livreur : sans elle, il ne sera prévenu d'une course que par le
  /// prochain rechargement manuel.
  bool get isConnected => _isFeedConnected;

  /// Branche les deux gestes qui demandent de connaître les courses. Appelé une
  /// fois par `AppService`, qui les détient.
  ///
  /// [readOrder] relit une commande après un changement de statut ; le message
  /// diffusé ne porte que le statut et sa raison, pas la commande entière.
  /// [reportPosition] dépose un relevé sur la course en cours — l'affectation
  /// visée n'est connue que d'`AppService`.
  void bind({
    required Future<Order?> Function(String orderId) readOrder,
    required Future<void> Function(Position position) reportPosition,
  }) {
    _readOrder = readOrder;
    _reportPosition = reportPosition;
  }

  String _wsUrl(String path) {
    final apiBaseUrl =
        dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1';
    final apiUri = Uri.parse(apiBaseUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: apiUri.host,
      port: apiUri.port,
      path: path,
    ).toString();
  }

  // ------------------------------------------------- session du livreur

  /// Ouvre la file des courses et démarre l'émission de position.
  ///
  /// Les deux vivent le temps de la session, pas le temps d'un écran : un
  /// livreur qui quitte la carte reste suivi et reste joignable. C'est
  /// précisément ce que l'émission portée par l'écran de suivi ne garantissait
  /// pas — fermer l'écran suffisait à disparaître.
  Future<void> startCourierSession() async {
    await _connectCourierFeed();
    await _startPositionEmission();
    notifyListeners();
  }

  /// Referme la file et arrête l'émission — à la déconnexion, ou dès que le
  /// compte n'est plus celui d'un livreur.
  Future<void> stopCourierSession() async {
    _emissionTimer?.cancel();
    _emissionTimer = null;
    _currentPosition = null;

    await _feedSubscription?.cancel();
    await _feedChannel?.close();
    _feedSubscription = null;
    _feedChannel = null;
    _isFeedConnected = false;

    notifyListeners();
  }

  Future<void> _connectCourierFeed() async {
    await _feedSubscription?.cancel();
    await _feedChannel?.close();

    final channel = eccore.RealtimeChannel(
      wsUrl: _wsUrl('/ws/couriers/me/'),
      tokenStorage: eccore.TokenStorage(),
    );
    _feedChannel = channel;

    _feedSubscription = channel.connect().listen(
      (event) {
        if (event.type != 'delivery.offered') return;
        _courseOffersController.add(eccore.AssignmentOffer.fromPayload(event.payload));
      },
      onDone: () {
        // Le canal ne rouvre pas indéfiniment (une seule reconnexion). Le dire
        // plutôt que laisser croire à une file ouverte : l'écran retombe alors
        // sur le rechargement manuel, qui reste correct, seulement plus lent.
        _isFeedConnected = false;
        notifyListeners();
      },
    );

    // Le consommateur refuse la connexion d'un dossier non éligible (L1, code
    // 4403) : le flux se ferme alors sans qu'aucun événement ne soit passé, et
    // `onDone` remet cet état à faux.
    _isFeedConnected = true;
  }

  Future<void> _startPositionEmission() async {
    _emissionTimer?.cancel();

    if (!await _ensureLocationPermission()) {
      debugPrint('⚠️ Position non autorisée : aucune émission de suivi.');
      return;
    }

    await _emitPosition();
    _emissionTimer = Timer.periodic(
      _emissionInterval,
      (_) => unawaited(_emitPosition()),
    );
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Un relevé, puis sa remise à `AppService`.
  ///
  /// Rien n'est relancé en cas d'échec : un relevé perdu n'a aucune valeur,
  /// c'est le suivant qui compte. Une file de relevés en attente ferait
  /// remonter, au retour du réseau, des positions que le livreur a quittées
  /// depuis longtemps.
  Future<void> _emitPosition() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      notifyListeners();

      await _reportPosition?.call(_currentPosition!);
    } catch (e) {
      debugPrint('⚠️ Relevé de position impossible : $e');
    }
  }

  // --------------------------------------------------- suivi d'une commande

  /// Suit une commande — `ws/orders/{id}/tracking/`.
  Future<void> trackOrder(String orderId) async {
    await _orderSubscription?.cancel();
    await _orderChannel?.close();

    final channel = eccore.RealtimeChannel(
      wsUrl: _wsUrl('/ws/orders/$orderId/tracking/'),
      tokenStorage: eccore.TokenStorage(),
    );
    _orderChannel = channel;
    _trackedOrderId = orderId;

    _orderSubscription = channel.connect().listen((event) async {
      switch (event.type) {
        case 'order.status':
          // Le message ne porte que le statut et sa raison ; la commande se
          // relit pour rester cohérente avec ce que l'écran affiche déjà.
          final order = await _readOrder?.call(orderId);
          if (order != null) _orderUpdatesController.add(order);
          break;
        case 'tracking.position':
          // `speed`/`heading` ne sont pas relayés par ce canal côté serveur
          // (`OrderTrackingConsumer`) — le livreur les émet, la diffusion ne
          // les porte pas.
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

  Future<void> untrackOrder(String orderId) async {
    if (_trackedOrderId != orderId) return;

    await _orderSubscription?.cancel();
    await _orderChannel?.close();
    _orderSubscription = null;
    _orderChannel = null;
    _trackedOrderId = null;
  }

  // ------------------------------------------------------------ géocodage
  //
  // Sans rapport avec Supabase : ces quatre-là s'appuient sur Google Maps et
  // n'ont pas bougé avec la migration.

  Future<LatLng?> geocodeAddress(String address) =>
      _geocodingService.geocodeAddress(address);

  double calculateDistance(LatLng point1, LatLng point2) =>
      _geocodingService.calculateDistance(point1, point2);

  Future<int?> calculateTravelTime(LatLng origin, LatLng destination) =>
      _geocodingService.calculateTravelTime(origin, destination);

  Future<List<LatLng>?> getDirections(LatLng origin, LatLng destination) =>
      _geocodingService.getDirections(origin, destination);

  /// Ferme tout : file des courses, émission, et suivi de commande éventuel.
  Future<void> disconnect() async {
    await stopCourierSession();

    await _orderSubscription?.cancel();
    await _orderChannel?.close();
    _orderSubscription = null;
    _orderChannel = null;
    _trackedOrderId = null;

    debugPrint('RealtimeTrackingService: Déconnecté');
  }

  @override
  void dispose() {
    disconnect();
    _courseOffersController.close();
    _orderUpdatesController.close();
    _deliveryLocationUpdatesController.close();
    super.dispose();
  }
}
