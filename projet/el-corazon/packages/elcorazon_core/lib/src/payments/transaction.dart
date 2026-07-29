import '../models/money.dart';

/// Encaissement — miroir de `TransactionSerializer`
/// (`backend/apps/payments/serializers.py`). Son statut n'évolue jamais sur la
/// foi d'un geste côté client : seul un webhook signé du prestataire le fait
/// avancer (invariant central du module, `apps/payments/services.py`).
class Transaction {
  const Transaction({
    required this.id,
    required this.orderId,
    required this.provider,
    required this.providerReference,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.failureReason = '',
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      orderId: json['order'] as String,
      provider: json['provider'] as String,
      providerReference: json['provider_reference'] as String,
      amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
      status: json['status'] as String,
      completedAt: json['completed_at'] == null ? null : DateTime.parse(json['completed_at'] as String),
      failureReason: json['failure_reason'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String orderId;

  /// `paydunya` | `cash` | `wallet` (`PaymentProvider` côté serveur).
  final String provider;
  final String providerReference;
  final Money amount;

  /// `pending` | `processing` | `completed` | `failed` (`PaymentStatus`).
  final String status;
  final DateTime? completedAt;
  final String failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}

/// Ce que le client doit faire pour payer — miroir de `CheckoutSerializer`.
class CheckoutInstruction {
  const CheckoutInstruction({
    required this.transaction,
    required this.checkoutUrl,
    required this.instructions,
  });

  factory CheckoutInstruction.fromJson(Map<String, dynamic> json) {
    return CheckoutInstruction(
      transaction: Transaction.fromJson(json['transaction'] as Map<String, dynamic>),
      checkoutUrl: json['checkout_url'] as String,
      instructions: json['instructions'] as String? ?? '',
    );
  }

  final Transaction transaction;
  final String checkoutUrl;
  final String instructions;
}
