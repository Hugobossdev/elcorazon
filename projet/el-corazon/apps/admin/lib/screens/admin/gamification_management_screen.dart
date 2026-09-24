import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/screens/admin/gamification/achievements.dart';
import 'package:admin/screens/admin/gamification/badges.dart';
import 'package:admin/screens/admin/gamification/challenges.dart';
import 'package:admin/screens/admin/gamification/rewards.dart';
import 'package:admin/services/gamification_service.dart';

/// Fidélisation — succès, défis, badges et récompenses.
///
/// Les onglets n'apparaissent que si le compte peut **lire** leur catalogue :
/// les récompenses relèvent de `loyalty.read`, les trois autres de
/// `gamification.read`, et un rôle peut avoir l'un sans l'autre. Les gestes
/// d'écriture, eux, suivent `*.write` dans chaque onglet.
///
/// Le service n'est plus chargé au démarrage de l'application (il l'était
/// pour tout le monde, et avalait les 403 des comptes sans permission) : il se
/// charge à l'ouverture de l'écran.
class GamificationManagementScreen extends StatefulWidget {
  const GamificationManagementScreen({super.key});

  @override
  State<GamificationManagementScreen> createState() => _GamificationManagementScreenState();
}

class _GamificationManagementScreenState extends State<GamificationManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<GamificationService>().initialize());
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<GamificationService>();
    final onglets = <(Tab, Widget)>[
      if (service.peutLire(CatalogueDeFidelisation.succes))
        (const Tab(text: 'Succès', icon: Icon(Icons.emoji_events)), const AchievementsTab()),
      if (service.peutLire(CatalogueDeFidelisation.defis))
        (const Tab(text: 'Défis', icon: Icon(Icons.flag)), const ChallengesTab()),
      if (service.peutLire(CatalogueDeFidelisation.badges))
        (const Tab(text: 'Badges', icon: Icon(Icons.workspace_premium)), const BadgesTab()),
      if (service.peutLire(CatalogueDeFidelisation.recompenses))
        (const Tab(text: 'Récompenses', icon: Icon(Icons.card_giftcard)), const RewardsTab()),
    ];

    if (onglets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Votre rôle ne donne accès à aucun catalogue de fidélisation.'),
        ),
      );
    }

    return DefaultTabController(
      length: onglets.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fidélisation'),
          bottom: TabBar(isScrollable: true, tabs: [for (final (onglet, _) in onglets) onglet]),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recharger',
              onPressed: service.enCours ? null : () => unawaited(service.refresh()),
            ),
          ],
        ),
        body: service.enCours && service.succes.isEmpty && service.recompenses.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [for (final (_, vue) in onglets) vue]),
      ),
    );
  }
}
