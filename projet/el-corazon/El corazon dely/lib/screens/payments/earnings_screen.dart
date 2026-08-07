import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/services/error_handler_service.dart';
import 'package:elcora_dely/presentation/libelles_course.dart';
import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcora_dely/widgets/loading_widget.dart';
import 'package:elcora_dely/widgets/custom_button.dart';
import 'package:elcora_dely/screens/delivery/driver_profile_screen.dart';
import 'package:elcora_dely/screens/delivery/settings_screen.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  bool _isLoading = true;
  String _selectedPeriod = 'today';

  // Sample data - in real app, fetch from backend
  /// Gains par période — `calculateEarnings` les produit déjà en `num`, seul
  /// le champ qui les retenait était typé `dynamic`.
  Map<String, Map<String, num>> _earningsData = {};
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
        Journal.trace('⚠️ Could not refresh orders, using cached data: $e');
      }

      final deliveries = appService.assignedDeliveries
          .where((course) => course.etape == EtapeCourse.livree)
          .toList();

      final todayDeliveries =
          deliveries.where((c) => _isToday(c.passeeLe)).toList();
      final weekDeliveries =
          deliveries.where((c) => _isThisWeek(c.passeeLe)).toList();
      final monthDeliveries =
          deliveries.where((c) => _isThisMonth(c.passeeLe)).toList();

      /// Somme des rémunérations que le serveur a arrêtées pour ces courses.
      ///
      /// Cet écran appliquait auparavant une commission de 10 % au total de la
      /// commande, majorée de pourboires et de primes estimés à 10 % et 5 %.
      /// Aucun de ces trois taux n'existe au contrat, et le total en question
      /// vaut **zéro** sur toute course livrée : le détail d'une commande
      /// n'est pas relu une fois la course terminée. L'écran affichait donc
      /// invariablement 0 FCFA, quelle que soit la période.
      ///
      /// `courier_fee` est la rémunération réelle, calculée et rendue par le
      /// serveur sur chaque affectation. Le taux appartient au serveur.
      Map<String, num> calculerGains(List<Course> courses) {
        final total = courses.fold<int>(
          0,
          (somme, course) => somme + (course.remuneration?.amountMinor ?? 0),
        );
        return {'total': total, 'deliveries': courses.length};
      }

      if (mounted) {
        setState(() {
          _earningsData = {
            'today': calculerGains(todayDeliveries),
            'week': calculerGains(weekDeliveries),
            'month': calculerGains(monthDeliveries),
          };

          final triees = List<Course>.from(deliveries)
            ..sort((a, b) => b.passeeLe.compareTo(a.passeeLe));

          _recentEarnings = triees
              .take(10)
              .map((course) => {
                    'id': course.orderId,
                    'orderId': course.orderId.substring(0, 8).toUpperCase(),
                    'amount': course.remuneration?.amountMinor ?? 0,
                    'timestamp': course.passeeLe,
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
      await appService.requestWithdrawal(totalEarnings.toDouble());

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

  Map<String, num> _getCurrentEarnings() {
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
            const Text(
              'Gains totaux',
              style: TextStyle(
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
    final deliveriesEarning = earnings['total'] ?? 0;
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
    // Typé une fois ici : la carte est dynamique, et le compilateur ne dirait
    // rien d'une clé disparue.
    final montant = earning['amount']! as num;

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
                '${montant.toStringAsFixed(0)} FCFA',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
