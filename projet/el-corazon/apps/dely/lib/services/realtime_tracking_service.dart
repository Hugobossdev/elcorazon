import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcora_dely/config/adresses.dart';

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
class RealtimeTrackingService extends ChangeNotifier
    with WidgetsBindingObserver {
  static final RealtimeTrackingService _instance =
      RealtimeTrackingService._internal();
  factory RealtimeTrackingService() => _instance;
  RealtimeTrackingService._internal();

  /// Cadence d'émission, de filtrage et de reprise.
  ///
  /// Ces trois nombres étaient des constantes privées de cette classe : justes,
  /// mais impossibles à corriger sans republier l'application du livreur — or
  /// c'est précisément le genre de valeur qu'on ajuste à la lecture du terrain.
  /// Ils vivent maintenant dans `TrackingSettings` (socle), se lisent depuis
  /// l'environnement, et sont bornés par ce que le serveur accepte.
  ///
  /// Relus paresseusement : `dotenv` peut ne pas être chargé quand ce singleton
  /// est construit, et une lecture faite trop tôt figerait les valeurs par
  /// défaut pour toute la session.
  eccore.TrackingSettings? _reglagesLus;

  eccore.TrackingSettings get reglages {
    final dejaLus = _reglagesLus;
    if (dejaLus != null) return dejaLus;

    // `dotenv.env` **lève** tant que le fichier n'a pas été chargé — et il
    // peut ne jamais l'être : `main()` avale l'échec de `dotenv.load` pour que
    // l'application démarre quand même sur un `.env` manquant. Sans cette
    // garde, chaque relevé de position faisait alors remonter un
    // `NotInitializedError` au fond d'un écouteur asynchrone, et le suivi ne
    // démarrait pas — pour un fichier de configuration facultatif.
    final lus = eccore.TrackingSettings.depuisEnvironnement(
      dotenv.isInitialized ? dotenv.env : const {},
    );
    // **Toutes** les anomalies, pas seulement la première : n'en montrer qu'une
    // fait corriger le `.env` par tâtonnement, un redémarrage par ligne.
    // Journalisées, pas appliquées — un `.env` douteux ne doit pas couper le
    // suivi, il doit se voir.
    for (final avertissement in lus.avertissements) {
      eccore.Journal.trace('⚠️ Réglage de suivi : $avertissement');
    }
    return _reglagesLus = lus;
  }

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

  /// Le livreur a-t-il une course **en cours** ?
  ///
  /// ## Pourquoi le suivi ne suit plus la session
  ///
  /// Il la suivait : ouvrir l'application allumait le GPS jusqu'à la
  /// déconnexion. Trois choses en découlaient, toutes fausses.
  ///
  /// * **La batterie.** Un flux haute précision tourne alors pendant les
  ///   heures où le livreur attend une course. C'est le poste de dépense le
  ///   plus lourd d'un téléphone, et il ne servait à personne : hors course, le
  ///   serveur n'a aucune affectation à laquelle rattacher un relevé (L3), et
  ///   `updateDeliveryLocation` rendait la main sans rien envoyer.
  /// * **La promesse faite au livreur.** `Info.plist` lui annonce que sa
  ///   position « n'est pas relevée entre deux courses » ; le code relevait.
  ///   Une déclaration de confidentialité qui ne décrit pas le code est un
  ///   motif de rejet App Store, et surtout ce n'est pas vrai.
  /// * **La notification permanente.** Le service de premier plan Android
  ///   affichait « Course en cours » à un livreur qui n'en avait aucune.
  ///
  /// La porte est donc la course, et `AppService` la tient : il est le seul à
  /// savoir qu'une affectation est acceptée et pas encore livrée.
  bool _courseEnCours = false;

  /// Reprise du suivi quand l'obstacle a disparu.
  ///
  /// L'obstacle était constaté **une fois**, au démarrage : un livreur qui
  /// accepte une course GPS éteint, puis le rallume, restait hors suivi pour
  /// toute la course — rien ne relisait la condition. Le client voyait sa
  /// dernière position vieillir sans explication, et le livreur un bandeau
  /// qu'aucun de ses gestes ne faisait disparaître.
  Timer? _reprisePositionTimer;

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

  String _wsUrl(String path) => adresseWebSocket(path);

  // ------------------------------------------------- session du livreur

  /// Ouvre la file des courses.
  ///
  /// Elle vit le temps de la session, pas le temps d'un écran : un livreur qui
  /// quitte la carte reste joignable. C'est précisément ce qu'une file portée
  /// par un écran ne garantissait pas — le fermer suffisait à ne plus recevoir
  /// de course.
  ///
  /// **N'allume pas le GPS.** Le suivi de position, lui, est adossé à la
  /// course : voir [_courseEnCours] et [suivreLaCourse].
  Future<void> startCourierSession() async {
    // Rappelée sur une session déjà ouverte, elle inscrirait l'observateur une
    // seconde fois : `addObserver` empile, `removeObserver` n'en retire qu'un,
    // et chaque retour au premier plan déclencherait alors deux ouvertures de
    // flux concurrentes.
    if (_sessionOpen) return;
    _sessionOpen = true;
    // L'observateur de cycle de vie relit l'obstacle au retour au premier plan :
    // c'est là que le livreur revient d'un aller dans les réglages du système,
    // et le seul moment où l'on sait qu'il a peut-être changé quelque chose.
    WidgetsBinding.instance.addObserver(this);
    await _connectCourierFeed();
    notifyListeners();
  }

  /// Referme la file et arrête l'émission — à la déconnexion, ou dès que le
  /// compte n'est plus celui d'un livreur.
  Future<void> stopCourierSession() async {
    _sessionOpen = false;
    WidgetsBinding.instance.removeObserver(this);
    _feedReconnectTimer?.cancel();
    _feedReconnectTimer = null;
    _feedReconnectAttempts = 0;

    await _arreterEmission();
    _courseEnCours = false;

    await _feedSubscription?.cancel();
    await _feedChannel?.close();
    _feedSubscription = null;
    _feedChannel = null;
    _isFeedConnected = false;

    notifyListeners();
  }

  /// Ouvre ou ferme le suivi selon qu'une course est en cours.
  ///
  /// Appelée par `AppService` à chaque fois que l'état des courses bouge —
  /// acceptation, enlèvement, livraison, annulation, réaffectation,
  /// rechargement de la liste. Idempotente : la rappeler avec la même valeur ne
  /// rouvre pas le flux, ce qui compte parce qu'elle est appelée souvent et
  /// qu'un flux réouvert redemande une fixation au capteur.
  ///
  /// C'est cette porte, et non un `if` dans l'émission, qui réalise le cycle :
  ///
  ///     course acceptée → suivi actif → livrée/annulée → suivi arrêté
  Future<void> suivreLaCourse({required bool enCours}) async {
    if (_courseEnCours == enCours) return;
    _courseEnCours = enCours;

    if (!enCours) {
      eccore.Journal.trace('📍 Plus de course en cours — suivi arrêté.');
      await _arreterEmission();
      notifyListeners();
      return;
    }

    eccore.Journal.trace('📍 Course en cours — suivi démarré.');
    await _startPositionEmission();
  }

  /// Le suivi a-t-il encore lieu d'être, ici et maintenant ?
  ///
  /// Une session ouverte **et** une course en cours. Nommé plutôt que recopié :
  /// il se relit après chaque `await`, et une des trois relectures manquait.
  bool get _suiviAttendu => _sessionOpen && _courseEnCours;

  /// Coupe le flux, le battement et la reprise, et oublie la dernière position.
  ///
  /// La position est oubliée délibérément : la garder ferait repartir le
  /// battement sur un relevé vieux d'une course, et `currentPosition`
  /// annoncerait « ici » un endroit que le livreur a quitté.
  Future<void> _arreterEmission() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reprisePositionTimer?.cancel();
    _reprisePositionTimer = null;
    _lastEmissionAt = null;
    _currentPosition = null;
    _trackingUnavailableReason = null;
  }

  /// Relit l'obstacle au retour au premier plan.
  ///
  /// Le livreur revient des réglages du système — GPS rallumé, permission
  /// accordée — et rien ne le constatait : l'obstacle avait été lu une fois,
  /// au démarrage du suivi. Il restait affiché sur un téléphone où il n'existait
  /// plus.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_suiviAttendu) return;
    if (_positionSubscription != null) return;

    unawaited(_startPositionEmission());
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
    _reprisePositionTimer?.cancel();
    _reprisePositionTimer = null;

    // Garde de dernier recours : le flux ne s'ouvre que pour une course. Sans
    // elle, une reprise programmée juste avant la livraison rallumerait le GPS
    // après l'arrêt.
    if (!_suiviAttendu) return;

    final obstacle = await _locationObstacle();

    // **Relue après l'attente**, et pas seulement avant.
    //
    // `_locationObstacle` peut afficher la demande de permission du système et
    // rester suspendu le temps que le livreur réponde — quelques secondes, ou
    // le temps qu'il range son téléphone. La course peut se terminer pendant
    // ce temps-là : le suivi s'arrête, `_arreterEmission` ne trouve aucun
    // abonnement à couper puisqu'il n'y en a pas encore, puis cette
    // continuation reprend et ouvre le flux **pour une course qui n'existe
    // plus**. Le GPS tournait alors jusqu'à la déconnexion, sous une
    // notification « Course en cours » qui ne correspondait à rien — le
    // fantôme exact que la porte devait supprimer.
    if (!_suiviAttendu) return;

    if (obstacle != null) {
      _trackingUnavailableReason = obstacle;
      eccore.Journal.trace('⚠️ Suivi impossible : $obstacle');
      // Reprogrammée, et non abandonnée : le livreur peut rallumer son GPS ou
      // accorder la permission pendant la course, et le suivi doit repartir
      // sans qu'il ait à quitter puis rouvrir l'application.
      _programmerLaReprise();
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
        // Un flux mort ne se rouvre pas tout seul. Le laisser en l'état était
        // le pire des cas : le livreur restait « en course », la carte du
        // client figée, et rien n'annonçait la panne côté serveur.
        unawaited(_positionSubscription?.cancel());
        _positionSubscription = null;
        _programmerLaReprise();
        notifyListeners();
      },
    );

    // Battement pour le livreur immobile — voir [reglages.heartbeatInterval].
    _heartbeatTimer = Timer.periodic(reglages.heartbeatInterval, (_) {
      final position = _currentPosition;
      if (position != null) unawaited(_emitPosition(position));
    });

    notifyListeners();
  }

  /// Traduction du cran de précision partagé vers l'énumération du greffon.
  ///
  /// `TrackingAccuracy` n'en compte que trois là où `geolocator` en propose
  /// six : le suivi n'a pas besoin des autres, et les offrir inviterait à un
  /// réglage dont personne ne saurait dire l'effet.
  LocationAccuracy get _precision => switch (reglages.accuracy) {
        eccore.TrackingAccuracy.basse => LocationAccuracy.low,
        eccore.TrackingAccuracy.moyenne => LocationAccuracy.medium,
        eccore.TrackingAccuracy.haute => LocationAccuracy.high,
      };

  /// Reprogramme une tentative d'ouverture du flux de position.
  ///
  /// Cadence unique et non exponentielle, contrairement à la reprise de la file
  /// des courses : ici, ce qu'on attend est un geste de l'utilisateur — rallumer
  /// le GPS, accorder la permission —, pas le rétablissement d'un serveur qu'on
  /// martèlerait. Espacer n'apporterait rien et retarderait la reprise du seul
  /// moment qui compte.
  void _programmerLaReprise() {
    _reprisePositionTimer?.cancel();
    _reprisePositionTimer = Timer(reglages.retryInterval, () {
      if (!_suiviAttendu) return;
      unawaited(_startPositionEmission());
    });
  }

  /// Réglages du flux, par plateforme.
  ///
  /// Les deux déclarent l'arrière-plan explicitement : c'est ce qui distingue
  /// un suivi de livraison d'un relevé ponctuel.
  LocationSettings get _locationSettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: _precision,
        distanceFilter: reglages.distanceFilterMeters,
        intervalDuration: reglages.emissionInterval,
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
        accuracy: _precision,
        distanceFilter: reglages.distanceFilterMeters,
        showBackgroundLocationIndicator: true,
        activityType: ActivityType.automotiveNavigation,
      );
    }
    return LocationSettings(
      accuracy: _precision,
      distanceFilter: reglages.distanceFilterMeters,
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
  /// [reglages.emissionInterval].
  ///
  /// Rien n'est relancé en cas d'échec : un relevé perdu n'a aucune valeur,
  /// c'est le suivant qui compte. Une file de relevés en attente ferait
  /// remonter, au retour du réseau, des positions que le livreur a quittées
  /// depuis longtemps.
  Future<void> _emitPosition(Position position) async {
    final derniere = _lastEmissionAt;
    if (derniere != null &&
        DateTime.now().difference(derniere) < reglages.emissionInterval) {
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
