import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:elcora_fast/config/api_config.dart';
import 'package:elcora_fast/services/rest_client.dart';

class PayDunyaService extends ChangeNotifier {
  static final PayDunyaService _instance = PayDunyaService._internal();
  factory PayDunyaService() => _instance;
  PayDunyaService._internal();

  // Configuration PayDunya
  static const String _baseUrl = 'https://app.paydunya.com';
  // NOTE: le host `app-sandbox.paydunya.com` ne résout pas (ENOTFOUND) dans plusieurs environnements.
  // On utilise le même host et on différencie via les clés sandbox / prod.
  static const String _sandboxUrl = 'https://app.paydunya.com';
  final RestClient _rest = const RestClient(timeout: Duration(seconds: 30));

  String? _masterKey;
  String? _privateKey;
  String? _token;
  bool _isSandbox = true; // Mode test par défaut

  // État du service
  bool _isInitialized = false;
  String? _currentOrderId;
  PaymentStatus _paymentStatus = PaymentStatus.none;

  // Stream pour les mises à jour de paiement
  final StreamController<PaymentUpdate> _paymentController =
      StreamController<PaymentUpdate>.broadcast();

  Stream<PaymentUpdate> get paymentStream => _paymentController.stream;
  bool get isInitialized => _isInitialized;
  PaymentStatus get paymentStatus => _paymentStatus;

  /// Initialise le service PayDunya avec les clés
  Future<void> initialize({
    required String masterKey,
    required String privateKey,
    required String token,
    bool isSandbox = true,
  }) async {
    _masterKey = masterKey;
    _privateKey = privateKey;
    _token = token;
    _isSandbox = isSandbox;
    _isInitialized = true;

    debugPrint(
      'PayDunyaService: Initialisé en mode ${isSandbox ? "sandbox" : "production"}',
    );
    notifyListeners();
  }

  /// Obtient l'URL de base selon l'environnement
  String get _apiUrl => _isSandbox ? _sandboxUrl : _baseUrl;

  Uri _buildPayDunyaUri(String path) {
    // Web: proxy backend si PayDunya bloque le CORS
    if (kIsWeb) {
      return Uri.parse('${ApiConfig.backendUrl}/api/paydunya$path').replace(
        queryParameters: {
          'sandbox': _isSandbox ? 'true' : 'false',
        },
      );
    }
    return Uri.parse('$_apiUrl$path');
  }

  /// Crée une demande de paiement via le backend Node.js
  Future<PaymentRequestResult> createPaymentRequest({
    required String orderId,
    required double amount,
    required String currency,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String description,
    String? returnUrl,
    String? cancelUrl,
    String? webhookUrl,
    Map<String, dynamic>? metadata,
  }) async {
    // Note: Keys are now handled by the backend, but we check init for consistency
    if (!_isInitialized) {
      debugPrint(
        'PayDunyaService: Warning - Service not explicitly initialized, but proceeding with backend call.',
      );
    }

    try {
      // Call Node.js backend
      final backendUrl = ApiConfig.backendUrl;
      final url = Uri.parse('$backendUrl/api/payments/init');

      debugPrint('PayDunyaService: Calling backend at $url');

      final payload = {
        'amount': amount,
        'description': description,
        'orderId': orderId,
        // Add other fields if backend supports them
      };

      final response = await _rest.postJson(url, body: payload);

      if (response['success'] == true) {
        _currentOrderId = orderId;
        _paymentStatus = PaymentStatus.pending;

        final result = PaymentRequestResult(
          success: true,
          invoiceToken: response['invoiceToken'] as String?,
          invoiceUrl: response['url'] as String?, // Backend returns 'url'
          orderId: orderId,
        );

        _paymentController.add(
          PaymentUpdate(
            orderId: orderId,
            status: PaymentStatus.pending,
            message: 'Demande de paiement créée avec succès via backend',
          ),
        );

        notifyListeners();
        return result;
      } else {
        throw Exception('Backend Error: ${response['error']}');
      }
    } catch (e) {
      final error = 'Erreur inattendue: $e';
      debugPrint('PayDunyaService: $error');
      return PaymentRequestResult(
        success: false,
        error: error,
        orderId: orderId,
      );
    }
  }

