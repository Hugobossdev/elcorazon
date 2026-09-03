import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_dely/presentation/messages_erreur.dart';
import 'package:elcora_dely/screens/delivery/real_time_tracking_screen.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/services/notification_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

/// Ouvre la course que désigne une notification touchée.
///
/// ## Ce qui manquait
///
/// `NotificationService` recevait bien les trois cas — premier plan,
/// arrière-plan, démarrage à froid — et poussait la charge utile sur
/// `openedNotifications`. Mais le seul auditeur était `AppService`, qui se
/// contentait de **recharger les courses** :
///
/// ```dart
/// _notificationService.openedNotifications.listen((_) {
///   unawaited(loadAvailableOrders(forceRefresh: true));
/// });
/// ```
///
/// Toucher « Nouvelle course » posait donc le livreur sur l'écran où il se
/// trouvait, avec une liste fraîchement rechargée qu'il devait parcourir pour
/// retrouver ce qu'on venait de lui annoncer. Sur un scooter, à l'arrêt, c'est
/// la différence entre accepter une course et la laisser filer.
///
/// Le rechargement reste — il est nécessaire et il a lieu **avant** la
/// navigation, puisque la charge utile ne porte que des identifiants (ADR-008)
/// et que l'écran a besoin de la course elle-même.
///
/// ## Ce qu'il ne fait pas
///
/// Il ne fait confiance à rien de ce que porte la notification. L'identifiant
/// de commande sert à **chercher** la course dans ce que le serveur vient de
/// rendre ; si elle n'y est pas — course déjà prise par un collègue,
/// notification périmée, charge utile fabriquée — il ne se passe rien de plus
/// qu'un rechargement. Une notification n'ouvre jamais un écran sur des données
/// qu'elle transporte.
class NotificationRouter extends StatefulWidget {
  const NotificationRouter({required this.child, super.key});

  final Widget child;

  @override
  State<NotificationRouter> createState() => _NotificationRouterState();
}

class _NotificationRouterState extends State<NotificationRouter> {
  StreamSubscription<Map<String, dynamic>>? _abonnement;

  /// Vrai pendant qu'une ouverture est en cours de traitement.
  ///
  /// Le rechargement est asynchrone : sans ce verrou, deux notifications
  /// touchées coup sur coup empileraient deux écrans de suivi.
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    final service = NotificationService();
    _abonnement = service.openedNotifications.listen(_ouvrir);

    // Réclamer l'ouverture retenue pendant `initialize()`, quand ce widget
    // n'existait pas encore — le démarrage à froid par notification.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final attente = service.consommerOuvertureEnAttente();
      if (attente != null) unawaited(_ouvrir(attente));
    });
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    super.dispose();
  }

  Future<void> _ouvrir(Map<String, dynamic> charge) async {
    if (!mounted || _enCours) return;

    final brut = charge['order'];
    final orderId = brut is String && brut.isNotEmpty ? brut : null;
    if (orderId == null) return;

    NotificationService().oublierOuvertureEnAttente();
    _enCours = true;

    final app = context.read<AppService>();
    try {
      // La notification annonce, elle ne fait pas foi : c'est l'API qui porte
      // l'étape, les transitions permises et les montants. On relit **avant**
      // d'ouvrir quoi que ce soit.
      await app.loadAvailableOrders(forceRefresh: true);
    } catch (e) {
      Journal.trace('Notification : rechargement impossible — $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageErreur(e))),
        );
      }
      _enCours = false;
      return;
    }

    if (!mounted) {
      _enCours = false;
      return;
    }

    final course = app.courseForOrder(orderId);
    if (course == null) {
      // Course prise par un collègue entre l'envoi et le geste, ou sortie de
      // l'historique. La liste vient d'être rechargée : le livreur voit l'état
      // réel, ce qui est la bonne réponse — mieux qu'un écran vide.
      Journal.trace('Notification : course $orderId introuvable après relecture');
      _enCours = false;
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RealTimeTrackingScreen(order: course),
      ),
    );
    _enCours = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
