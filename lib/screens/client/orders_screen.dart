import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/widgets/delivery_status_card.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToDeliveryTracking(Order order) {
    context.navigateToDeliveryTracking(order.id);
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
            icon: const Icon(Icons.filter_list, color: Colors.white),
            tooltip: 'Vue améliorée',
            onPressed: () => context.navigateToEnhancedOrders(),
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
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
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
            onAction: () {
              // Navigate to menu
            },
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeOrders.length,
          itemBuilder: (context, index) {
            final order = activeOrders[index];
            return DeliveryStatusCard(
              order: order,
              onTap: () => _navigateToDeliveryTracking(order),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderHistory() {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final completedOrders = appService.orders
            .where((order) =>
                order.status == OrderStatus.delivered ||
                order.status == OrderStatus.cancelled,)
            .toList();

        if (completedOrders.isEmpty) {
          return _buildEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Aucune commande passée',
            subtitle: 'Votre historique de commandes apparaîtra ici',
            actionLabel: 'Passer ma première commande',
            onAction: () {
              // Navigate to menu
              context.navigateToMenu();
            },
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: completedOrders.length,
          itemBuilder: (context, index) {
            final order = completedOrders[index];
            return DeliveryStatusCard(
              order: order,
              onTap: () => _navigateToDeliveryTracking(order),
            );
          },
        );
      },
    );
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
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
