import 'package:elcorazon_core/src/models/money.dart';

/// Part d'un paiement partagé — miroir de `SplitShareSerializer`.
///
/// [shareToken] est le lien à transmettre au convive. Il n'est rendu qu'aux
/// participants du partage et à l'initiateur : le donner à un tiers reviendrait
/// à lui laisser voir la commande.
class SplitShare {
  const SplitShare({
    required this.id,
    required this.displayName,
    required this.phone,
    required this.amount,
    required this.status,
    required this.shareToken,
    required this.createdAt,
  });

  factory SplitShare.fromJson(Map<String, dynamic> json) {
    return SplitShare(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
      status: json['status'] as String,
      shareToken: json['share_token'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String displayName;
  final String phone;
  final Money amount;

  /// `pending` | `paid` | `failed` | `cancelled` (`SplitShareStatus`).
  final String status;
  final String shareToken;
  final DateTime createdAt;

  bool get isPaid => status == 'paid';
}

/// Paiement partagé d'une commande — miroir de `SplitPaymentSerializer`.
class SplitPayment {
  const SplitPayment({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.totalAmount,
    required this.status,
    required this.shares,
    required this.createdAt,
  });

  factory SplitPayment.fromJson(Map<String, dynamic> json) {
    return SplitPayment(
      id: json['id'] as String,
      orderId: json['order'] as String,
      orderReference: json['order_reference'] as String? ?? '',
      totalAmount: Money.fromJson(json['total_amount'] as Map<String, dynamic>),
      status: json['status'] as String,
      shares: (json['shares'] as List<dynamic>? ?? const [])
          .map((json) => SplitShare.fromJson(json as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String orderId;
  final String orderReference;
  final Money totalAmount;

  /// `pending` | `completed` | `cancelled` — c'est le serveur qui solde le
  /// partage quand toutes les parts sont réglées, jamais le client.
  final String status;
  final List<SplitShare> shares;
  final DateTime createdAt;

  Money get paidAmount {
    var total = 0;
    for (final share in shares) {
      if (share.isPaid) total += share.amount.amountMinor;
    }
    return Money(amountMinor: total, currency: totalAmount.currency);
  }

  int get paidCount => shares.where((share) => share.isPaid).length;
}

/// Convive à inviter au partage.
///
/// [user] est facultatif : la moitié des participants d'un repas partagé n'ont
/// pas de compte, et exiger une inscription pour payer sa part ferait échouer
/// la fonctionnalité sur son cas le plus courant.
///
/// [amount] l'est aussi — omis pour tout le monde, le serveur répartit le total
/// à parts égales sans perdre une unité mineure. Le fournir pour certains
/// seulement est refusé côté serveur : une répartition à moitié déclarée ne
/// tomberait pas juste.
class SplitParticipantInput {
  const SplitParticipantInput({
    required this.displayName,
    this.userId,
    this.phone = '',
    this.amount,
  });

  final String displayName;
  final String? userId;
  final String phone;
  final Money? amount;

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        if (userId != null) 'user': userId,
        if (phone.isNotEmpty) 'phone': phone,
        if (amount != null) 'amount': amount!.toJson(),
      };
}

/// Règlement d'une part — miroir de `ShareCheckoutSerializer`.
class ShareCheckout {
  const ShareCheckout({
    required this.share,
    required this.checkoutUrl,
    required this.instructions,
  });

  factory ShareCheckout.fromJson(Map<String, dynamic> json) {
    return ShareCheckout(
      share: SplitShare.fromJson(json['share'] as Map<String, dynamic>),
      checkoutUrl: json['checkout_url'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
    );
  }

  final SplitShare share;
  final String checkoutUrl;
  final String instructions;
}


/// Demande de retrait des gains d'un livreur — miroir de
/// `WithdrawalSerializer`.
///
/// Elle enregistre une **intention de versement**, pas un versement : le
/// mouvement d'argent est exécuté par l'exploitation, et le statut ne passe à
/// `completed` que par elle. L'app livreur appelait auparavant l'API de
/// décaissement elle-même, puis écrivait « payé ».
class Withdrawal {
  const Withdrawal({
    required this.id,
    required this.amount,
    required this.status,
    required this.providerReference,
    required this.failureReason,
    required this.createdAt,
    this.completedAt,
  });

  factory Withdrawal.fromJson(Map<String, dynamic> json) {
    return Withdrawal(
      id: json['id'] as String,
      amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
      status: json['status'] as String,
      providerReference: json['provider_reference'] as String? ?? '',
      failureReason: json['failure_reason'] as String? ?? '',
      completedAt:
          json['completed_at'] == null ? null : DateTime.parse(json['completed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final Money amount;

  /// `pending` | `processing` | `completed` | `failed` | `cancelled`.
  final String status;
  final String providerReference;
  final String failureReason;
  final DateTime? completedAt;
  final DateTime createdAt;

  bool get isPending => status == 'pending' || status == 'processing';
}
