import 'package:flutter/material.dart';

import 'package:admin/services/dashboard_realtime_service.dart';
import 'package:admin/ui/ui.dart';

/// Les commandes d'une liste paginée : page précédente, rang, page suivante.
///
/// Pourquoi ce widget existe
/// -------------------------
///
/// La supervision chargeait **toutes** les commandes de la fenêtre — le dépôt
/// suivait `next` jusqu'au bout — puis affichait la liste entière dans un
/// `ListView`. Cela tenait à cent commandes et s'écroulait à dix mille : cinq
/// cents requêtes avant la première ligne, et autant d'objets en mémoire pour
/// en montrer vingt.
///
/// Le rang est affiché en toutes lettres (« page 2 sur 17 · 331 commandes »)
/// plutôt qu'en simples flèches : sans lui, on ne sait pas si l'on regarde le
/// début du service ou sa fin, ni combien il reste à parcourir.
class BarrePagination extends StatelessWidget {
  const BarrePagination({
    required this.numeroDePage,
    required this.nombreDePages,
    required this.total,
    required this.enCours,
    required this.onPrecedente,
    required this.onSuivante,
    super.key,
  });

  final int numeroDePage;
  final int nombreDePages;
  final int total;
  final bool enCours;

  /// `null` désactive le bouton — première ou dernière page.
  final VoidCallback? onPrecedente;
  final VoidCallback? onSuivante;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              total == 0
                  ? 'Aucune commande'
                  : 'Page $numeroDePage sur $nombreDePages · '
                      '$total commande${total > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          // Le chargement s'affiche **ici** et non par-dessus la liste : la
          // page précédente reste lisible pendant que la suivante arrive, ce
          // qui évite le clignotement d'un écran vidé puis rempli.
          if (enCours)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Page précédente',
            onPressed: enCours ? null : onPrecedente,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Page suivante',
            onPressed: enCours ? null : onSuivante,
          ),
        ],
      ),
    );
  }
}

/// L'état du lien temps réel, en une pastille.
///
/// Discrète par construction : un bandeau permanent annonçant « connecté » sur
/// un écran qui l'est presque toujours devient invisible à force, et ne se
/// remarque plus le jour où il dit le contraire.
///
/// Elle ne montre **jamais** « connecté » sans que le socket le soit :
/// [DashboardRealtimeService] dérive son état de la vie réelle du canal, il ne
/// le pose pas par optimisme.
class PastilleTempsReel extends StatelessWidget {
  const PastilleTempsReel({required this.etat, super.key});

  final EtatTempsReel etat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    final (couleur, libelle, aide) = switch (etat) {
      EtatTempsReel.connecte => (
          sem.success,
          'En direct',
          'Les changements de statut arrivent d’eux-mêmes.',
        ),
      EtatTempsReel.connexion => (
          sem.warning,
          'Reconnexion…',
          'Le lien temps réel est coupé. La liste reste à jour au rechargement.',
        ),
      EtatTempsReel.refuse => (
          scheme.onSurfaceVariant,
          'Sans direct',
          'Ce compte n’a pas accès au canal temps réel de cet établissement. '
              'Tout le reste fonctionne : rechargez pour voir les changements.',
        ),
      EtatTempsReel.ferme => (
          scheme.onSurfaceVariant,
          'Hors ligne',
          'Aucun lien temps réel. Utilisez « Recharger ».',
        ),
    };

    return Tooltip(
      message: aide,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              libelle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: couleur,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le bandeau qui signale des changements hors de la sélection affichée.
///
/// Une commande dont le statut change alors qu'elle n'est **pas** dans la page
/// courante ne peut pas être insérée : elle romprait l'ordre, fausserait le
/// compte et pourrait apparaître deux fois à la page suivante. La signaler et
/// laisser recharger est la seule réponse qui ne mente pas.
class BandeauNouveautes extends StatelessWidget {
  const BandeauNouveautes({
    required this.nombre,
    required this.onRecharger,
    super.key,
  });

  final int nombre;
  final VoidCallback onRecharger;

  @override
  Widget build(BuildContext context) {
    if (nombre == 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: onRecharger,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.sync, size: 18, color: scheme.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nombre == 1
                      ? 'Une commande a changé hors de cette sélection.'
                      : '$nombre commandes ont changé hors de cette sélection.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              Text(
                'Recharger',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
