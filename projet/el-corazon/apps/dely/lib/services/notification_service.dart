import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:elcora_dely/firebase_options.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

/// Reçu quand l'application est en arrière-plan ou fermée.
///
/// Point d'entrée isolé, exécuté dans un moteur Dart distinct : rien de l'état
/// de l'application n'y est accessible, d'où le `Firebase.initializeApp`. Le
/// système affiche lui-même la bannière tant que le message porte un bloc
/// `notification` ; ce gestionnaire ne sert qu'à la trace.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Journal.trace('📨 Message reçu en arrière-plan : ${message.messageId}');
}

/// Notifications d'appareil du livreur — permission, jeton FCM, affichage au
/// premier plan, et ouverture.
///
/// ## Ce que ce service n'est plus
///
/// Il portait une liste de **trois notifications fabriquées** au démarrage
/// — « 20 % de réduction sur votre première commande », « votre commande #1234
/// est en préparation », « votre livreur arrivera dans 10 minutes » — copiées
/// de l'application cliente, adressées à un client, dans l'application du
/// livreur. Aucun écran ne les affichait, et l'historique réel des
/// notifications se lit de toute façon sur `/api/v1/notifications/`, produit
/// par le serveur. Elles sont supprimées, avec les trois méthodes d'envoi
/// héritées du client (confirmation de commande, promotion, rappel).
///
/// ## Ce qu'il fait, et pourquoi il doit tourner
///
/// [initialize] n'était **appelée nulle part**. Sans elle : aucune permission
/// demandée, aucun jeton obtenu, donc `fcmToken` toujours nul, donc
/// `AppService` n'enregistrait jamais l'appareil auprès de `/auth/devices/`.
/// Le serveur poussait ses offres de course vers une liste d'appareils vide
/// (`apps/notifications/receivers.py`), et une course proposée n'atteignait le
/// livreur que si l'application était au premier plan au bon moment. C'est le
/// seul flux où rater un événement a un coût métier direct (ADR-008).
///
/// Une seule instance, comme `ChatService` et `RealtimeTrackingService` :
/// `main()` et `AppService` en construisaient chacun une, et seule celle de
/// `main()` aurait été initialisée — `AppService` aurait lu le jeton de
/// l'autre, toujours nul.
class NotificationService extends ChangeNotifier {
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  /// Canal des offres de course. Déclaré explicitement : depuis Android 8, une
  /// notification sans canal enregistré n'apparaît pas, et l'importance décide
  /// seule de la bannière — une course proposée qui ne s'affiche qu'en tirant
  /// le volet ne sert à rien à quelqu'un qui roule.
  static const _courseChannel = AndroidNotificationChannel(
    'delivery_offers',
    'Courses proposées',
    description: 'Les courses qui vous sont proposées.',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging? _messaging;
  String? _fcmToken;
  bool _isInitialized = false;
  AuthorizationStatus _authorization = AuthorizationStatus.notDetermined;

  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _openedController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Jeton d'appareil, ou `null` tant que [initialize] n'a pas abouti.
  String? get fcmToken => _fcmToken;

  bool get isInitialized => _isInitialized;

  /// Le livreur a-t-il accepté les notifications ? À afficher : un livreur qui
  /// a refusé ne recevra aucune offre et doit le savoir, plutôt que de
  /// s'étonner de ne rien recevoir.
  bool get isAuthorized =>
      _authorization == AuthorizationStatus.authorized ||
      _authorization == AuthorizationStatus.provisional;

  /// Émet à chaque rotation du jeton d'appareil (FCM le renouvelle de son
  /// propre chef, sans nous prévenir autrement). `AppService` s'y abonne pour
  /// ré-enregistrer le nouveau jeton auprès de `/auth/devices/` : sans cela le
  /// livreur cesse silencieusement de recevoir ses offres de course.
  Stream<String> get tokenRefreshStream => _tokenRefreshController.stream;

  /// Charge utile des notifications reçues ou ouvertes par le livreur — au
  /// premier plan, depuis l'arrière-plan, ou au démarrage à froid.
  ///
  /// Le serveur n'y met que de quoi ouvrir le bon écran (`assignment`,
  /// `order`), jamais une copie de l'objet métier : il aura changé d'ici la
  /// lecture. C'est donc l'API qui fait foi, et `AppService` recharge.
  Stream<Map<String, dynamic>> get openedNotifications =>
      _openedController.stream;

  /// À appeler une fois au démarrage, après `Firebase.initializeApp`.
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _initializeLocalNotifications();

    try {
      final messaging = FirebaseMessaging.instance;
      _messaging = messaging;

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      await _requestPermission(messaging);
      await _readToken(messaging);

      // Premier plan : le système n'affiche rien de lui-même, c'est à nous.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Ouverture depuis l'arrière-plan, puis démarrage à froid : les deux
      // chemins sont distincts côté Firebase, et n'en traiter qu'un laisse la
      // moitié des ouvertures sans effet.
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _onOpened(initial);
    } catch (e) {
      // Un échec ici ne doit pas empêcher l'application de démarrer : le
      // livreur garde la file WebSocket et le rechargement manuel.
      Journal.trace('⚠️ Notifications indisponibles : $e');
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _initializeLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _openedController.add({'order': payload});
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_courseChannel);
  }

