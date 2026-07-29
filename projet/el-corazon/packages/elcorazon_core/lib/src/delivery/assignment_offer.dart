/// Une course proposée, telle qu'elle arrive sur la file du livreur
/// (`ws/couriers/me/`, événement `delivery.offered` — voir
/// `AssignmentService.offer`).
///
/// Volontairement pauvre, et c'est le contrat qui le veut : le message porte de
/// quoi **alerter**, pas de quoi travailler. L'étape de la course, les
/// transitions permises, les montants et les articles se relisent par l'API,
/// qui seule fait autorité. Un client qui déciderait à partir de ce message
/// afficherait un état que le serveur n'a pas confirmé.
class AssignmentOffer {
  const AssignmentOffer({
    required this.assignmentId,
    required this.orderId,
    required this.reference,
    required this.restaurant,
    required this.deliveryAddressLine,
  });

  /// Les cinq champs sont émis ensemble par le serveur ; les lire en tolérant
  /// leur absence évite qu'une trame partielle — une version de serveur plus
  /// ancienne, un champ renommé — ne fasse tomber la file entière. Rater une
  /// proposition coûte un repas froid (ADR-008) : mieux vaut une alerte
  /// incomplète que pas d'alerte.
  factory AssignmentOffer.fromPayload(Map<String, dynamic> payload) {
    return AssignmentOffer(
      assignmentId: payload['assignment'] as String? ?? '',
      orderId: payload['order'] as String? ?? '',
      reference: payload['reference'] as String? ?? '',
      restaurant: payload['restaurant'] as String? ?? '',
      deliveryAddressLine: payload['delivery_address_line'] as String? ?? '',
    );
  }

  final String assignmentId;
  final String orderId;
  final String reference;
  final String restaurant;
  final String deliveryAddressLine;
}
