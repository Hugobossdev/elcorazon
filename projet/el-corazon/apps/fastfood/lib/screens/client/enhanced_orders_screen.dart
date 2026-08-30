import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/order_history_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/widgets/delivery_status_card.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/presentation/reprise_de_commande.dart';
import 'package:elcora_fast/presentation/suivi_commande.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart' as etats;
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/repositories/django_order_repository.dart';

/// Écran amélioré de l'historique des commandes avec filtres et tri
class EnhancedOrdersScreen extends StatefulWidget {
  const EnhancedOrdersScreen({super.key});

  @override
  State<EnhancedOrdersScreen> createState() => _EnhancedOrdersScreenState();
}

class _EnhancedOrdersScreenState extends State<EnhancedOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late OrderHistoryService _orderHistoryService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialiser le service
    final orderRepository = DjangoOrderRepository();
    _orderHistoryService = OrderHistoryService(orderRepository);

    // Charger les commandes
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final appService = Provider.of<AppService>(context, listen: false);
    final userId = appService.currentUser?.id;

    if (userId != null) {
      await _orderHistoryService.loadOrders(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: 'Mes commandes',
        actions: [
          GlassIconButton(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filtrer et trier',
            filled: false,
            onPressed: _showFilterDialog,
          ),
        ],
        bottom: SegmentedTabs(
          controller: _tabController,
          labels: const ['En cours', 'Historique'],
          icons: const [Icons.schedule_rounded, Icons.history_rounded],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _enCours(theme),
          _historique(theme),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- en cours

  Widget _enCours(ThemeData theme) {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final actives = appService.orders.where(_estEnCours).toList();

        if (actives.isEmpty) {
          return etats.EmptyStateWidget(
            title: 'Aucune commande en cours',
            message: 'Vos commandes actives apparaîtront ici.',
            icon: Icons.shopping_bag_outlined,
            actionText: 'Explorer la carte',
            onAction: () => context.navigateToMenu(),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadOrders,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DesignConstants.edgeMargin,
              DesignConstants.spacingM,
              DesignConstants.edgeMargin,
              DesignConstants.spacingXL,
            ),
            children: [
              for (final order in actives) ...[
                DeliveryStatusCard(
                  order: order,
                  onTap: () => context.navigateToDeliveryTracking(order.id),
                ),
                // La mini-chronologie de la maquette `order_history`. Elle
                // partage sa règle avec le détail de commande et le suivi
                // (`presentation/suivi_commande.dart`) : trois vues du même
                // cycle qui divergeraient sinon.
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: DesignConstants.spacingL,
                  ),
                  child: _chronologieCompacte(theme, order),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Une commande est « en cours » tant qu'elle n'est ni livrée ni close.
  ///
  /// `refunded` et `failed` rejoignent l'historique : ce sont des issues, pas
  /// des étapes. Le `switch` est exhaustif, comme dans `orders_screen` — un
  /// statut ajouté au serveur fera échouer la compilation plutôt que de
  /// retomber silencieusement dans « en cours ».
  bool _estEnCours(Order commande) {
    switch (commande.status) {
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
      case OrderStatus.failed:
        return false;
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
      case OrderStatus.ready:
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay:
        return true;
    }
  }

  /// Les quatre jalons en une ligne, sous la carte de commande active.
  Widget _chronologieCompacte(ThemeData theme, Order order) {
    final etapes = etapesDeSuivi(order);

    return Row(
      children: [
        for (var i = 0; i < etapes.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: etapes[i].franchie
                    ? AppColors.success
                    : theme.colorScheme.outlineVariant,
              ),
            ),
          Tooltip(
            message: etapes[i].annulation
                ? libelleDeSortie(order.status)
                : etapes[i].jalon.libelle,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: etapes[i].annulation
                    ? theme.colorScheme.error
                    : etapes[i].franchie
                        ? AppColors.success
                        : theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                etapes[i].annulation
                    ? Icons.close_rounded
                    : etapes[i].franchie
                        ? Icons.check_rounded
                        : Icons.circle_outlined,
                size: 11,
                color: etapes[i].franchie || etapes[i].annulation
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ historique

  Widget _historique(ThemeData theme) {
    return ChangeNotifierProvider<OrderHistoryService>.value(
      value: _orderHistoryService,
      child: Consumer<OrderHistoryService>(
        builder: (context, service, child) {
          if (service.isLoading) {
            return const etats.PageLoadingWidget(
              message: 'Chargement de votre historique…',
            );
          }

          final orders = service.orders;

          if (orders.isEmpty) {
            return etats.EmptyStateWidget(
              title: 'Aucune commande trouvée',
              message: 'Aucune commande ne correspond à vos filtres.',
              icon: Icons.receipt_long_outlined,
              actionText: 'Réinitialiser les filtres',
              onAction: service.resetFilters,
            );
          }

          final parDate = service.getOrdersGroupedByDate();
          final dates = parDate.keys.toList()
            ..sort((a, b) {
              if (a == 'Aujourd\'hui') return -1;
              if (b == 'Aujourd\'hui') return 1;
              if (a == 'Hier') return -1;
              if (b == 'Hier') return 1;
              return b.compareTo(a);
            });

          return RefreshIndicator(
            onRefresh: _loadOrders,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                DesignConstants.edgeMargin,
                DesignConstants.spacingM,
                DesignConstants.edgeMargin,
                DesignConstants.spacingXL,
              ),
              children: [
                for (var i = 0; i < dates.length; i++) ...[
                  Padding(
                    padding: EdgeInsets.only(
                      top: i > 0 ? DesignConstants.spacingL : 0,
                      bottom: DesignConstants.spacingS,
                    ),
                    child: Text(
                      dates[i],
                      style: AppTypography.labelLg(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final order in parDate[dates[i]]!)
                    _carteDeCommande(theme, order),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _carteDeCommande(ThemeData theme, Order order) {
    final apparence = _apparenceDuStatut(theme, order.status);
    final heure = DateFormat('HH:mm').format(order.createdAt);

    return SectionCard(
      margin: const EdgeInsets.only(bottom: DesignConstants.spacingM),
      onTap: () => Navigator.of(context).pushNamed(
        AppRouter.orderDetails,
        arguments: {'order': order},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(
                label: apparence.libelle,
                background: apparence.fond,
                foreground: apparence.encre,
              ),
              const Spacer(),
              Text(
                heure,
                style: AppTypography.bodyMd(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingM),
          for (final item in order.items.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: DesignConstants.spacingXS),
              child: Row(
                children: [
                  Text(
                    '${item.quantity}×',
                    style: AppTypography.labelLg(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: DesignConstants.spacingS),
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLg(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    PriceFormatter.format(item.totalPrice),
                    style: AppTypography.bodyLg(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          if (order.items.length > 3)
            Text(
              '+ ${order.items.length - 3} autre'
              '${order.items.length - 3 > 1 ? 's' : ''}',
              style: AppTypography.bodyMd(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SummaryDivider(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total',
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      PriceFormatter.format(order.total),
                      style: AppTypography.priceDisplay(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              // « Reorder » de la maquette. La logique existait déjà
              // (`_reorderItems`) : elle repose les articles au panier depuis
              // la commande, sans rien recalculer.
              if (order.status == OrderStatus.delivered)
                ActionButton(
                  label: 'Recommander',
                  emphasis: ActionEmphasis.outlined,
                  icon: Icons.refresh_rounded,
                  expand: false,
                  height: 40,
                  onPressed: () => _reorderItems(order),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Le mot et les teintes d'un statut, pris aux rôles du thème.
  ///
  /// Remplace `_getStatusColor` et `_getStatusLabel`, qui rendaient les verts,
  /// bleus, oranges et violets de Material — les mêmes que
  /// `DeliveryStatusCard` a quittés au premier lot. Deux écrans qui montrent
  /// le même statut ne peuvent pas le peindre différemment.
  ({String libelle, Color fond, Color encre}) _apparenceDuStatut(
    ThemeData theme,
    OrderStatus statut,
  ) {
    switch (statut) {
      case OrderStatus.delivered:
        return (
          libelle: 'Livrée',
          fond: AppColors.successLight,
          encre: AppColors.success,
        );
      case OrderStatus.cancelled:
      case OrderStatus.failed:
        return (
          libelle: statut == OrderStatus.failed ? 'Échouée' : 'Annulée',
          fond: theme.colorScheme.errorContainer,
          encre: theme.colorScheme.onErrorContainer,
        );
      case OrderStatus.refunded:
        return (
          libelle: 'Remboursée',
          fond: theme.colorScheme.surfaceContainerHighest,
          encre: theme.colorScheme.onSurfaceVariant,
        );
      case OrderStatus.preparing:
      case OrderStatus.ready:
        return (
          libelle: statut == OrderStatus.ready ? 'Prête' : 'En préparation',
          fond: theme.colorScheme.tertiaryContainer,
          encre: theme.colorScheme.onTertiaryContainer,
        );
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay:
        return (
          libelle: statut == OrderStatus.pickedUp ? 'Récupérée' : 'En route',
          fond: theme.colorScheme.primaryContainer,
          encre: theme.colorScheme.onPrimaryContainer,
        );
      case OrderStatus.pending:
      case OrderStatus.confirmed:
        return (
          libelle: statut == OrderStatus.pending ? 'En attente' : 'Confirmée',
          fond: theme.colorScheme.secondaryContainer,
          encre: theme.colorScheme.onSecondaryContainer,
        );
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FilterBottomSheet(
        orderHistoryService: _orderHistoryService,
      ),
    );
  }




  /// Réorganise les items d'une commande dans le panier
  /// Repose les articles de [order] au panier.
  ///
  /// La logique vit dans `CartService.reprendreLaCommande`, partagée avec
  /// l'onglet « Commandes » de la barre inférieure. Cet écran ne fait plus
  /// qu'annoncer le résultat.
  Future<void> _reorderItems(Order order) async {
    final cartService = Provider.of<CartService>(context, listen: false);
    final appService = Provider.of<AppService>(context, listen: false);

    final resultat = cartService.reprendreLaCommande(
      [
        for (final item in order.items)
          (
            menuItemId: item.menuItemId,
            nom: item.name,
            quantite: item.quantity,
            options: item.customizations,
          ),
      ],
      appService.menuItems,
    );

    if (!mounted) return;
    annoncerLaReprise(context, resultat);
  }
}

/// Bottom sheet pour les filtres
class _FilterBottomSheet extends StatefulWidget {
  final OrderHistoryService orderHistoryService;

  const _FilterBottomSheet({required this.orderHistoryService});

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late OrderFilter _selectedFilter;
  late OrderSortOption _selectedSort;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.orderHistoryService.currentFilter;
    _selectedSort = widget.orderHistoryService.sortOption;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtres et Tri',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Filtres par statut
          Text(
            'Statut',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...OrderFilter.values.map((filter) {
                final isSelected = _selectedFilter == filter;
                return FilterChip(
                  label: Text(_getFilterLabel(filter)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                    widget.orderHistoryService.applyFilter(filter);
                  },
                );
              }),
            ],
          ),

          const SizedBox(height: 24),

          // Options de tri
          Text(
            'Trier par',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          DropdownButton<OrderSortOption>(
            value: _selectedSort,
            isExpanded: true,
            items: [
              ...OrderSortOption.values.map((sort) {
                return DropdownMenuItem(
                  value: sort,
                  child: Text(_getSortLabel(sort)),
                );
              }),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedSort = value;
                });
                widget.orderHistoryService.applySort(value);
              }
            },
          ),

          const SizedBox(height: 24),

          // Boutons d'action
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.orderHistoryService.resetFilters();
                    setState(() {
                      _selectedFilter = OrderFilter.all;
                      _selectedSort = OrderSortOption.dateDesc;
                    });
                  },
                  child: const Text('Réinitialiser'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Appliquer'),
                ),
              ),
            ],
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  String _getFilterLabel(OrderFilter filter) {
    switch (filter) {
      case OrderFilter.all:
        return 'Toutes';
      case OrderFilter.active:
        return 'En cours';
      case OrderFilter.completed:
        return 'Terminées';
      case OrderFilter.cancelled:
        return 'Annulées';
    }
  }

  String _getSortLabel(OrderSortOption sort) {
    switch (sort) {
      case OrderSortOption.dateDesc:
        return 'Plus récentes en premier';
      case OrderSortOption.dateAsc:
        return 'Plus anciennes en premier';
      case OrderSortOption.totalDesc:
        return 'Plus chères en premier';
      case OrderSortOption.totalAsc:
        return 'Moins chères en premier';
      case OrderSortOption.status:
        return 'Par statut';
    }
  }
}
