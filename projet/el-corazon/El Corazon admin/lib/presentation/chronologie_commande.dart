import 'package:admin/models/order.dart';

/// Une étape de la vie d'une commande, telle que l'écran la montre.
class EtapeCommande {
  const EtapeCommande({
    required this.libelle,
    required this.quand,
    required this.franchie,
  });

  final String libelle;

  /// **Cette heure est fabriquée.** Voir [chronologieDe].
  final DateTime quand;

  final bool franchie;
}

/// L'historique affiché d'une commande.
///
/// ⚠ Les heures sont **inventées**
/// -------------------------------
///
/// Chaque étape affiche `orderTime` augmenté d'un délai fixe : 5 minutes pour
/// « confirmée », 10 pour « en préparation », 25 pour « prête », 30 pour « en
/// livraison », 45 pour « livrée ». Aucun de ces instants ne correspond à
/// quoi que ce soit qui se soit produit. Un opérateur lit « Prête, 12:25 » sur
/// une commande dont personne ne sait quand elle a été prête.
///
/// Ce n'est pas corrigé ici, et ce n'est pas un oubli : le serveur ne renvoie
/// pas d'horodatage par étape. `Order` porte `placedAt`, `updatedAt` et
/// `estimatedDeliveryAt`, rien de plus. Trois sorties sont possibles — n'afficher
/// que l'étape sans heure, retirer l'historique, ou obtenir les horodatages du
/// serveur (ce dernier point touche au back-end). Le choix appartient au
/// produit ; ce fichier se contente de rendre le problème visible et testable.
///
/// La comparaison `status.index >= n` est reprise telle quelle : elle suppose
/// que l'ordre de déclaration de [OrderStatus] est l'ordre du cycle de vie.
List<EtapeCommande> chronologieDe(Order commande) {
  final depart = commande.orderTime;
  final statut = commande.status;

  return [
    EtapeCommande(
      libelle: 'Commande passée',
      quand: depart,
      franchie: true,
    ),
    EtapeCommande(
      libelle: 'Commande confirmée',
      quand: depart.add(const Duration(minutes: 5)),
      franchie: statut.index >= 1,
    ),
    EtapeCommande(
      libelle: 'En préparation',
      quand: depart.add(const Duration(minutes: 10)),
      franchie: statut.index >= 2,
    ),
    EtapeCommande(
      libelle: 'Prête',
      quand: depart.add(const Duration(minutes: 25)),
      franchie: statut.index >= 3,
    ),
    EtapeCommande(
      libelle: 'En livraison',
      quand: depart.add(const Duration(minutes: 30)),
      franchie: statut.index >= 4,
    ),
    EtapeCommande(
      libelle: 'Livrée',
      quand: depart.add(const Duration(minutes: 45)),
      franchie: statut == OrderStatus.delivered,
    ),
  ];
}
