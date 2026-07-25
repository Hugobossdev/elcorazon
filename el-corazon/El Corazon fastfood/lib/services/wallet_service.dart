import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/services/database_service.dart';

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
  final int mealsUsedThisPeriod;

  VIPSubscription({
    required this.id,
    required this.planName,
    required this.monthlyFee,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.benefits,
    this.mealsUsedThisPeriod = 0,
  });
}

class WalletService extends ChangeNotifier {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final DatabaseService _databaseService = DatabaseService();

  double _balance = 0.0;
  double _cashbackBalance = 0.0;
  List<Transaction> _transactions = [];
  VIPSubscription? _vipSubscription;
  bool _isInitialized = false;
  String? _currentUserId;

  // Cashback settings
  final double _cashbackRate = 0.05; // 5% cashback
  final double _vipCashbackRate = 0.08; // 8% cashback for VIP

  double get balance => _balance;
  double get cashbackBalance => _cashbackBalance;
  List<Transaction> get transactions => List.unmodifiable(_transactions);
  VIPSubscription? get vipSubscription => _vipSubscription;
  bool get isVIP => _vipSubscription?.isActive ?? false;
  double get currentCashbackRate => isVIP ? _vipCashbackRate : _cashbackRate;

  Future<void> initialize({String? userId}) async {
    if (_isInitialized && _currentUserId == userId) return;

    try {
      _currentUserId = userId ?? _databaseService.currentUser?.id;

      if (_currentUserId != null) {
        // Récupérer l'ID utilisateur dans la table users
        final userData = await _databaseService.ensureUserProfileExists(
          userId: _currentUserId!,
        );
        if (userData != null) {
          _currentUserId = userData['id']?.toString();
        }
      }

      // Load wallet data from Supabase
      await _loadWalletData();
      await _loadVIPSubscription();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing Wallet Service: $e');
    }
  }

  Future<void> _loadWalletData() async {
    if (_currentUserId == null) return;

    try {
      // Charger le solde depuis la table users (si disponible)
      final userData = await _databaseService.getUserProfile(_currentUserId!);
      if (userData != null) {
        // Le solde pourrait être stocké dans une table wallet séparée
        // Pour l'instant, on garde la logique locale mais on peut utiliser wallet_balance si disponible
        _balance = (userData['wallet_balance'] as num?)?.toDouble() ?? 0.0;
        _cashbackBalance =
            (userData['cashback_balance'] as num?)?.toDouble() ?? 0.0;
      }

      // Charger les transactions depuis Supabase
      await _loadTransactions();
    } catch (e) {
      debugPrint('Error loading wallet data: $e');
    }
  }

  /// Charger les transactions depuis Supabase
  Future<void> _loadTransactions() async {
    if (_currentUserId == null) return;

    try {
      final response = await _supabase
          .from('wallet_transactions')
          .select()
          .eq('user_id', _currentUserId!)
          .order('created_at', ascending: false)
          .limit(100);

      _transactions = (response as List<dynamic>).map((data) {
        final map = Map<String, dynamic>.from(data as Map);
        return Transaction(
          id: map['id'] as String,
          type: map['transaction_type'] as String,
          amount: (map['amount'] as num).toDouble(),
          description: map['description'] as String? ?? '',
          createdAt: DateTime.parse(map['created_at'] as String),
          orderId: map['order_id'] as String?,
        );
      }).toList();

      debugPrint(
          '✅ Loaded ${_transactions.length} wallet transactions from Supabase',);
    } catch (e) {
      // Si la table n'existe pas, on continue avec une liste vide
      if (e.toString().contains('PGRST205') ||
          e.toString().contains('does not exist')) {
        debugPrint(
            '⚠️ wallet_transactions table does not exist, using empty list',);
        _transactions = [];
      } else {
        debugPrint('❌ Error loading wallet transactions: $e');
        _transactions = [];
      }
    }
  }

  /// Sauvegarder une transaction dans Supabase
  Future<void> _saveTransaction(Transaction transaction) async {
    if (_currentUserId == null) return;

    try {
      await _supabase.from('wallet_transactions').insert({
        'id': transaction.id,
        'user_id': _currentUserId!,
        'transaction_type': transaction.type,
        'amount': transaction.amount,
        'description': transaction.description,
        'order_id': transaction.orderId,
        'created_at': transaction.createdAt.toIso8601String(),
      });

      // Mettre à jour le solde dans la table users
      await _updateWalletBalance();
    } catch (e) {
      // Si la table n'existe pas, on continue sans erreur
      if (e.toString().contains('PGRST205') ||
          e.toString().contains('does not exist')) {
        debugPrint(
            '⚠️ wallet_transactions table does not exist, transaction not saved',);
      } else {
        debugPrint('❌ Error saving wallet transaction: $e');
      }
    }
  }

