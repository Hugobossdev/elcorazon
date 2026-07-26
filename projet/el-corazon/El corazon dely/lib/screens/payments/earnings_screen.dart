import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_service.dart';
import '../../services/error_handler_service.dart';
import '../../models/order.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/custom_button.dart';
import '../delivery/driver_profile_screen.dart';
import '../delivery/settings_screen.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  bool _isLoading = true;
  String _selectedPeriod = 'today';

  // Sample data - in real app, fetch from backend
  Map<String, dynamic> _earningsData = {};
  List<Map<String, dynamic>> _recentEarnings = [];

  @override
  void initState() {
    super.initState();
    _loadEarningsData();
  }

  Future<void> _loadEarningsData() async {
    if (!mounted) return;

    try {
      final appService = Provider.of<AppService>(context, listen: false);

      // Load available orders to get latest data (with timeout)
      try {
        await appService
            .loadAvailableOrders()
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        // Continuer même si le chargement échoue, utiliser les données en cache
        debugPrint('⚠️ Could not refresh orders, using cached data: $e');
      }

      final deliveries = appService.assignedDeliveries
          .where((order) => order.status == OrderStatus.delivered)
          .toList();

      // Calculate earnings by period
      final todayDeliveries =
          deliveries.where((d) => _isToday(d.orderTime)).toList();
      final weekDeliveries =
          deliveries.where((d) => _isThisWeek(d.orderTime)).toList();
      final monthDeliveries =
          deliveries.where((d) => _isThisMonth(d.orderTime)).toList();

      // Calculate earnings (10% commission per delivery, plus estimated tips and bonuses)
      const commissionRate = 0.10;

      Map<String, num> calculateEarnings(List<Order> orders) {
        if (orders.isEmpty) {
          return {
            'total': 0.0,
            'deliveries': 0,
            'bonus': 0.0,
            'tips': 0.0,
          };
        }

        final baseEarnings = orders.fold<double>(
            0.0, (sum, order) => sum + (order.total * commissionRate));
        final deliveriesCount = orders.length;
        final estimatedTips = baseEarnings * 0.1; // 10% of earnings as tips
        final estimatedBonus = deliveriesCount > 10
            ? baseEarnings * 0.05
            : 0.0; // 5% bonus if > 10 deliveries

        return {
          'total': baseEarnings + estimatedTips + estimatedBonus,
          'deliveries': deliveriesCount,
          'bonus': estimatedBonus,
          'tips': estimatedTips,
        };
      }

      if (mounted) {
        setState(() {
          _earningsData = {
            'today': calculateEarnings(todayDeliveries),
            'week': calculateEarnings(weekDeliveries),
            'month': calculateEarnings(monthDeliveries),
          };

          // Build recent earnings from recent deliveries (sorted by date)
          final sortedDeliveries = List<Order>.from(deliveries)
            ..sort((a, b) => b.orderTime.compareTo(a.orderTime));

          _recentEarnings = sortedDeliveries
              .take(10)
              .map((order) => {
                    'id': order.id,
                    'orderId': order.id.substring(0, 8).toUpperCase(),
                    'amount': order.total * commissionRate,
                    'tip': (order.total * commissionRate * 0.1),
                    'bonus': 0.0,
                    'timestamp': order.orderTime,
                    'status': 'completed',
                  })
              .toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errorHandler =
            Provider.of<ErrorHandlerService>(context, listen: false);
        errorHandler.logError('Erreur chargement gains', details: e);
        errorHandler.showErrorSnackBar(
            context, 'Erreur de chargement des gains: $e');
      }
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day &&
        date.month == now.month &&
        date.year == now.year;
  }

  bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        date.isBefore(weekEnd.add(const Duration(days: 1)));
  }

  bool _isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.month == now.month && date.year == now.year;
  }

  Future<void> _requestWithdrawal() async {
    try {
      final appService = Provider.of<AppService>(context, listen: false);
      final totalEarnings = _getCurrentEarnings()['total'] ?? 0.0;

      if (totalEarnings <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun solde disponible pour le retrait'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // In real app, integrate with PayDunya for withdrawal
      await appService.requestWithdrawal(totalEarnings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de retrait soumise avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorHandler =
            Provider.of<ErrorHandlerService>(context, listen: false);
        errorHandler.logError('Erreur retrait', details: e);
        errorHandler.showErrorSnackBar(context, 'Erreur de retrait: $e');
      }
    }
  }

  Map<String, dynamic> _getCurrentEarnings() {
    return _earningsData[_selectedPeriod] ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes gains'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _requestWithdrawal,
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Demander un retrait',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverProfileScreen(),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Mon profil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Paramètres'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Chargement des gains...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 24),
                  _buildEarningsSummary(),
                  const SizedBox(height: 24),
                  _buildEarningsBreakdown(),
                  const SizedBox(height: 24),
                  _buildRecentEarnings(),
                  const SizedBox(height: 24),
                  _buildWithdrawalSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Période',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPeriodButton('Aujourd\'hui', 'today'),
                const SizedBox(width: 8),
                _buildPeriodButton('Cette semaine', 'week'),
                const SizedBox(width: 8),
                _buildPeriodButton('Ce mois', 'month'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsSummary() {
    final earnings = _getCurrentEarnings();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Column(
          children: [
            Text(
              'Gains totaux',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${earnings['total']?.toStringAsFixed(0) ?? '0'} FCFA',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                    'Livraisons', '${earnings['deliveries'] ?? 0}'),
                _buildSummaryItem('Bonus',
                    '${earnings['bonus']?.toStringAsFixed(0) ?? '0'} FCFA'),
                _buildSummaryItem('Pourboires',
                    '${earnings['tips']?.toStringAsFixed(0) ?? '0'} FCFA'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsBreakdown() {
    final earnings = _getCurrentEarnings();
    final deliveriesCount = earnings['deliveries'] ?? 0;
    final baseAmount = earnings['total'] ?? 0.0;
    final deliveriesEarning =
        baseAmount - (earnings['tips'] ?? 0.0) - (earnings['bonus'] ?? 0.0);
    final avgPerDelivery =
        deliveriesCount > 0 ? deliveriesEarning / deliveriesCount : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détail des gains',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildBreakdownItem(
              'Livraisons',
              '$deliveriesCount livraison${deliveriesCount > 1 ? 's' : ''}',
              '${deliveriesEarning.toStringAsFixed(0)} FCFA',
              Icons.delivery_dining,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildBreakdownItem(
              'Bonus',
              'Prime de performance',
              '${earnings['bonus']?.toStringAsFixed(0) ?? '0'} FCFA',
              Icons.star,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildBreakdownItem(
              'Pourboires',
              'Gratifications clients',
              '${earnings['tips']?.toStringAsFixed(0) ?? '0'} FCFA',
              Icons.volunteer_activism,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildBreakdownItem(
              'Gain moyen',
              'par livraison',
              '${avgPerDelivery.toStringAsFixed(0)} FCFA',
              Icons.payments_outlined,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(String title, String subtitle, String amount,
      IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentEarnings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gains récents',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ..._recentEarnings.map((earning) => _buildEarningItem(earning)),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningItem(Map<String, dynamic> earning) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande ${earning['orderId']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatTimestamp(earning['timestamp']),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(earning['amount'] + earning['tip'] + earning['bonus']).toStringAsFixed(0)} FCFA',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (earning['tip'] > 0)
                Text(
                  '+${earning['tip'].toStringAsFixed(0)} FCFA pourboire',
                  style: TextStyle(
                    color: Colors.green[600],
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalSection() {
    final totalEarnings = _getCurrentEarnings()['total'] ?? 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Retrait',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                        'Solde disponible',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${totalEarnings.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                CustomButton(
                  text: 'Retirer',
                  onPressed: totalEarnings > 0 ? _requestWithdrawal : null,
                  icon: Icons.account_balance_wallet,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Les retraits sont traités dans les 24h via PayDunya',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes}min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return 'Il y a ${difference.inDays}j';
    }
  }
}
