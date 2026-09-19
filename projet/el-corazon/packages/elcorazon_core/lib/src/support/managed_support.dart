import 'package:elcorazon_core/src/models/money.dart';
import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/network/page.dart';
import 'package:elcorazon_core/src/support/support_ticket.dart';

/// Le support vu du personnel — `/support/manage/*`
/// (`backend/apps/support/backoffice.py`).
///
/// Les routes du support n'étaient ouvertes qu'aux clients : un client
/// écrivait, réclamait, demandait un retour, et le back-office ne pouvait ni le
/// lire ni lui répondre. Chaque geste de ce dépôt part maintenant vers lui en
/// notification.

/// Libellés des statuts du support, tels que les trois modèles les nomment.
abstract final class StatutSupport {
  static String ticket(String statut) => switch (statut) {
        'open' => 'Ouvert',
        'in_progress' => 'En cours',
        'resolved' => 'Résolu',
        'closed' => 'Fermé',
        _ => statut,
      };

  static String reclamation(String statut) => switch (statut) {
        'pending' => 'En attente',
        'under_review' => 'En examen',
        'resolved' => 'Résolue',
        'rejected' => 'Rejetée',
        _ => statut,
      };

  static String retour(String statut) => switch (statut) {
        'pending' => 'En attente',
        'approved' => 'Approuvé',
        'rejected' => 'Refusé',
        'refunded' => 'Remboursé',
        _ => statut,
      };

  static String categorie(String categorie) => switch (categorie) {
        'order' => 'Commande',
        'payment' => 'Paiement',
        'account' => 'Compte',
        'delivery' => 'Livraison',
        'other' => 'Autre',
        _ => categorie,
      };
}

/// Un ticket, avec qui l'a écrit. [messages] n'est rempli qu'au détail.
class ManagedTicket {
  const ManagedTicket({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    required this.createdAt,
    this.customerPhone,
    this.attachments = const [],
    this.resolution = '',
    this.resolvedAt,
    this.messagesCount = 0,
    this.messages = const [],
  });

