import 'package:elcorazon_core/src/models/money.dart';
import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/network/page.dart';
import 'package:elcorazon_core/src/payments/split_payment.dart';
import 'package:elcorazon_core/src/payments/transaction.dart';
import 'package:elcorazon_core/src/payments/vocabulaire_paiement.dart';

/// Accès à `/api/v1/payments/*` — voir
/// `backend/apps/payments/{serializers,views,services}.py`. Le client ouvre
/// une demande de paiement et lit son statut ; il ne le fait jamais avancer
/// lui-même — seul un webhook signé du prestataire le peut.
class PaymentRepository {
  PaymentRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Les moyens de paiement acceptés, dans l'ordre où les proposer.
  Future<List<AcceptedPaymentMethod>> acceptedMethods() async {
    final response = await apiClient.get('/payments/methods/');
    return (response.data as List<dynamic>)
        .map((json) => AcceptedPaymentMethod.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Ouvre la demande de paiement de la commande — ou **rend** celle qui est
  /// déjà ouverte (200 au lieu de 201) : un second appel ne crée jamais une
  /// seconde facture chez le prestataire.
  Future<CheckoutInstruction> initiate(String orderId) async {
    final response = await apiClient.post('/payments/$orderId/initiate/');
    return CheckoutInstruction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Transaction>> getTransactions({required String orderId}) async {
    final transactions = <Transaction>[];
    String? path = '/payments/transactions/';
    Map<String, dynamic>? queryParameters = {'order': orderId};

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      transactions.addAll(results.map((json) => Transaction.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
      queryParameters = null;
    }

    return transactions;
  }

  /// **Une page** d'encaissements du périmètre.
  ///
  /// Le serveur applique le sien : pour un compte du personnel, les
  /// transactions des établissements auxquels il est rattaché ; pour un client,
  /// celles de ses propres commandes.
  ///
  /// Remplace la lecture qui suivait `next` jusqu'au bout : le back-office
  /// téléchargeait tout l'historique des encaissements — sans borne de date —
  /// pour en afficher vingt, puis cherchait dans ce qu'il avait reçu.
  ///
  /// [search] porte sur la référence du prestataire et celle de la commande.
  Future<Page<Transaction>> transactionsPage({
    String? status,
    String? restaurantSlug,
    String? currency,
    String? search,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 25,
  }) async {
    final response = await apiClient.get(
      '/payments/transactions/',
      queryParameters: _filtres(
        status: status,
        restaurantSlug: restaurantSlug,
        currency: currency,
        search: search,
        from: from,
        to: to,
      )
        ..['page'] = page
        ..['page_size'] = pageSize,
    );
    return Page<Transaction>.fromJson(
      response.data as Map<String, dynamic>,
      Transaction.fromJson,
    );
  }

  /// La page désignée par un `next`/`previous` du serveur — filtres compris.
  Future<Page<Transaction>> transactionsAt(String url) async {
    final response = await apiClient.get(url);
    return Page<Transaction>.fromJson(
      response.data as Map<String, dynamic>,
      Transaction.fromJson,
    );
  }

  /// Totaux de la sélection — **une ligne par devise** pour l'encaissé, et le
  /// compte de chaque statut. Mêmes filtres que [transactionsPage].
  ///
  /// L'écran additionnait les montants de la page chargée, XOF et XAF
  /// confondus, et intitulait le résultat « Total encaissé ».
  Future<TransactionSummary> transactionsSummary({
    String? status,
    String? restaurantSlug,
    String? currency,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await apiClient.get(
      '/payments/transactions/summary/',
      queryParameters: _filtres(
        status: status,
        restaurantSlug: restaurantSlug,
        currency: currency,
        search: search,
        from: from,
        to: to,
      ),
    );
    return TransactionSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Map<String, dynamic> _filtres({
    String? status,
    String? restaurantSlug,
    String? currency,
    String? search,
    DateTime? from,
    DateTime? to,
  }) {
    return {
      if (status != null) 'status': status,
      if (restaurantSlug != null) 'order__restaurant__slug': restaurantSlug,
      if (currency != null) 'amount_currency': currency,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (from != null) 'created_at__gte': from.toUtc().toIso8601String(),
      if (to != null) 'created_at__lte': to.toUtc().toIso8601String(),
    };
  }

  // --------------------------------------------------------- remboursement

  /// Rembourse tout ou partie d'une commande — permission `orders.refund`.
  ///
  /// **Le remboursement n'est pas un appel au prestataire depuis l'écran.**
  /// L'ancien back-office joignait PayDunya directement, avec les clés
  /// marchandes embarquées dans l'application : quiconque ouvrait le bundle
  /// pouvait déclencher des remboursements. Ici, le serveur détient les clés,
  /// vérifie le rattachement de la commande — un opérateur de Kara ne rembourse
  /// pas une commande de Lomé, avec l'argent de Lomé — et applique le plafond
  /// P3 : la somme des remboursements ne dépasse jamais l'encaissement.
  ///
  /// [transactionId] désigne l'encaissement à rembourser : une commande peut en
  /// porter plusieurs (paiement partagé), et rembourser « la commande » sans
  /// dire lequel ne voudrait rien dire.
  Future<Refund> refund({
    required String orderId,
    required String transactionId,
    required Money amount,
    required String reason,
  }) async {
    final response = await apiClient.post(
      '/payments/$orderId/refund/',
      data: {
        'transaction': transactionId,
        'amount': amount.toJson(),
        'reason': reason,
      },
    );
    return Refund.fromJson(response.data as Map<String, dynamic>);
  }

  // ------------------------------------------------------------- partage

  /// Ouvre un partage sur une commande. Le total est celui de la commande ;
  /// omettre les montants le répartit à parts égales côté serveur, **sans
  /// perdre d'unité mineure** — une division faite ici laisserait un franc
  /// orphelin à chaque partage impair.
  Future<SplitPayment> createSplit({
    required String orderId,
    required List<SplitParticipantInput> participants,
  }) async {
    final response = await apiClient.post(
      '/payments/$orderId/split/',
      data: {'participants': participants.map((p) => p.toJson()).toList()},
    );
    return SplitPayment.fromJson(response.data as Map<String, dynamic>);
  }

  /// État du partage d'une commande — réservé à son client.
  Future<SplitPayment> getSplit(String orderId) async {
    final response = await apiClient.get('/payments/$orderId/split/');
    return SplitPayment.fromJson(response.data as Map<String, dynamic>);
  }

  /// La part vue par son destinataire, **sans authentification** : le
  /// justificatif est le jeton du lien. Il ne donne accès qu'à cette part, ni à
  /// la commande ni aux autres participants.
  Future<SplitShare> getShare(String token) async {
    final response = await apiClient.get('/payments/shares/$token/');
    return SplitShare.fromJson(response.data as Map<String, dynamic>);
  }

  // ------------------------------------------------------------ retraits

  /// Demande le retrait de ses gains — réservé au livreur qui appelle.
  ///
  /// Le bénéficiaire ne se désigne pas : c'est l'appelant. Le solde est débité
  /// **à la demande**, sous verrou côté serveur ; le versement lui-même est un
  /// geste de l'exploitation, si bien que la demande naît « en attente ».
  Future<Withdrawal> requestWithdrawal(Money amount) async {
    final response = await apiClient.post(
      '/payments/withdrawals/',
      data: {'amount': amount.toJson()},
    );
    return Withdrawal.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Withdrawal>> getWithdrawals() async {
    final response = await apiClient.get('/payments/withdrawals/');
    return (response.data as List<dynamic>)
        .map((json) => Withdrawal.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Ouvre le règlement d'une part. Ne solde rien : la part suivra sa
  /// transaction, que seul le webhook signé du prestataire fait avancer.
  Future<ShareCheckout> payShare(String token) async {
    final response = await apiClient.post('/payments/shares/$token/');
    return ShareCheckout.fromJson(response.data as Map<String, dynamic>);
  }
}
