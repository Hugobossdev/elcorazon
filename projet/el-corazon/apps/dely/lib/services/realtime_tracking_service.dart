import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

import 'package:elcora_dely/repositories/django_delivery_repository.dart';

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

  /// Intervalle minimal entre deux relevés envoyés au serveur.
  ///
  /// Le serveur n'en retient de toute façon qu'un toutes les
  /// `TRACKING_MIN_WRITE_SECONDS` (30 s) ou tous les
  /// `TRACKING_MIN_WRITE_METERS` (100 m) — voir `apps/tracking/services.py`.
  /// Émettre plus vite consomme du réseau et de la batterie pour des relevés
  /// que le serveur écarte, et rapproche du quota (`429`).
  static const _emissionMinimumInterval = Duration(seconds: 10);

  /// Déplacement à partir duquel le système réveille l'application.
  ///
  /// Sous le seuil serveur (100 m) à dessein : un relevé à 25 m arrivé juste
  /// après les 30 s d'attente est écrit, alors qu'un filtre à 100 m ferait
  /// perdre les déplacements lents — un livreur dans les embouteillages.
  static const _distanceFilterMeters = 25;

  /// Battement pour un livreur immobile.
  ///
  /// Le flux de position ne dit rien tant que rien ne bouge : sans ce
  /// battement, un livreur arrêté à un feu ou attendant au restaurant
  /// disparaîtrait de la carte du client, qui verrait sa dernière position
  /// vieillir sans savoir si le suivi fonctionne encore.
  static const _heartbeatInterval = Duration(seconds: 30);

  // --- file des courses proposées (ws/couriers/me/)
  eccore.RealtimeChannel? _feedChannel;
  StreamSubscription<eccore.RealtimeEvent>? _feedSubscription;
  final _courseOffersController = StreamController<eccore.AssignmentOffer>.broadcast();

  /// Reprise de la file après coupure.
  ///
  /// `RealtimeChannel` ne tente **qu'une seule** reconnexion, puis ferme le
  /// flux : c'est une politique délibérée du socle, partagée avec
  /// l'application cliente, où un flux perdu se rattrape au prochain
  /// rechargement d'écran.
  ///
  /// Elle ne convient pas ici. Un livreur roule, traverse des zones sans
  /// réseau, et sa file est le seul flux où rater un événement a un coût
  /// métier direct (ADR-008) : une course non vue est un repas qui refroidit.
  /// Après deux coupures — quelques minutes de tournée — la file restait
  /// fermée pour le reste de la session, sans que rien ne la rouvre, et le
  /// livreur ne dépendait plus que du sondage de trente secondes de l'écran
  /// d'accueil, à condition qu'il soit ouvert.
  ///
  /// La reprise vit donc ici, où l'on sait qu'une session de livreur est
  /// ouverte, et non dans le socle.
  Timer? _feedReconnectTimer;
  int _feedReconnectAttempts = 0;

  /// Une session de livreur est-elle ouverte ? Décide si une reprise de la
  /// file a encore un sens : rouvrir le socket d'un livreur déconnecté
  /// l'ouvrirait au nom de personne.
  bool _sessionOpen = false;

  /// Report exponentiel, plafonné : inutile de marteler un serveur injoignable,
  /// et une minute d'attente reste courte devant une tournée. Le plafond est
  /// aussi ce qui fait qu'un dossier non éligible (fermeture `4403`) coûte une
  /// poignée de main par minute — et rouvre la file de lui-même dès qu'il est
  /// validé, sans redémarrage de l'application.
  static const _feedRetryDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 40),
    Duration(seconds: 60),
  ];

  // --- suivi d'une commande (ws/orders/{id}/tracking/)
  eccore.RealtimeChannel? _orderChannel;
  StreamSubscription<eccore.RealtimeEvent>? _orderSubscription;
  String? _trackedOrderId;
  final _orderUpdatesController = StreamController<Course>.broadcast();
  final _deliveryLocationUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();

  // --- émission de position
  StreamSubscription<Position>? _positionSubscription;
  Timer? _heartbeatTimer;
  DateTime? _lastEmissionAt;
  Position? _currentPosition;

  /// Pourquoi le suivi ne tourne pas, s'il ne tourne pas. `null` quand tout va
  /// bien.
  ///
  /// Le service se contentait d'écrire une ligne de journal et de ne rien
  /// faire : le livreur restait « en ligne » à l'écran, croyait être suivi, et
  /// n'apprenait le contraire que par le reproche d'un client. Cet état-là est
  /// fait pour être affiché.
  String? _trackingUnavailableReason;

  Future<Course?> Function(String orderId)? _readCourse;
  Future<void> Function(Position position)? _reportPosition;

  bool _isFeedConnected = false;

  /// Position du livreur, rafraîchie par la boucle d'émission. Nulle tant que
  /// [startCourierSession] n'a pas obtenu de relevé — un `null` veut donc dire
  /// « pas encore localisé », jamais « immobile ».
  Position? get currentPosition => _currentPosition;

  /// Les courses qu'on me propose, à mesure qu'elles arrivent.
  Stream<eccore.AssignmentOffer> get courseOffers => _courseOffersController.stream;

  Stream<Course> get orderUpdates => _orderUpdatesController.stream;
  Stream<Map<String, dynamic>> get deliveryLocationUpdates =>
      _deliveryLocationUpdatesController.stream;

  /// Vrai quand la file des courses est ouverte. C'est l'état qui compte pour
  /// le livreur : sans elle, il ne sera prévenu d'une course que par le
  /// prochain rechargement manuel.
  bool get isConnected => _isFeedConnected;

  /// Vrai quand le flux de position est ouvert et qu'un relevé peut partir.
  bool get isTrackingLocation => _positionSubscription != null;

  /// Ce qui empêche le suivi, en une phrase destinée au livreur. `null` quand
  /// le suivi tourne.
  String? get trackingUnavailableReason => _trackingUnavailableReason;

  /// Branche les deux gestes qui demandent de connaître les courses. Appelé une
  /// fois par `AppService`, qui les détient.
  ///
  /// [readCourse] relit la course après un changement de statut ; le message
  /// diffusé ne porte que le statut et sa raison, pas la commande entière.
  /// [reportPosition] dépose un relevé sur la course en cours — l'affectation
  /// visée n'est connue que d'`AppService`.
  void bind({
    required Future<Course?> Function(String orderId) readCourse,
    required Future<void> Function(Position position) reportPosition,
  }) {
    _readCourse = readCourse;
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
    _sessionOpen = true;
    await _connectCourierFeed();
    await _startPositionEmission();
    notifyListeners();
  }

  /// Referme la file et arrête l'émission — à la déconnexion, ou dès que le
  /// compte n'est plus celui d'un livreur.
  Future<void> stopCourierSession() async {
    _sessionOpen = false;
    _feedReconnectTimer?.cancel();
    _feedReconnectTimer = null;
    _feedReconnectAttempts = 0;

    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastEmissionAt = null;
    _currentPosition = null;
    _trackingUnavailableReason = null;

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
        // Un message reçu prouve que la file fonctionne : le compteur de
        // reprises repart de zéro, sans quoi une coupure de la veille
        // imposerait encore une minute d'attente à la suivante.
        _feedReconnectAttempts = 0;

        if (event.type != 'delivery.offered') return;
        _courseOffersController.add(eccore.AssignmentOffer.fromPayload(event.payload));
      },
      onDone: () {
        _isFeedConnected = false;
        notifyListeners();
        _scheduleFeedReconnect();
      },
    );

    // Le consommateur refuse la connexion d'un dossier non éligible (L1, code
    // 4403) : le flux se ferme alors sans qu'aucun événement ne soit passé, et
    // `onDone` remet cet état à faux.
    _isFeedConnected = true;
  }

  /// Ouvre le flux de position et l'émission vers le serveur.
  ///
  /// ## Ce qui a remplacé quoi
  ///
  /// Une minuterie Dart appelait `getCurrentPosition` toutes les dix secondes.
  /// Deux défauts, dont un rédhibitoire :
  ///
  /// * **une minuterie Dart ne survit pas à l'arrière-plan.** Android gèle le
  ///   processus peu après que le livreur range son téléphone, et le suivi
  ///   s'arrêtait sans que rien ne le dise — précisément quand il sert,
  ///   puisqu'un livreur qui roule ne regarde pas son écran ;
  /// * **un point GPS neuf toutes les dix secondes coûte cher** en batterie,
  ///   pour des relevés que le serveur écarte de toute façon à moins de 100 m
  ///   ou 30 s du précédent (`apps/tracking/services.py`).
  ///
  /// Le flux, lui, s'adosse au service de premier plan déclaré par
  /// `geolocator_android` : il continue en arrière-plan, sous une notification
  /// que le livreur voit — il sait donc qu'il est suivi, ce qui n'est pas
  /// négociable.
  /// Reprogramme l'ouverture de la file après une fermeture subie.
  ///
  /// Ne fait rien si la session a été fermée entre-temps : rouvrir la file
  /// d'un livreur déconnecté ouvrirait un socket au nom de personne.
  void _scheduleFeedReconnect() {
    _feedReconnectTimer?.cancel();

    final delai = _feedRetryDelays[
        _feedReconnectAttempts.clamp(0, _feedRetryDelays.length - 1)];
    _feedReconnectAttempts++;

    eccore.Journal.trace(
      '🔌 File des courses fermée — nouvelle tentative dans '
      '${delai.inSeconds} s',
    );

    _feedReconnectTimer = Timer(delai, () {
      if (!_sessionOpen) return;
      unawaited(_connectCourierFeed().then((_) => notifyListeners()));
    });
  }

  Future<void> _startPositionEmission() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();

    final obstacle = await _locationObstacle();
    if (obstacle != null) {
      _trackingUnavailableReason = obstacle;
      eccore.Journal.trace('⚠️ Suivi impossible : $obstacle');
      notifyListeners();
      return;
    }
    _trackingUnavailableReason = null;

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: _locationSettings).listen(
      (position) {
        _currentPosition = position;
        notifyListeners();
        unawaited(_emitPosition(position));
      },
      onError: (Object error) {
        // Le flux se ferme sur erreur : sans ce marquage, `isTrackingLocation`
        // resterait vrai sur un abonnement mort.
        _trackingUnavailableReason = 'Position indisponible : $error';
        eccore.Journal.trace('⚠️ Flux de position interrompu : $error');
        notifyListeners();
      },
    );

    // Battement pour le livreur immobile — voir [_heartbeatInterval].
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final position = _currentPosition;
      if (position != null) unawaited(_emitPosition(position));
    });

    notifyListeners();
  }

  /// Réglages du flux, par plateforme.
  ///
  /// Les deux déclarent l'arrière-plan explicitement : c'est ce qui distingue
  /// un suivi de livraison d'un relevé ponctuel.
  LocationSettings get _locationSettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
        intervalDuration: _emissionMinimumInterval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Course en cours',
          notificationText: 'Votre position est partagée avec le client.',
          notificationChannelName: 'Suivi de livraison',
          // Le système ne laisse pas ce service tourner sans notification
          // visible, et c'est tant mieux : le livreur doit savoir qu'il est
          // suivi. `setOngoing` empêche seulement de la balayer par mégarde.
          setOngoing: true,
          enableWakeLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      // `allowBackgroundLocationUpdates` et `pauseLocationUpdatesAutomatically`
      // ne sont pas répétés : le greffon les fixe déjà à `true` et `false`,
      // ce dont le suivi a besoin — iOS suspend sinon les relevés dès qu'il
      // croit le trajet terminé, ce qu'il fait sur un livreur qui attend au
      // restaurant. L'indicateur, lui, est demandé explicitement : le livreur
      // doit voir que sa position part.
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
        showBackgroundLocationIndicator: true,
        activityType: ActivityType.automotiveNavigation,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _distanceFilterMeters,
    );
  }

  /// Ce qui empêche de relever la position, dit au livreur. `null` si rien.
  ///
  /// Les trois cas se distinguent parce qu'ils appellent trois gestes
  /// différents : rallumer le GPS, répondre à la demande, ou passer par les
  /// réglages du système — un refus définitif ne se redemande pas.
  Future<String?> _locationObstacle() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'La localisation est désactivée sur cet appareil.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return switch (permission) {
      LocationPermission.always || LocationPermission.whileInUse => null,
      LocationPermission.deniedForever =>
        'Position refusée définitivement : autorisez-la dans les réglages du téléphone.',
      _ => 'Position non autorisée : le client ne peut pas suivre sa livraison.',
    };
  }

  /// Remet un relevé à `AppService`, au plus une fois par
  /// [_emissionMinimumInterval].
  ///
  /// Rien n'est relancé en cas d'échec : un relevé perdu n'a aucune valeur,
  /// c'est le suivant qui compte. Une file de relevés en attente ferait
  /// remonter, au retour du réseau, des positions que le livreur a quittées
  /// depuis longtemps.
  Future<void> _emitPosition(Position position) async {
    final derniere = _lastEmissionAt;
    if (derniere != null &&
        DateTime.now().difference(derniere) < _emissionMinimumInterval) {
      return;
    }
    _lastEmissionAt = DateTime.now();

    try {
      await _reportPosition?.call(position);
    } catch (e) {
      eccore.Journal.trace('⚠️ Émission de position impossible : $e');
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
          final course = await _readCourse?.call(orderId);
          if (course != null) _orderUpdatesController.add(course);
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

  // Quatre délégations de géocodage vivaient ici — adresse vers
  // coordonnées, distance, temps de trajet, itinéraire — et aucune n'avait
  // d'appelant : l'écran de suivi construisait sa propre instance de
  // `GeocodingService`, et l'itinéraire passe par `DirectionsService`, adossé
  // au `DirectionsRepository` du socle. Un service de transport temps réel
  // n'a pas à proxyfier une API de cartographie.

  /// Ferme tout : file des courses, émission, et suivi de commande éventuel.
  Future<void> disconnect() async {
    await stopCourierSession();

    await _orderSubscription?.cancel();
    await _orderChannel?.close();
    _orderSubscription = null;
    _orderChannel = null;
    _trackedOrderId = null;

    eccore.Journal.trace('RealtimeTrackingService: Déconnecté');
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