  /// Mettre à jour le solde dans la table users
  Future<void> _updateWalletBalance() async {
    if (_currentUserId == null) return;

    try {
      await _supabase.from('users').update({
        'wallet_balance': _balance,
        'cashback_balance': _cashbackBalance,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentUserId!);
    } catch (e) {
      debugPrint('⚠️ Error updating wallet balance: $e');
    }
  }

  /// Charger l'abonnement VIP depuis Supabase
  Future<void> _loadVIPSubscription() async {
    if (_currentUserId == null) return;

    try {
      // Chercher un abonnement VIP actif
      final response = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('subscription_type', 'vip')
          .eq('status', 'active')
          .maybeSingle();

      if (response != null) {
        final endDate =
            DateTime.parse(response['current_period_end'] as String);
        final isActive =
            response['status'] == 'active' && endDate.isAfter(DateTime.now());

        // Récupérer les bénéfices du plan
        final planName = response['plan_name'] as String? ?? 'VIP Standard';
        final plans = getVIPPlans();
        final plan = plans[planName] as Map<String, dynamic>?;

        _vipSubscription = VIPSubscription(
          id: response['id'] as String,
          planName: planName,
          monthlyFee: (response['monthly_price'] as num).toDouble(),
          startDate: DateTime.parse(response['current_period_start'] as String),
          endDate: endDate,
          isActive: isActive,
        benefits: plan != null
            ? List<String>.from(plan['benefits'] as List)
            : ['Livraison gratuite', 'Cashback 8%'],
          mealsUsedThisPeriod: response['meals_used_this_period'] as int? ?? 0,
        );
      } else {
        _vipSubscription = null;
      }
    } catch (e) {
      debugPrint('Error loading VIP subscription: $e');
      _vipSubscription = null;
    }
  }

  // Recharge wallet
  Future<bool> rechargeWallet(double amount, String paymentMethod) async {
    try {
      await Future.delayed(
        const Duration(seconds: 2),
      ); // Simulate payment processing

      _balance += amount;

      final Transaction transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'credit',
        amount: amount,
        description: 'Rechargement $paymentMethod',
        createdAt: DateTime.now(),
      );

      _transactions.insert(0, transaction);

      // Sauvegarder la transaction dans Supabase
      await _saveTransaction(transaction);

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

      final Transaction transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'debit',
        amount: amount,
        description: 'Commande #$orderId',
        createdAt: DateTime.now(),
        orderId: orderId,
      );

      _transactions.insert(0, transaction);

      // Sauvegarder la transaction dans Supabase
      await _saveTransaction(transaction);

      // Calculate and add cashback
      final double cashbackAmount = amount * currentCashbackRate;
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

    final Transaction cashbackTransaction = Transaction(
      id: '${DateTime.now().millisecondsSinceEpoch}_cb',
      type: 'cashback',
      amount: amount,
      description:
          'Cashback ${(currentCashbackRate * 100).toInt()}% - Commande #$orderId',
      createdAt: DateTime.now(),
      orderId: orderId,
    );

    _transactions.insert(0, cashbackTransaction);

    // Sauvegarder la transaction cashback dans Supabase
    await _saveTransaction(cashbackTransaction);
  }

  // Convert cashback to main balance
  Future<void> convertCashback() async {
    if (_cashbackBalance <= 0) return;

    final cashbackAmount = _cashbackBalance;
    _balance += cashbackAmount;

    final Transaction transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'credit',
      amount: cashbackAmount,
      description: 'Conversion Cashback vers Solde Principal',
      createdAt: DateTime.now(),
    );

    _transactions.insert(0, transaction);
    _cashbackBalance = 0.0;

    // Sauvegarder la transaction dans Supabase
    await _saveTransaction(transaction);

