import 'package:elcorazon_core/src/models/money.dart';
import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/network/page.dart';

/// Les sorties d'argent que l'exploitation instruit — `/payments/manage/*`
/// (`backend/apps/payments/backoffice.py`).
///
/// Deux choses, et une règle commune : **rien ici ne verse**. PayDunya n'expose
/// pas d'API de remboursement, et le décaissement vers un livreur part lui aussi
/// d'un geste humain chez le prestataire. Ces appels **constatent** ce qui a été
/// fait ailleurs.
///
/// * un retrait livreur débitait ses gains à la demande, puis restait en
///   attente pour toujours : rien ne pouvait le solder ni le refuser ;
/// * un remboursement se demandait depuis le back-office et ne se clôturait
///   que dans l'administration Django.

/// Statuts d'un mouvement d'argent, tels que `PaymentStatus` les nomme.
abstract final class StatutVersement {
  static const enAttente = 'pending';
  static const enCours = 'processing';
  static const verse = 'completed';
  static const refuse = 'failed';

  /// Une demande de remboursement **abandonnée** : rien n'a été versé, et le
  /// montant redevient remboursable. Nommée depuis que le back-office sait la
  /// poser (`/payments/manage/refunds/{id}/cancel/`).
  static const annule = 'cancelled';

  /// Libellé d'écran. Un statut inconnu s'affiche tel quel plutôt que d'être
  /// maquillé en l'un des connus.
  static String libelle(String statut) => switch (statut) {
        enAttente => 'À verser',
        enCours => 'En cours',
        verse => 'Versé',
        refuse => 'Refusé',
        annule => 'Abandonné',
        'refunded' => 'Remboursé',
        _ => statut,
      };
}

/// Une demande de retrait, avec de quoi la verser sans rouvrir le dossier.
class ManagedWithdrawal {
  const ManagedWithdrawal({
    required this.id,
    required this.courierId,
    required this.courierName,
    required this.restaurantSlug,
    required this.restaurantName,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.courierPhone,
    this.providerReference = '',
    this.failureReason = '',
    this.processedByName,
    this.completedAt,
  });

  factory ManagedWithdrawal.fromJson(Map<String, dynamic> json) => ManagedWithdrawal(
        id: json['id'] as String,
        courierId: json['courier'] as String,
        courierName: json['courier_name'] as String? ?? '',
        courierPhone: json['courier_phone'] as String?,
        restaurantSlug: json['restaurant'] as String? ?? '',
        restaurantName: json['restaurant_name'] as String? ?? '',
        amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
        status: json['status'] as String,
        providerReference: json['provider_reference'] as String? ?? '',
        failureReason: json['failure_reason'] as String? ?? '',
        processedByName: json['processed_by_name'] as String?,
        completedAt: _date(json['completed_at']),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String courierId;
  final String courierName;

  /// Le numéro du compte livreur — c'est là qu'on verse : le dossier ne porte
  /// pas de coordonnées de versement distinctes.
  final String? courierPhone;
  final String restaurantSlug;
  final String restaurantName;
  final Money amount;
  final String status;
  final String providerReference;
  final String failureReason;

  /// Qui a constaté ou refusé. Nul tant que la demande attend.
  final String? processedByName;
  final DateTime? completedAt;
  final DateTime createdAt;

  /// Encore à instruire : ni versée, ni refusée.
  bool get aInstruire => status == StatutVersement.enAttente || status == StatutVersement.enCours;
}

/// Un remboursement demandé, et ce qu'il faut pour l'exécuter.
class ManagedRefund {
  const ManagedRefund({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.restaurantName,
    required this.customerName,
    required this.provider,
    required this.amount,
    required this.reason,
    required this.status,
    required this.requestedByName,
    required this.createdAt,
    this.customerPhone,
    this.completedAt,
  });