  /// Vérifie le statut d'un paiement
  Future<PaymentStatus> checkPaymentStatus(String invoiceToken) async {
    try {
      final url =
          _buildPayDunyaUri('/api/v1/checkout-invoice/confirm/$invoiceToken');

      final headers = {
        'PAYDUNYA-MASTER-KEY': _masterKey!,
        'PAYDUNYA-PRIVATE-KEY': _privateKey!,
        'PAYDUNYA-TOKEN': _token!,
      };

      final data = await _rest.getJson(url, headers: headers);

      if (data['response_code'] == '00') {
        final responseText = data['response_text'] as Map<String, dynamic>;
        final status = responseText['status'] as String;

        PaymentStatus paymentStatus;
        switch (status) {
          case 'completed':
            paymentStatus = PaymentStatus.completed;
            break;
          case 'cancelled':
            paymentStatus = PaymentStatus.cancelled;
            break;
          case 'pending':
            paymentStatus = PaymentStatus.pending;
            break;
          default:
            paymentStatus = PaymentStatus.pending;
        }

        _paymentStatus = paymentStatus;

        _paymentController.add(
          PaymentUpdate(
            orderId: _currentOrderId ?? '',
            status: paymentStatus,
            message: 'Statut mis à jour: $status',
            transactionId: responseText['transaction_id'] as String?,
          ),
        );

        notifyListeners();
        return paymentStatus;
      } else {
        throw Exception('Erreur PayDunya: ${data['response_text']}');
      }
    } catch (e) {
      debugPrint('PayDunyaService: Erreur vérification statut - $e');
      return PaymentStatus.error;
    }
  }

  /// Traite un paiement mobile money
  Future<PaymentResult> processMobileMoneyPayment({
    required String orderId,
    required double amount,
    required String phoneNumber,
    required String operator, // 'mtn', 'orange', 'moov'
    required String customerName,
    required String customerEmail,
  }) async {
    try {
      // Créer la demande de paiement
      final paymentRequest = await createPaymentRequest(
        orderId: orderId,
        amount: amount,
        currency: 'XOF',
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: phoneNumber,
        description: 'Paiement FastEat - Commande #$orderId',
        metadata: {
          'payment_method': 'mobile_money',
          'operator': operator,
        },
      );

      if (!paymentRequest.success) {
        return PaymentResult(
          success: false,
          error: paymentRequest.error ?? 'Erreur création paiement',
          orderId: orderId,
        );
      }

      // Simuler le processus de paiement mobile money
      // Dans une vraie implémentation, cela déclencherait le paiement via l'opérateur
      await _simulateMobileMoneyPayment(
        invoiceToken: paymentRequest.invoiceToken!,
        phoneNumber: phoneNumber,
        operator: operator,
      );

      return PaymentResult(
        success: true,
        invoiceToken: paymentRequest.invoiceToken,
        invoiceUrl: paymentRequest.invoiceUrl,
        orderId: orderId,
      );
    } catch (e) {
      debugPrint('PayDunyaService: Erreur paiement mobile money - $e');
      return PaymentResult(
        success: false,
        error: e.toString(),
        orderId: orderId,
      );
    }
  }

  /// Traite un paiement par carte bancaire
  Future<PaymentResult> processCardPayment({
    required String orderId,
    required double amount,
    required String cardNumber,
    required String cardHolderName,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
    required String customerName,
    required String customerEmail,
  }) async {
    try {
      // Créer la demande de paiement
      final paymentRequest = await createPaymentRequest(
        orderId: orderId,
        amount: amount,
        currency: 'XOF',
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: '',
        description: 'Paiement FastEat - Commande #$orderId',
        metadata: {
          'payment_method': 'card',
          'card_last_four': cardNumber.substring(cardNumber.length - 4),
        },
      );

      if (!paymentRequest.success) {
        return PaymentResult(
          success: false,
          error: paymentRequest.error ?? 'Erreur création paiement',
          orderId: orderId,
        );
      }

      // Simuler le processus de paiement par carte
      await _simulateCardPayment(
        invoiceToken: paymentRequest.invoiceToken!,
        cardNumber: cardNumber,
        cardHolderName: cardHolderName,
        expiryMonth: expiryMonth,
        expiryYear: expiryYear,
        cvv: cvv,
      );

      return PaymentResult(
        success: true,
        invoiceToken: paymentRequest.invoiceToken,
        invoiceUrl: paymentRequest.invoiceUrl,
        orderId: orderId,
      );
    } catch (e) {
      debugPrint('PayDunyaService: Erreur paiement carte - $e');
      return PaymentResult(
        success: false,
        error: e.toString(),
        orderId: orderId,
      );
    }
  }

