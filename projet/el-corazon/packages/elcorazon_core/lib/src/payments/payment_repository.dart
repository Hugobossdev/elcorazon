import '../models/money.dart';
import '../network/api_client.dart';
import 'split_payment.dart';
import 'transaction.dart';

/// Accès à `/api/v1/payments/*` — voir
/// `backend/apps/payments/{serializers,views,services}.py`. Le client ouvre
/// une demande de paiement et lit son statut ; il ne le fait jamais avancer
/// lui-même — seul un webhook signé du prestataire le peut.
class PaymentRepository {
  PaymentRepository({required this.apiClient});

  final ApiClient apiClient;

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
