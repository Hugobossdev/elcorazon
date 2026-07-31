import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/services/paydunya_service.dart';

enum GroupPaymentStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

enum GroupPaymentParticipantStatus {
  pending,
  processing,
  paid,
  failed,
  cancelled,
}

class GroupPaymentSession {
  final String id;
  final String orderId;
  final String? groupId;
  final String? initiatedBy;
  final double totalAmount;
  final double paidAmount;
  final GroupPaymentStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<GroupPaymentParticipant> participants;

  GroupPaymentSession({
    required this.id,
    required this.orderId,
    required this.groupId,
    required this.initiatedBy,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.participants,
  });

  /// Depuis le contrat Django (`SplitPaymentSerializer`).
  ///
  /// `paidAmount` n'est plus un champ tenu en base côté client : il se déduit
  /// des parts déjà réglées, et le serveur est seul à décider qu'une part l'est
  /// — via le webhook signé du prestataire.
  factory GroupPaymentSession.fromRemote(eccore.SplitPayment split) {
    return GroupPaymentSession(
      id: split.id,
      orderId: split.orderId,
      // Le partage porte sur une commande, pas sur un groupe : le lien au
      // panier collaboratif n'existe plus une fois la commande née.
      groupId: null,
      initiatedBy: null,
      totalAmount: split.totalAmount.toMajorUnits(),
      paidAmount: split.paidAmount.toMajorUnits(),
      status: _statusFromRemote(split.status),
      createdAt: split.createdAt,
      updatedAt: null,
      participants:
          split.shares.map(GroupPaymentParticipant.fromRemote).toList(growable: false),
    );
  }

  static GroupPaymentStatus _statusFromRemote(String status) {
    switch (status) {
      case 'completed':
        return GroupPaymentStatus.completed;
      case 'cancelled':
        return GroupPaymentStatus.cancelled;
      default:
        return GroupPaymentStatus.pending;
    }
  }

  factory GroupPaymentSession.fromMap(Map<String, dynamic> map) {
    final participantsRaw =
        (map['participants'] as List<dynamic>? ?? <dynamic>[])
            .cast<Map<String, dynamic>>();

    return GroupPaymentSession(
      id: map['id']?.toString() ?? '',
      orderId: map['order_id']?.toString() ?? '',
      groupId: map['group_id']?.toString(),
      initiatedBy: map['initiated_by']?.toString(),
      totalAmount: _toDouble(map['total_amount']),
      paidAmount: _toDouble(map['paid_amount']),
      status: _parseStatus(map['status']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
      participants: participantsRaw
          .map(GroupPaymentParticipant.fromMap)
          .toList(growable: false),
    );
  }

  GroupPaymentSession copyWith({
    double? totalAmount,
    double? paidAmount,
    GroupPaymentStatus? status,
    List<GroupPaymentParticipant>? participants,
  }) {
    return GroupPaymentSession(
      id: id,
      orderId: orderId,
      groupId: groupId,
      initiatedBy: initiatedBy,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      participants: participants ?? this.participants,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static GroupPaymentStatus _parseStatus(dynamic value) {
    switch (value?.toString()) {
      case 'completed':
        return GroupPaymentStatus.completed;
      case 'in_progress':
        return GroupPaymentStatus.inProgress;
      case 'cancelled':
        return GroupPaymentStatus.cancelled;
      case 'pending':
      default:
        return GroupPaymentStatus.pending;
    }
  }
}

class GroupPaymentParticipant {
  final String id;
  final String? userId;
  final String name;
  final String? email;
  final String? phone;
  final String? operator;
  final double amount;
  final double paidAmount;
  final GroupPaymentParticipantStatus status;
  final String? transactionId;
  final Map<String, dynamic>? paymentResult;

  /// Jeton du lien de règlement — vide hors contrat Django.
  final String shareToken;

  GroupPaymentParticipant({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.operator,
    required this.amount,
    required this.paidAmount,
    required this.status,
    required this.transactionId,
    required this.paymentResult,
    this.shareToken = '',
  });

  /// Depuis le contrat Django (`SplitShareSerializer`).
  ///
  /// [shareToken] est le lien à transmettre au convive : c'est lui qui permet
  /// de régler sa part **sans compte**, ce que l'ancienne implémentation ne
  /// permettait pas — elle exigeait un `user_id` pour chaque participant.
  factory GroupPaymentParticipant.fromRemote(eccore.SplitShare share) {
    return GroupPaymentParticipant(
      id: share.id,
      userId: null,
      name: share.displayName,
      email: null,
      phone: share.phone,
      operator: null,
      amount: share.amount.toMajorUnits(),
      paidAmount: share.isPaid ? share.amount.toMajorUnits() : 0.0,
      status: _participantStatusFromRemote(share.status),
      transactionId: null,
      paymentResult: null,
      shareToken: share.shareToken,
    );
  }

  static GroupPaymentParticipantStatus _participantStatusFromRemote(String status) {
    switch (status) {
      case 'paid':
        return GroupPaymentParticipantStatus.paid;
      case 'failed':
        return GroupPaymentParticipantStatus.failed;
      case 'cancelled':
        return GroupPaymentParticipantStatus.cancelled;
      default:
        return GroupPaymentParticipantStatus.pending;
    }
  }

  factory GroupPaymentParticipant.fromMap(Map<String, dynamic> map) {
    return GroupPaymentParticipant(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      name: map['name']?.toString() ?? 'Participant',
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
      operator: map['operator']?.toString(),
      amount: GroupPaymentSession._toDouble(map['amount']),
      paidAmount: GroupPaymentSession._toDouble(map['paid_amount']),
      status: _parseParticipantStatus(map['status']),
      transactionId: map['transaction_id']?.toString(),
      paymentResult:
          map['payment_result'] is Map<String, dynamic> ? map['payment_result'] as Map<String, dynamic> : null,
    );
  }

  GroupPaymentParticipant copyWith({
    String? phone,
    String? operator,
    double? paidAmount,
    GroupPaymentParticipantStatus? status,
    String? transactionId,
    Map<String, dynamic>? paymentResult,
  }) {
    return GroupPaymentParticipant(
      id: id,
      userId: userId,
      name: name,
      email: email,
      phone: phone ?? this.phone,
      operator: operator ?? this.operator,
      amount: amount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      transactionId: transactionId ?? this.transactionId,
      paymentResult: paymentResult ?? this.paymentResult,
    );
  }

  PaymentParticipant toPaymentParticipant() {
    return PaymentParticipant(
      userId: userId ?? '',
      name: name,
      email: email ?? '',
      phoneNumber: phone ?? '',
      operator: operator ?? '',
      amount: amount,
      backendId: id,
    );
  }

  static GroupPaymentParticipantStatus _parseParticipantStatus(dynamic value) {
    switch (value?.toString()) {
      case 'processing':
        return GroupPaymentParticipantStatus.processing;
      case 'paid':
        return GroupPaymentParticipantStatus.paid;
      case 'failed':
        return GroupPaymentParticipantStatus.failed;
      case 'cancelled':
        return GroupPaymentParticipantStatus.cancelled;
      case 'pending':
      default:
        return GroupPaymentParticipantStatus.pending;
    }
  }
}



