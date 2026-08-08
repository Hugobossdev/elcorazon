import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/services/driver_management_service.dart';
import 'package:admin/models/order.dart';
import 'package:admin/presentation/anciennete_commande.dart';
import 'package:admin/presentation/couleur_statut.dart';
import 'package:admin/presentation/dialogues/assignation_livreur.dart';
import 'package:admin/presentation/dialogues/changement_statut.dart';
import 'package:admin/presentation/dialogues/details_commande.dart';
import 'package:admin/presentation/onglets/statistiques_commandes.dart';
import 'package:admin/presentation/tri_commandes.dart';
import 'package:admin/widgets/custom_button.dart';
import 'package:admin/widgets/loading_widget.dart';
import 'package:admin/utils/price_formatter.dart';
import 'package:admin/ui/ui.dart';


class AdvancedOrderManagementScreen extends StatefulWidget {
  const AdvancedOrderManagementScreen({super.key});

  @override
  State<AdvancedOrderManagementScreen> createState() =>
      _AdvancedOrderManagementScreenState();
}

class _AdvancedOrderManagementScreenState
    extends State<AdvancedOrderManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  /// Recherche et tri sont **tenus par l'écran**, pas par le service.
  ///
  /// Ce sont des réglages d'affichage : deux écrans ouverts sur le même
  /// service n'ont aucune raison de partager le tri de l'un ni la recherche de
  /// l'autre. Les porter dans le service les rendrait globaux, et un filtre
  /// posé ici resterait actif sur un écran qui ne le montre pas.
  String _searchQuery = '';
  TriCommandes _sortOption = TriCommandes.dateDecroissante;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    // IMPORTANT: Écouter les changements d'onglet pour mettre à jour l'IndexedStack
    _tabController.addListener(() {
      if (!mounted) return;
      // Reporter setState après le build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // context.read<OrderManagementService>().initialize(); // Méthode non implémentée
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
    final sem = AdminColorTokens.semantic(scheme);

    // Pas d'AppBar ici car il est déjà géré par AdminNavigationScreen
    // IMPORTANT: cette page peut être affichée dans une arborescence sans ancêtre Material.
    // Or certains widgets Material (TextField, etc.) l'exigent.
    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          // Barre d'actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              boxShadow: [
                BoxShadow(
                  color: sem.shadow,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher par ID, client, adresse...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showFilterDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.filter_list),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      context.read<OrderManagementService>().refresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rafraîchissement des commandes...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.refresh),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _exportOrders,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.download, color: scheme.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // TabBar
          Container(
            color: scheme.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: scheme.primary,
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard), text: 'Vue d\'ensemble'),
                Tab(icon: Icon(Icons.pending), text: 'En attente'),
                Tab(icon: Icon(Icons.verified), text: 'Confirmées'),
                Tab(icon: Icon(Icons.restaurant), text: 'En préparation'),
                Tab(icon: Icon(Icons.check_circle), text: 'Prêtes'),
                Tab(icon: Icon(Icons.delivery_dining), text: 'En livraison'),
                Tab(icon: Icon(Icons.analytics), text: 'Statistiques'),
              ],
            ),
          ),
          // Contenu
          Expanded(
            child: Consumer<OrderManagementService>(
              builder: (context, orderService, child) {
                // Afficher un indicateur de chargement si en cours et liste vide
                if (orderService.isLoading && orderService.allOrders.isEmpty) {
                  return const LoadingWidget(
                      message: 'Chargement des commandes...',);
                }

                // Afficher un message si aucune commande et pas de chargement
                if (!orderService.isLoading && orderService.allOrders.isEmpty) {
                  final scheme = Theme.of(context).colorScheme;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune commande trouvée',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Les commandes apparaîtront ici une fois chargées',
                          style: TextStyle(
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => orderService.refresh(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Rafraîchir'),
                        ),
                      ],
                    ),
                  );
                }

                // IMPORTANT: Construire seulement l'onglet visible pour éviter les problèmes de hit testing
                // Utiliser un switch au lieu d'IndexedStack pour construire seulement l'onglet actif
                switch (_tabController.index) {
                  case 0:
                    return SizedBox.expand(
                        child: _buildOverviewTab(context, orderService),);
                  case 1:
                    return SizedBox.expand(
                        child: _buildOrdersTab(context, orderService,
                            OrderStatus.pending, 'Aucune commande en attente',),);
                  case 2:
                    return SizedBox.expand(
                        child: _buildOrdersTab(context, orderService,
                            OrderStatus.confirmed, 'Aucune commande confirmée',),);
                  case 3:
                    return SizedBox.expand(
                        child: _buildOrdersTab(context, orderService,
                            OrderStatus.preparing, 'Aucune commande en préparation',),);
                  case 4:
                    return SizedBox.expand(
                        child: _buildOrdersTab(context, orderService,
                            OrderStatus.ready, 'Aucune commande prête',),);
                  case 5:
                    return SizedBox.expand(
                        child: _buildOrdersTab(context, orderService,
                            OrderStatus.onTheWay, 'Aucune commande en livraison',),);
                  case 6:
                    return SizedBox.expand(
                        child: OngletStatistiques(orderService: orderService),);
                  default:
                    return SizedBox.expand(
                        child: _buildOverviewTab(context, orderService),);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
      BuildContext context, OrderManagementService orderService,) {
    final stats = orderService.getOrderStats();
    final urgentOrders = orderService.urgentOrders;
    final overdueOrders = orderService.overdueOrders;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistiques principales
          _buildStatsGrid(context, stats),
          const SizedBox(height: 20),

          // Alertes
          if (urgentOrders.isNotEmpty || overdueOrders.isNotEmpty) ...[
            _buildAlertsSection(context, urgentOrders, overdueOrders),
            const SizedBox(height: 20),
          ],

          // Commandes récentes
          _buildRecentOrdersSection(context, orderService),
          const SizedBox(height: 20),

          // Performance
          _buildPerformanceSection(context, orderService),
        ],
      ),
    );
  }

  /// L'onglet d'un statut : les cinq se ressemblaient à la ligne près.
  ///
  /// Chacun rechargeait depuis la base plutôt que de filtrer la liste déjà en
  /// mémoire ; cette lecture et le message affiché quand il n'y a rien sont
  /// leur seule différence.
  Widget _buildOrdersTab(
    BuildContext context,
    OrderManagementService orderService,
    OrderStatus statut,
    String messageVide,
  ) {
    return Consumer<OrderManagementService>(
      builder: (context, service, child) {
        return FutureBuilder<List<Order>>(
          future: service.loadOrdersByStatusFromDB(statut),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red,),
                    const SizedBox(height: 16),
                    Text('Erreur: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        service.refresh();
                        setState(() {});
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            final commandes = snapshot.data ?? [];

            return commandes.isEmpty
                ? _buildEmptyState(context, messageVide)
                : _buildOrdersList(context, commandes, orderService);
          },
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          context,
          'Total commandes',
          '${stats['total_orders'] ?? 0}',
          Icons.receipt_long,
          Theme.of(context).colorScheme.primary,
        ),
        _buildStatCard(
          context,
          'En attente',
          '${stats['pending_orders'] ?? 0}',
          Icons.pending,
          AdminColorTokens.semantic(Theme.of(context).colorScheme).warning,
        ),
        _buildStatCard(
          context,
          'En préparation',
          '${stats['preparing_orders'] ?? 0}',
          Icons.restaurant,
          Theme.of(context).colorScheme.tertiary,
        ),
        _buildStatCard(
          context,
          'Livrées',
          '${stats['delivered_orders'] ?? 0}',
          Icons.check_circle,
          AdminColorTokens.semantic(Theme.of(context).colorScheme).success,
        ),
        _buildStatCard(
          context,
          'Revenus totaux',
          PriceFormatter.format(
              (stats['total_revenue'] as num?)?.toDouble() ?? 0.0,),
          Icons.monetization_on,
          Theme.of(context).colorScheme.secondary,
        ),
        _buildStatCard(
          context,
          'Panier moyen',
          PriceFormatter.format(
              (stats['average_order_value'] as num?)?.toDouble() ?? 0.0,),
          Icons.shopping_cart,
          Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color,) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context, List<Order> urgentOrders,
      List<Order> overdueOrders,) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: sem.danger),
                const SizedBox(width: 8),
                Text(
                  'Alertes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: sem.danger,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (urgentOrders.isNotEmpty) ...[
              Text(
                '⚠️ ${urgentOrders.length} commande(s) urgente(s)',
                style: TextStyle(color: sem.danger),
              ),
              const SizedBox(height: 4),
            ],
            if (overdueOrders.isNotEmpty) ...[
              Text(
                '🚨 ${overdueOrders.length} commande(s) en retard',
                style: TextStyle(color: sem.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrdersSection(
      BuildContext context, OrderManagementService orderService,) {
    // Charger directement depuis la base de données
    return Consumer<OrderManagementService>(
      builder: (context, service, child) {
        final future = service.loadRecentOrdersFromDB();

        return FutureBuilder<List<Order>>(
          future: future,
          builder: (context, snapshot) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commandes récentes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (snapshot.hasError)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Erreur: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    else if (snapshot.data == null || snapshot.data!.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Aucune commande récente'),
                        ),
                      )
                    else
                      ...snapshot.data!.map(
                        (order) =>
                            _buildOrderListItem(context, order, orderService),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPerformanceSection(
      BuildContext context, OrderManagementService orderService,) {
    final performanceStats = orderService.getPerformanceStats();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceItem(
                    context,
                    'Temps moyen',
                    '${(performanceStats['average_delivery_time'] as num?)?.toDouble().toInt() ?? 0} min',
                    Icons.timer,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildPerformanceItem(
                    context,
                    'Livraison à temps',
                    '${((performanceStats['on_time_delivery_rate'] as num?)?.toDouble() ?? 0.0) * 100}%',
                    Icons.schedule,
                    AdminColorTokens.semantic(Theme.of(context).colorScheme)
                        .success,
                  ),
                ),
                Expanded(
                  child: _buildPerformanceItem(
                    context,
                    'Satisfaction',
                    '${(performanceStats['customer_satisfaction'] as num?)?.toDouble() ?? 0.0}/5',
                    Icons.star,
                    AdminColorTokens.semantic(Theme.of(context).colorScheme)
                        .warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceItem(BuildContext context, String title, String value,
      IconData icon, Color color,) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Recherche et tri s'appliquent **ici**, seul point par lequel passent les
  /// cinq onglets de statut : les y poser une fois vaut mieux que cinq
  /// applications qui finiraient par diverger.
  ///
  /// La recherche portait jusqu'ici sur un appel dont le résultat était jeté
  /// (`service.searchOrders(value);`, valeur de retour ignorée) et le tri sur
  /// une liste déroulante branchée sur rien : les deux contrôles étaient
  /// visibles et sans effet.

  Widget _buildOrdersList(BuildContext context, List<Order> orders,
      OrderManagementService orderService,) {
    final affichees = commandesAffichees(
      orders,
      recherche: _searchQuery,
      tri: _sortOption,
    );

    if (affichees.isEmpty) {
      return _buildEmptyState(
        context,
        'Aucune commande ne correspond à « $_searchQuery »',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: affichees.length,
      itemBuilder: (context, index) {
        final order = affichees[index];
        return _buildOrderCard(context, order, orderService);
      },
    );
  }

  Widget _buildOrderCard(
      BuildContext context, Order order, OrderManagementService orderService,) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: couleurDeStatut(order.status, Theme.of(context).colorScheme)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.status.displayName,
                    style: TextStyle(
                      color: couleurDeStatut(order.status, Theme.of(context).colorScheme),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  PriceFormatter.format(order.total),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Commande #${order.id.substring(0, 8).toUpperCase()}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${order.items.length} article${order.items.length > 1 ? 's' : ''} • ${ancienneteCommande(order.orderTime)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            // Afficher les articles de la commande
            if (order.items.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Articles:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    ...order.items.take(3).map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                '• ${item.quantity}x ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.menuItemName.isNotEmpty
                                          ? item.menuItemName
                                          : item.name.isNotEmpty
                                              ? item.name
                                              : 'Article',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (item
                                        .getFormattedCustomizations()
                                        .isNotEmpty)
                                      Text(
                                        item
                                                .getFormattedCustomizations()
                                                .take(2)
                                                .join(', ') +
                                            (item
                                                        .getFormattedCustomizations()
                                                        .length >
                                                    2
                                                ? '...'
                                                : ''),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                PriceFormatter.format(item.totalPrice),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),),
                    if (order.items.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+ ${order.items.length - 3} autre${order.items.length - 3 > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      size: 16,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aucun article trouvé dans cette commande',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onTertiaryContainer,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              order.deliveryAddress,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Voir détails',
                    onPressed: () => afficherDetailsCommande(context, order),
                    variant: ButtonVariant.outlined,
                    height: 36,
                  ),
                ),
                const SizedBox(width: 8),
                if (order.status == OrderStatus.pending)
                  Expanded(
                    child: CustomButton(
                      text: 'Confirmer',
                      onPressed: () => _confirmOrder(order, orderService),
                      color: AdminColorTokens.semantic(
                        Theme.of(context).colorScheme,
                      ).success,
                      height: 36,
                    ),
                  ),
                if (order.status == OrderStatus.confirmed)
                  Expanded(
                    child: CustomButton(
                      text: 'Préparer',
                      onPressed: () => _prepareOrder(order, orderService),
                      color: Theme.of(context).colorScheme.primary,
                      height: 36,
                    ),
                  ),
                if (order.status == OrderStatus.preparing)
                  Expanded(
                    child: CustomButton(
                      text: 'Prêt',
                      onPressed: () => _readyOrder(order, orderService),
                      color: AdminColorTokens.semantic(
                        Theme.of(context).colorScheme,
                      ).warning,
                      height: 36,
                    ),
                  ),
                if (order.status == OrderStatus.ready)
                  Expanded(
                    child: Consumer<DriverManagementService>(
                      builder: (context, driverService, child) {
                        return CustomButton(
                          text: order.deliveryPersonId != null
                              ? 'Réassigner'
                              : 'Assigner livreur',
                          onPressed: () => unawaited(
                            afficherAssignationLivreur(
                              context: context,
                              order: order,
                              orderService: orderService,
                              driverService: driverService,
                            ),
                          ),
                          color: Theme.of(context).colorScheme.primary,
                          height: 36,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderListItem(
      BuildContext context, Order order, OrderManagementService orderService,) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            couleurDeStatut(order.status, Theme.of(context).colorScheme).withValues(alpha: 0.1),
        child: Text(
          order.status.emoji,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      title: Text('Commande #${order.id.substring(0, 8).toUpperCase()}'),
      subtitle: Text(
          '${order.status.displayName} • ${PriceFormatter.format(order.total)}',),
      trailing: Text(ancienneteCommande(order.orderTime)),
      onTap: () => afficherDetailsCommande(context, order),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }



  // Méthode _showSearchDialog supprimée car la recherche est maintenant intégrée directement dans l'interface

  void _showFilterDialog() {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 500.0);
    const dialogHeight = 300.0;

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtrer les commandes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    // IMPORTANT: Material + InkWell + Container avec taille explicite
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: const Icon(Icons.close, size: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Contenu
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  // `StatefulBuilder` : le `setState` de l'écran ne redessine
                  // pas le contenu d'une boîte de dialogue, qui vit dans une
                  // autre route. Sans lui, le tri s'appliquerait à la liste
                  // mais la liste déroulante afficherait encore l'ancien choix.
                  child: StatefulBuilder(
                    builder: (context, setDialogState) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Le filtre par statut a été retiré : les cinq
                          // onglets de cet écran *sont* le filtre par statut.
                          // Un second filtre, global et invisible depuis
                          // l'onglet courant, ne pouvait que le contredire —
                          // choisir « Prêtes » depuis l'onglet « En attente »
                          // vidait la liste sans expliquer pourquoi.
                          DropdownButtonFormField<TriCommandes>(
                            decoration: const InputDecoration(
                              labelText: 'Trier par',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: _sortOption,
                            items: TriCommandes.values.map((option) {
                              return DropdownMenuItem<TriCommandes>(
                                value: option,
                                child: Text(option.libelle),
                              );
                            }).toList(),
                            onChanged: (option) {
                              if (option == null) return;
                              setDialogState(() => _sortOption = option);
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Le tri s’applique aux commandes de chaque onglet. '
                            'Pour filtrer par statut, changez d’onglet.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                      ),
                      child: TextButton(
                        onPressed: () {
                          // Remet l'écran dans son état d'ouverture : tri par
                          // date décroissante et recherche vide.
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _sortOption = TriCommandes.dateDecroissante;
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('Effacer'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fermer'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportOrders() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Export des commandes en cours...'),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
      ),
    );
  }

  void _confirmOrder(Order order, OrderManagementService orderService) {
    unawaited(
      confirmerChangementStatut(
        context: context,
        order: order,
        nouveauStatut: OrderStatus.confirmed,
        orderService: orderService,
        message:
            'Voulez-vous confirmer cette commande ?\n\nCette action valide la commande et commence le processus de préparation.',
      ),
    );
  }

  void _prepareOrder(Order order, OrderManagementService orderService) {
    unawaited(
      confirmerChangementStatut(
        context: context,
        order: order,
        nouveauStatut: OrderStatus.preparing,
        orderService: orderService,
        message:
            'Voulez-vous commencer la préparation de cette commande ?\n\nCette action indique que la cuisine commence à préparer les articles.',
      ),
    );
  }

  void _readyOrder(Order order, OrderManagementService orderService) {
    unawaited(
      confirmerChangementStatut(
        context: context,
        order: order,
        nouveauStatut: OrderStatus.ready,
        orderService: orderService,
        message:
            'Voulez-vous marquer cette commande comme prête ?\n\nCette action indique que la commande est prête pour la livraison.',
      ),
    );
  }

  /// Widget helper pour afficher une ligne de détail
}