  factory ManagedRefund.fromJson(Map<String, dynamic> json) => ManagedRefund(
        id: json['id'] as String,
        orderId: json['order'] as String,
        orderReference: json['order_reference'] as String? ?? '',
        restaurantName: json['restaurant_name'] as String? ?? '',
        customerName: json['customer_name'] as String? ?? '',
        customerPhone: json['customer_phone'] as String?,
        provider: json['provider'] as String? ?? '',
        amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
        reason: json['reason'] as String? ?? '',
        status: json['status'] as String,
        requestedByName: json['requested_by_name'] as String? ?? '',
        completedAt: _date(json['completed_at']),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String orderId;
  final String orderReference;
  final String restaurantName;
  final String customerName;
  final String? customerPhone;

  /// Le prestataire de l'encaissement d'origine — `paydunya`, `cash`… C'est
  /// par lui que l'argent repart.
  final String provider;
  final Money amount;
  final String reason;
  final String status;
  final String requestedByName;
  final DateTime? completedAt;
  final DateTime createdAt;

  bool get aVerser => status == StatutVersement.enAttente || status == StatutVersement.enCours;
}

DateTime? _date(Object? valeur) => valeur == null ? null : DateTime.parse(valeur as String);

class ManagedPayoutRepository {
  ManagedPayoutRepository({required this.apiClient});

  final ApiClient apiClient;

  // ----------------------------------------------------------- retraits

  /// Une page de demandes de retrait — `payouts.read`.
  ///
  /// [status] filtre côté serveur : « à verser » est la question du quotidien,
  /// et filtrer une page déjà reçue n'y répondrait que pour vingt lignes.
  Future<Page<ManagedWithdrawal>> withdrawals({
    String? status,
    String? search,
    int pageSize = 50,
  }) async {
    final response = await apiClient.get(
      '/payments/manage/withdrawals/',
      queryParameters: {
        'page_size': pageSize,
        if (status != null) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return Page.fromJson(response.data as Map<String, dynamic>, ManagedWithdrawal.fromJson);
  }

  /// Constate le versement — `payouts.settle`. La référence du virement est
  /// exigée par le serveur : c'est la preuve qu'on cherchera.
  Future<ManagedWithdrawal> settleWithdrawal({
    required String withdrawalId,
    required String providerReference,
  }) async {
    final response = await apiClient.post(
      '/payments/manage/withdrawals/$withdrawalId/settle/',
      data: {'provider_reference': providerReference},
    );
    return ManagedWithdrawal.fromJson(response.data as Map<String, dynamic>);
  }

  /// Refuse le versement — les gains sont rendus au livreur, qui lit le motif.
  Future<ManagedWithdrawal> rejectWithdrawal({
    required String withdrawalId,
    required String reason,
  }) async {
    final response = await apiClient.post(
      '/payments/manage/withdrawals/$withdrawalId/reject/',
      data: {'reason': reason},
    );
    return ManagedWithdrawal.fromJson(response.data as Map<String, dynamic>);
  }

  // ------------------------------------------------------- remboursements

  Future<Page<ManagedRefund>> refunds({String? status, int pageSize = 50}) async {
    final response = await apiClient.get(
      '/payments/manage/refunds/',
      queryParameters: {
        'page_size': pageSize,
        if (status != null) 'status': status,
      },
    );
    return Page.fromJson(response.data as Map<String, dynamic>, ManagedRefund.fromJson);
  }

  /// Constate un remboursement versé — `orders.refund`. La référence est
  /// facultative : un remboursement rendu au comptoir n'en a pas.
  Future<ManagedRefund> settleRefund({
    required String refundId,
    String providerReference = '',
  }) async {
    final response = await apiClient.post(
      '/payments/manage/refunds/$refundId/settle/',
      data: {
        if (providerReference.trim().isNotEmpty) 'provider_reference': providerReference.trim(),
      },
    );
    return ManagedRefund.fromJson(response.data as Map<String, dynamic>);
  }

  /// Abandonne un remboursement qui ne sera pas versé — `orders.refund`.
  ///
  /// Le motif est exigé par le serveur. Sans cette sortie, une demande saisie
  /// par erreur restait en attente pour toujours **et** consommait le plafond
  /// du remboursable : la commande devenait irremboursable.
  Future<ManagedRefund> cancelRefund({
    required String refundId,
    required String reason,
  }) async {
    final response = await apiClient.post(
      '/payments/manage/refunds/$refundId/cancel/',
      data: {'reason': reason},
    );
    return ManagedRefund.fromJson(response.data as Map<String, dynamic>);
  }
}
