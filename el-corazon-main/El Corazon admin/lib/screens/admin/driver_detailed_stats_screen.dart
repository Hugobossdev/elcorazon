import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/driver.dart';
import '../../models/driver_badge.dart';
import '../../models/order.dart'; // Import OrderStatus
import '../../services/driver_management_service.dart';
import '../../services/order_management_service.dart'; // Import Service
import '../../widgets/driver_badge_widget.dart';
import '../../widgets/custom_bar_chart.dart';

class DriverDetailedStatsScreen extends StatefulWidget {
  final Driver? driver;

  const DriverDetailedStatsScreen({super.key, required this.driver});

  @override
  State<DriverDetailedStatsScreen> createState() =>
      _DriverDetailedStatsScreenState();
}

class _DriverDetailedStatsScreenState extends State<DriverDetailedStatsScreen> {
  bool _isLoading = false;
  List<DriverBadge> _badges = [];
  Map<String, dynamic> _detailedStats = {};

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
      final results = await Future.wait([
        service.getDriverBadges(widget.driver!.id),
        service.getDriverDetailedStats(widget.driver!.id),
      ]);

      setState(() {
        _badges = results[0] as List<DriverBadge>;
        _detailedStats = results[1] as Map<String, dynamic>;
      });
    } catch (e) {
      debugPrint('Erreur chargement détails: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAssignBadgeDialog() async {
    final service = context.read<DriverManagementService>();
    final allBadges = await service.getAllBadges();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attribuer un badge'),
        content: SizedBox(
          width: double.maxFinite,
          child: allBadges.isEmpty
              ? const Center(child: Text('Aucun badge disponible'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: allBadges.length,
                  itemBuilder: (context, index) {
                    final badge = allBadges[index];
                    final isAssigned = _badges.any((b) => b.id == badge['id']);

                    return ListTile(
                      leading: Text(
                        badge['icon'] ?? '🏅',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(badge['title'] ?? ''),
                      subtitle: Text(badge['description'] ?? ''),
                      trailing: isAssigned
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                  final success = await service.assignBadgeToDriver(
                                    widget.driver!.id,
                                    badge['id'],
                                  );
                                  if (success) {
                                    _loadData();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Badge attribué avec succès'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  }
                              },
                              child: const Text('Attribuer'),
                            ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.driver == null) {
      return const Center(
          child: Text(
              'Sélectionnez un livreur pour voir ses statistiques détaillées.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.driver!.name),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<OrderManagementService>(
              // Utiliser Consumer pour accéder aux commandes
              builder: (context, orderService, child) {
                // Calculer les données réelles pour le graphique
                final driverOrders = orderService.allOrders
                    .where((o) =>
                        o.deliveryPersonId == widget.driver!.userId ||
                        o.deliveryPersonId == widget.driver!.id)
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
                  'Dim'
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
                        o.status ==
                            OrderStatus
                                .delivered; // Compter seulement les livrées
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
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Livraisons',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  Text('7 derniers jours',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12)),
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

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Badges & Récompenses',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          TextButton.icon(
                            onPressed: _showAssignBadgeDialog,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Attribuer un badge'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_badges.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.emoji_events_outlined,
                                  size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Aucun badge pour le moment',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _badges.length,
                          itemBuilder: (context, index) {
                            return DriverBadgeWidget(badge: _badges[index]);
                          },
                        ),

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
            Theme.of(context).primaryColor.withValues(alpha: 0.8)
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
              backgroundImage: widget.driver!.profileImageUrl != null
                  ? NetworkImage(widget.driver!.profileImageUrl!)
                  : null,
              child: widget.driver!.profileImageUrl == null
                  ? Text(
                      widget.driver!.name[0],
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.driver!.name,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            widget.driver!.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${widget.driver!.totalDeliveries} livraisons',
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
    final timeRating = (_detailedStats['avg_time_rating'] as num?)?.toDouble() ?? widget.driver!.rating;
    final serviceRating = (_detailedStats['avg_service_rating'] as num?)?.toDouble() ?? widget.driver!.rating;
    final conditionRating = (_detailedStats['avg_condition_rating'] as num?)?.toDouble() ?? widget.driver!.rating;

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
                padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
            _buildRatingRow(
              'Relation Client',
              serviceRating,
            ),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
            _buildRatingRow(
              'Soin du colis',
              conditionRating,
            ),
             const Padding(
                padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
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
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500))),
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