    notifyListeners();
  }

  // VIP Subscription management
  Future<bool> subscribeToVIP(String planName) async {
    if (_currentUserId == null) {
      debugPrint('WalletService: User ID not set');
      return false;
    }

    try {
      final Map<String, dynamic> plans = getVIPPlans();
      final selectedPlan = plans[planName];

      if (selectedPlan == null) return false;

      final selectedPlanMap = selectedPlan as Map<String, dynamic>;
      final double monthlyFee = selectedPlanMap['price'] as double;

      // Check if user has enough balance
      if (_balance < monthlyFee) return false;

      // Récupérer l'ID utilisateur dans la table users
      final userData = await _databaseService.ensureUserProfileExists(
        userId: _currentUserId!,
      );
      if (userData == null) {
        debugPrint('WalletService: User profile not found');
        return false;
      }

      final userId = userData['id']?.toString() ?? _currentUserId!;

      // Process payment
      _balance -= monthlyFee;

      // Créer l'abonnement VIP dans Supabase
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 30));

      final subscriptionData = {
        'user_id': userId,
        'subscription_type': 'vip',
        'plan_name': planName,
        'meals_per_week': 0, // VIP n'a pas de repas par semaine
        'monthly_price': monthlyFee,
        'price_per_meal': 0.0,
        'current_period_start': now.toIso8601String(),
        'current_period_end': endDate.toIso8601String(),
        'status': 'active',
        'meals_used_this_period': 0,
        'auto_renew': true,
      };

      // Vérifier si un abonnement VIP existe déjà
      final existing = await _supabase
          .from('subscriptions')
          .select('id')
          .eq('user_id', userId)
          .eq('subscription_type', 'vip')
          .maybeSingle();

      final result = existing != null
          ? await _supabase
              .from('subscriptions')
              .update(subscriptionData)
              .eq('id', existing['id'])
              .select()
              .single()
          : await _supabase
              .from('subscriptions')
              .insert(subscriptionData)
              .select()
              .single();

      // Créer l'abonnement VIP local
      _vipSubscription = VIPSubscription(
        id: result['id'] as String,
        planName: planName,
        monthlyFee: monthlyFee,
        startDate: now,
        endDate: endDate,
        isActive: true,
        benefits: List<String>.from(selectedPlan['benefits'] as List),
      );

      // Add transaction
      final Transaction transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'debit',
        amount: monthlyFee,
        description: 'Abonnement VIP - $planName',
        createdAt: DateTime.now(),
      );

      _transactions.insert(0, transaction);

      // Sauvegarder la transaction dans Supabase
      await _saveTransaction(transaction);

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
    if (_vipSubscription == null || _currentUserId == null) return false;

    try {
      // Récupérer l'ID utilisateur dans la table users
      final userData = await _databaseService.ensureUserProfileExists(
        userId: _currentUserId!,
      );
      if (userData == null) {
        debugPrint('WalletService: User profile not found');
        return false;
      }

      final userId = userData['id']?.toString() ?? _currentUserId!;

      // Annuler l'abonnement VIP dans Supabase
      await _supabase
          .from('subscriptions')
          .update({
            'status': 'cancelled',
            'auto_renew': false,
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _vipSubscription!.id)
          .eq('user_id', userId);

      // Mettre à jour l'abonnement local
      _vipSubscription = _vipSubscription!.copyWith(isActive: false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error cancelling VIP subscription: $e');
      return false;
    }
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

  // Check if user is eligible for free meal (VIP Premium only)
  bool get isEligibleForFreeMeal {
    if (_vipSubscription == null || !_vipSubscription!.isActive) return false;
    // Seulement VIP Premium a le repas gratuit
    if (_vipSubscription!.planName != 'VIP Premium') return false;

    // 1 repas par mois (période)
    return _vipSubscription!.mealsUsedThisPeriod < 1;
  }

  // Marquer le repas gratuit comme utilisé
  Future<bool> useFreeMeal() async {
    if (!isEligibleForFreeMeal || _currentUserId == null) return false;

    try {
      await _supabase.from('subscriptions').update({
        'meals_used_this_period': _vipSubscription!.mealsUsedThisPeriod + 1,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _vipSubscription!.id);

      // Mettre à jour l'état local
      _vipSubscription = _vipSubscription!.copyWith(
        mealsUsedThisPeriod: _vipSubscription!.mealsUsedThisPeriod + 1,
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error using free meal: $e');
      return false;
    }
  }

  // Analytics
  Map<String, dynamic> getWalletAnalytics() {
    final double totalSpent = _transactions
        .where((t) => t.type == 'debit')
        .fold(0.0, (sum, t) => sum + t.amount);

    final double totalCashbackEarned = _transactions
        .where((t) => t.type == 'cashback')
        .fold(0.0, (sum, t) => sum + t.amount);

    final double totalRecharged = _transactions
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

    final Transaction transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'refund',
      amount: amount,
      description: 'Remboursement Commande #$orderId',
      createdAt: DateTime.now(),
      orderId: orderId,
    );

    _transactions.insert(0, transaction);

    // Sauvegarder la transaction dans Supabase
    await _saveTransaction(transaction);

    notifyListeners();
  }

  // Withdraw balance from wallet
  Future<bool> withdrawBalance(double amount) async {
    if (_balance < amount) {
      return false; // Insufficient funds
    }

    try {
      _balance -= amount;

      final Transaction transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'debit',
        amount: amount,
        description: 'Retrait de fonds',
        createdAt: DateTime.now(),
      );

      _transactions.insert(0, transaction);

      // Sauvegarder la transaction dans Supabase
      await _saveTransaction(transaction);

      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error withdrawing balance: $e');
      return false;
    }
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
    int? mealsUsedThisPeriod,
  }) {
    return VIPSubscription(
      id: id ?? this.id,
      planName: planName ?? this.planName,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      benefits: benefits ?? this.benefits,
      mealsUsedThisPeriod: mealsUsedThisPeriod ?? this.mealsUsedThisPeriod,
    );
  }
}
