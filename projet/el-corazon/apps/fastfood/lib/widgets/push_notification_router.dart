import 'dart:async';

import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _abonnement =
        PushNotificationService().notificationStream.listen(_ouvrir);
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    super.dispose();
  }

  void _ouvrir(PushNotification notification) {
    if (!mounted) return;

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
  Widget build(BuildContext context) => widget.child;
}
