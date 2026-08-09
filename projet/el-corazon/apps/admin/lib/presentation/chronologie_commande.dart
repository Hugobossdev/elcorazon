import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/statut_commande.dart';

/// Une étape de la vie d'une commande, telle que l'écran la montre.
class EtapeCommande {
  const EtapeCommande({
    required this.statut,
    required this.franchie,
    required this.quand,
  });

  final StatutCommande statut;

  String get libelle => statut.libelle;

  /// La commande a-t-elle atteint cette étape ?
  final bool franchie;

  /// Quand elle l'a atteinte, d'après le journal du serveur.
  ///
  /// `null` quand on ne sait pas : étape pas encore franchie, ou franchie
  /// avant que le journal ne soit consultable (la forme liste ne le rend pas).
  /// Un écran qui reçoit `null` n'affiche pas d'heure — il n'en invente pas.
  final DateTime? quand;
}

/// L'historique d'une commande, d'après ce que le serveur a enregistré.
///
/// Ce que ce fichier ne fait plus
/// ------------------------------
///
/// Il affichait des heures **fabriquées** : l'heure de commande augmentée de
/// 5, 10, 25, 30 puis 45 minutes. Rien de mesuré n'y entrait — une commande
/// encore en attente affichait la même heure de « livrée » qu'une commande
/// livrée.
///
/// La vraie source existait depuis toujours côté serveur : `OrderStatusEvent`,
/// écrit par la machine à états dans la même transaction que le changement de
/// statut. Le socle ne le lisait pas ; il le lit désormais, et les heures
/// affichées sont celles des transitions.
///
/// Elles ne sont peuplées que sur la **forme détail** (`GET /orders/{id}/`).
/// Sur la forme liste, [EtapeCommande.quand] vaut `null` partout : l'étape
/// s'affiche sans heure plutôt qu'avec une heure inventée.
///
/// Deuxième correction : une commande **annulée** ne coche plus les étapes du
/// service. Le rang se lisait sur `status.index`, et `cancelled` était déclaré
/// après `delivered` — une commande annulée paraissait donc avoir été mise en
/// livraison. [StatutCommande.rang] rend `null` pour une annulation, qui n'est
/// pas une étape de plus mais une sortie.
List<EtapeCommande> chronologieDe(eccore.Order commande) {
  final atteint = commande.statut.rang;

  return [
    for (final etape in _etapesDuService)
      EtapeCommande(
        statut: etape,
        franchie: atteint != null && atteint >= etape.rang!,
        quand: _quandFranchie(commande, etape),
      ),
  ];
}

/// Les six étapes que le service traverse, dans l'ordre.
///
/// L'annulation n'en fait pas partie : elle interrompt la suite, elle ne la
/// prolonge pas.
const _etapesDuService = <StatutCommande>[
  StatutCommande.enAttente,
  StatutCommande.confirmee,
  StatutCommande.enPreparation,
  StatutCommande.prete,
  StatutCommande.recuperee,
  StatutCommande.enRoute,
  StatutCommande.livree,
];

/// Le moment où la commande est passée à [etape], si le journal le dit.
DateTime? _quandFranchie(eccore.Order commande, StatutCommande etape) {
  for (final transition in commande.statusEvents) {
    if (transition.toStatus == etape.versServeur) return transition.createdAt;
  }

  // La toute première étape n'a pas toujours de transition écrite : une
  // commande naît « en attente », sans venir d'ailleurs.
  if (etape == StatutCommande.enAttente) return commande.passeeLe;

  return null;
}

/// L'annulation d'une commande, quand elle a eu lieu.
///
/// Rendue à part des étapes : elle ne se range pas dans la file, elle
/// l'arrête. Le serveur en donne l'heure et le motif.
({DateTime? quand, String motif})? annulationDe(eccore.Order commande) {
  if (commande.statut != StatutCommande.annulee) return null;

  return (
    quand: commande.cancelledAt ?? _quandFranchie(commande, StatutCommande.annulee),
    motif: commande.cancellationReason,
  );
}
