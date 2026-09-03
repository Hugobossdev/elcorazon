import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:elcora_fast/models/order.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

/// Reçoit les messages quand l'app est fermée ou en arrière-plan. Doit être
/// une fonction de premier niveau annotée `@pragma('vm:entry-point')` : elle
/// est exécutée dans un isolat séparé, sans rien de l'état de l'app.
///
/// Rien à faire ici : Android affiche lui-même la notification portée par le
/// bloc `notification` du message, et l'historique se relit depuis
/// `/api/v1/notifications/` à la réouverture. Ce handler existe pour que le
/// message ne soit pas perdu et pour la trace.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  Journal.trace('PushNotificationService: message en arrière-plan ${message.messageId}');
}

/// Notifications de l'app client : locales (programmation, affichage) **et**
/// push FCM (Phase 6).
///
/// La partie push se limite volontairement à trois gestes : obtenir le jeton
/// d'appareil, le tenir à jour, et afficher au premier plan un message que le
/// système n'affiche pas de lui-même. C'est le backend qui décide *quoi*
/// envoyer et *à qui* — cette classe n'a aucune règle d'envoi.
class PushNotificationService extends ChangeNotifier {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _userId;
  String? _fcmToken;
  AuthorizationStatus _authorization = AuthorizationStatus.notDetermined;
  StreamSubscription<String>? _abonnementRotation;
  final StreamController<PushNotification> _notificationController =
      StreamController<PushNotification>.broadcast();

  /// Émet à chaque rotation du jeton d'appareil (FCM le renouvelle de son
  /// propre chef). `AppService` s'y abonne pour ré-enregistrer le nouveau
  /// jeton auprès de `/auth/devices/` — sans cela, l'appareil cesse
  /// silencieusement de recevoir quoi que ce soit.
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();

  // Getters
  bool get isInitialized => _isInitialized;
  String? get userId => _userId;

  /// Jeton d'appareil FCM, `null` tant que Firebase n'est pas initialisé ou
  /// que la permission n'a pas été accordée.
  String? get fcmToken => _fcmToken;

  /// L'utilisateur a-t-il accepté les notifications ?
  ///
  /// `provisional` compte comme accordé : c'est le mode iOS où les
  /// notifications arrivent discrètement, sans avoir été demandées — elles
  /// arrivent bel et bien.
  bool get isAuthorized =>
      _authorization == AuthorizationStatus.authorized ||
      _authorization == AuthorizationStatus.provisional;
  Stream<PushNotification> get notificationStream =>
      _notificationController.stream;
  Stream<String> get tokenRefreshStream => _tokenRefreshController.stream;

