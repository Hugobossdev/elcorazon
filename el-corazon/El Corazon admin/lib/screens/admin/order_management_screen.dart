import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/app_service.dart';
import '../../models/order.dart';
import '../../widgets/custom_button.dart';
import '../../utils/dialog_helper.dart';
import 'driver_assignment_dialog.dart';
import '../../services/order_management_service.dart';
import '../../services/paydunya_service.dart';
import '../../widgets/order_timeline_widget.dart';
import '../../utils/price_formatter.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTimeRange = 'today';
  String _selectedZone = 'all';
  final _searchController = TextEditingController();

  // Cache des noms de clients (userId -> name)
  final Map<String, String> _clientNamesCache = {};
  bool _isLoadingClientNames = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    // IMPORTANT: Écouter les changements d'onglet pour mettre à jour le switch
    _tabController.addListener(() {
      if (!mounted) return;
      // Reporter setState après le build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    });

    // Charger les noms de clients après le premier build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClientNames();
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: scheme.tertiary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Gestion des commandes',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  fontSize: 20,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: scheme.tertiary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualiser',
              onPressed: () {
                final orderService = context.read<OrderManagementService>();
                orderService.refresh();
                setState(() {});
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: scheme.tertiary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Exporter',
              onPressed: () => _exportOrders(),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: scheme.tertiary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: scheme.onSurface,
              unselectedLabelColor: scheme.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              tabs: const [
                Tab(text: 'Toutes'),
                Tab(text: 'En attente'),
                Tab(text: 'En préparation'),
                Tab(text: 'En livraison'),
                Tab(text: 'Livrées'),
              ],
            ),
          ),
        ),
      ),
      body: Consumer2<AppService, OrderManagementService>(
        builder: (context, appService, orderService, child) {
          // Utiliser OrderManagementService au lieu de AppService pour les commandes
          final allOrders = orderService.allOrders;
          final filteredOrders = _filterOrders(allOrders);
          final isLoading = orderService.isLoading;

          return Column(
            children: [
              // Filters
              _buildFiltersSection(),

              // Loading indicator
              if (isLoading)
                LinearProgressIndicator(
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.tertiary),
                ),

              // Orders list
              Expanded(
                child: isLoading && allOrders.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            scheme.tertiary,
                          ),
                        ),
                      )
                    : SizedBox.expand(
                        child: Builder(
                          builder: (context) {
                            // IMPORTANT: Construire seulement l'onglet visible pour éviter les problèmes de hit testing
                            switch (_tabController.index) {
                              case 0:
                                return _buildOrdersList(
                                  filteredOrders,
                                  appService,
                                );
                              case 1:
                                return _buildOrdersList(
                                  filteredOrders
                                      .where(
                                        (o) => o.status == OrderStatus.pending,
                                      )
                                      .toList(),
                                  appService,
                                );
                              case 2:
                                return _buildOrdersList(
                                  filteredOrders
                                      .where(
                                        (o) =>
                                            o.status == OrderStatus.preparing,
                                      )
                                      .toList(),
                                  appService,
                                );
                              case 3:
                                return _buildOrdersList(
                                  filteredOrders
                                      .where(
                                        (o) => o.status == OrderStatus.onTheWay,
                                      )
                                      .toList(),
                                  appService,
                                );
                              case 4:
                                return _buildOrdersList(
                                  filteredOrders
                                      .where(
                                        (o) =>
                                            o.status == OrderStatus.delivered,
                                      )
                                      .toList(),
                                  appService,
                                );
                              default:
                                return _buildOrdersList(
                                  filteredOrders,
                                  appService,
                                );
                            }
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFiltersSection() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.tertiary,
                        scheme.tertiary.withValues(alpha: 0.70),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: scheme.onTertiary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Filtres de recherche',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: scheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Search bar
            TextField(
              controller: _searchController,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: 'Rechercher une commande',
                hintText: 'ID, adresse...',
                labelStyle: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                hintStyle: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: scheme.tertiary,
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outline.withValues(alpha: 0.30),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.tertiary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              onChanged: (value) {
                setState(() {});
                // Charger les noms de clients manquants si nécessaire
                _loadClientNamesIfNeeded();
              },
            ),
            const SizedBox(height: 20),

            // Filters row
            Row(
              children: [
                // Time range filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedTimeRange,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Période',
                      labelStyle: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.outline.withValues(alpha: 0.30),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.tertiary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'today',
                        child: Text('Aujourd\'hui'),
                      ),
                      DropdownMenuItem(
                        value: 'week',
                        child: Text('Cette semaine'),
                      ),
                      DropdownMenuItem(value: 'month', child: Text('Ce mois')),
                      DropdownMenuItem(value: 'all', child: Text('Toutes')),
                    ],
                    dropdownColor: scheme.surfaceContainerHigh,
                    onChanged: (value) {
                      setState(() {
                        _selectedTimeRange = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Zone filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedZone,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Zone',
                      labelStyle: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.outline.withValues(alpha: 0.30),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.tertiary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('Toutes les zones'),
                      ),
                      DropdownMenuItem(
                        value: 'zone1',
                        child: Text('Zone 1 - Centre'),
                      ),
                      DropdownMenuItem(
                        value: 'zone2',
                        child: Text('Zone 2 - Nord'),
                      ),
                      DropdownMenuItem(
                        value: 'zone3',
                        child: Text('Zone 3 - Sud'),
                      ),
                    ],
                    dropdownColor: scheme.surfaceContainerHigh,
                    onChanged: (value) {
                      setState(() {
                        _selectedZone = value!;
                      });
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

  Widget _buildOrdersList(List<Order> orders, AppService appService) {
    if (orders.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 72,
                color: scheme.tertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune commande trouvée',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ajustez les filtres pour voir plus de résultats',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final scheme = Theme.of(context).colorScheme;
        final statusColor = _getStatusColor(order.status);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          constraints: const BoxConstraints(minHeight: 80),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: scheme.surface.withValues(alpha: 0.0),
              cardColor: scheme.surface.withValues(alpha: 0.0),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              childrenPadding: const EdgeInsets.all(20),
              leading: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withValues(alpha: 0.3),
                      statusColor.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    order.status.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Commande #${order.id.substring(0, 8).toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.5,
                        color: scheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: statusColor, width: 1.5),
                      ),
                      child: Text(
                        order.status.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.monetization_on_rounded,
                              size: 18,
                              color: scheme.tertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              PriceFormatter.format(order.total),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: scheme.tertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_bag_rounded,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${order.items.length} ${order.items.length > 1 ? 'articles' : 'article'}',
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(order.orderTime),
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              trailing: _buildOrderActions(order, appService),
              children: [
                // Order details
                SizedBox(
                  width: double.infinity,
                  child: _buildOrderDetails(order),
                ),
                const SizedBox(height: 16),

                // Order items
                SizedBox(
                  width: double.infinity,
                  child: _buildOrderItems(order),
                ),
                const SizedBox(height: 16),

                // Order timeline
                SizedBox(
                  width: double.infinity,
                  child: _buildOrderTimeline(order),
                ),
                const SizedBox(height: 16),

                // Action buttons
                SizedBox(
                  width: double.infinity,
                  child: _buildOrderActionButtons(order, appService),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderDetails(Order order) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Détails de la commande',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDetailRow('Client:', order.userId, Icons.person),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Adresse:',
                        order.deliveryAddress,
                        Icons.location_on,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Paiement:',
                        order.paymentMethod.displayName,
                        Icons.payment,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDetailRow(
                        'Sous-total:',
                        PriceFormatter.format(order.subtotal),
                        Icons.receipt,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Livraison:',
                        PriceFormatter.format(order.deliveryFee),
                        Icons.local_shipping,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Total:',
                        PriceFormatter.format(order.total),
                        Icons.monetization_on,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFFF6A00)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                    color: isBold ? const Color(0xFFFF6A00) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItems(Order order) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Articles commandés',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            ...order.items.map((item) {
              final customizations = item.getFormattedCustomizations();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF6A00).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6A00), Color(0xFFFF8A50)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
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
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${PriceFormatter.format(item.unitPrice)} × ${item.quantity}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            PriceFormatter.format(item.totalPrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFFFF6A00),
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    // Afficher les customizations si elles existent
                    if (customizations.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.tune,
                                  size: 16,
                                  color: const Color(0xFFFF6A00)
                                      .withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Personnalisations',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...customizations.map((custom) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 4,
                                        margin: const EdgeInsets.only(
                                            top: 6, right: 8),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFF6A00),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          custom,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                    // Afficher les notes si elles existent
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.note,
                              size: 16,
                              color: Colors.blue.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.notes!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTimeline(Order order) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Historique de la commande',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimelineItem('Commande passée', order.orderTime, true),
            _buildTimelineItem(
              'Commande confirmée',
              order.orderTime.add(const Duration(minutes: 5)),
              order.status.index >= 1,
            ),
            _buildTimelineItem(
              'En préparation',
              order.orderTime.add(const Duration(minutes: 10)),
              order.status.index >= 2,
            ),
            _buildTimelineItem(
              'Prête',
              order.orderTime.add(const Duration(minutes: 25)),
              order.status.index >= 3,
            ),
            _buildTimelineItem(
              'En livraison',
              order.orderTime.add(const Duration(minutes: 30)),
              order.status.index >= 4,
            ),
            _buildTimelineItem(
              'Livrée',
              order.orderTime.add(const Duration(minutes: 45)),
              order.status == OrderStatus.delivered,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(String title, DateTime time, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF4CAF50) : Colors.transparent,
              border: Border.all(
                color: isCompleted
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF666666),
                width: 2,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isCompleted ? Icons.check : null,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isCompleted
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                fontWeight: isCompleted ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatTime(time),
                style: TextStyle(
                  color: isCompleted
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF666666),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActions(Order order, AppService appService) {
    return SizedBox(
      width: 40,
      height: 40,
      child: PopupMenuButton(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        itemBuilder: (context) {
          final actions = <PopupMenuEntry>[];

          switch (order.status) {
            case OrderStatus.pending:
              actions.addAll([
                const PopupMenuItem(
                  value: 'confirm',
                  child: ListTile(
                    leading: Icon(Icons.check, color: Colors.green),
                    title: Text('Confirmer'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: ListTile(
                    leading: Icon(Icons.cancel, color: Colors.red),
                    title: Text('Annuler'),
                    dense: true,
                  ),
                ),
              ]);
              break;
            case OrderStatus.confirmed:
              actions.add(
                const PopupMenuItem(
                  value: 'prepare',
                  child: ListTile(
                    leading: Icon(Icons.restaurant, color: Colors.orange),
                    title: Text('Mettre en préparation'),
                    dense: true,
                  ),
                ),
              );
              break;
            case OrderStatus.preparing:
              actions.add(
                const PopupMenuItem(
                  value: 'ready',
                  child: ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Marquer comme prête'),
                    dense: true,
                  ),
                ),
              );
              break;
            case OrderStatus.ready:
              actions.add(
                const PopupMenuItem(
                  value: 'assign',
                  child: ListTile(
                    leading: Icon(Icons.delivery_dining, color: Colors.blue),
                    title: Text('Assigner un livreur'),
                    dense: true,
                  ),
                ),
              );
              break;
            case OrderStatus.onTheWay:
              actions.add(
                const PopupMenuItem(
                  value: 'delivered',
                  child: ListTile(
                    leading: Icon(Icons.home, color: Colors.green),
                    title: Text('Marquer comme livrée'),
                    dense: true,
                  ),
                ),
              );
              break;
            default:
              break;
          }

          actions.addAll([
            const PopupMenuItem(
              value: 'refund',
              child: ListTile(
                leading: Icon(Icons.money_off, color: Colors.orange),
                title: Text('Rembourser'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'details',
              child: ListTile(
                leading: Icon(Icons.info),
                title: Text('Détails'),
                dense: true,
              ),
            ),
          ]);

          return actions;
        },
        onSelected: (value) {
          switch (value) {
            case 'confirm':
              _acceptOrder(order);
              break;
            case 'cancel':
              _rejectOrder(order);
              break;
            case 'prepare':
              _prepareOrder(order, appService);
              break;
            case 'ready':
              _readyOrder(order, appService);
              break;
            case 'assign':
              _assignDriver(order, appService);
              break;
            case 'delivered':
              _deliverOrder(order, appService);
              break;
            case 'refund':
              _refundOrder(order, appService);
              break;
            case 'details':
              _showOrderDetails(order);
              break;
          }
        },
      ),
    );
  }

  Widget _buildOrderActionButtons(Order order, AppService appService) {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: 'Voir sur la carte',
            onPressed: () => _showOnMap(order),
            icon: Icons.map_rounded,
            color: const Color(0xFFFF6A00),
            backgroundColor: const Color(0xFFFF6A00),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomButton(
            text: 'Contacter client',
            onPressed: () => _contactCustomer(order),
            icon: Icons.phone_rounded,
            color: const Color(0xFF2196F3),
            backgroundColor: const Color(0xFF2196F3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }

  List<Order> _filterOrders(List<Order> orders) {
    var filtered = orders.where((order) {
      // Search filter
      if (_searchController.text.isNotEmpty) {
        final searchText = _searchController.text.toLowerCase();
        final matchesId = order.id.toLowerCase().contains(searchText);
        final matchesAddress = order.deliveryAddress.toLowerCase().contains(
              searchText,
            );

        // Recherche par nom de client (utilise le cache)
        bool matchesClientName = false;
        final clientName = _clientNamesCache[order.userId];
        if (clientName != null) {
          matchesClientName = clientName.toLowerCase().contains(searchText);
        }

        if (!matchesId && !matchesAddress && !matchesClientName) {
          return false;
        }
      }

      // Zone filter
      if (_selectedZone != 'all') {
        final orderZone = _getZoneFromAddress(order.deliveryAddress);
        if (orderZone != _selectedZone) {
          return false;
        }
      }

      // Time range filter
      final now = DateTime.now();
      switch (_selectedTimeRange) {
        case 'today':
          if (!_isToday(order.orderTime)) return false;
          break;
        case 'week':
          if (now.difference(order.orderTime).inDays > 7) return false;
          break;
        case 'month':
          if (now.difference(order.orderTime).inDays > 30) return false;
          break;
      }

      return true;
    }).toList();

    // Sort by most recent
    filtered.sort((a, b) => b.orderTime.compareTo(a.orderTime));

    return filtered;
  }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year;
  }

  /// Détermine la zone à partir de l'adresse de livraison
  /// Utilise des mots-clés simples pour identifier la zone
  String _getZoneFromAddress(String address) {
    final addressLower = address.toLowerCase();

    // Mots-clés pour Zone 1 - Centre
    final centreKeywords = [
      'centre',
      'center',
      'downtown',
      'centre-ville',
      'ville',
      'plateau',
      'indépendance',
      'place',
      'avenue',
      'boulevard',
    ];

    // Mots-clés pour Zone 2 - Nord
    final nordKeywords = [
      'nord',
      'north',
      'nord-foire',
      'foire',
      'parcelles',
      'assainies',
      'yoff',
      'cambérène',
      'mermoz',
      'sacré-coeur',
      'almadies',
    ];

    // Mots-clés pour Zone 3 - Sud
    final sudKeywords = [
      'sud',
      'south',
      'medina',
      'grand-yoff',
      'pikine',
      'guediawaye',
      'thiaroye',
      'rufisque',
      'bargny',
      'diamniadio',
    ];

    // Vérifier Zone 1 - Centre
    for (final keyword in centreKeywords) {
      if (addressLower.contains(keyword)) {
        return 'zone1';
      }
    }

    // Vérifier Zone 2 - Nord
    for (final keyword in nordKeywords) {
      if (addressLower.contains(keyword)) {
        return 'zone2';
      }
    }

    // Vérifier Zone 3 - Sud
    for (final keyword in sudKeywords) {
      if (addressLower.contains(keyword)) {
        return 'zone3';
      }
    }

    // Par défaut, retourner 'zone1' si aucune zone n'est identifiée
    // Cela permet de ne pas exclure les commandes dont l'adresse n'est pas reconnue
    return 'zone1';
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
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.refunded:
        return Colors.grey;
      case OrderStatus.failed:
        return Colors.brown;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}min';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  // Order action methods
  Future<void> _acceptOrder(Order order) async {
    final orderService = context.read<OrderManagementService>();
    final success = await orderService.acceptOrder(order.id);

    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Commande #${order.id.substring(0, 8).toUpperCase()} acceptée'
                : '❌ Erreur lors de l\'acceptation',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectOrder(Order order) async {
    final reasonController = TextEditingController();
    final confirmed = await DialogHelper.showSafeDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Refuser la commande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voulez-vous refuser la commande #${order.id.substring(0, 8).toUpperCase()} ?',
            ),
            const SizedBox(height: 16),
            const Text('Raison du refus (optionnel):'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Entrez la raison du refus...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted || !context.mounted) return;
      final orderService = context.read<OrderManagementService>();
      final success = await orderService.rejectOrder(
        order.id,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );

      if (!mounted || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Commande #${order.id.substring(0, 8).toUpperCase()} refusée'
                : '❌ Erreur lors du refus',
          ),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
    }
  }

  Future<void> _prepareOrder(Order order, AppService appService) async {
    final confirmed = await DialogHelper.showSafeDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mettre en préparation'),
        content: Text(
          'Voulez-vous mettre la commande #${order.id.substring(0, 8).toUpperCase()} en préparation ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted || !context.mounted) return;
      final orderService = context.read<OrderManagementService>();
      final success = await orderService.startPreparingOrder(order.id);

      if (!mounted || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Commande #${order.id.substring(0, 8).toUpperCase()} mise en préparation'
                : '❌ Erreur lors de la mise en préparation',
          ),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
    }
  }

  Future<void> _readyOrder(Order order, AppService appService) async {
    final confirmed = await DialogHelper.showSafeDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Marquer comme prête'),
        content: Text(
          'Voulez-vous marquer la commande #${order.id.substring(0, 8).toUpperCase()} comme prête ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted || !context.mounted) return;
      final orderService = context.read<OrderManagementService>();
      final success = await orderService.markOrderReady(order.id);

      if (!mounted || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Commande #${order.id.substring(0, 8).toUpperCase()} marquée comme prête'
                : '❌ Erreur lors de la mise à jour',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _assignDriver(Order order, AppService appService) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => DriverAssignmentDialog(order: order),
    );
  }

  Future<void> _deliverOrder(Order order, AppService appService) async {
    final confirmed = await DialogHelper.showSafeDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Marquer comme livrée'),
        content: Text(
          'Voulez-vous marquer la commande #${order.id.substring(0, 8).toUpperCase()} comme livrée ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted || !context.mounted) return;
      final orderService = context.read<OrderManagementService>();
      final success = await orderService.markOrderDelivered(order.id);

      if (!mounted || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Commande #${order.id.substring(0, 8).toUpperCase()} marquée comme livrée'
                : '❌ Erreur lors de la mise à jour',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _refundOrder(Order order, AppService appService) async {
    final refundType = await DialogHelper.showSafeDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rembourser la commande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Commande #${order.id.substring(0, 8).toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Montant total: ${PriceFormatter.format(order.total)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text('Type de remboursement:'),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text('Remboursement total'),
              subtitle: Text(PriceFormatter.format(order.total)),
              onTap: () => Navigator.of(dialogContext).pop('total'),
            ),
            ListTile(
              leading: const Icon(
                Icons.account_balance_wallet,
                color: Colors.blue,
              ),
              title: const Text('Remboursement partiel'),
              subtitle: const Text('Choisir le montant'),
              onTap: () => Navigator.of(dialogContext).pop('partial'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (refundType == null) return;

    // Vérifier que le widget est toujours monté avant d'utiliser context
    if (!mounted || !context.mounted) return;

    double refundAmount = order.total;
    if (refundType == 'partial') {
      final amountController = TextEditingController(
        text: order.total.toStringAsFixed(2),
      );
      final confirmed = await DialogHelper.showSafeDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Montant du remboursement'),
          content: TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Montant (CFA)',
              border: OutlineInputBorder(),
              prefixText: '',
              suffixText: ' CFA',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0 && amount <= order.total) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      refundAmount = double.tryParse(amountController.text) ?? order.total;
    }

    // Intégrer avec PayDunya
    if (!mounted || !context.mounted) return;

    // Vérifier que la commande a un transaction_id PayDunya
    final transactionId = order.paymentTransactionId;
    if (transactionId == null || transactionId.isEmpty) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Cette commande n\'a pas de transaction PayDunya associée. Impossible de rembourser.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final paydunyaService = Provider.of<PayDunyaService>(
      context,
      listen: false,
    );
    final refundResult = await paydunyaService.refundTransaction(
      transactionId: transactionId,
      amount: refundAmount,
      reason: refundType == 'partial'
          ? 'Remboursement partiel'
          : 'Remboursement total',
    );

    if (!mounted || !context.mounted) return;

    if (refundResult != null && refundResult.isSuccess) {
      if (!mounted || !context.mounted) return;
      final orderService = context.read<OrderManagementService>();
      await orderService.processRefund(order.id, refundAmount);

      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Remboursement de ${PriceFormatter.format(refundAmount)} effectué',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erreur lors du remboursement'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOrderDetails(Order order) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Commande #${order.id.substring(0, 8).toUpperCase()}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informations générales
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getStatusIcon(order.status),
                                color: _getStatusColor(order.status),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Statut: ${order.status.displayName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            'Total',
                            PriceFormatter.format(order.total),
                            Icons.monetization_on,
                          ),
                          _buildDetailRow(
                            'Sous-total',
                            PriceFormatter.format(order.subtotal),
                            Icons.receipt,
                          ),
                          _buildDetailRow(
                            'Frais de livraison',
                            PriceFormatter.format(order.deliveryFee),
                            Icons.local_shipping,
                          ),
                          if (order.discount > 0)
                            _buildDetailRow(
                              'Réduction',
                              '-${PriceFormatter.format(order.discount)}',
                              Icons.discount,
                            ),
                          _buildDetailRow(
                            'Articles',
                            '${order.items.length}',
                            Icons.restaurant,
                          ),
                          _buildDetailRow(
                            'Paiement',
                            order.paymentMethod.displayName,
                            Icons.payment,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Timeline
                  OrderTimelineWidget(order: order),
                  const SizedBox(height: 16),
                  // Articles
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Articles',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...order.items.map((item) {
                            final customizations =
                                item.getFormattedCustomizations();
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ExpansionTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF6A00),
                                        Color(0xFFFF8A50)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${PriceFormatter.format(item.unitPrice)} × ${item.quantity} = ${PriceFormatter.format(item.totalPrice)}',
                                    ),
                                    if (customizations.isNotEmpty ||
                                        (item.notes != null &&
                                            item.notes!.isNotEmpty))
                                      const SizedBox(height: 4),
                                    if (customizations.isNotEmpty)
                                      Text(
                                        '${customizations.length} personnalisation(s)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  PriceFormatter.format(item.totalPrice),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFFFF6A00),
                                  ),
                                ),
                                children: [
                                  if (customizations.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.tune,
                                                size: 16,
                                                color: Colors.grey[700],
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Personnalisations',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ...customizations.map((custom) =>
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 4, left: 22),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      width: 4,
                                                      height: 4,
                                                      margin:
                                                          const EdgeInsets.only(
                                                              top: 6, right: 8),
                                                      decoration:
                                                          const BoxDecoration(
                                                        color:
                                                            Color(0xFFFF6A00),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        custom,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              Colors.grey[800],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (item.notes != null &&
                                      item.notes!.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.blue[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.note,
                                              size: 16,
                                              color: Colors.blue[700],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                item.notes!,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[800],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Informations de livraison
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Livraison',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Adresse',
                            order.deliveryAddress,
                            Icons.location_on,
                          ),
                          if (order.deliveryNotes != null)
                            _buildDetailRow(
                              'Notes',
                              order.deliveryNotes!,
                              Icons.note,
                            ),
                          if (order.deliveryPersonId != null)
                            _buildDetailRow(
                              'Livreur',
                              'Assigné',
                              Icons.delivery_dining,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return Icons.check_circle_outline;
      case OrderStatus.pickedUp:
        return Icons.shopping_bag;
      case OrderStatus.onTheWay:
        return Icons.directions_bike;
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.refunded:
        return Icons.payment;
      case OrderStatus.failed:
        return Icons.error;
    }
  }

  Future<void> _showOnMap(Order order) async {
    try {
      // Encoder l'adresse pour l'URL Google Maps
      final encodedAddress = Uri.encodeComponent(order.deliveryAddress);
      final googleMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$encodedAddress';

      final uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d\'ouvrir Google Maps'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _contactCustomer(Order order) async {
    try {
      // Récupérer les informations du client depuis Supabase
      final supabase = Supabase.instance.client;
      Map<String, dynamic> userData;
      try {
        userData = await supabase
            .from('users')
            .select('name, phone, email')
            .eq('auth_user_id', order.userId)
            .single();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Informations client non trouvées'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final phone = userData['phone'] as String?;
      final email = userData['email'] as String?;
      final name = userData['name'] as String? ?? 'Client';

      if (mounted) {
        final action = await DialogHelper.showSafeDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Contacter $name'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (phone != null && phone.isNotEmpty) ...[
                  ListTile(
                    leading: const Icon(Icons.phone, color: Colors.green),
                    title: const Text('Appeler'),
                    subtitle: Text(phone),
                    onTap: () => Navigator.of(context).pop('call'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.sms, color: Colors.blue),
                    title: const Text('Envoyer un SMS'),
                    subtitle: Text(phone),
                    onTap: () => Navigator.of(context).pop('sms'),
                  ),
                ],
                if (email != null && email.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.email, color: Colors.orange),
                    title: const Text('Envoyer un email'),
                    subtitle: Text(email),
                    onTap: () => Navigator.of(context).pop('email'),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
            ],
          ),
        );

        if (action != null) {
          if ((action == 'call' || action == 'sms') &&
              phone != null &&
              phone.isNotEmpty) {
            if (action == 'call') {
              final uri = Uri.parse('tel:$phone');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Impossible d\'ouvrir l\'application téléphone',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } else if (action == 'sms') {
              final uri = Uri.parse('sms:$phone');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Impossible d\'ouvrir l\'application SMS'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          } else if (action == 'email' && email != null && email.isNotEmpty) {
            final uri = Uri.parse(
              'mailto:$email?subject=Commande #${order.id.substring(0, 8).toUpperCase()}',
            );
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Impossible d\'ouvrir l\'application email'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de la récupération des informations: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportOrders() async {
    try {
      final orderService = context.read<OrderManagementService>();
      final allOrders = orderService.allOrders;
      final filteredOrders = _filterOrders(allOrders);

      if (filteredOrders.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucune commande à exporter'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Créer le contenu CSV
      final csvBuffer = StringBuffer();
      csvBuffer.writeln('ID,Date,Client,Adresse,Statut,Total,Articles');

      for (final order in filteredOrders) {
        try {
          // Récupérer le nom du client
          final supabase = Supabase.instance.client;
          final userData = await supabase
              .from('users')
              .select('name')
              .eq('auth_user_id', order.userId)
              .single();
          final clientName = userData['name'] as String? ?? 'Inconnu';

          csvBuffer.writeln(
            [
              order.id,
              order.orderTime.toIso8601String(),
              clientName.replaceAll(',', ';'),
              order.deliveryAddress.replaceAll(',', ';'),
              order.status.displayName,
              PriceFormatter.format(order.total)
                  .replaceAll(' ', ''), // Remove spaces for CSV
              order.items.length,
            ].join(','),
          );
        } catch (e) {
          // Si on ne peut pas récupérer le nom, continuer sans
          csvBuffer.writeln(
            [
              order.id,
              order.orderTime.toIso8601String(),
              'Inconnu',
              order.deliveryAddress.replaceAll(',', ';'),
              order.status.displayName,
              PriceFormatter.format(order.total)
                  .replaceAll(' ', ''), // Remove spaces for CSV
              order.items.length,
            ].join(','),
          );
        }
      }

      // Pour le web, on peut utiliser le partage ou le téléchargement
      // Pour mobile, on peut utiliser share_plus
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${filteredOrders.length} commande(s) exportée(s)'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Copier',
              onPressed: () {
                // Copier le CSV dans le presse-papier
                // Note: clipboard nécessite un package supplémentaire
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'CSV généré (fonctionnalité de copie à implémenter)',
                    ),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
          ),
        );
      }

      // Log pour debug
      debugPrint('CSV Export:\n${csvBuffer.toString()}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Charger les noms de clients pour toutes les commandes
  Future<void> _loadClientNames() async {
    if (_isLoadingClientNames) return;

    final orderService = context.read<OrderManagementService>();
    final allOrders = orderService.allOrders;

    if (allOrders.isEmpty) return;

    // Identifier les userIds manquants dans le cache
    final missingUserIds = allOrders
        .map((order) => order.userId)
        .where((userId) => !_clientNamesCache.containsKey(userId))
        .toSet()
        .toList();

    if (missingUserIds.isEmpty) return;

    _isLoadingClientNames = true;

    try {
      final supabase = Supabase.instance.client;

      // Charger les noms par lots pour éviter les requêtes trop nombreuses
      const batchSize = 50;
      for (int i = 0; i < missingUserIds.length; i += batchSize) {
        final batch = missingUserIds.skip(i).take(batchSize).toList();

        final response = await supabase
            .from('users')
            .select('auth_user_id, name')
            .inFilter('auth_user_id', batch);

        for (final userData in response) {
          final userId = userData['auth_user_id'] as String?;
          final name = userData['name'] as String? ?? 'Inconnu';
          if (userId != null) {
            _clientNamesCache[userId] = name;
          }
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des noms de clients: $e');
    } finally {
      _isLoadingClientNames = false;
    }
  }

  /// Charger les noms de clients manquants si nécessaire (pour la recherche)
  Future<void> _loadClientNamesIfNeeded() async {
    if (_searchController.text.isEmpty) return;
    if (_isLoadingClientNames) return;

    final orderService = context.read<OrderManagementService>();
    final allOrders = orderService.allOrders;

    // Identifier les userIds manquants dans le cache pour les commandes visibles
    final missingUserIds = allOrders
        .map((order) => order.userId)
        .where((userId) => !_clientNamesCache.containsKey(userId))
        .take(20) // Limiter à 20 pour éviter de surcharger
        .toList();

    if (missingUserIds.isEmpty) return;

    _isLoadingClientNames = true;

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('users')
          .select('auth_user_id, name')
          .inFilter('auth_user_id', missingUserIds);

      for (final userData in response) {
        final userId = userData['auth_user_id'] as String?;
        final name = userData['name'] as String? ?? 'Inconnu';
        if (userId != null) {
          _clientNamesCache[userId] = name;
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des noms de clients: $e');
    } finally {
      _isLoadingClientNames = false;
    }
  }
}
