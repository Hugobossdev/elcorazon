import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/statut_commande.dart'; // Import StatutCommande
import 'package:admin/services/assignment_service.dart';
import 'package:admin/services/driver_management_service.dart';
import 'package:admin/services/order_management_service.dart'; // Import Service
import 'package:admin/widgets/custom_bar_chart.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

class DriverDetailedStatsScreen extends StatefulWidget {
  final eccore.CourierProfile? driver;

  const DriverDetailedStatsScreen({required this.driver, super.key});

  @override
  State<DriverDetailedStatsScreen> createState() => _DriverDetailedStatsScreenState();
}

class _DriverDetailedStatsScreenState extends State<DriverDetailedStatsScreen> {
  bool _isLoading = false;
  Map<String, dynamic> _detailedStats = {};

  /// Les commandes que ce livreur a portées.
  ///
  /// Le graphique hebdomadaire les cherchait sur `Order.livreurAffecte`, que le
  /// serveur ne rend pas : la condition était toujours fausse, et les sept
  /// barres restaient à zéro quel que soit le livreur. Le rattachement se lit
  /// sur les courses (`/delivery/manage/assignments/`).
  Set<String> _commandesPortees = const {};

  @override
  void initState() {
    super.initState();
    if (widget.driver != null) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final service = context.read<DriverManagementService>();
      final courses =
          await context.read<AssignmentService>().historyOf(widget.driver!.id);
      final stats = await service.getDriverDetailedStats(widget.driver!.id);

      if (!mounted) return;
      setState(() {
        _detailedStats = stats;
        _commandesPortees = {for (final course in courses) course.orderId};
      });
    } catch (e) {
      Journal.trace('Erreur chargement détails: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.driver == null) {
      return const Center(
        child: Text(
          'Sélectionnez un livreur pour voir ses statistiques détaillées.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.driver!.fullName),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<OrderManagementService>(
              // Utiliser Consumer pour accéder aux commandes
              builder: (context, orderService, child) {
                // Calculer les données réelles pour le graphique
                final driverOrders = orderService.allOrders
                    .where((o) => _commandesPortees.contains(o.id))
                    .toList();

                final weeklyData = List<double>.filled(7, 0);
                final now = DateTime.now();
                const dayNames = [
                  'Lun',
                  'Mar',
                  'Mer',
                  'Jeu',
                  'Ven',
                  'Sam',
                  'Dim',
                ];
                final labels = <String>[];

                // Calculer pour les 7 derniers jours
                for (int i = 6; i >= 0; i--) {
                  final date = now.subtract(Duration(days: i));
                  labels.add(dayNames[date.weekday - 1]);

                  final count = driverOrders.where((o) {
                    return o.createdAt.year == date.year &&
                        o.createdAt.month == date.month &&
                        o.createdAt.day == date.day &&
                        o.statut == StatutCommande.livree;
                  }).length;
                  weeklyData[6 - i] = count.toDouble();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(context),
                      const SizedBox(height: 24),

                      // Graphique Hebdomadaire
                      const Text(
                        'Activité Hebdomadaire (Livrées)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Livraisons',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '7 derniers jours',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              CustomBarChart(
                                data: weeklyData,
                                labels: labels,
                                height: 180,
                                color: Theme.of(context).primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const SizedBox(height: 24),

                      Text(
                        'Performance Qualité',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildDetailedRatings(),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 34,
              child: Text(
                widget.driver!.fullName[0],
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.driver!.fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            widget.driver!.ratingAverage.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${widget.driver!.deliveriesCompleted} livraisons',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedRatings() {
    // Utiliser les vraies stats si disponibles, sinon utiliser le rating global ou 0
    final timeRating = (_detailedStats['avg_time_rating'] as num?)?.toDouble() ??
        widget.driver!.ratingAverage;
    final serviceRating = (_detailedStats['avg_service_rating'] as num?)?.toDouble() ??
        widget.driver!.ratingAverage;
    final conditionRating =
        (_detailedStats['avg_condition_rating'] as num?)?.toDouble() ??
            widget.driver!.ratingAverage;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildRatingRow('Rapidité', timeRating),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            _buildRatingRow(
              'Relation Client',
              serviceRating,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            _buildRatingRow(
              'Soin du colis',
              conditionRating,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            Text(
              'Basé sur ${_detailedStats['total_reviews'] ?? 0} avis détaillés',
              style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow(String label, double rating) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          height: 8,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rating / 5.0,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                rating >= 4.0
                    ? Colors.green
                    : (rating >= 3.0 ? Colors.amber : Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