  /// Prépare tout ce qui **ne demande rien à l'utilisateur** — à appeler au
  /// démarrage.
  ///
  /// ## Pourquoi ce service était entièrement inerte
  ///
  /// `initialize()` n'avait **aucun appelant**. Le fournisseur de `main.dart`
  /// se contentait de construire l'objet (`create: (_) => …`, et `lazy`), le
  /// `PushNotificationRouter` écoutait un flux que rien n'alimentait, et
  /// `AppService._registerPushDeviceBestEffort` sortait dès sa première ligne
  /// puisque `fcmToken` restait nul. Résultat : aucune permission demandée,
  /// aucun jeton obtenu, **aucun appareil client enregistré**, et un serveur
  /// qui poussait vers une liste vide. Toute la chaîne existait et rien ne la
  /// démarrait — le même défaut que `dely` avait eu, dans l'autre application.
  ///
  /// ## Pourquoi c'est coupé en deux
  ///
  /// La permission ne se demande pas ici. Sur Android 13+, une demande faite
  /// au premier lancement — devant un écran d'accueil, avant même que
  /// l'utilisateur sache ce que l'application fait — se solde par un refus, et
  /// un refus y est **définitif** : le système ne redemandera plus. Elle est
  /// donc reportée à [enableForUser], appelée à l'ouverture de session, quand
  /// « suivre ma commande » veut dire quelque chose.
  ///
  /// Ce qui reste ici est tout ce qui doit être en place **avant** le premier
  /// message : le gestionnaire d'arrière-plan, les canaux Android, et les trois
  /// écoutes de réception. En particulier [FirebaseMessaging.getInitialMessage],
  /// qui n'est lisible **qu'une fois** : la différer ferait perdre la
  /// notification qui vient de lancer l'application.
  Future<void> prepare() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));

      await _initializeLocalNotifications();

      // Push FCM — indépendant de ce qui précède : un échec ici (pas de projet
      // Firebase configuré, services Google absents) laisse les notifications
      // locales fonctionnelles.
      await _ecouterLesMessages();

      _isInitialized = true;
      notifyListeners();
      Journal.trace('PushNotificationService: prêt (permission non demandée)');
    } catch (e) {
      Journal.trace('PushNotificationService: Erreur d\'initialisation - $e');
    }
  }

  /// Conservée pour les appelants existants : prépare, et demande la
  /// permission dans la foulée quand un compte est déjà connu.
  Future<void> initialize({String? userId}) async {
    await prepare();
    if (userId != null) await enableForUser(userId);
  }

  Future<void> _ecouterLesMessages() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Enregistré avant toute réception, et **sans condition de permission** :
      // c'est un point d'entrée de l'isolat d'arrière-plan, pas un affichage.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Les trois états de l'application, et ils sont bien trois chemins
      // distincts côté Firebase : n'en traiter que deux laisse un tiers des
      // ouvertures sans effet.
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedFromMessage);

      // Application **fermée**, lancée par la notification.
      // `onMessageOpenedApp` ne couvre que l'app déjà vivante en arrière-plan ;
      // au démarrage à froid, le message déclencheur n'y passe jamais et n'est
      // lisible qu'ici, une seule fois.
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _handleOpenedFromMessage(initial);
      }
    } catch (e) {
      // Notamment sur un appareil sans services Google, ou si le projet
      // Firebase n'est pas joignable : l'app tourne sans push plutôt que de
      // refuser de démarrer.
      Journal.trace('PushNotificationService: FCM indisponible - $e');
    }
  }

  /// Demande la permission et obtient le jeton — à l'ouverture de session.
  ///
  /// Idempotent par compte : rappelée pour le même utilisateur avec un jeton
  /// déjà en main, elle ne redemande rien.
  ///
  /// Un refus n'est **pas** une erreur : l'application continue, simplement
  /// sans push. Elle garde son suivi temps réel et son historique
  /// (`/api/v1/notifications/`), qui ne dépendent ni de FCM ni d'une
  /// permission système.
  Future<void> enableForUser(String userId) async {
    _userId = userId;

    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission();
      _authorization = settings.authorizationStatus;
      Journal.trace('PushNotificationService: permission ${_authorization.name}');

      if (!isAuthorized) return;

      _fcmToken = await messaging.getToken();
      Journal.trace(
        'PushNotificationService: jeton FCM ${_fcmToken == null ? 'indisponible' : 'obtenu'}',
      );

      await _abonnementRotation?.cancel();
      _abonnementRotation = messaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _tokenRefreshController.add(token);
      });

      // Le jeton peut arriver après que `AppService` a ouvert la session :
      // sans cette première émission, l'appareil ne serait enregistré qu'à la
      // prochaine rotation, c'est-à-dire peut-être jamais.
      final token = _fcmToken;
      if (token != null) _tokenRefreshController.add(token);

      notifyListeners();
    } catch (e) {
      Journal.trace('PushNotificationService: activation impossible - $e');
    }
  }

  /// Retire le jeton de cet appareil côté FCM — à la déconnexion, **après** que
  /// le serveur l'a détaché du compte.
  ///
  /// Sans ce geste, le jeton reste valide : un téléphone partagé continuerait
  /// de recevoir les notifications du compte précédent si le détachement côté
  /// serveur avait échoué. `dely` le faisait déjà ; l'app cliente non.
  Future<void> deleteToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      Journal.trace('PushNotificationService: retrait du jeton impossible - $e');
    }
    _fcmToken = null;
    _userId = null;
    await _abonnementRotation?.cancel();
    _abonnementRotation = null;
    notifyListeners();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    unawaited(
      _showLocalNotification(
        title: notification.title ?? 'El Corazón',
        body: notification.body ?? '',
        payload: json.encode(message.data),
        channelId: _channelForKind(message.data['kind']?.toString()),
      ),
    );
  }

  /// La dernière notification ouverte, tant que personne ne l'a traitée.
  ///
  /// ## Pourquoi une retenue, et pas seulement un flux
  ///
  /// `getInitialMessage()` est lue pendant [prepare], c'est-à-dire **avant
  /// `runApp`** : à cet instant, `PushNotificationRouter` n'est pas monté et
  /// n'écoute rien. Un `StreamController.broadcast` jette ce qu'il émet sans
  /// auditeur — la notification qui vient de lancer l'application serait donc
  /// perdue, et c'est précisément celle qui compte le plus.
  ///
  /// Elle est donc retenue ici, et le routeur la réclame à son montage.
  PushNotification? _ouvertureEnAttente;

  /// Réclame l'ouverture retenue, et la consomme.
  PushNotification? consommerOuvertureEnAttente() {
    final attente = _ouvertureEnAttente;
    _ouvertureEnAttente = null;
    return attente;
  }

  /// Signale qu'une ouverture a été traitée par le flux — pour que le montage
  /// suivant du routeur ne la rejoue pas.
  void marquerOuvertureTraitee(String id) {
    if (_ouvertureEnAttente?.id == id) _ouvertureEnAttente = null;
  }

  void _handleOpenedFromMessage(RemoteMessage message) {
    _ouvertureEnAttente = PushNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      data: Map<String, dynamic>.from(message.data),
      type: PushNotification._getNotificationType(message.data),
      timestamp: message.sentTime ?? DateTime.now(),
    );

    _notificationController.add(
      PushNotification(
        // `data` porte de quoi ouvrir le bon écran, pas l'objet métier — il
        // aura changé d'ici la lecture (contrat des notifications).
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
        data: Map<String, dynamic>.from(message.data),
        type: PushNotification._getNotificationType(message.data),
        timestamp: message.sentTime ?? DateTime.now(),
      ),
    );
  }

  /// Canal Android d'après `NotificationKind` du serveur.
  String _channelForKind(String? kind) {
    switch (kind) {
      case 'delivery_offer':
        return 'delivery';
      case 'marketing':
        return 'promotions';
      default:
        return 'orders';
    }
  }

  /// Initialise les notifications locales
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Créer les canaux de notification Android
    await _createNotificationChannels();
  }

  /// Crée les canaux de notification Android
  Future<void> _createNotificationChannels() async {
    const List<AndroidNotificationChannel> channels = [
      AndroidNotificationChannel(
        'orders',
        'Commandes',
        description: 'Notifications pour les commandes',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        'delivery',
        'Livraisons',
        description: 'Notifications pour les livraisons',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        'promotions',
        'Promotions',
        description: 'Notifications pour les promotions',
        importance: Importance.high,
        enableVibration: false,
      ),
      AndroidNotificationChannel(
        'achievements',
        'Achievements',
        description: 'Notifications pour les achievements',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'social',
        'Social',
        description: 'Notifications sociales',
        playSound: false,
        enableVibration: false,
      ),
    ];

    for (final channel in channels) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Gère les clics sur les notifications locales
  void _onNotificationTapped(NotificationResponse response) {
    Journal.trace('PushNotificationService: Notification locale cliquée');
    Journal.trace('Payload: ${response.payload}');

    if (response.payload != null) {
      try {
        // La charge utile est le `data` **du message FCM** — c'est ce que
        // `_handleForegroundMessage` y encode. `PushNotification.fromMap`
        // attendait, elle, un objet complet avec ses clés `id`/`title`/`data`,
        // et lisait donc `map['data']` sur une carte qui n'en a pas : la
        // notification remontait avec un `data` **vide**, c'est-à-dire sans
        // l'identifiant de commande — le seul élément qui permet d'ouvrir le
        // bon écran. Un message touché au premier plan ne menait nulle part.
        final data = Map<String, dynamic>.from(
          json.decode(response.payload!) as Map,
        );
        _notificationController.add(
          PushNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: '',
            body: '',
            data: data,
            type: PushNotification._getNotificationType(data),
            timestamp: DateTime.now(),
          ),
        );
      } catch (e) {
        Journal.trace('PushNotificationService: Erreur parsing payload - $e');
      }
    }
  }

  /// Affiche une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'orders',
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'orders',
      'Commandes',
      channelDescription: 'Notifications pour les commandes',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  /// Envoie une notification de statut de commande
  Future<void> sendOrderStatusNotification({
    required String userId,
    required Order order,
    required String status,
  }) async {
    const title = 'Statut de votre commande';
    String body;
    String emoji;

    switch (status.toLowerCase()) {
      case 'confirmed':
        body =
            'Votre commande #${order.id.substring(0, 8)} a été confirmée! 🎉';
        emoji = '🎉';
        break;
      case 'preparing':
        body =
            'Votre commande #${order.id.substring(0, 8)} est en cours de préparation 👨‍🍳';
        emoji = '👨‍🍳';
        break;
      case 'ready':
        body = 'Votre commande #${order.id.substring(0, 8)} est prête! 🍔';
        emoji = '🍔';
        break;
      case 'on_the_way':
        body = 'Votre commande #${order.id.substring(0, 8)} est en route! 🚗';
        emoji = '🚗';
        break;
      case 'delivered':
        body =
            'Votre commande #${order.id.substring(0, 8)} a été livrée! Bon appétit! 😋';
        emoji = '😋';
        break;
      default:
        body = 'Mise à jour de votre commande #${order.id.substring(0, 8)}';
        emoji = '📦';
    }

    await _showLocalNotification(
      title: '$emoji $title',
      body: body,
      payload: json.encode({
        'type': 'order_status',
        'orderId': order.id,
        'status': status,
        'userId': userId,
      }),
    );

  }

  /// Envoie une notification de promotion
  Future<void> sendPromotionNotification({
    required String userId,
    required String title,
    required String description,
    String? promoCode,
    String? imageUrl,
  }) async {
    final notificationTitle = '🎁 $title';
    final notificationBody = promoCode != null
        ? '$description\n\nCode promo: $promoCode'
        : description;

    await _showLocalNotification(
      title: notificationTitle,
      body: notificationBody,
      payload: json.encode({
        'type': 'promotion',
        'promoCode': promoCode,
        'userId': userId,
      }),
      channelId: 'promotions',
    );

  }

  /// Envoie une notification d'achievement
  Future<void> sendAchievementNotification({
    required String userId,
    required String achievementName,
    required String description,
    required int points,
    String? badgeImageUrl,
  }) async {
    const title = '🏆 Achievement débloqué!';
    final body = '$achievementName: $description (+$points points)';

    await _showLocalNotification(
      title: title,
      body: body,
      payload: json.encode({
        'type': 'achievement',
        'achievementName': achievementName,
        'points': points,
        'userId': userId,
      }),
      channelId: 'achievements',
    );

  }

  /// Envoie une notification de livraison
  Future<void> sendDeliveryNotification({
    required String userId,
    required String orderId,
    required String deliveryPersonName,
    required String estimatedTime,
    String? deliveryPersonPhone,
  }) async {
    const title = '🚗 Votre livreur arrive!';
    final body =
        '$deliveryPersonName livrera votre commande dans $estimatedTime';

    await _showLocalNotification(
      title: title,
      body: body,
      payload: json.encode({
        'type': 'delivery',
        'orderId': orderId,
        'deliveryPersonName': deliveryPersonName,
        'estimatedTime': estimatedTime,
        'userId': userId,
      }),
      channelId: 'delivery',
    );

  }

  /// Envoie une notification sociale
  Future<void> sendSocialNotification({
    required String userId,
    required String title,
    required String message,
    String? fromUserId,
    String? fromUserName,
  }) async {
    await _showLocalNotification(
      title: title,
      body: message,
      payload: json.encode({
        'type': 'social',
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'userId': userId,
      }),
      channelId: 'social',
    );

  }

  /// Planifie une notification
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String channelId = 'orders',
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'orders',
      'Commandes',
      channelDescription: 'Notifications pour les commandes',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.getLocation('Europe/Paris')),
      platformDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // `_saveNotificationToDatabase` supprimé : il traçait chaque notification
  // locale dans Supabase (`trackEvent`). L'historique lisible après coup vit
  // désormais dans `/api/v1/notifications/`, alimenté par le serveur —
  // dupliquer côté client ce qu'il produit ferait deux listes divergentes.

  /// Envoie une notification personnalisée (méthode publique)
  Future<void> sendCustomNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'general',
  }) async {
    await _showLocalNotification(
      title: title,
      body: body,
      payload: payload,
      channelId: channelId,
    );
  }

  /// Envoie une notification de test
  Future<void> sendTestNotification() async {
    await _showLocalNotification(
      title: '🧪 Test de notification',
      body: 'Ceci est une notification de test d\'El Corazón!',
      payload: json.encode({
        'type': 'test',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  /// Annule une notification
  Future<void> cancelNotification(int notificationId) async {
    await _localNotifications.cancel(notificationId);
  }

  /// Annule toutes les notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Obtient les notifications en attente
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _localNotifications.pendingNotificationRequests();
  }

  @override
  void dispose() {
    _notificationController.close();
    _tokenRefreshController.close();
    super.dispose();
  }
}

/// Modèle de données pour les notifications push
class PushNotification {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;

  PushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory PushNotification.fromMap(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final dynamicData = map['data'];

    return PushNotification(
      id: map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? '',
      body: map['message']?.toString() ?? map['body']?.toString() ?? '',
      data: dynamicData is Map<String, dynamic>
          ? dynamicData
          : (dynamicData is Map ? Map<String, dynamic>.from(dynamicData) : {}),
      type: _getNotificationType(map),
      timestamp: DateTime.tryParse(
            map['created_at']?.toString() ?? map['timestamp']?.toString() ?? '',
          ) ??
          DateTime.now(),
      isRead: (map['is_read'] ?? map['isRead'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'data': data,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  /// Le genre porté par la charge utile.
  ///
  /// `kind` d'abord : c'est la clé que le serveur écrit, et **la seule**, dans
  /// toutes ses notifications (`payload_for`, `apps/notifications/push.py`).
  /// Cette fonction ne lisait que `type`, qui n'existe nulle part côté serveur
  /// — tout message push retombait donc sur `general`, y compris un
  /// changement de statut de commande. `type` reste lu en second pour les
  /// charges utiles fabriquées localement.
  ///
  /// Les valeurs reconnues sont celles de `NotificationKind`
  /// (`order_status`, `delivery_offer`, `payment`, `account`, `marketing`),
  /// en plus des anciennes, gardées : une notification déjà partie ne se
  /// renomme pas.
  static NotificationType _getNotificationType(Map<String, dynamic> data) {
    final type =
        (data['kind'] ?? data['type'])?.toString().toLowerCase();

    switch (type) {
      case 'order_status':
      case 'order':
      case 'order_update':
        return NotificationType.orderStatus;
      case 'marketing':
      case 'promotion':
        return NotificationType.promotion;
      case 'delivery_offer':
      case 'delivery':
        return NotificationType.delivery;
      case 'achievement':
        return NotificationType.achievement;
      case 'challenge':
        return NotificationType.challenge;
      case 'reward':
        return NotificationType.reward;
      case 'reminder':
        return NotificationType.reminder;
      case 'system':
        return NotificationType.system;
      case 'social':
        return NotificationType.social;
      default:
        return NotificationType.general;
    }
  }
}

/// Types de notifications
enum NotificationType {
  orderStatus,
  promotion,
  delivery,
  achievement,
  challenge,
  reward,
  reminder,
  system,
  social,
  general,
}
