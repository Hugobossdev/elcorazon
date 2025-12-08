import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/wallet_service.dart';
import 'package:elcora_fast/widgets/custom_button.dart';
import 'package:elcora_fast/utils/price_formatter.dart';

/// Écran de gestion du portefeuille numérique
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portefeuille'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showTransactionHistory(context),
          ),
        ],
      ),
      body: Consumer<WalletService>(
        builder: (context, walletService, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceCard(context, walletService),
                const SizedBox(height: 24),
                _buildQuickActions(context, walletService),
                const SizedBox(height: 24),
                _buildVIPSection(context, walletService),
                const SizedBox(height: 24),
                _buildRecentTransactions(context, walletService),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, WalletService walletService) {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Solde Principal',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                  ),
                ),
                Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              PriceFormatter.format(walletService.balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cashback',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        PriceFormatter.format(walletService.cashbackBalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (walletService.cashbackBalance > 0)
                  CustomButton(
                    text: 'Convertir',
                    onPressed: () => _convertCashback(walletService),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WalletService walletService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions Rapides',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    'Recharger',
                    Icons.add_circle_outline,
                    Colors.green,
                    () => _showRechargeDialog(context, walletService),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    context,
                    'Retirer',
                    Icons.remove_circle_outline,
                    Colors.orange,
                    () => _showWithdrawDialog(context, walletService),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVIPSection(BuildContext context, WalletService walletService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Abonnement VIP',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (walletService.vipSubscription?.isActive == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'VIP',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (walletService.vipSubscription?.isActive == true) ...[
              Text(
                'Plan: ${walletService.vipSubscription!.planName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Expire le: ${_formatDate(walletService.vipSubscription!.endDate)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Annuler l\'abonnement',
                onPressed: () => _cancelVIPSubscription(walletService),
              ),
            ] else ...[
              Text(
                'Profitez d\'avantages exclusifs avec un abonnement VIP',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Voir les plans VIP',
                onPressed: () => _showVIPPlans(context, walletService),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(
      BuildContext context, WalletService walletService,) {
    final recentTransactions = walletService.transactions.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transactions Récentes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => _showTransactionHistory(context),
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (recentTransactions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune transaction',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...recentTransactions
                  .map((transaction) => _buildTransactionItem(transaction)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(dynamic transaction) {
    final isCredit =
        transaction.type == 'credit' || transaction.type == 'cashback';
    final color = isCredit ? Colors.green : Colors.red;
    final icon = isCredit ? Icons.add_circle : Icons.remove_circle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatDate(transaction.createdAt),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${PriceFormatter.format(transaction.amount)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showRechargeDialog(BuildContext context, WalletService walletService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recharger le portefeuille'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant (FCFA)',
                  border: OutlineInputBorder(),
                  prefixText: 'FCFA ',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Montants suggérés:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [5000, 10000, 25000, 50000].map((amount) {
                  return ActionChip(
                    label: Text('${amount.toString()} FCFA'),
                    onPressed: () {
                      _amountController.text = amount.toString();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          CustomButton(
            text: 'Recharger',
            onPressed: () => _rechargeWallet(walletService),
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context, WalletService walletService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer des fonds'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant à retirer (FCFA)',
                  border: OutlineInputBorder(),
                  prefixText: 'FCFA ',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Solde disponible: ${PriceFormatter.format(walletService.balance)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          CustomButton(
            text: 'Retirer',
            onPressed: () => _withdrawFromWallet(walletService),
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  void _showVIPPlans(BuildContext context, WalletService walletService) {
    final plans = walletService.getVIPPlans();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Plans VIP'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: plans.entries.map((entry) {
              final planName = entry.key;
              final planData = entry.value;
              final price = planData['price'] as double;
              final benefits = planData['benefits'] as List<String>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            planName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            PriceFormatter.format(price),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Avantages:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      ...benefits.map((benefit) => Padding(
                            padding: const EdgeInsets.only(left: 8, top: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.check,
                                    size: 16, color: Colors.green,),
                                const SizedBox(width: 8),
                                Expanded(child: Text(benefit)),
                              ],
                            ),
                          ),),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: CustomButton(
                          text: 'S\'abonner',
                          onPressed: () =>
                              _subscribeToVIP(walletService, planName),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showTransactionHistory(BuildContext context) {
    // Navigate to transaction history screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TransactionHistoryScreen(),
      ),
    );
  }

  Future<void> _rechargeWallet(WalletService walletService) async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un montant valide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use a default payment method for now (can be enhanced later with payment method selection)
      final success =
          await walletService.rechargeWallet(amount, 'Mobile Money');
      Navigator.of(context).pop();
      _amountController.clear();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Portefeuille rechargé de ${PriceFormatter.format(amount)}',),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du rechargement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _withdrawFromWallet(WalletService walletService) async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un montant valide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amount > walletService.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solde insuffisant'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await walletService.withdrawBalance(amount);
      Navigator.of(context).pop();
      _amountController.clear();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Retrait de ${PriceFormatter.format(amount)} effectué'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du retrait'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _convertCashback(WalletService walletService) async {
    try {
      await walletService.convertCashback();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cashback converti avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _subscribeToVIP(
      WalletService walletService, String planName,) async {
    try {
      final success = await walletService.subscribeToVIP(planName);
      Navigator.of(context).pop();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Abonnement VIP $planName activé'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solde insuffisant pour l\'abonnement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelVIPSubscription(WalletService walletService) async {
    try {
      await walletService.cancelVIPSubscription();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abonnement VIP annulé'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Écran d'historique des transactions
class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des transactions'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Consumer<WalletService>(
        builder: (context, walletService, child) {
          final transactions = walletService.transactions;

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune transaction',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              final isCredit = transaction.type == 'credit' ||
                  transaction.type == 'cashback';
              final color = isCredit ? Colors.green : Colors.red;
              final icon = isCredit ? Icons.add_circle : Icons.remove_circle;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color),
                  ),
                  title: Text(transaction.description),
                  subtitle: Text(_formatDateTime(transaction.createdAt)),
                  trailing: Text(
                    '${isCredit ? '+' : '-'}${PriceFormatter.format(transaction.amount)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
