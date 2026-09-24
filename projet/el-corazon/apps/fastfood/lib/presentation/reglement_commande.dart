import 'package:elcora_fast/models/order.dart';

/// Où en est le règlement d'une commande, tel que le détail doit le dire.
///
/// ## Ce qui se passait
///
/// Le détail écrivait « Réglé par Mobile Money », coche à l'appui, sur
/// **toutes** les commandes : celle dont le paiement avait échoué, celle que
/// le client avait quittée avant de valider sur son téléphone, celle payable
/// en espèces et pas encore livrée. Le moyen de paiement annonce une
/// intention ; seul `amount_paid`, que le serveur tient à jour à chaque
/// encaissement confirmé, dit ce qui a été payé.
///
/// Et la commande laissée en attente n'avait aucun chemin de retour vers le
/// paiement : l'écran de règlement ne s'ouvrait que depuis la caisse.
enum SituationDuReglement {
  /// Le serveur a encaissé le total.
  reglee,

  /// Espèces pas encore remises : le livreur encaisse à la livraison, et le
  /// serveur l'enregistre à ce moment-là.
  aLaLivraison,

  /// Paiement en ligne non encaissé, sur une commande encore vivante — le
  /// client peut (re)lancer le paiement.
  enAttente,

  /// Commande annulée sans encaissement.
  sansEncaissement,

  /// Commande relue d'un cache antérieur, qui ne porte pas le montant
  /// encaissé : on ne prétend rien.
  inconnue,
}

SituationDuReglement situationDuReglement(Order commande) {
  final regle = commande.montantRegle;
  if (regle == null) return SituationDuReglement.inconnue;
  if (commande.total > 0 && regle >= commande.total) {
    return SituationDuReglement.reglee;
  }
  if (commande.status == OrderStatus.cancelled) {
    return SituationDuReglement.sansEncaissement;
  }
  if (commande.paymentMethod == PaymentMethod.cash) {
    return SituationDuReglement.aLaLivraison;
  }
  return SituationDuReglement.enAttente;
}

/// La phrase du détail de commande, pour chaque situation.
String libelleDuReglement(Order commande) {
  final moyen = commande.paymentMethod.displayName;
  switch (situationDuReglement(commande)) {
    case SituationDuReglement.reglee:
      return 'Réglé par $moyen';
    case SituationDuReglement.aLaLivraison:
      // Pas encore remises : le serveur enregistre les espèces au passage en
      // `delivered` (`apps/payments/cash.py`), et la commande devient alors
      // [SituationDuReglement.reglee].
      return 'Espèces, à régler à la livraison';
    case SituationDuReglement.enAttente:
      return 'Paiement en attente ($moyen)';
    case SituationDuReglement.sansEncaissement:
      return 'Aucun paiement encaissé';
    case SituationDuReglement.inconnue:
      return 'Moyen de paiement : $moyen';
  }
}
