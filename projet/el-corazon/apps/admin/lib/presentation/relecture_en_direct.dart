import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/dashboard_realtime_service.dart';

/// Un écran qui **suit le service** sans que l'opérateur ait à recharger.
///
/// Le temps réel n'était branché que dans l'écran Commandes, démonté dès
/// qu'on le quitte : « Livraisons actives » et le tableau de bord, laissés
/// ouverts, montraient une liste figée. Et sur un poste de bureau, le « tirer
/// pour rafraîchir » ne répond pas à la souris — il ne restait qu'à changer
/// d'écran et revenir.
///
/// Même principe que le poste de cuisine : chaque événement du canal
/// (commande reçue, statut changé, reconnexion) programme **une** relecture,
/// regroupée sur [rebondDirect] pour qu'un coup de feu à dix commandes ne
/// déclenche pas dix lectures ; un filet périodique rattrape un canal muet
/// (aucun établissement supervisé, socket coupé).
mixin RelectureEnDirect<T extends StatefulWidget> on State<T> {
  final List<StreamSubscription<Object?>> _abonnementsDirect = [];
  Timer? _rebondDirect;
  Timer? _filetDirect;

  /// Délai de regroupement des événements.
  Duration get rebondDirect => const Duration(seconds: 2);

  /// Relecture de secours, même sans événement.
  Duration get cadenceDeSecours => const Duration(minutes: 1);

  /// Ce que l'écran relit quand le service bouge.
  Future<void> relireEnDirect();

  /// À appeler une fois, dans `initState` ou juste après le premier rendu.
  void brancherLeDirect() {
    final temps = context.read<DashboardRealtimeService>();
    _abonnementsDirect
      ..add(temps.arrivees.listen((_) => _programmer()))
      ..add(temps.changements.listen((_) => _programmer()))
      ..add(temps.reconnexions.listen((_) => _programmer()));
    _filetDirect = Timer.periodic(cadenceDeSecours, (_) {
      if (mounted) unawaited(relireEnDirect());
    });
    unawaited(connecterLeDirect(temps));
  }

  /// Ouvre le canal de l'établissement supervisé — sans effet s'il l'est déjà.
  Future<void> connecterLeDirect(DashboardRealtimeService temps) => temps.connect();

  void _programmer() {
    _rebondDirect?.cancel();
    _rebondDirect = Timer(rebondDirect, () {
      if (mounted) unawaited(relireEnDirect());
    });
  }

  @override
  void dispose() {
    for (final abonnement in _abonnementsDirect) {
      unawaited(abonnement.cancel());
    }
    _rebondDirect?.cancel();
    _filetDirect?.cancel();
    super.dispose();
  }
}

/// Le bouton « Actualiser » des écrans de liste.
///
/// Le « tirer pour rafraîchir » ne répond qu'au doigt : à la souris, c'est le
/// seul moyen de relire sans quitter l'écran. Neutralisé pendant la lecture,
/// pour qu'un double clic ne lance pas deux lectures.
class BoutonActualiser extends StatelessWidget {
  const BoutonActualiser({
    required this.onPressed,
    this.enCours = false,
    this.couleur,
    super.key,
  });

  final VoidCallback onPressed;
  final bool enCours;

  /// Sur un fond coloré (bandeau d'accueil), la couleur du texte de ce fond.
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('actualiser'),
      tooltip: 'Actualiser',
      icon: const Icon(Icons.refresh),
      color: couleur,
      onPressed: enCours ? null : onPressed,
    );
  }
}
