/// État d'un paiement, tel que l'affiche l'écran de règlement.
///
/// C'est une **projection** du statut de transaction rendu par le serveur
/// (`/payments/transactions/`), pas une décision du client : l'application ne
/// déclare jamais qu'un paiement a abouti. Seul le webhook signé du prestataire
/// fait avancer une transaction, côté serveur ; le retour de l'utilisateur sur
/// l'application n'écrit aucun état.
///
/// L'énumération vivait auparavant dans `paydunya_service.dart`, aux côtés des
/// clés marchandes et des appels directs à `app.paydunya.com`. Elle est le seul
/// morceau de ce fichier qui méritait de survivre.
enum PaymentStatus {
  /// Aucun règlement engagé — commande à payer à la livraison, ou écran
  /// tout juste ouvert.
  none,

  /// Le serveur a ouvert une transaction ; l'utilisateur est chez le
  /// prestataire, ou vient d'en revenir sans que le webhook soit arrivé.
  pending,

  /// Le serveur tient la transaction pour réglée.
  completed,

  /// Abandonné par l'utilisateur ou expiré côté prestataire.
  cancelled,

  /// L'ouverture du règlement a échoué — le serveur a refusé, ou le réseau
  /// n'a pas répondu.
  error,

  /// Remboursée, en tout ou partie, depuis le back-office.
  refunded,
}
