import '../network/api_client.dart';
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
}
