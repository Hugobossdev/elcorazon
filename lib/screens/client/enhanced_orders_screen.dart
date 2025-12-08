import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/order_history_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/widgets/delivery_status_card.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/repositories/supabase_order_repository.dart';
import 'package:elcora_fast/navigation/app_router.dart';

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
    final orderRepository = SupabaseOrderRepository();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mes Commandes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtres',
            onPressed: () => _showFilterDialog(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.3),
                    Colors.white.withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              indicatorColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
              tabs: const [
                Tab(
                  text: 'En cours',
                  icon: Icon(Icons.access_time_rounded, size: 20),
                ),
                Tab(
                  text: 'Historique',
                  icon: Icon(Icons.history_rounded, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveOrders(),
          _buildOrderHistory(),
        ],
      ),
    );
  }

  Widget _buildActiveOrders() {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final activeOrders = appService.orders
            .where((order) =>
                order.status != OrderStatus.delivered &&
                order.status != OrderStatus.cancelled,)
            .toList();

        if (activeOrders.isEmpty) {
          return _buildEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'Aucune commande en cours',
            subtitle: 'Vos commandes actives apparaîtront ici',
            actionLabel: 'Explorer le menu',
            onAction: () => context.navigateToMenu(),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeOrders.length,
          itemBuilder: (context, index) {
            final order = activeOrders[index];
            return DeliveryStatusCard(
              order: order,
              onTap: () => context.navigateToDeliveryTracking(order.id),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderHistory() {
    return ChangeNotifierProvider<OrderHistoryService>.value(
      value: _orderHistoryService,
      child: Consumer<OrderHistoryService>(
        builder: (context, service, child) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = service.orders;

          if (orders.isEmpty) {
            return _buildEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Aucune commande trouvée',
              subtitle: 'Aucune commande ne correspond à vos filtres',
              actionLabel: 'Réinitialiser les filtres',
              onAction: () {
                service.resetFilters();
              },
            );
          }

          // Grouper par date
          final groupedOrders = service.getOrdersGroupedByDate();
          final sortedDates = groupedOrders.keys.toList()
            ..sort((a, b) {
              // Trier les dates (Aujourd'hui, Hier, etc. en premier)
              if (a == 'Aujourd\'hui') return -1;
              if (b == 'Aujourd\'hui') return 1;
              if (a == 'Hier') return -1;
              if (b == 'Hier') return 1;
              return b.compareTo(a);
            });

          return RefreshIndicator(
            onRefresh: _loadOrders,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final dateKey = sortedDates[index];
                final dateOrders = groupedOrders[dateKey]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête de date
                    Padding(
                      padding: EdgeInsets.only(bottom: 8, top: index > 0 ? 24 : 0),
                      child: Text(
                        dateKey,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),

                    // Commandes du jour
                    ...dateOrders.map((order) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildOrderCard(order),
                      );
                    }),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => context.navigateToDeliveryTracking(order.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec statut et date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Statut
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(order.status),
                      ),
                    ),
                    child: Text(
                      _getStatusLabel(order.status),
                      style: TextStyle(
                        color: _getStatusColor(order.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // Date
                  Text(
                    dateFormat.format(order.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Items
              ...order.items.take(3).map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        '${item.quantity}x',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.menuItemName,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        PriceFormatter.format(item.totalPrice),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                );
              }),

              if (order.items.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+ ${order.items.length - 3} autre(s) article(s)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),

              const Divider(height: 24),

              // Total et actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      Text(
                        PriceFormatter.format(order.total),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                      ),
                    ],
                  ),

                  // Actions
                  Row(
                    children: [
                      if (order.status == OrderStatus.delivered)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.reorder),
                          label: const Text('Commander à nouveau'),
                          onPressed: () => _reorderItems(order),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => context.navigateToDeliveryTracking(order.id),
                        tooltip: 'Voir les détails',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.pickedUp:
        return Colors.teal;
      case OrderStatus.onTheWay:
        return Colors.indigo;
      case OrderStatus.delivered:
        return Colors.green.shade700;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.confirmed:
        return 'Confirmée';
      case OrderStatus.preparing:
        return 'En préparation';
      case OrderStatus.ready:
        return 'Prête';
      case OrderStatus.pickedUp:
        return 'Récupérée';
      case OrderStatus.onTheWay:
        return 'En livraison';
      case OrderStatus.delivered:
        return 'Livrée';
      case OrderStatus.cancelled:
        return 'Annulée';
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.explore),
              label: Text(actionLabel),
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Réorganise les items d'une commande dans le panier
  Future<void> _reorderItems(Order order) async {
    try {
      final cartService = Provider.of<CartService>(context, listen: false);
      final appService = Provider.of<AppService>(context, listen: false);
      
      int addedCount = 0;
      
      // Ajouter chaque item de la commande au panier
      for (final orderItem in order.items) {
        try {
          // Chercher le menu item correspondant
          MenuItem? menuItem;
          if (orderItem.menuItemId.isNotEmpty) {
            try {
              menuItem = appService.menuItems.firstWhere(
                (item) => item.id == orderItem.menuItemId,
              );
            } catch (e) {
              // Si l'item n'existe plus, créer un item temporaire
              menuItem = MenuItem(
                id: orderItem.menuItemId,
                name: orderItem.name,
                price: orderItem.unitPrice,
                description: '',
                categoryId: 'temp-category',
                category: null,
                imageUrl: orderItem.menuItemImage,
                isAvailable: true,
                isVegetarian: false,
                isVegan: false,
              );
            }
          } else {
            // Créer un menu item temporaire si l'ID n'existe pas
            menuItem = MenuItem(
              id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
              name: orderItem.name,
              price: orderItem.unitPrice,
              description: '',
              categoryId: 'temp-category',
              category: null,
              imageUrl: orderItem.menuItemImage,
              isAvailable: true,
              isVegetarian: false,
              isVegan: false,
            );
          }
          
          // Ajouter au panier avec la quantité de la commande
          for (int i = 0; i < orderItem.quantity; i++) {
            cartService.addItem(
              menuItem,
              quantity: 1,
              customizations: orderItem.customizations,
            );
            addedCount++;
          }
        } catch (e) {
          debugPrint('Erreur lors de l\'ajout de l\'item ${orderItem.name}: $e');
        }
      }
      
      if (addedCount > 0 && mounted) {
        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$addedCount article(s) ajouté(s) au panier'),
            backgroundColor: AppColors.primary,
            action: SnackBarAction(
              label: 'Voir le panier',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).pushNamed(AppRouter.cart);
              },
            ),
          ),
        );
        
        // Naviguer vers le panier après un court délai
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pushNamed(AppRouter.cart);
          }
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun article n\'a pu être ajouté au panier'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la réorganisation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