  /// Traite un paiement partagé
  Future<SharedPaymentResult> processSharedPayment({
    required String orderId,
    required double totalAmount,
    required List<PaymentParticipant> participants,
    required String organizerName,
    required String organizerEmail,
  }) async {
    try {
      final results = <PaymentResult>[];

      for (final participant in participants) {
        final result = await processMobileMoneyPayment(
          orderId: '${orderId}_${participant.userId}',
          amount: participant.amount,
          phoneNumber: participant.phoneNumber,
          operator: participant.operator,
          customerName: participant.name,
          customerEmail: participant.email,
        );

        results.add(result);
      }

      final successCount = results.where((r) => r.success).length;
      final isFullyPaid = successCount == participants.length;

      final amountByUser = <String, double>{
        for (final participant in participants)
          participant.userId: participant.amount,
      };
      double paidAmount = 0.0;
      for (final result in results) {
        if (result.success) {
          final parts = result.orderId.split('_');
          final userPart = parts.isNotEmpty ? parts.last : '';
          paidAmount += amountByUser[userPart] ?? 0.0;
        }
      }

      return SharedPaymentResult(
        success: isFullyPaid,
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        participants: participants,
        results: results,
        orderId: orderId,
      );
    } catch (e) {
      debugPrint('PayDunyaService: Erreur paiement partagé - $e');
      return SharedPaymentResult(
        success: false,
        totalAmount: totalAmount,
        paidAmount: 0.0,
        participants: participants,
        results: [],
        orderId: orderId,
        error: e.toString(),
      );
    }
  }