  factory ManagedTicket.fromJson(Map<String, dynamic> json) => ManagedTicket(
        id: json['id'] as String,
        customerId: json['user'] as String,
        customerName: json['customer_name'] as String? ?? '',
        customerEmail: json['customer_email'] as String? ?? '',
        customerPhone: json['customer_phone'] as String?,
        category: json['category'] as String,
        subject: json['subject'] as String,
        description: json['description'] as String? ?? '',
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .map((url) => url.toString())
            .toList(),
        status: json['status'] as String,
        resolution: json['resolution'] as String? ?? '',
        resolvedAt: _date(json['resolved_at']),
        messagesCount: json['messages_count'] as int? ?? 0,
        messages: (json['messages'] as List<dynamic>? ?? const [])
            .map((m) => SupportMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String? customerPhone;
  final String category;
  final String subject;
  final String description;
  final List<String> attachments;
  final String status;
  final String resolution;
  final DateTime? resolvedAt;
  final int messagesCount;
  final List<SupportMessage> messages;
  final DateTime createdAt;

  /// Attend encore quelqu'un : ni résolu, ni fermé.
  bool get enSouffrance => status == 'open' || status == 'in_progress';
}

class ManagedComplaint {
  const ManagedComplaint({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.restaurantName,
    required this.customerName,
    required this.kind,
    required this.subject,
    required this.description,
    required this.status,
    required this.createdAt,
    this.customerPhone,
    this.photos = const [],
    this.resolution = '',
  });

  factory ManagedComplaint.fromJson(Map<String, dynamic> json) => ManagedComplaint(
        id: json['id'] as String,
        orderId: json['order'] as String,
        orderReference: json['order_reference'] as String? ?? '',
        restaurantName: json['restaurant_name'] as String? ?? '',
        customerName: json['customer_name'] as String? ?? '',
        customerPhone: json['customer_phone'] as String?,
        kind: json['kind'] as String,
        subject: json['subject'] as String,
        description: json['description'] as String? ?? '',
        photos: (json['photos'] as List<dynamic>? ?? const []).map((u) => u.toString()).toList(),
        status: json['status'] as String,
        resolution: json['resolution'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String orderId;
  final String orderReference;
  final String restaurantName;
  final String customerName;
  final String? customerPhone;
  final String kind;
  final String subject;
  final String description;
  final List<String> photos;
  final String status;
  final String resolution;
  final DateTime createdAt;

  /// Close : résolue ou rejetée. Le serveur refuse de la rejuger.
  bool get close => status == 'resolved' || status == 'rejected';
}

class ManagedReturn {
  const ManagedReturn({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.orderTotal,
    required this.restaurantName,
    required this.customerName,
    required this.reason,
    required this.items,
    required this.refundAmount,
    required this.status,
    required this.createdAt,
    this.customerPhone,
    this.resolution = '',
    this.resolvedAt,
  });

  factory ManagedReturn.fromJson(Map<String, dynamic> json) => ManagedReturn(
        id: json['id'] as String,
        orderId: json['order'] as String,
        orderReference: json['order_reference'] as String? ?? '',
        orderTotal: Money.fromJson(json['order_total'] as Map<String, dynamic>),
        restaurantName: json['restaurant_name'] as String? ?? '',
        customerName: json['customer_name'] as String? ?? '',
        customerPhone: json['customer_phone'] as String?,
        reason: json['reason'] as String? ?? '',
        items: (json['items'] as List<dynamic>? ?? const []).map((i) => i.toString()).toList(),
        refundAmount: Money.fromJson(json['refund_amount'] as Map<String, dynamic>),
        status: json['status'] as String,
        resolution: json['resolution'] as String? ?? '',
        resolvedAt: _date(json['resolved_at']),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String orderId;
  final String orderReference;
  final Money orderTotal;
  final String restaurantName;
  final String customerName;
  final String? customerPhone;
  final String reason;
  final List<String> items;
  final Money refundAmount;
  final String status;
  final String resolution;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  /// Ce que le serveur accepte depuis l'état courant — la même table que
  /// `RETURN_TRANSITIONS`. Sert à ne proposer que les gestes possibles ; le
  /// serveur reste juge, et refuse le reste en 409.
  List<String> get decisionsPossibles => switch (status) {
        'pending' => const ['approved', 'rejected'],
        'approved' => const ['refunded', 'rejected'],
        _ => const [],
      };
}

DateTime? _date(Object? valeur) => valeur == null ? null : DateTime.parse(valeur as String);

class ManagedSupportRepository {
  ManagedSupportRepository({required this.apiClient});

  final ApiClient apiClient;

  // ------------------------------------------------------------- tickets

  /// [statuts] part en `status__in` : « à traiter » couvre deux statuts, et
  /// deux requêtes recollées feraient mentir la pagination.
  Future<Page<ManagedTicket>> tickets({
    List<String>? statuts,
    String? search,
    int pageSize = 50,
  }) async {
    final response = await apiClient.get(
      '/support/manage/tickets/',
      queryParameters: {
        'page_size': pageSize,
        if (statuts != null && statuts.isNotEmpty) 'status__in': statuts.join(','),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return Page.fromJson(response.data as Map<String, dynamic>, ManagedTicket.fromJson);
  }

  /// Le ticket et son fil.
  Future<ManagedTicket> ticket(String ticketId) async {
    final response = await apiClient.get('/support/manage/tickets/$ticketId/');
    return ManagedTicket.fromJson(response.data as Map<String, dynamic>);
  }

  /// Répond au client — il en est prévenu, et le ticket passe « en cours ».
  Future<SupportMessage> reply({required String ticketId, required String content}) async {
    final response = await apiClient.post(
      '/support/manage/tickets/$ticketId/reply/',
      data: {'content': content},
    );
    return SupportMessage.fromJson(response.data as Map<String, dynamic>);
  }

  /// Résout, ferme ou rouvre. Résoudre exige une [resolution] (409 sinon).
  Future<ManagedTicket> setTicketStatus({
    required String ticketId,
    required String status,
    String resolution = '',
  }) async {
    final response = await apiClient.post(
      '/support/manage/tickets/$ticketId/status/',
      data: {'status': status, 'resolution': resolution},
    );
    return ManagedTicket.fromJson(response.data as Map<String, dynamic>);
  }

  // --------------------------------------------------------- réclamations

  Future<Page<ManagedComplaint>> complaints({
    List<String>? statuts,
    int pageSize = 50,
  }) async {
    final response = await apiClient.get(
      '/support/manage/complaints/',
      queryParameters: {
        'page_size': pageSize,
        if (statuts != null && statuts.isNotEmpty) 'status__in': statuts.join(','),
      },
    );
    return Page.fromJson(response.data as Map<String, dynamic>, ManagedComplaint.fromJson);
  }

  Future<ManagedComplaint> decideComplaint({
    required String complaintId,
    required String status,
    String resolution = '',
  }) async {
    final response = await apiClient.post(
      '/support/manage/complaints/$complaintId/decide/',
      data: {'status': status, 'resolution': resolution},
    );
    return ManagedComplaint.fromJson(response.data as Map<String, dynamic>);
  }

  // -------------------------------------------------------------- retours

  Future<Page<ManagedReturn>> returns({
    List<String>? statuts,
    int pageSize = 50,
  }) async {
    final response = await apiClient.get(
      '/support/manage/returns/',
      queryParameters: {
        'page_size': pageSize,
        if (statuts != null && statuts.isNotEmpty) 'status__in': statuts.join(','),
      },
    );
    return Page.fromJson(response.data as Map<String, dynamic>, ManagedReturn.fromJson);
  }

  Future<ManagedReturn> decideReturn({
    required String returnId,
    required String status,
    String resolution = '',
  }) async {
    final response = await apiClient.post(
      '/support/manage/returns/$returnId/decide/',
      data: {'status': status, 'resolution': resolution},
    );
    return ManagedReturn.fromJson(response.data as Map<String, dynamic>);
  }
}
