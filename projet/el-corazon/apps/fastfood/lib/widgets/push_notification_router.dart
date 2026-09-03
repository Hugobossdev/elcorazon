import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_fast/services/app_service.dart';

import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/services/push_notification_service.dart';

/// Ouvre l'écran que désigne une notification touchée.
///
/// ## Ce qui manquait
///
/// `PushNotificationService` faisait déjà tout son travail : jeton, canaux,
/// réception au premier plan, et `_notificationController` où atterrissait
/// chaque notification ouverte. Mais **personne n'écoutait ce flux**. Toucher
/// une notification « Votre commande est en route » posait donc l'application
/// sur l'accueil, exactement comme si l'on avait touché son icône — le seul
/// geste que la notification devait éviter.
///
/// Le service ne navigue pas lui-même, et c'est volontaire : il n'a pas de
/// `BuildContext`, et lui en confier un ferait d'un service de plate-forme un
/// dépendant de l'arbre de widgets. Ce guet vit donc dans le `builder` de
/// `MaterialApp`, sous le `Navigator` — au même endroit et pour la même raison
/// que [IncomingCallHandler], qui règle le même problème pour les appels.
///
/// ## La règle de destination
///
/// C'est celle de l'écran des notifications
/// (`NotificationsScreen._navigateBasedOnNotification`), et pas une seconde :
/// une notification de commande doit mener au même endroit qu'on la touche
/// dans la barre système ou dans la liste de l'application.
class PushNotificationRouter extends StatefulWidget {
  const PushNotificationRouter({required this.child, super.key});

  final Widget child;

  @override
  State<PushNotificationRouter> createState() => _PushNotificationRouterState();
}

class _PushNotificationRouterState extends State<PushNotificationRouter> {
  StreamSubscription<PushNotification>? _abonnement;

  /// L'intention gardée quand la notification arrive avant la session.
  ///
  /// Au démarrage à froid, la notification est lue **avant `runApp`** et la
  /// session n'est pas encore restaurée. Naviguer tout de suite enverrait vers
  /// un écran protégé un utilisateur que l'application ne connaît pas encore.
  /// On garde donc l'intention et on la rejoue dès qu'une session s'ouvre —
  /// ce que demande le contrat des notifications : authentifier d'abord,
  /// naviguer ensuite.
  PushNotification? _enAttenteDeSession;

  @override
  void initState() {
    super.initState();
    final service = PushNotificationService();
    _abonnement = service.notificationStream.listen(_ouvrir);

    // Réclamer l'ouverture retenue pendant `prepare()`, quand ce widget
    // n'existait pas encore. Après l'abonnement, pour qu'une notification
    // déjà passée par le flux ne soit pas rejouée.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final attente = service.consommerOuvertureEnAttente();
      if (attente != null) _ouvrir(attente);
    });
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    super.dispose();
  }

  void _ouvrir(PushNotification notification) {
    if (!mounted) return;
    PushNotificationService().marquerOuvertureTraitee(notification.id);

    // Pas de session : on retient plutôt que d'envoyer vers un écran que le
    // serveur refusera de toute façon.
    if (!context.read<AppService>().isLoggedIn) {
      _enAttenteDeSession = notification;
      return;
    }

    // Le contrat des notifications est explicite : la charge utile porte de
    // quoi **ouvrir un écran**, jamais l'objet métier — il aura changé d'ici
    // la lecture. On ne transmet donc qu'un identifiant, et l'écran recharge.
    final commande = notification.data['order'];
    final orderId = commande is String && commande.isNotEmpty ? commande : null;

    switch (notification.type) {
      case NotificationType.orderStatus:
      case NotificationType.delivery:
        // Sans identifiant — cas d'une notification mal formée —, la liste
        // des commandes plutôt que rien : l'utilisateur y retrouve la sienne.
        Navigator.of(context).pushNamed(
          orderId == null ? AppRouter.orders : AppRouter.deliveryTracking,
          arguments: orderId == null ? null : {'orderId': orderId},
        );
      case NotificationType.promotion:
        Navigator.of(context).pushNamed(AppRouter.menu);
      case NotificationType.achievement:
      case NotificationType.challenge:
      case NotificationType.reward:
        Navigator.of(context).pushNamed(AppRouter.rewards);
      case NotificationType.reminder:
      case NotificationType.system:
      case NotificationType.social:
      case NotificationType.general:
        // Rien à ouvrir : ces notifications se lisent. Les envoyer vers un
        // écran arbitraire serait plus déroutant que de rester où l'on est.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // `watch` et non `read` : c'est ce qui reconstruit ce widget quand la
    // session s'ouvre, et donc ce qui rejoue l'intention gardée. Sans lui,
    // une notification reçue avant la connexion resterait en attente pour
    // toujours.
    final connecte = context.watch<AppService>().isLoggedIn;
    final attente = _enAttenteDeSession;

    if (connecte && attente != null) {
      _enAttenteDeSession = null;
      // Après la frame : naviguer pendant un `build` est interdit.
      WidgetsBinding.instance.addPostFrameCallback((_) => _ouvrir(attente));
    }

    return widget.child;
  }
}
