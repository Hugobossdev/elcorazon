/// État d'une transaction d'encaissement — `apps.payments.models.PaymentStatus`.
///
/// Le filtre de l'écran des paiements écrivait sa propre liste et en oubliait
/// une valeur (`cancelled`) : une transaction annulée n'était visible sous
/// aucun filtre, sinon « Tous ». La liste vient maintenant d'ici, et
/// `tools/contrat_vocabulaire.py` la confronte aux `TextChoices` du serveur.
abstract final class PaymentStatus {
  static const pending = 'pending';
  static const processing = 'processing';
  static const completed = 'completed';
  static const failed = 'failed';
  static const cancelled = 'cancelled';
  static const refunded = 'refunded';

  static const values = [pending, processing, completed, failed, cancelled, refunded];

  static String libelle(String valeur) => switch (valeur) {
        pending => 'En attente',
        processing => 'En cours',
        completed => 'Encaissé',
        failed => 'Échoué',
        cancelled => 'Annulé',
        refunded => 'Remboursé',
        _ => valeur,
      };
}

/// Un moyen de paiement **accepté** à la commande — `GET /payments/methods/`.
///
/// La liste vient du serveur (réglage `PAYMENT_METHODS`), qui refuse à la
/// création tout moyen qu'il ne publie pas. L'application client la désactivait
/// en dur (« bientôt ») ; elle n'en décide plus.
class AcceptedPaymentMethod {
  const AcceptedPaymentMethod({required this.code, required this.label});

  factory AcceptedPaymentMethod.fromJson(Map<String, dynamic> json) {
    return AcceptedPaymentMethod(
      code: json['code'] as String,
      label: json['label'] as String,
    );
  }

  /// La valeur à renvoyer dans `payment_method` — `apps.orders.models.PaymentMethod`.
  final String code;

  /// Le libellé du serveur, tel qu'il le montre partout ailleurs.
  final String label;
}