  /// Simule un paiement mobile money (pour les tests)
  Future<void> _simulateMobileMoneyPayment({
    required String invoiceToken,
    required String phoneNumber,
    required String operator,
  }) async {
    // Simuler le délai de traitement
    await Future.delayed(const Duration(seconds: 3));

    // Simuler le succès du paiement
    _paymentStatus = PaymentStatus.completed;

    _paymentController.add(
      PaymentUpdate(
        orderId: _currentOrderId ?? '',
        status: PaymentStatus.completed,
        message: 'Paiement mobile money effectué avec succès',
        transactionId: 'TXN_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    notifyListeners();
  }

  /// Simule un paiement par carte (pour les tests)
  Future<void> _simulateCardPayment({
    required String invoiceToken,
    required String cardNumber,
    required String cardHolderName,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
  }) async {
    // Simuler le délai de traitement
    await Future.delayed(const Duration(seconds: 2));

    // Simuler le succès du paiement
    _paymentStatus = PaymentStatus.completed;

    _paymentController.add(
      PaymentUpdate(
        orderId: _currentOrderId ?? '',
        status: PaymentStatus.completed,
        message: 'Paiement par carte effectué avec succès',
        transactionId: 'TXN_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    notifyListeners();
  }

  /// Annule un paiement
  Future<bool> cancelPayment(String invoiceToken) async {
    try {
      final url =
          _buildPayDunyaUri('/api/v1/checkout-invoice/cancel/$invoiceToken');

      final headers = {
        'PAYDUNYA-MASTER-KEY': _masterKey!,
        'PAYDUNYA-PRIVATE-KEY': _privateKey!,
        'PAYDUNYA-TOKEN': _token!,
      };

      final data = await _rest.postJson(url, headers: headers, body: {});

      if (data['response_code'] == '00') {
        _paymentStatus = PaymentStatus.cancelled;

        _paymentController.add(
          PaymentUpdate(
            orderId: _currentOrderId ?? '',
            status: PaymentStatus.cancelled,
            message: 'Paiement annulé avec succès',
          ),
        );

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('PayDunyaService: Erreur annulation - $e');
      return false;
    }
  }

  /// Traite un remboursement
  Future<bool> processRefund({
    required String transactionId,
    required double amount,
    required String reason,
  }) async {
    try {
      final url = _buildPayDunyaUri('/api/v1/refund');

      final payload = {
        'transaction_id': transactionId,
        'amount': amount,
        'reason': reason,
      };

      final headers = {
        'PAYDUNYA-MASTER-KEY': _masterKey!,
        'PAYDUNYA-PRIVATE-KEY': _privateKey!,
        'PAYDUNYA-TOKEN': _token!,
      };

      final data = await _rest.postJson(url, headers: headers, body: payload);

      if (data['response_code'] == '00') {
        _paymentController.add(
          PaymentUpdate(
            orderId: _currentOrderId ?? '',
            status: PaymentStatus.refunded,
            message: 'Remboursement effectué avec succès',
            transactionId: (data['response_text']
                as Map<String, dynamic>?)?['refund_id'] as String?,
          ),
        );

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('PayDunyaService: Erreur remboursement - $e');
      return false;
    }
  }

  /// Obtient l'historique des paiements
  Future<List<PaymentHistoryItem>> getPaymentHistory({
    int page = 1,
    int limit = 20,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Dans une vraie implémentation, ceci ferait un appel API
      // Pour l'instant, on retourne des données simulées
      await Future.delayed(const Duration(seconds: 1));

      return List.generate(
        10,
        (index) => PaymentHistoryItem(
          id: 'TXN_${DateTime.now().millisecondsSinceEpoch}_$index',
          orderId: 'ORDER_${DateTime.now().millisecondsSinceEpoch}_$index',
          amount: 5000.0 + (index * 1000),
          currency: 'XOF',
          status: PaymentStatus.completed,
          method: index % 2 == 0 ? 'mobile_money' : 'card',
          createdAt: DateTime.now().subtract(Duration(days: index)),
          description: 'Commande FastEat #${index + 1}',
        ),
      );
    } catch (e) {
      debugPrint('PayDunyaService: Erreur historique - $e');
      return [];
    }
  }

  /// Obtient les opérateurs mobile money disponibles
  List<Map<String, dynamic>> getAvailableMobileMoneyOperators() {
    return [
      {
        'id': 'mtn',
        'name': 'MTN Mobile Money',
        'icon': 'assets/icons/mtn.png',
        'color': 0xFFF7931E,
        'description': 'Paiement via MTN Mobile Money',
        'supported': true,
      },
      {
        'id': 'orange',
        'name': 'Orange Money',
        'icon': 'assets/icons/orange.png',
        'color': 0xFFFF6600,
        'description': 'Paiement via Orange Money',
        'supported': true,
      },
      {
        'id': 'moov',
        'name': 'Moov Money',
        'icon': 'assets/icons/moov.png',
        'color': 0xFF00A651,
        'description': 'Paiement via Moov Money',
        'supported': true,
      },
    ];
  }

  @override
  void dispose() {
    _paymentController.close();
    super.dispose();
  }
}

// Modèles de données
enum PaymentStatus {
  none,
  pending,
  completed,
  cancelled,
  error,
  refunded,
}

class PaymentRequestResult {
  final bool success;
  final String? invoiceToken;
  final String? invoiceUrl;
  final String? qrCode;
  final String? error;
  final String orderId;

  PaymentRequestResult({
    required this.success,
    required this.orderId,
    this.invoiceToken,
    this.invoiceUrl,
    this.qrCode,
    this.error,
  });
}

class PaymentResult {
  final bool success;
  final String? invoiceToken;
  final String? invoiceUrl;
  final String? error;
  final String orderId;

  PaymentResult({
    required this.success,
    required this.orderId,
    this.invoiceToken,
    this.invoiceUrl,
    this.error,
  });
}

class SharedPaymentResult {
  final bool success;
  final double totalAmount;
  final double paidAmount;
  final List<PaymentParticipant> participants;
  final List<PaymentResult> results;
  final String? error;
  final String orderId;

  SharedPaymentResult({
    required this.success,
    required this.totalAmount,
    required this.paidAmount,
    required this.participants,
    required this.results,
    required this.orderId,
    this.error,
  });
}

class PaymentParticipant {
  final String userId;
  final String name;
  final String email;
  final String phoneNumber;
  final String operator;
  final double amount;
  final String? backendId;

  PaymentParticipant({
    required this.userId,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.operator,
    required this.amount,
    this.backendId,
  });

  PaymentParticipant copyWith({
    String? phoneNumber,
    String? operator,
    double? amount,
    String? backendId,
  }) {
    return PaymentParticipant(
      userId: userId,
      name: name,
      email: email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      operator: operator ?? this.operator,
      amount: amount ?? this.amount,
      backendId: backendId ?? this.backendId,
    );
  }
}

class PaymentUpdate {
  final String orderId;
  final PaymentStatus status;
  final String message;
  final String? transactionId;

  PaymentUpdate({
    required this.orderId,
    required this.status,
    required this.message,
    this.transactionId,
  });
}

class PaymentHistoryItem {
  final String id;
  final String orderId;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String method;
  final DateTime createdAt;
  final String description;

  PaymentHistoryItem({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.method,
    required this.createdAt,
    required this.description,
  });
}