  Future<void> _requestPermission(FirebaseMessaging messaging) async {
    final settings = await messaging.requestPermission();
    _authorization = settings.authorizationStatus;
    Journal.trace('🔔 Notifications : ${_authorization.name}');
  }

  Future<void> _readToken(FirebaseMessaging messaging) async {
    final token = await messaging.getToken();
    _fcmToken = token;
    Journal.trace('🔑 Jeton FCM ${token == null ? 'indisponible' : 'obtenu'}');

    messaging.onTokenRefresh.listen((refreshed) {
      _fcmToken = refreshed;
      _tokenRefreshController.add(refreshed);
    });

    // Le jeton peut arriver après que `AppService` a ouvert la session : sans
    // cette première émission, l'appareil ne serait enregistré qu'à la
    // prochaine rotation, c'est-à-dire peut-être jamais.
    if (token != null) _tokenRefreshController.add(token);
  }

  /// Affiche un message reçu alors que l'application est visible.
  ///
  /// Le bloc `notification` est lu quand il est là, mais l'affichage ne s'y
  /// résume pas : la charge `data` suffit à composer la bannière, et une
  /// implémentation qui ignorait les messages sans bloc `notification`
  /// laisserait passer sans bruit toute offre poussée en données seules.
  void _onForegroundMessage(RemoteMessage message) {
    final titre = message.notification?.title ?? 'Nouvelle course';
    final corps = message.notification?.body ??
        (message.data['reference'] as String? ?? '');

    unawaited(
      _localNotifications.show(
        message.hashCode,
        titre,
        corps,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _courseChannel.id,
            _courseChannel.name,
            channelDescription: _courseChannel.description,
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: message.data['order'] as String?,
      ),
    );

    // Le message annonce, il ne fait pas foi : c'est l'API qui porte l'étape,
    // les transitions permises et les montants. L'écouteur recharge.
    _openedController.add(Map<String, dynamic>.from(message.data));
  }

  void _onOpened(RemoteMessage message) {
    Journal.trace('📬 Notification ouverte : ${message.data}');
    _openedController.add(Map<String, dynamic>.from(message.data));
  }

  /// Retire le jeton de cet appareil côté FCM — à la déconnexion, après que le
  /// serveur l'a détaché du compte.
  ///
  /// Sans ce geste, le jeton reste valide : un appareil partagé entre deux
  /// tournées continuerait de recevoir les offres du livreur précédent si le
  /// détachement côté serveur avait échoué.
  Future<void> deleteToken() async {
    try {
      await _messaging?.deleteToken();
      _fcmToken = null;
    } catch (e) {
      Journal.trace('⚠️ Retrait du jeton FCM impossible : $e');
    }
  }

  @override
  void dispose() {
    unawaited(_tokenRefreshController.close());
    unawaited(_openedController.close());
    super.dispose();
  }
}
