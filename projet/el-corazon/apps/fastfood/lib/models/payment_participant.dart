/// Un convive d'un paiement partagé, tel que le compose l'écran de partage.
///
/// C'est une **saisie**, pas un état : le nom, le téléphone et l'opérateur sont
/// ce que l'initiateur renseigne avant d'envoyer la répartition au serveur
/// (`POST /payments/{commande}/split/`). Ce que devient chaque part — réglée,
/// en attente, expirée — n'est pas ici : cela vient de `eccore.SplitShare`,
/// c'est-à-dire du serveur.
///
/// Le modèle vivait auparavant dans `paydunya_service.dart`, avec les clés
/// marchandes et les appels directs au prestataire. Il n'a lui-même aucun lien
/// avec PayDunya, d'où son déplacement plutôt que sa suppression.
class PaymentParticipant {
  const PaymentParticipant({
    required this.userId,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.operator,
    required this.amount,
    this.backendId,
  });

  final String userId;
  final String name;
  final String email;
  final String phoneNumber;

  /// Opérateur de monnaie électronique choisi par le convive.
  final String operator;

  /// Montant de la part, en unité majeure — ce que l'écran affiche.
  ///
  /// La répartition qui fait foi est celle du serveur : lui seul découpe le
  /// total sans perdre d'unité mineure. Une division faite ici laisserait un
  /// franc orphelin à chaque partage impair.
  final double amount;

  /// Identifiant de la part une fois créée côté serveur, `null` avant.
  final String? backendId;

  PaymentParticipant copyWith({
    String? phoneNumber,
    String? operator,
    double? amount,
    String? backendId,
  }) {
    return PaymentParticipant(
      userId: userId,
      name: name,
      email: email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      operator: operator ?? this.operator,
      amount: amount ?? this.amount,
      backendId: backendId ?? this.backendId,
    );
  }
}
