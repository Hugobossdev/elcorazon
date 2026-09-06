import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin/services/driver_management_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/statut_livreur.dart';
import 'package:admin/widgets/loading_widget.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/screens/admin/driver_form_dialog.dart';
import 'package:admin/screens/admin/driver_history_screen.dart';
import 'package:admin/screens/admin/driver_schedule_screen.dart';
import 'package:admin/screens/admin/driver_detailed_stats_screen.dart';
import 'package:admin/screens/admin/driver_map_screen.dart';
import 'package:admin/ui/ui.dart';

enum DriverSortOption { nameAsc, nameDesc, status, rating, deliveries }

extension DriverSortOptionExtension on DriverSortOption {
  String get displayName {
    switch (this) {
      case DriverSortOption.nameAsc:
        return 'Nom (A-Z)';
      case DriverSortOption.nameDesc:
        return 'Nom (Z-A)';
      case DriverSortOption.status:
        return 'Statut';
      case DriverSortOption.rating:
        return 'Note';
      case DriverSortOption.deliveries:
        return 'Livraisons';
    }
  }
}

class DriverManagementScreen extends StatefulWidget {
  const DriverManagementScreen({super.key});

  @override
  State<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: scheme.primary,
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined), text: 'Aperçu'),
                Tab(
                    icon: Icon(Icons.check_circle_outline),
                    text: 'Disponibles',),
                Tab(
                    icon: Icon(Icons.offline_bolt_outlined),
                    text: 'Hors ligne',),
                Tab(icon: Icon(Icons.analytics_outlined), text: 'Stats'),
              ],
            ),
          ),
          Expanded(
            child: Consumer<DriverManagementService>(
              builder: (context, driverService, child) {
                if (driverService.isLoading) {
                  return const LoadingWidget(
                      message: 'Chargement des livreurs...',);
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context, driverService),
                    _buildDriverListTab(
                        context, driverService, StatutLivreur.disponible,),
                    _buildDriverListTab(
                        context, driverService, StatutLivreur.horsLigne,),
                    const DriverDetailedStatsScreen(
                        driver: null,), // Placeholder for global stats tab
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: sem.shadow,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un livreur...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onChanged: (value) {
                context.read<DriverManagementService>().searchDrivers(value);
              },
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrer',
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: _showAddDriverDialog,
            elevation: 0,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
      BuildContext context, DriverManagementService driverService,) {
    final stats = driverService.getDriverStats();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatsGrid(context, stats),
        const SizedBox(height: 24),
        Text(
          'Localisation en temps réel',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _carteDesLivreurs(context, driverService.drivers),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Top Livreurs',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _tabController.animateTo(4), // Go to Stats
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...driverService.getTopRatedDrivers(limit: 3).map(
            (driver) => _buildDriverListItem(context, driver, driverService),),
      ],
    );
  }

  Widget _buildDriverListTab(BuildContext context,
      DriverManagementService service, StatutLivreur status,) {
    final drivers = service.getDriversByStatus(status);

    if (drivers.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off_outlined,
              size: 64,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun livreur ${status.libelle.toLowerCase()}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: drivers.length,
      itemBuilder: (context, index) =>
          _buildDriverCard(context, drivers[index], service),
    );
  }

  /// Entrée vers la carte des livreurs.
  ///
  /// ## Ce que ce bloc montrait, et pourquoi il a été refait
  ///
  /// Il affichait les cinq premiers livreurs sous forme de pastilles posées sur
  /// un planisphère décoratif, à des positions tirées d'une liste
  /// d'`Alignment` écrite en dur. Ces positions n'avaient **aucun rapport** avec
  /// l'endroit où se trouvaient les livreurs : sous un titre « Localisation en
  /// temps réel », un superviseur lisait une répartition inventée. C'est le
  /// genre de figure qu'on croit sur parole pendant des mois.
  ///
  /// Le fond de carte venait par-dessus le marché de `NetworkImage` sur
  /// Wikimedia : une requête sortante depuis le poste du personnel à chaque
  /// affichage, et un bloc vide le jour où l'URL bouge.
  ///
  /// La vraie carte existe et fonctionne — [DriverMapScreen], qui lit les
  /// positions rendues par le serveur et s'ouvre sur l'établissement supervisé.
  /// Ce bloc n'est donc plus qu'une **porte** vers elle, et il ne dit que ce
  /// qu'il sait : combien de livreurs sont en ligne, et pour combien d'entre
  /// eux une position est connue.
  Widget _carteDesLivreurs(
    BuildContext context,
    List<eccore.CourierProfile> drivers,
  ) {
    final scheme = Theme.of(context).colorScheme;

    final enLigne = drivers.where((d) => d.isOnline).length;
    final localises = drivers
        .where((d) => d.isOnline && d.lastLatitude != null && d.lastLongitude != null)
        .length;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverMapScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: scheme.primary, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Carte des livreurs',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // Distinguer « en ligne » de « localisé » plutôt que de
                    // supposer l'un depuis l'autre : un livreur qui vient de
                    // démarrer son application est en ligne sans avoir encore
                    // émis de position, et la carte ne pourra pas le placer.
                    enLigne == 0
                        ? 'Aucun livreur en ligne pour le moment.'
                        : localises == enLigne
                            ? '$enLigne en ligne, tous localisés.'
                            : '$enLigne en ligne, $localises avec une position connue.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, Map<String, dynamic> stats) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Livreurs',
          stats['total_drivers'].toString(),
          Icons.people,
          sem.info,
        ),
        _buildStatCard(
          'En Ligne',
          stats['online_drivers'].toString(),
          Icons.wifi,
          sem.success,
        ),
        _buildStatCard(
          'Courses actives',
          stats['busy_drivers'].toString(),
          Icons.local_shipping,
          sem.warning,
        ),
        _buildStatCard(
          'Note Moyenne',
          (stats['average_rating'] as num).toStringAsFixed(1),
          Icons.star,
          scheme.tertiary,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color,) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: sem.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(
      BuildContext context, eccore.CourierProfile driver, DriverManagementService service,) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 24,
                backgroundColor:
                    _getStatusColor(driver.statut).withValues(alpha: 0.1),
                child: Text(
                  driver.fullName[0].toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(driver.statut),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                driver.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Row(
                children: [
                  Icon(Icons.star, size: 14, color: scheme.tertiary),
                  Text(
                    ' ${driver.ratingAverage.toStringAsFixed(1)} • ${driver.deliveriesCompleted} courses',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(driver.statut).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  driver.statut.libelle,
                  style: TextStyle(
                    color: _getStatusColor(driver.statut),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  context,
                  Icons.calendar_month,
                  'Planning',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              DriverScheduleScreen(driver: driver),),),
                ),
                _buildActionButton(
                  context,
                  Icons.analytics_outlined,
                  'Stats',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              DriverDetailedStatsScreen(driver: driver),),),
                ),
                _buildActionButton(
                  context,
                  Icons.history,
                  'Historique',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DriverHistoryScreen(driver: driver),),),
                ),
                _buildActionButton(
                  context,
                  Icons.edit_outlined,
                  'Éditer',
                  () => _editDriver(driver),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverListItem(
      BuildContext context, eccore.CourierProfile driver, DriverManagementService service,) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DriverDetailedStatsScreen(driver: driver),),),
      leading: CircleAvatar(
        child: Text(driver.fullName[0]),
      ),
      title: Text(driver.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),),
      subtitle: Text('${driver.deliveriesCompleted} livraisons'),
      trailing: Icon(
        Icons.chevron_right,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, IconData icon, String label, VoidCallback onTap,) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(StatutLivreur status) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    switch (status) {
      case StatutLivreur.disponible:
        return sem.success;
      case StatutLivreur.horsLigne:
        return scheme.onSurfaceVariant;
      case StatutLivreur.indisponible:
        return sem.danger;
    }
  }

  void _showFilterDialog() {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrer les livreurs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Filtrer par statut
            DropdownButtonFormField<StatutLivreur>(
              decoration: const InputDecoration(
                labelText: 'Statut',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.filter_alt),
              ),
              items: StatutLivreur.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.libelle),
                );
              }).toList(),
              onChanged: (status) {
                context.read<DriverManagementService>().filterByStatus(status);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            // Filtrer par tri
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Trier par',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.sort),
              ),
              items: const [
                DropdownMenuItem(value: 'name', child: Text('Nom (A-Z)')),
                DropdownMenuItem(value: 'nameDesc', child: Text('Nom (Z-A)')),
                DropdownMenuItem(
                    value: 'rating', child: Text('Meilleure Note'),),
                DropdownMenuItem(
                    value: 'deliveries', child: Text('Plus de livraisons'),),
              ],
              onChanged: (value) {
                if (value != null) {
                  context.read<DriverManagementService>().setSortOption(value);
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                context.read<DriverManagementService>().filterByStatus(null);
                context
                    .read<DriverManagementService>()
                    .setSortOption('name'); // Reset sort
                Navigator.pop(context);
              },
              child: const Text('Réinitialiser les filtres'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDriverDialog() {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => const DriverFormDialog(),
    );
  }

  void _editDriver(eccore.CourierProfile driver) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => DriverFormDialog(driver: driver),
    );
  }
}
