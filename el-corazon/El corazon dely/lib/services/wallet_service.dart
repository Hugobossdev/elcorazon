import 'package:flutter/foundation.dart';

class Transaction {
  final String id;
  final String type; // 'credit', 'debit', 'cashback', 'refund'
  final double amount;
  final String description;
  final DateTime createdAt;
  final String? orderId;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.orderId,
  });
}

class VIPSubscription {
  final String id;
  final String planName;
  final double monthlyFee;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final List<String> benefits;

  VIPSubscription({
    required this.id,
    required this.planName,
    required this.monthlyFee,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.benefits,
  });
}

class WalletService extends ChangeNotifier {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  double _balance = 0.0;
  double _cashbackBalance = 0.0;
  List<Transaction> _transactions = [];
  VIPSubscription? _vipSubscription;
  bool _isInitialized = false;

  // Cashback settings
  final double _cashbackRate = 0.05; // 5% cashback
  final double _vipCashbackRate = 0.08; // 8% cashback for VIP

  double get balance => _balance;
  double get cashbackBalance => _cashbackBalance;
  List<Transaction> get transactions => List.unmodifiable(_transactions);
  VIPSubscription? get vipSubscription => _vipSubscription;
  bool get isVIP => _vipSubscription?.isActive ?? false;
  double get currentCashbackRate => isVIP ? _vipCashbackRate : _cashbackRate;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load wallet data from storage (simulated)
      await _loadWalletData();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing Wallet Service: $e');
    }
  }

  Future<void> _loadWalletData() async {
    // Simulate loading from local storage or API
    await Future.delayed(const Duration(milliseconds: 500));

    // Test data
    _balance = 15000.0; // 15,000 CFA
    _cashbackBalance = 2500.0; // 2,500 CFA cashback

    _transactions = [
      Transaction(
        id: '1',
        type: 'credit',
        amount: 20000,
        description: 'Rechargement Mobile Money',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Transaction(
        id: '2',
        type: 'debit',
        amount: 7500,
        description: 'Commande #12345 - Burger Menu',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        orderId: '12345',
      ),
      Transaction(
        id: '3',
        type: 'cashback',
        amount: 375,
        description: 'Cashback 5% - Commande #12345',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        orderId: '12345',
      ),
    ];
  }

  // Recharge wallet
  Future<bool> rechargeWallet(double amount, String paymentMethod) async {
    try {
      await Future.delayed(
          const Duration(seconds: 2)); // Simulate payment processing

      _balance += amount;

      Transaction transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'credit',
        amount: amount,
        description: 'Rechargement $paymentMethod',
        createdAt: DateTime.now(),
      );

      _transactions.insert(0, transaction);
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error recharging wallet: $e');
      return false;
    }
  }

  // Process payment from wallet
  Future<bool> processPayment(double amount, String orderId) async {
    if (_balance < amount) {
      return false; // Insufficient funds
    }

    try {
      _balance -= amount;

      Transaction transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'debit',
        amount: amount,
        description: 'Commande #$orderId',
        createdAt: DateTime.now(),
        orderId: orderId,
      );

      _transactions.insert(0, transaction);

      // Calculate and add cashback
      double cashbackAmount = amount * currentCashbackRate;
      await _addCashback(cashbackAmount, orderId);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error processing payment: $e');
      return false;
    }
  }

  Future<void> _addCashback(double amount, String orderId) async {
    _cashbackBalance += amount;

    Transaction cashbackTransaction = Transaction(
      id: '${DateTime.now().millisecondsSinceEpoch}_cb',
      type: 'cashback',
      amount: amount,
      description:
          'Cashback ${(currentCashbackRate * 100).toInt()}% - Commande #$orderId',
      createdAt: DateTime.now(),
      orderId: orderId,
    );

    _transactions.insert(0, cashbackTransaction);
  }

  // Convert cashback to main balance
  Future<void> convertCashback() async {
    if (_cashbackBalance <= 0) return;

    _balance += _cashbackBalance;

    Transaction transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'credit',
      amount: _cashbackBalance,
      description: 'Conversion Cashback vers Solde Principal',
      createdAt: DateTime.now(),
    );

    _transactions.insert(0, transaction);
    _cashbackBalance = 0.0;

    notifyListeners();
  }

  // VIP Subscription management
  Future<bool> subscribeToVIP(String planName) async {
    try {
      Map<String, dynamic> plans = getVIPPlans();
      var selectedPlan = plans[planName];

      if (selectedPlan == null) return false;

      double monthlyFee = selectedPlan['price'];

      // Check if user has enough balance
      if (_balance < monthlyFee) return false;

      // Process payment
      _balance -= monthlyFee;

      // Create VIP subscription
      _vipSubscription = VIPSubscription(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        planName: planName,
        monthlyFee: monthlyFee,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        isActive: true,
        benefits: List<String>.from(selectedPlan['benefits']),
      );

      // Add transaction
      Transaction transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'debit',
        amount: monthlyFee,
        description: 'Abonnement VIP - $planName',
        createdAt: DateTime.now(),
      );

      _transactions.insert(0, transaction);
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error subscribing to VIP: $e');
      return false;
    }
  }

  Map<String, dynamic> getVIPPlans() {
    return {
      'VIP Standard': {
        'price': 5000.0,
        'benefits': [
          'Livraison gratuite',
          'Cashback 8%',
          'Accès prioritaire aux promos',
          'Support client premium',
        ],
      },
      'VIP Premium': {
        'price': 8000.0,
        'benefits': [
          'Livraison gratuite',
          'Cashback 10%',
          'Accès prioritaire aux promos',
          'Support client premium',
          'Menu exclusif VIP',
          '1 repas gratuit par mois',
        ],
      },
    };
  }

  Future<bool> cancelVIPSubscription() async {
    final subscription = _vipSubscription;
    if (subscription == null) return false;

    _vipSubscription = subscription.copyWith(isActive: false);
    notifyListeners();
    return true;
  }

  // Get payment methods
  List<Map<String, dynamic>> getPaymentMethods() {
    return [
      {
        'id': 'mobile_money',
        'name': 'Mobile Money',
        'icon': 'phone',
        'description': 'Orange Money, MTN Money, Moov Money',
        'minAmount': 1000.0,
        'maxAmount': 500000.0,
      },
      {
        'id': 'bank_card',
        'name': 'Carte Bancaire',
        'icon': 'credit_card',
        'description': 'Visa, Mastercard',
        'minAmount': 5000.0,
        'maxAmount': 1000000.0,
      },
      {
        'id': 'bank_transfer',
        'name': 'Virement Bancaire',
        'icon': 'account_balance',
        'description': 'Virement SEPA, Western Union',
        'minAmount': 10000.0,
        'maxAmount': 2000000.0,
      },
    ];
  }

  // Analytics
  Map<String, dynamic> getWalletAnalytics() {
    double totalSpent = _transactions
        .where((t) => t.type == 'debit')
        .fold(0.0, (sum, t) => sum + t.amount);

    double totalCashbackEarned = _transactions
        .where((t) => t.type == 'cashback')
        .fold(0.0, (sum, t) => sum + t.amount);

    double totalRecharged = _transactions
        .where((t) => t.type == 'credit')
        .fold(0.0, (sum, t) => sum + t.amount);

    return {
      'currentBalance': _balance,
      'cashbackBalance': _cashbackBalance,
      'totalSpent': totalSpent,
      'totalCashbackEarned': totalCashbackEarned,
      'totalRecharged': totalRecharged,
      'isVIP': isVIP,
      'vipSavings': isVIP ? totalSpent * 0.03 : 0.0, // Estimated VIP savings
      'transactionCount': _transactions.length,
    };
  }

  // Quick actions
  List<Map<String, dynamic>> getQuickRechargeAmounts() {
    return [
      {'label': '5 000', 'amount': 5000.0},
      {'label': '10 000', 'amount': 10000.0},
      {'label': '20 000', 'amount': 20000.0},
      {'label': '50 000', 'amount': 50000.0},
      {'label': '100 000', 'amount': 100000.0},
    ];
  }

  Future<void> refundOrder(String orderId, double amount) async {
    _balance += amount;

    Transaction transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'refund',
      amount: amount,
      description: 'Remboursement Commande #$orderId',
      createdAt: DateTime.now(),
      orderId: orderId,
    );

    _transactions.insert(0, transaction);
    notifyListeners();
  }
}

// Extension for VIPSubscription copying
extension VIPSubscriptionCopyWith on VIPSubscription {
  VIPSubscription copyWith({
    String? id,
    String? planName,
    double? monthlyFee,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    List<String>? benefits,
  }) {
    return VIPSubscription(
      id: id ?? this.id,
      planName: planName ?? this.planName,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      benefits: benefits ?? this.benefits,
    );
  }
}
