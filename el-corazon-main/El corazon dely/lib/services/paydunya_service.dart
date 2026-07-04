import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class PayDunyaService extends ChangeNotifier {
  static final PayDunyaService _instance = PayDunyaService._internal();
  factory PayDunyaService() => _instance;
  PayDunyaService._internal();

  // Configuration PayDunya
  static const String _baseUrl = 'https://app.paydunya.com';
  static const String _sandboxUrl = 'https://app-sandbox.paydunya.com';

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
    String? masterKey,
    String? privateKey,
    String? token,
    bool isSandbox = true,
  }) async {
    _masterKey = masterKey ?? ApiConfig.payDunyaMasterKey;
    _privateKey = privateKey ?? ApiConfig.payDunyaPrivateKey;
    _token = token ?? ApiConfig.payDunyaToken;
    _isSandbox = isSandbox;
    _isInitialized = true;

    debugPrint(
      'PayDunyaService: Initialisé en mode ${isSandbox ? "sandbox" : "production"}',
    );
    notifyListeners();
  }

  /// Obtient l'URL de base selon l'environnement
  String get _apiUrl => _isSandbox ? _sandboxUrl : _baseUrl;

  /// S'assure que le service est initialisé
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Crée une demande de paiement
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
    await _ensureInitialized();

    if (!_isInitialized) {
      throw Exception('PayDunyaService non initialisé (Clés manquantes)');
    }

    try {
      final url = Uri.parse('$_apiUrl/api/v1/checkout-invoice/create');

      final payload = {
        'invoice': {
          'items': [
            {
              'name': description,
              'quantity': 1,
              'unit_price': amount,
              'total_price': amount,
              'description': description,
            },
          ],
          'taxes': [],
          'total_amount': amount,
          'description': description,
        },
        'store': {
          'name': 'El Corazon Dely',
          'tagline': 'Votre restaurant de confiance',
          'postal_address': 'Abidjan, Côte d\'Ivoire',
          'phone': '+225 XX XX XX XX',
          'website_url': 'https://fasteat.ci',
          'logo_url': 'https://fasteat.ci/logo.png',
        },
        'custom_data': {
          'order_id': orderId,
          'customer_name': customerName,
          'customer_email': customerEmail,
          'customer_phone': customerPhone,
          ...(metadata ?? {}),
        },
        'actions': {
          'cancel_url': cancelUrl ?? 'https://fasteat.ci/cancel',
          'return_url': returnUrl ?? 'https://fasteat.ci/success',
          'callback_url': webhookUrl ?? 'https://fasteat.ci/webhook',
        },
      };

      final headers = {
        'Content-Type': 'application/json',
        'PAYDUNYA-MASTER-KEY': _masterKey!,
        'PAYDUNYA-PRIVATE-KEY': _privateKey!,
        'PAYDUNYA-TOKEN': _token!,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        if (data['response_code'] == '00') {
          _currentOrderId = orderId;
          _paymentStatus = PaymentStatus.pending;

          final result = PaymentRequestResult(
            success: true,
            invoiceToken: data['response_text']['token'],
            invoiceUrl: data['response_text']['invoice_url'],
            qrCode: data['response_text']['qrcode'],
            orderId: orderId,
          );

          _paymentController.add(
            PaymentUpdate(
              orderId: orderId,
              status: PaymentStatus.pending,
              message: 'Demande de paiement créée avec succès',
            ),
          );

          notifyListeners();
          return result;
        } else {
          throw Exception('Erreur PayDunya: ${data['response_text']}');
        }
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('PayDunyaService: Erreur création paiement - $e');
      return PaymentRequestResult(
        success: false,
        error: e.toString(),
        orderId: orderId,
      );
    }
  }

  /// Vérifie le statut d'un paiement
  Future<PaymentStatus> checkPaymentStatus(String invoiceToken) async {
    try {
      final url = Uri.parse(
        '$_apiUrl/api/v1/checkout-invoice/confirm/$invoiceToken',
      );

      final headers = {
        'Content-Type': 'application/json',
        'PAYDUNYA-MASTER-KEY': _masterKey!,
        'PAYDUNYA-PRIVATE-KEY': _privateKey!,
        'PAYDUNYA-TOKEN': _token!,
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['response_code'] == '00') {
          final status = data['response_text']['status'];

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
              transactionId: data['response_text']['transaction_id'],
            ),
          );

          notifyListeners();
          return paymentStatus;
        } else {
          throw Exception('Erreur PayDunya: ${data['response_text']}');
        }
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
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
        description: 'Paiement El Corazon Dely - Commande #$orderId',
        metadata: {'payment_method': 'mobile_money', 'operator': operator},
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
        description: 'Paiement El Corazon Dely - Commande #$orderId',
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

      return SharedPaymentResult(
        success: isFullyPaid,
        totalAmount: totalAmount,
        paidAmount: results
            .where((r) => r.success)
            .fold(
              0.0,
              (sum, r) =>
                  sum +
                  participants
                      .firstWhere((p) => p.userId == r.orderId.split('_').last)
                      .amount,
            ),
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
      final url = Uri.parse(
        '$_apiUrl/api/v1/checkout-invoice/cancel/$invoiceToken',
      );

      final headers = {
        'Content-Type': 'application/json',
        'PAYDUNYA-MASTER-KEY': _masterKey!,
        'PAYDUNYA-PRIVATE-KEY': _privateKey!,
        'PAYDUNYA-TOKEN': _token!,
      };

      final response = await http.post(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

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
      final url = Uri.parse('$_apiUrl/api/v1/refund');

      final payload = {
        'transaction_id': transactionId,
        'amount': amount,
        'reason': reason,
      };

      final headers = {
        'Content-Type': 'application/json',
        'PAYDUNYA-MASTER-KEY': _masterKey!,
        'PAYDUNYA-PRIVATE-KEY': _privateKey!,
        'PAYDUNYA-TOKEN': _token!,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['response_code'] == '00') {
          _paymentController.add(
            PaymentUpdate(
              orderId: _currentOrderId ?? '',
              status: PaymentStatus.refunded,
              message: 'Remboursement effectué avec succès',
              transactionId: data['response_text']['refund_id'],
            ),
          );

          notifyListeners();
          return true;
        }
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
          description: 'Commande El Corazon Dely #${index + 1}',
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

  /// Traite un retrait (disbursement) vers Mobile Money
  Future<WithdrawalResult> processWithdrawal({
    required String userId,
    required double amount,
    required String phoneNumber,
    required String accountName,
    String? operator, // 'mtn', 'orange', 'moov' - auto-détecté si null
  }) async {
    await _ensureInitialized();

    if (!_isInitialized) {
      return WithdrawalResult(
        success: false,
        error: 'PayDunyaService non initialisé (Clés manquantes)',
      );
    }

    try {
      // Détecter l'opérateur si non spécifié
      String detectedOperator =
          operator ?? _detectMobileMoneyOperator(phoneNumber);

      if (detectedOperator.isEmpty) {
        return WithdrawalResult(
          success: false,
          error:
              'Impossible de détecter l\'opérateur Mobile Money. Veuillez spécifier l\'opérateur.',
        );
      }

      // Utiliser l'API PayDunya Disbursement pour effectuer le retrait
      final url = Uri.parse('$_apiUrl/api/v1/disburse/send');

      final payload = {
        'account_alias': phoneNumber,
        'account_number': phoneNumber,
        'amount': amount.toString(),
        'withdraw_mode': detectedOperator, // 'mtn', 'orange', 'moov'
        'callback_url': '', // URL de callback pour les notifications
        'metadata': {
          'user_id': userId,
          'account_name': accountName,
          'withdrawal_type': 'driver_earnings',
        },
      };

      final headers = {
        'Content-Type': 'application/json',
        'PAYDUNYA-MASTER-KEY': _masterKey!,
        'PAYDUNYA-PRIVATE-KEY': _privateKey!,
        'PAYDUNYA-TOKEN': _token!,
      };

      final response = await http
          .post(url, headers: headers, body: json.encode(payload))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['response_code'] == '00' || data['status'] == 'success') {
          final transactionId =
              data['response_text']?['transaction_id'] ??
              data['transaction_id'] ??
              'TXN_${DateTime.now().millisecondsSinceEpoch}';

          debugPrint(
            '✅ PayDunyaService: Retrait effectué avec succès - $transactionId',
          );

          return WithdrawalResult(
            success: true,
            transactionId: transactionId,
            amount: amount,
            operator: detectedOperator,
            message: 'Retrait effectué avec succès',
          );
        } else {
          final errorMessage =
              data['response_text']?['description'] ??
              data['description'] ??
              'Erreur lors du retrait';

          return WithdrawalResult(success: false, error: errorMessage);
        }
      } else {
        return WithdrawalResult(
          success: false,
          error: 'Erreur HTTP: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('❌ PayDunyaService: Erreur retrait - $e');
      return WithdrawalResult(
        success: false,
        error: 'Erreur lors du retrait: $e',
      );
    }
  }

  /// Détecte l'opérateur Mobile Money à partir du numéro de téléphone
  String _detectMobileMoneyOperator(String phoneNumber) {
    // Nettoyer le numéro (enlever les espaces, tirets, etc.)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-]'), '');

    // Préfixes pour chaque opérateur en Côte d'Ivoire
    // MTN: 05, 07, 01
    // Orange: 07, 05, 09
    // Moov: 01, 05, 07

    // Vérifier les préfixes MTN
    if (cleanNumber.startsWith('05') ||
        cleanNumber.startsWith('07') ||
        cleanNumber.startsWith('01')) {
      // Pour plus de précision, on pourrait vérifier la plage exacte
      // Pour l'instant, on retourne 'mtn' par défaut pour ces préfixes
      return 'mtn';
    }

    // Vérifier les préfixes Orange
    if (cleanNumber.startsWith('09')) {
      return 'orange';
    }

    // Par défaut, essayer MTN (le plus commun)
    return 'mtn';
  }

  @override
  void dispose() {
    _paymentController.close();
    super.dispose();
  }
}

// Modèles de données
enum PaymentStatus { none, pending, completed, cancelled, error, refunded }

class PaymentRequestResult {
  final bool success;
  final String? invoiceToken;
  final String? invoiceUrl;
  final String? qrCode;
  final String? error;
  final String orderId;

  PaymentRequestResult({
    required this.success,
    this.invoiceToken,
    this.invoiceUrl,
    this.qrCode,
    this.error,
    required this.orderId,
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
    this.invoiceToken,
    this.invoiceUrl,
    this.error,
    required this.orderId,
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
    this.error,
    required this.orderId,
  });
}

class PaymentParticipant {
  final String userId;
  final String name;
  final String email;
  final String phoneNumber;
  final String operator;
  final double amount;

  PaymentParticipant({
    required this.userId,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.operator,
    required this.amount,
  });
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

/// Résultat d'un retrait PayDunya
class WithdrawalResult {
  final bool success;
  final String? transactionId;
  final double? amount;
  final String? operator;
  final String? message;
  final String? error;

  WithdrawalResult({
    required this.success,
    this.transactionId,
    this.amount,
    this.operator,
    this.message,
    this.error,
  });
}
