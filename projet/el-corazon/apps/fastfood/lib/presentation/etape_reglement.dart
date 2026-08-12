/// Où en est l'écran de règlement.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Il vient de `models/payment_status.dart`, mais ce n'était pas un modèle :
/// aucune de ces valeurs ne voyage, et le serveur n'en connaît aucune. C'est
/// l'**état de l'écran**, et sa place est ici.
///
/// L'ancien commentaire annonçait « une projection du statut de transaction
/// rendu par le serveur ». C'était inexact, et l'inexactitude coûtait deux
/// valeurs mortes. Le statut du serveur est
/// `pending | processing | completed | failed` ; l'écran ne le lit pas
/// directement, il interroge `Transaction.isCompleted` et
/// `Transaction.isFailed` en attendant le webhook. Ce que décrit cette
/// énumération, c'est donc ce que l'utilisateur a sous les yeux, pas l'état
/// comptable.
///
/// Deux valeurs de l'ancienne liste ont été retirées : `cancelled` et
/// `refunded`. **Aucun chemin ne les produisait.** Une annulation côté
/// prestataire arrive ici comme un échec, et un remboursement est décidé au
/// back-office, longtemps après que cet écran a été refermé. Un test les
/// gardait en vie en affirmant que l'énumération comptait six valeurs — il
/// vérifiait la liste, pas le cycle de vie qu'elle prétendait couvrir.
enum EtapeReglement {
  /// Rien d'engagé — écran tout juste ouvert.
  aucune,

  /// La transaction est ouverte ; l'utilisateur est chez le prestataire, ou
  /// vient d'en revenir sans que le webhook soit arrivé.
  enAttente,

  /// Le serveur tient la transaction pour réglée. C'est **lui** qui le dit :
  /// le retour de l'utilisateur sur l'application n'écrit aucun état.
  reglee,

  /// L'ouverture du règlement a échoué, le prestataire a refusé, ou le réseau
  /// n'a pas répondu.
  echouee,
}
