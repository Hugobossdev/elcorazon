import 'package:elcorazon_core/src/models/money.dart';

/// Demande de retour — miroir de `ReturnRequestSerializer`. C'est une
/// **demande**, pas un remboursement : le versement reste un geste humain
/// côté back-office, et `refundAmount` est plafonné au total de la commande
/// par le serveur (`SupportService.request_return`), jamais ici.
class ReturnRequest {
  const ReturnRequest({
    required this.id,
    required this.orderId,
    required this.reason,
    required this.items,
    required this.refundAmount,
    required this.status,
    required this.createdAt,
    this.resolution = '',
    this.resolvedAt,
  });

  factory ReturnRequest.fromJson(Map<String, dynamic> json) {
    return ReturnRequest(
      id: json['id'] as String,
      orderId: json['order'] as String,
      reason: json['reason'] as String,
      items: (json['items'] as List<dynamic>).map((e) => e.toString()).toList(),
      refundAmount: Money.fromJson(json['refund_amount'] as Map<String, dynamic>),
      status: json['status'] as String,
      resolution: json['resolution'] as String? ?? '',
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String orderId;
  final String reason;
  final List<String> items;
  final Money refundAmount;

  /// `pending` | `approved` | `rejected` | `refunded` (`ReturnStatus`).
  final String status;

  /// Ce que l'exploitation a répondu — le motif d'un refus, d'abord. Vide
  /// tant qu'elle n'a pas statué, et pour un serveur antérieur au champ.
  final String resolution;
  final DateTime? resolvedAt;
  final DateTime createdAt;
}
