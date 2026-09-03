import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_dely/screens/communication/call_screen.dart';
import 'package:elcora_dely/services/call_service.dart';

/// Fait sonner le livreur, où qu'il soit dans l'application.
///
/// ## Pourquoi c'est un widget qui enveloppe, et pas un écran
///
/// Un appel entrant n'a aucune raison d'arriver pendant que le livreur regarde
/// la commande concernée : il conduit, il consulte ses gains, il est sur ses
/// réglages. Ce widget enveloppe l'application entière et n'affiche rien tant
/// que rien ne sonne — c'est le seul montage qui garantisse que la sonnerie ne
/// dépende pas de l'écran ouvert.
///
/// ## Ce qu'il n'ouvre pas
///
/// **Pas la file `ws/me/`.** Elle est ouverte par `AppService` à l'ouverture de
/// session, au même endroit que la file des courses et l'émission de position,
/// et pour la même raison : ces trois-là suivent la session, pas un écran. Un
/// widget qui l'ouvrirait la refermerait en se démontant — c'est-à-dire au
/// premier changement d'écran de la journée.
///
/// Ce widget ne fait donc qu'**écouter** et présenter le choix.
class IncomingCallHandler extends StatefulWidget {
  const IncomingCallHandler({required this.child, super.key});

  final Widget child;

  @override
  State<IncomingCallHandler> createState() => _IncomingCallHandlerState();
}

class _IncomingCallHandlerState extends State<IncomingCallHandler> {
  StreamSubscription<eccore.Call>? _abonnement;

  /// L'appel affiché en ce moment, s'il y en a un.
  ///
  /// Retenu pour deux raisons : ne pas empiler deux boîtes de dialogue, et
  /// savoir si l'annulation qui arrive concerne bien celle qui est ouverte —
  /// un client qui renonce doit faire disparaître **sa** sonnerie, pas la
  /// suivante.
  eccore.Call? _quiSonne;

  @override
  void initState() {
    super.initState();
    // Après la première frame : `context.read` avant celle-ci lirait un arbre
    // de providers pas encore monté.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appels = context.read<CallService>();
      _abonnement = appels.appelsEntrants.listen(_sonner);
    });
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    super.dispose();
  }

  Future<void> _sonner(eccore.Call appel) async {
    if (!mounted || _quiSonne != null) return;
    setState(() => _quiSonne = appel);

    // Le contexte du `Navigator` racine, et non celui de l'écran courant : la
    // boîte doit survivre à une navigation déclenchée par ailleurs — une
    // notification ouverte, un retour automatique — pendant qu'elle sonne.
    final navigateur = Navigator.of(context, rootNavigator: true);

    final abonnementFin = context.read<CallService>().changementsDEtat.listen((maj) {
      // L'appelant a renoncé pendant que ça sonnait : refermer la boîte plutôt
      // que de laisser le livreur décrocher dans le vide.
      if (maj.id == appel.id && !maj.isActive && _quiSonne != null) {
        _quiSonne = null;
        navigateur.pop();
      }
    });

    final decroche = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BoiteDAppel(appel: appel),
    );

    await abonnementFin.cancel();
    if (!mounted) return;
    final etaitEnCours = _quiSonne != null;
    setState(() => _quiSonne = null);

    // La boîte s'est refermée d'elle-même (l'appelant a renoncé) : il n'y a ni
    // à décrocher ni à refuser, l'appel est déjà clos côté serveur.
    if (!etaitEnCours) return;

    final appels = context.read<CallService>();
    if (decroche != true) {
      await appels.refuser(appel);
      return;
    }

    // Le jeton RTC est demandé ici, par `decrocher` : le destinataire n'en a
    // pas tant qu'il n'a pas accepté.
    if (!await appels.decrocher(appel)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de prendre l\'appel.')),
      );
      return;
    }

    if (!mounted) return;
    unawaited(
      navigateur.push(
        MaterialPageRoute<void>(
          builder: (_) => CallScreen(
            orderId: appel.orderId,
            appelEntrant: appel,
            video: appel.kind == 'video',
            nomInterlocuteur: appel.callerName,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BoiteDAppel extends StatelessWidget {
  const _BoiteDAppel({required this.appel});

  final eccore.Call appel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final video = appel.kind == 'video';

    // `PopScope(canPop: false)` : le bouton retour du système ne doit pas
    // écarter la boîte sans rien décider. Un appel écarté silencieusement
    // continue de sonner chez le client, qui attend une réponse qui ne
    // viendra pas.
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(video ? Icons.videocam : Icons.phone_in_talk_rounded,
                color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(video ? 'Appel vidéo entrant' : 'Appel entrant'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appel.callerName.isEmpty ? 'Client' : appel.callerName,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'À propos d\'une de vos courses',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.call_end),
            label: const Text('Refuser'),
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.call),
            label: const Text('Répondre'),
          ),
        ],
      ),
    );
  }
}
