import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour gérer les paiements et remboursements PayDunya
class PayDunyaService extends ChangeNotifier {
  static final PayDunyaService _instance = PayDunyaService._internal();
  factory PayDunyaService() => _instance;
  PayDunyaService._internal();

  String? _masterKey;
  String? _publicKey;
  String? _privateKey;
  String? _token;
  bool _isConfigured = false;
  bool _isLoading = false;
  String? _error;

  // Getters
  bool get isConfigured => _isConfigured;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialiser le service avec les clés API
  Future<void> initialize({
    String? masterKey,
    String? publicKey,
    String? privateKey,
    String? token,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();

      // Charger depuis les préférences ou utiliser les paramètres fournis
      _masterKey = masterKey ?? prefs.getString('paydunya_master_key');
      _publicKey = publicKey ?? prefs.getString('paydunya_public_key');
      _privateKey = privateKey ?? prefs.getString('paydunya_private_key');
      _token = token ?? prefs.getString('paydunya_token');

      if (_masterKey != null &&
          _publicKey != null &&
          _privateKey != null &&
          _token != null) {
        _isConfigured = true;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      _isConfigured = false;
      notifyListeners();
      debugPrint('PayDunyaService: Erreur d\'initialisation - $e');
    }
  }

  /// Configurer les clés API
  Future<bool> configure({
    required String masterKey,
    required String publicKey,
    required String privateKey,
    required String token,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('paydunya_master_key', masterKey);
      await prefs.setString('paydunya_public_key', publicKey);
      await prefs.setString('paydunya_private_key', privateKey);
      await prefs.setString('paydunya_token', token);

      _masterKey = masterKey;
      _publicKey = publicKey;
      _privateKey = privateKey;
      _token = token;
      _isConfigured = true;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      _isConfigured = false;
      notifyListeners();
      debugPrint('PayDunyaService: Erreur de configuration - $e');
      return false;
    }
  }

  /// Vérifier le statut d'une transaction
  Future<PayDunyaTransactionStatus?> checkTransactionStatus(
      String transactionId) async {
    if (!_isConfigured) {
      _error = 'PayDunya n\'est pas configuré';
      notifyListeners();
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Appel API PayDunya pour vérifier le statut d'une transaction
      final response = await http.get(
        Uri.parse('https://api.paydunya.com/v1/transaction/$transactionId'),
        headers: {
          'PAYDUNYA-MASTER-KEY': _masterKey!,
          'PAYDUNYA-PRIVATE-KEY': _privateKey!,
          'PAYDUNYA-TOKEN': _token!,
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout lors de la vérification du statut de la transaction');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        final status = PayDunyaTransactionStatus(
          transactionId: transactionId,
          status: data['status']?.toString() ?? 'unknown',
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          createdAt: data['created_at'] != null
              ? DateTime.parse(data['created_at'].toString())
              : DateTime.now(),
          paymentMethod: data['payment_method']?.toString(),
          metadata: data['metadata'] != null
              ? Map<String, dynamic>.from(data['metadata'] as Map)
              : null,
        );

        _isLoading = false;
        notifyListeners();
        return status;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>?;
        final errorMessage = errorData?['message']?.toString() ?? 
            'Erreur lors de la vérification du statut (${response.statusCode})';
        _error = errorMessage;
        _isLoading = false;
        notifyListeners();
        debugPrint('PayDunyaService: Erreur vérification statut - $errorMessage');
        return null;
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('PayDunyaService: Erreur vérification statut - $e');
      return null;
    }
  }

  /// Rembourser une transaction
  Future<PayDunyaRefundResult?> refundTransaction({
    required String transactionId,
    required double amount,
    String? reason,
  }) async {
    if (!_isConfigured) {
      _error = 'PayDunya n\'est pas configuré';
      notifyListeners();
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Appel API PayDunya pour rembourser une transaction
      final response = await http.post(
        Uri.parse('https://api.paydunya.com/v1/refund'),
        headers: {
          'PAYDUNYA-MASTER-KEY': _masterKey!,
          'PAYDUNYA-PRIVATE-KEY': _privateKey!,
          'PAYDUNYA-TOKEN': _token!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'transaction_id': transactionId,
          'amount': amount,
          if (reason != null) 'reason': reason,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout lors du remboursement de la transaction');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        final result = PayDunyaRefundResult(
          refundId: data['refund_id']?.toString() ?? 
              'REF_${DateTime.now().millisecondsSinceEpoch}',
          transactionId: transactionId,
          amount: amount,
          status: data['status']?.toString() ?? 'success',
          refundedAt: data['refunded_at'] != null
              ? DateTime.parse(data['refunded_at'].toString())
              : DateTime.now(),
          reason: reason ?? data['reason']?.toString(),
        );

        _isLoading = false;
        notifyListeners();
        return result;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>?;
        final errorMessage = errorData?['message']?.toString() ?? 
            'Erreur lors du remboursement (${response.statusCode})';
        _error = errorMessage;
        _isLoading = false;
        notifyListeners();
        debugPrint('PayDunyaService: Erreur remboursement - $errorMessage');
        return null;
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('PayDunyaService: Erreur remboursement - $e');
      return null;
    }
  }

  /// Remboursement partiel
  Future<PayDunyaRefundResult?> partialRefund({
    required String transactionId,
    required double amount,
    String? reason,
  }) async {
    return refundTransaction(
      transactionId: transactionId,
      amount: amount,
      reason: reason,
    );
  }

  /// Obtenir l'historique des transactions
  Future<List<PayDunyaTransaction>> getTransactionHistory({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    if (!_isConfigured) {
      _error = 'PayDunya n\'est pas configuré';
      notifyListeners();
      return [];
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Simulation API Call
      await Future.delayed(const Duration(seconds: 1));
      
      // Generate mock transactions
      final transactions = List.generate(10, (index) {
        return PayDunyaTransaction(
          id: 'tx_$index',
          transactionId: 'PD_${DateTime.now().millisecondsSinceEpoch}_$index',
          amount: (index + 1) * 1000.0,
          status: 'success',
          createdAt: DateTime.now().subtract(Duration(days: index)),
          orderId: 'order_$index',
        );
      });

      _isLoading = false;
      notifyListeners();
      return transactions;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('PayDunyaService: Erreur historique - $e');
      return [];
    }
  }

  /// Réconciliation automatique (PayDunya → DB)
  Future<PayDunyaReconciliationResult> reconcileTransactions({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!_isConfigured) {
      return PayDunyaReconciliationResult(
        success: false,
        matchedCount: 0,
        unmatchedCount: 0,
        errors: ['PayDunya n\'est pas configuré'],
      );
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 1. Récupérer les transactions PayDunya
      final payDunyaTransactions = await getTransactionHistory(
        startDate: startDate, 
        endDate: endDate
      );

      // 2. Récupérer les transactions de la DB via Supabase
      // Note: Assuming 'orders' table has payment_id or transaction_id
      // For now, we simulate DB orders fetching to match mock transactions
      
      int matched = 0;
      int unmatched = 0;
      List<String> reconciliationErrors = [];

      for (var pdTx in payDunyaTransactions) {
        // Check if order exists in DB with this transaction ID
        // In real app:
        // final response = await supabase.from('orders').select().eq('transaction_id', pdTx.transactionId);
        // bool exists = (response as List).isNotEmpty;
        
        // Simulation: 80% match rate
        bool exists = pdTx.amount % 5000 != 0; 
        
        if (exists) {
          matched++;
        } else {
          unmatched++;
          reconciliationErrors.add('Transaction PayDunya ${pdTx.transactionId} non trouvée dans la DB');
        }
      }

      await Future.delayed(const Duration(seconds: 1));

      final result = PayDunyaReconciliationResult(
        success: true,
        matchedCount: matched,
        unmatchedCount: unmatched,
        errors: reconciliationErrors,
      );

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('PayDunyaService: Erreur réconciliation - $e');
      return PayDunyaReconciliationResult(
        success: false,
        matchedCount: 0,
        unmatchedCount: 0,
        errors: [e.toString()],
      );
    }
  }
}

/// Modèle pour le statut d'une transaction PayDunya
class PayDunyaTransactionStatus {
  final String transactionId;
  final String status; // success, failed, pending
  final double amount;
  final DateTime createdAt;
  final String? paymentMethod;
  final Map<String, dynamic>? metadata;

  PayDunyaTransactionStatus({
    required this.transactionId,
    required this.status,
    required this.amount,
    required this.createdAt,
    this.paymentMethod,
    this.metadata,
  });

  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending';
}

/// Modèle pour le résultat d'un remboursement
class PayDunyaRefundResult {
  final String refundId;
  final String transactionId;
  final double amount;
  final String status; // success, failed, pending
  final DateTime refundedAt;
  final String? reason;

  PayDunyaRefundResult({
    required this.refundId,
    required this.transactionId,
    required this.amount,
    required this.status,
    required this.refundedAt,
    this.reason,
  });

  bool get isSuccess => status == 'success';
}

/// Modèle pour une transaction PayDunya
class PayDunyaTransaction {
  final String id;
  final String transactionId;
  final double amount;
  final String status;
  final DateTime createdAt;
  final String? orderId;
  final String? customerId;
  final String? paymentMethod;

  PayDunyaTransaction({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.orderId,
    this.customerId,
    this.paymentMethod,
  });
}

/// Modèle pour le résultat de réconciliation
class PayDunyaReconciliationResult {
  final bool success;
  final int matchedCount;
  final int unmatchedCount;
  final List<String> errors;

  PayDunyaReconciliationResult({
    required this.success,
    required this.matchedCount,
    required this.unmatchedCount,
    required this.errors,
  });
}

