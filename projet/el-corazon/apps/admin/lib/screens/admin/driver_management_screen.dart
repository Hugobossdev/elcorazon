import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin/services/driver_management_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/autorisations.dart';
import 'package:admin/presentation/flotte.dart';
import 'package:admin/presentation/statut_livreur.dart';
import 'package:admin/widgets/loading_widget.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/screens/admin/driver_form_dialog.dart';
import 'package:admin/screens/admin/driver_history_screen.dart';
import 'package:admin/screens/admin/driver_schedule_screen.dart';
import 'package:admin/screens/admin/driver_detailed_stats_screen.dart';
import 'package:admin/screens/admin/driver_map_screen.dart';
import 'package:admin/ui/ui.dart';

/// La flotte : un aperçu, puis une liste par onglet ([OngletFlotte]).
///
/// La recherche et le tri s'appliquent à chaque liste ; le classement garde
/// son ordre. Les livreurs suspendus ou refusés ont leur onglet — sans lui, ils
/// n'apparaissaient nulle part, et une suspension ne pouvait plus être levée.
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
    _tabController = TabController(length: 1 + OngletFlotte.values.length, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    });
    // C'est l'écran de la flotte : c'est lui qui la demande. Elle se chargeait
    // à la construction du service, donc à l'ouverture de n'importe quel écran
    // du back-office.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<DriverManagementService>().ensureLoaded());
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
              tabs: [
                const Tab(icon: Icon(Icons.dashboard_outlined), text: 'Aperçu'),
                for (final onglet in OngletFlotte.values)
                  Tab(icon: Icon(_iconeDOnglet(onglet)), text: onglet.libelle),
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
                    for (final onglet in OngletFlotte.values)
                      _buildDriverListTab(context, driverService, onglet),
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
                hintText: 'Nom, courriel, téléphone ou plaque…',
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
                context.read<DriverManagementService>().rechercher(value);
              },
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: _showSortDialog,
            icon: const Icon(Icons.sort),
            tooltip: 'Trier',
          ),
          const SizedBox(width: 8),
          // Embaucher crée un compte : `couriers.write`. Le bouton s'offrait à
          // tout le personnel, et le formulaire entier était rempli avant le
          // 403.
          if (context.peut('couriers.write'))
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
    final stats = driverService.statistiques;

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
              // Le classement entier. L'onglet visé était un « Stats » qui
              // n'affichait que « Sélectionnez un livreur », sans rien pour en
              // sélectionner un.
              onPressed: () =>
                  _tabController.animateTo(1 + OngletFlotte.classement.index),
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...driverService.tetesDeClassement().map(
            (driver) => _buildDriverListItem(context, driver, driverService),),
      ],
    );
  }

  IconData _iconeDOnglet(OngletFlotte onglet) => switch (onglet) {
        OngletFlotte.disponibles => Icons.check_circle_outline,
        OngletFlotte.horsLigne => Icons.offline_bolt_outlined,
        OngletFlotte.horsService => Icons.block_outlined,
        OngletFlotte.classement => Icons.leaderboard_outlined,
      };

  Widget _buildDriverListTab(BuildContext context,
      DriverManagementService service, OngletFlotte onglet,) {
    final drivers = service.livreursDe(onglet);

    if (drivers.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      // Une recherche sans résultat n'est pas une flotte vide : le dire
      // évite de chercher les livreurs ailleurs.
      final message = service.recherche.trim().isNotEmpty
          ? 'Aucun livreur ne correspond à « ${service.recherche.trim()} » '
              'dans « ${onglet.libelle} ».'
          : switch (onglet) {
              OngletFlotte.disponibles => 'Aucun livreur disponible',
              OngletFlotte.horsLigne => 'Aucun livreur hors ligne',
              OngletFlotte.horsService => 'Aucun livreur hors service',
              OngletFlotte.classement => 'Aucun dossier validé',
            };
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (onglet == OngletFlotte.classement) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: drivers.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) =>
            _buildRangDuClassement(context, index + 1, drivers[index]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: drivers.length,
      itemBuilder: (context, index) => onglet == OngletFlotte.horsService
          ? _buildHorsServiceCard(context, drivers[index], service)
          : _buildDriverCard(context, drivers[index], service),
    );
  }

  /// Une ligne du classement : le rang, la note **avec son nombre d'avis** —
  /// 5,0 sur un avis ne pèse pas 4,8 sur deux cents — et les courses.
  Widget _buildRangDuClassement(
      BuildContext context, int rang, eccore.CourierProfile driver,) {
    final scheme = Theme.of(context).colorScheme;
    final note = driver.ratingCount == 0
        ? 'Pas encore noté'
        : '${driver.ratingAverage.toStringAsFixed(1)} '
            '(${driver.ratingCount} avis)';
    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DriverDetailedStatsScreen(driver: driver)),
      ),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          '$rang',
          style: TextStyle(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(driver.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Row(
        children: [
          Icon(Icons.star, size: 14, color: scheme.tertiary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$note • ${driver.deliveriesCompleted} courses',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
    );
  }

  /// Carte d'un livreur hors service : pourquoi, et le geste qui l'y ramène.
  ///
  /// Les gestes suivent la machine à états du serveur (`delivery/states.py`) :
  /// un suspendu se **réactive** (`suspended → approved`) ; un dossier refusé
  /// ne se valide pas d'ici — il **repasse en instruction**
  /// (`rejected → pending`) et rejoint le centre de validation, où ses pièces
  /// seront relues. Les deux demandent `couriers.approve`.
  Widget _buildHorsServiceCard(
      BuildContext context, eccore.CourierProfile driver, DriverManagementService service,) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    final peutInstruire = context.peut('couriers.approve');
    final geste = switch (driver.verificationStatus) {
      'suspended' => (libelle: 'Réactiver', icone: Icons.play_circle_outline, cible: 'approved'),
      'rejected' => (libelle: 'Réinstruire', icone: Icons.restart_alt, cible: 'pending'),
      _ => null,
    };

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: sem.danger.withValues(alpha: 0.1),
                child: Text(
                  driver.fullName.isEmpty ? '?' : driver.fullName[0].toUpperCase(),
                  style: TextStyle(color: sem.danger, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                driver.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${driver.deliveriesCompleted} courses • ${driver.phone.isEmpty ? driver.email : driver.phone}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sem.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  driver.motifHorsService,
                  style: TextStyle(
                    color: sem.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Le motif est celui que le livreur lit dans son profil : le
            // superviseur doit voir le même avant de revenir sur la décision.
            if (driver.verificationNotes.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Motif : ${driver.verificationNotes.trim()}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (geste != null && peutInstruire)
                  _buildActionButton(
                    context,
                    geste.icone,
                    geste.libelle,
                    () => unawaited(
                      _revenirSurLaDecision(driver, geste.libelle, geste.cible),
                    ),
                  ),
                _buildActionButton(
                  context,
                  Icons.history,
                  'Historique',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DriverHistoryScreen(driver: driver)),
                  ),
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

  /// Réactive un suspendu ou remet un dossier refusé en instruction, après
  /// confirmation. Le succès ne s'annonce qu'une fois le serveur d'accord ; un
  /// refus s'annonce avec sa phrase — une pièce expirée, par exemple, empêche
  /// une réactivation.
  Future<void> _revenirSurLaDecision(
    eccore.CourierProfile driver,
    String geste,
    String cible,
  ) async {
    final explication = cible == 'approved'
        ? '${driver.fullName} pourra de nouveau se mettre en ligne et recevoir '
            'des courses.'
        : 'Le dossier de ${driver.fullName} repassera en attente : il '
            'apparaîtra dans le centre de validation, où ses pièces seront '
            'relues avant toute reprise.';
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$geste ${driver.fullName} ?'),
        content: Text(explication),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(geste),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    final service = context.read<DriverManagementService>();
    final reussi = cible == 'approved'
        ? await service.reactivateDriver(driver.id)
        : await service.setVerification(driver.id, cible);
    if (!mounted) return;

    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reussi
              ? (cible == 'approved'
                  ? '${driver.fullName} est de nouveau en service.'
                  : 'Le dossier de ${driver.fullName} est repassé en instruction.')
              : (service.error ?? 'Le serveur a refusé ce geste.'),
        ),
        backgroundColor: reussi ? null : scheme.error,
      ),
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

  Widget _buildStatsGrid(BuildContext context, StatistiquesDeFlotte stats) {
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
          'Effectif',
          stats.effectif.toString(),
          Icons.people,
          sem.info,
        ),
        // « En ligne » comptait les dossiers **validés** : un livreur validé
        // mais téléphone éteint y figurait, et le siège croyait avoir dix
        // personnes en ville.
        _buildStatCard(
          'En ligne',
          stats.enLigne.toString(),
          Icons.wifi,
          sem.success,
        ),
        // « Courses actives » s'affichait « null » : le compteur n'était pas
        // produit, et le dossier d'un livreur ne dit rien de ses affectations.
        // Les dossiers à instruire, eux, appellent un geste.
        _buildStatCard(
          'Dossiers à instruire',
          stats.dossiersAInstruire.toString(),
          Icons.fact_check_outlined,
          sem.warning,
        ),
        _buildStatCard(
          stats.noteMoyenne == null
              ? 'Note moyenne'
              : 'Note moyenne (${stats.livreursNotes} noté'
                  '${stats.livreursNotes > 1 ? 's' : ''})',
          // Une moyenne sur zéro note vaut 0,0 : l'afficher ferait passer une
          // flotte neuve pour une flotte mal notée.
          stats.noteMoyenne?.toStringAsFixed(1) ?? '—',
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

  /// Le tri des listes. Le filtre par statut qui l'accompagnait a disparu :
  /// les onglets **sont** ce filtre, et filtrer « Disponible » dans l'onglet
  /// « Hors ligne » ne pouvait rendre qu'une liste vide.
  void _showSortDialog() {
    final service = context.read<DriverManagementService>();
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Trier les livreurs'),
        children: [
          for (final tri in TriFlotte.values)
            SimpleDialogOption(
              onPressed: () {
                service.trierPar(tri);
                Navigator.pop(context);
              },
              child: Row(
                children: [
                  Icon(
                    tri == service.tri ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(tri.libelle),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              'Le classement garde son ordre : de la meilleure note à la moins bonne.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
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
