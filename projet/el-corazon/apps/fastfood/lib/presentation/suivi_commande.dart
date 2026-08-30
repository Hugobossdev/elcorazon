import 'package:elcora_fast/models/order.dart';

/// La chronologie d'une commande, telle que le détail et le suivi l'affichent.
///
/// ## Pourquoi ce fichier existe
///
/// La maquette `order_details` met une chronologie à quatre jalons au premier
/// plan — « Order Confirmed 12:30 PM », « Preparing », « On the way »,
/// « Delivered ». Décider quel jalon est franchi, lequel est courant et à
/// quelle heure, c'est une **règle**, pas une mise en forme : elle mérite
/// d'être nommée et éprouvée ailleurs que dans une méthode privée d'écran.
///
/// Les dix statuts du serveur se replient sur quatre jalons ; c'est ce
/// repliement qui est délicat, et c'est lui que les tests tiennent.
class EtapeDeSuivi {
  const EtapeDeSuivi({
    required this.jalon,
    required this.franchie,
    required this.courante,
    this.horodatage,
    this.annulation = false,
  });

  final JalonDeSuivi jalon;

  /// L'étape a eu lieu.
  final bool franchie;

  /// C'est l'étape où en est la commande.
  final bool courante;

  /// Quand le serveur l'a enregistrée, si un événement lui correspond.
  ///
  /// `null` sur une étape franchie signifie « on sait que c'est arrivé, pas
  /// quand » — et non « ce n'est pas arrivé ». Une heure inventée serait pire
  /// qu'une heure absente sur un écran de suivi.
  final DateTime? horodatage;

  /// L'étape marque une sortie du cycle : annulation, échec, remboursement.
  final bool annulation;
}

/// Les quatre jalons du cycle de vie, dans l'ordre.
enum JalonDeSuivi {
  confirmee('Commande confirmée', 'Nous avons bien reçu votre commande.'),
  enPreparation('En préparation', 'La cuisine s’occupe de votre commande.'),
  enRoute('En route', 'Votre livreur est en chemin.'),
  livree('Livrée', 'Bon appétit !');

  const JalonDeSuivi(this.libelle, this.description);

  final String libelle;
  final String description;
}

/// Le rang d'un statut dans la chronologie à quatre jalons.
///
/// `-1` pour ce qui sort du cycle — une annulation n'est pas une étape de
/// plus, c'est une sortie.
int rangDuStatut(OrderStatus statut) {
  switch (statut) {
    case OrderStatus.pending:
    case OrderStatus.confirmed:
      return 0;
    case OrderStatus.preparing:
    case OrderStatus.ready:
      return 1;
    case OrderStatus.pickedUp:
    case OrderStatus.onTheWay:
      return 2;
    case OrderStatus.delivered:
      return 3;
    case OrderStatus.cancelled:
    case OrderStatus.refunded:
    case OrderStatus.failed:
      return -1;
  }
}

/// Vrai quand la commande est sortie du cycle sans être livrée.
bool estSortieDuCycle(OrderStatus statut) =>
    statut == OrderStatus.cancelled ||
    statut == OrderStatus.refunded ||
    statut == OrderStatus.failed;

/// La chronologie de [commande].
///
/// ## Ce que fait le cas d'une commande annulée
///
/// Elle ne montre pas quatre jalons dont trois grisés : cela laisserait croire
/// à une livraison encore possible. Elle montre les étapes **réellement
/// franchies**, puis un jalon de sortie — « Annulée », « Échouée » ou
/// « Remboursée » — qui referme la liste.
///
/// ## D'où viennent les heures
///
/// De `Order.statusUpdates`, que le serveur remplit (`status_events` sur
/// `OrderSerializer`). Le premier jalon retombe sur l'heure de dépôt de la
/// commande : elle est toujours connue, et c'est la même chose.
List<EtapeDeSuivi> etapesDeSuivi(Order commande) {
  final rang = rangDuStatut(commande.status);
  final sortie = estSortieDuCycle(commande.status);

  DateTime? horodatageDe(List<OrderStatus> statuts) {
    for (final maj in commande.statusUpdates) {
      if (statuts.contains(maj.status)) return maj.timestamp;
    }
    return null;
  }

  final jalons = <EtapeDeSuivi>[
    EtapeDeSuivi(
      jalon: JalonDeSuivi.confirmee,
      franchie: rang >= 0,
      courante: rang == 0,
      horodatage:
          horodatageDe([OrderStatus.pending, OrderStatus.confirmed]) ??
              commande.orderTime,
    ),
    EtapeDeSuivi(
      jalon: JalonDeSuivi.enPreparation,
      franchie: rang >= 1,
      courante: rang == 1,
      horodatage: horodatageDe([OrderStatus.preparing, OrderStatus.ready]),
    ),
    EtapeDeSuivi(
      jalon: JalonDeSuivi.enRoute,
      franchie: rang >= 2,
      courante: rang == 2,
      horodatage: horodatageDe([OrderStatus.pickedUp, OrderStatus.onTheWay]),
    ),
    EtapeDeSuivi(
      jalon: JalonDeSuivi.livree,
      franchie: rang >= 3,
      courante: rang == 3,
      horodatage: horodatageDe([OrderStatus.delivered]),
    ),
  ];

  if (!sortie) return jalons;

  return [
    ...jalons.where((etape) => etape.franchie),
    EtapeDeSuivi(
      jalon: JalonDeSuivi.livree, // porteur seulement ; le libellé vient d'en bas
      franchie: true,
      courante: true,
      annulation: true,
      horodatage: horodatageDe([
        OrderStatus.cancelled,
        OrderStatus.failed,
        OrderStatus.refunded,
      ]),
    ),
  ];
}

/// Le mot qui referme une commande sortie du cycle.
String libelleDeSortie(OrderStatus statut) {
  switch (statut) {
    case OrderStatus.refunded:
      return 'Remboursée';
    case OrderStatus.failed:
      return 'Échouée';
    default:
      return 'Annulée';
  }
}
