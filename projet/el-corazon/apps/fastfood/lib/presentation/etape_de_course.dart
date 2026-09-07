/// Une étape de la **course**, telle que le serveur la diffuse au client.
///
/// ## Pourquoi c'est distinct du statut de la commande
///
/// Le serveur publie deux événements sur le canal d'une commande, et ils ne
/// disent pas la même chose :
///
/// * `order.status` — le repas : confirmée, en préparation, prête, en route ;
/// * `delivery.status` — la course : acceptée, récupérée, en route, livrée.
///
/// Les deux se recouvrent en partie, et pas partout. `accepted` **ne projette
/// rien** sur la commande, délibérément : une commande reste « prête » tant que
/// le repas n'est pas parti, et c'est en voulant projeter cette étape-là que
/// l'ancien code écrivait un statut hors énumération.
///
/// Le client n'écoutait donc que `order.status`, et l'affectation d'un livreur
/// ne produisait pour lui **aucun** événement. Elle n'apparaissait qu'à la
/// relecture périodique suivante — jusqu'à une minute plus tard, le canal temps
/// réel étant ouvert. Pendant ce temps, l'écran affichait « Prête » sans dire
/// que quelqu'un venait de prendre la commande et roulait vers le restaurant.
///
/// « votre livreur a récupéré la commande » et « commande récupérée » sont le
/// même instant mais pas la même information : l'une nomme quelqu'un.
class EtapeDeCourse {
  const EtapeDeCourse({
    required this.assignmentId,
    required this.orderId,
    required this.statut,
    required this.livreur,
  });

  /// Depuis la charge utile d'un `delivery.status`.
  ///
  /// Rend `null` sur un message incomplet plutôt que de lever : un événement
  /// mal formé ne doit pas faire tomber l'écran de suivi d'un client qui attend
  /// son repas.
  static EtapeDeCourse? depuisDiffusion(Map<String, dynamic> charge) {
    final commande = charge['order'];
    final statut = charge['status'];
    if (commande is! String || statut is! String) return null;

    return EtapeDeCourse(
      assignmentId: charge['assignment'] as String? ?? '',
      orderId: commande,
      statut: statut,
      // Vide plutôt que nul : les écrans testent `isNotEmpty`, et un livreur
      // sans nom affiché vaut mieux qu'un écran qui refuse de se dessiner.
      livreur: charge['courier'] as String? ?? '',
    );
  }

  final String assignmentId;
  final String orderId;

  /// `accepted`, `picked_up`, `on_the_way`, `delivered`, `cancelled` — miroir
  /// de `DeliveryStatus` (`backend/apps/delivery/states.py`).
  final String statut;

  /// Le nom du livreur, tel que le serveur le communique au client. Ni son
  /// e-mail ni son numéro personnel ne circulent : le joindre passe par le
  /// canal d'appel.
  final String livreur;

  /// La course vient d'être prise. C'est l'étape que la commande ne reflète
  /// pas, et donc la seule que ce canal apprend en exclusivité.
  bool get vientDEtreAcceptee => statut == 'accepted';
}
