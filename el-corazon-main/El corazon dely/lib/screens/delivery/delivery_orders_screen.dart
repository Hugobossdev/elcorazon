import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_service.dart';
import '../../utils/price_formatter.dart';
import '../../services/error_handler_service.dart';
import '../../models/order.dart';
import 'real_time_tracking_screen.dart';
import 'driver_profile_screen.dart';
import 'settings_screen.dart';

class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      await appService.loadAvailableOrders();
    } catch (e) {
      if (mounted) {
        final errorHandler = Provider.of<ErrorHandlerService>(
          context,
          listen: false,
        );
        errorHandler.logError('Erreur chargement commandes', details: e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Livraisons'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(
            context,
          ).colorScheme.onPrimary.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: 'En cours', icon: Icon(Icons.delivery_dining)),
            Tab(text: 'Terminées', icon: Icon(Icons.check_circle)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildActiveDeliveries(), _buildCompletedDeliveries()],
      ),
    );
  }

  Widget _buildActiveDeliveries() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<AppService>(
      builder: (context, appService, child) {
        final activeDeliveries = appService.assignedDeliveries
            .where(
              (order) =>
                  order.status != OrderStatus.delivered &&
                  order.status != OrderStatus.cancelled,
            )
            .toList();

        if (activeDeliveries.isEmpty) {
          return _buildEmptyState(
            icon: Icons.delivery_dining_outlined,
            title: 'Aucune livraison en cours',
            subtitle: 'Vos livraisons actives apparaîtront ici',
          );
        }

        return RefreshIndicator(
          onRefresh: _loadOrders,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeDeliveries.length,
            itemBuilder: (context, index) {
              final order = activeDeliveries[index];
              return _buildDeliveryCard(order, isActive: true);
            },
          ),
        );
      },
    );
  }

  Widget _buildCompletedDeliveries() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<AppService>(
      builder: (context, appService, child) {
        final completedDeliveries = appService.assignedDeliveries
            .where(
              (order) =>
                  order.status == OrderStatus.delivered ||
                  order.status == OrderStatus.cancelled,
            )
            .toList();

        if (completedDeliveries.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history_outlined,
            title: 'Aucune livraison terminée',
            subtitle: 'Votre historique de livraisons apparaîtra ici',
          );
        }

        return RefreshIndicator(
          onRefresh: _loadOrders,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: completedDeliveries.length,
            itemBuilder: (context, index) {
              final order = completedDeliveries[index];
              return _buildDeliveryCard(order, isActive: false);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(Order order, {required bool isActive}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showDeliveryDetails(order),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDeliveryHeader(order, isActive),
              const SizedBox(height: 12),
              _buildDeliveryInfo(order),
              const SizedBox(height: 12),
              _buildOrderItems(order),
              if (isActive) ...[
                const SizedBox(height: 16),
                _buildDeliveryActions(order),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryHeader(Order order, bool isActive) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getStatusColor(order.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              order.status.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Livraison #${order.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDateTime(order.orderTime),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.status.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${PriceFormatter.format(order.total)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryInfo(Order order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.deliveryAddress,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (order.deliveryNotes?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.note, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Note: ${order.deliveryNotes}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.estimatedDeliveryTime != null
                      ? 'Livraison prévue: ${_formatTime(order.estimatedDeliveryTime!)}'
                      : 'Temps estimé: 30 min',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItems(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${order.items.length} article${order.items.length > 1 ? 's' : ''} commandé${order.items.length > 1 ? 's' : ''}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...order.items
            .take(3)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        item.menuItemImage,
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 24,
                          height: 24,
                          color: Colors.grey[300],
                          child: const Icon(Icons.fastfood, size: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.quantity}x',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.menuItemName,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        if (order.items.length > 3)
          Text(
            '... et ${order.items.length - 3} autre${order.items.length - 3 > 1 ? 's' : ''} article${order.items.length - 3 > 1 ? 's' : ''}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildDeliveryActions(Order order) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _navigateToCustomer(order),
            icon: const Icon(Icons.navigation, size: 18),
            label: const Text('Navigation'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateDeliveryStatus(order),
            icon: Icon(_getNextActionIcon(order.status), size: 18),
            label: Text(_getNextActionText(order.status)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void _showDeliveryDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DeliveryDetailsSheet(order: order),
    );
  }

  void _navigateToCustomer(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RealTimeTrackingScreen(order: order),
      ),
    );
  }

  Future<void> _updateDeliveryStatus(Order order) async {
    try {
      final appService = Provider.of<AppService>(context, listen: false);
      OrderStatus nextStatus;

      switch (order.status) {
        case OrderStatus.pickedUp:
          nextStatus = OrderStatus.onTheWay;
          break;
        case OrderStatus.onTheWay:
          nextStatus = OrderStatus.delivered;
          break;
        default:
          return;
      }

      await appService.updateOrderStatus(order.id, nextStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut mis à jour: ${nextStatus.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh orders after status update
        await _loadOrders();
      }
    } catch (e) {
      if (mounted) {
        final errorHandler = Provider.of<ErrorHandlerService>(
          context,
          listen: false,
        );
        errorHandler.logError('Erreur mise à jour statut', details: e);
        errorHandler.showErrorSnackBar(
          context,
          'Erreur lors de la mise à jour: $e',
        );
      }
    }
  }

  String _getNextActionText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pickedUp:
        return 'En route';
      case OrderStatus.onTheWay:
        return 'Livré';
      default:
        return 'Suivant';
    }
  }

  IconData _getNextActionIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pickedUp:
        return Icons.delivery_dining;
      case OrderStatus.onTheWay:
        return Icons.check_circle;
      default:
        return Icons.arrow_forward;
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.ready:
        return Colors.orange;
      case OrderStatus.pickedUp:
        return Colors.teal;
      case OrderStatus.onTheWay:
        return Colors.indigo;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Il y a ${difference.inMinutes}min';
      }
      return 'Il y a ${difference.inHours}h${difference.inMinutes % 60}min';
    } else if (difference.inDays == 1) {
      return 'Hier ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class DeliveryDetailsSheet extends StatefulWidget {
  final Order order;

  const DeliveryDetailsSheet({super.key, required this.order});

  @override
  State<DeliveryDetailsSheet> createState() => _DeliveryDetailsSheetState();
}

class _DeliveryDetailsSheetState extends State<DeliveryDetailsSheet> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Détails de la livraison',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection(context),
                    const SizedBox(height: 16),
                    _buildCustomerSection(context),
                    const SizedBox(height: 16),
                    _buildItemsSection(context),
                    const SizedBox(height: 16),
                    _buildMapSection(context),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations de livraison',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Numéro',
              '#${widget.order.id.substring(0, 8).toUpperCase()}',
            ),
            _buildInfoRow(
              'Statut',
              '${widget.order.status.emoji} ${widget.order.status.displayName}',
            ),
            _buildInfoRow(
              'Montant',
              '${PriceFormatter.format(widget.order.total)}',
            ),
            _buildInfoRow(
              'Paiement',
              '${widget.order.paymentMethod.emoji} ${widget.order.paymentMethod.displayName}',
            ),
            if (widget.order.estimatedDeliveryTime != null)
              _buildInfoRow(
                'Livraison prévue',
                _formatTime(widget.order.estimatedDeliveryTime!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adresse de livraison',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.order.deliveryAddress,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            if (widget.order.deliveryNotes?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.note, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Instructions: ${widget.order.deliveryNotes}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callCustomer(),
                    icon: const Icon(Icons.phone),
                    label: const Text('Appeler'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _messageCustomer(),
                    icon: const Icon(Icons.message),
                    label: const Text('Message'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Articles à livrer',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...widget.order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.menuItemImage,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 40,
                          height: 40,
                          color: Colors.grey[300],
                          child: const Icon(Icons.fastfood, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.menuItemName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Quantité: ${item.quantity}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${PriceFormatter.format(item.totalPrice)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Navigation',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 48, color: Colors.grey[600]),
                    const SizedBox(height: 8),
                    Text(
                      'Carte interactive',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fonctionnalité à venir',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openNavigation(),
                icon: const Icon(Icons.navigation),
                label: const Text('Ouvrir la navigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _callCustomer() async {
    try {
      // Récupérer le numéro de téléphone depuis le profil utilisateur
      final userProfile = await _getUserProfile(widget.order.userId);
      final phoneNumber = userProfile?['phone'] as String?;

      if (phoneNumber == null || phoneNumber.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Numéro de téléphone non disponible'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Nettoyer le numéro (enlever les espaces, tirets, etc.)
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Utiliser url_launcher pour ouvrir l'appel téléphonique
      final uri = Uri.parse('tel:$cleanPhone');
      final canLaunch = await canLaunchUrl(uri);

      if (canLaunch) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d\'ouvrir l\'application d\'appel'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'appel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _messageCustomer() async {
    try {
      // Récupérer le numéro de téléphone depuis le profil utilisateur
      final userProfile = await _getUserProfile(widget.order.userId);
      final phoneNumber = userProfile?['phone'] as String?;

      if (phoneNumber == null || phoneNumber.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Numéro de téléphone non disponible'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Nettoyer le numéro (enlever les espaces, tirets, etc.)
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Ouvrir WhatsApp avec un message pré-rempli
      final message =
          'Bonjour, je suis votre livreur pour la commande #${widget.order.id}.';
      final uri = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
      );
      final canLaunch = await canLaunchUrl(uri);

      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: ouvrir SMS
        final smsUri = Uri.parse(
          'sms:$cleanPhone?body=${Uri.encodeComponent(message)}',
        );
        await launchUrl(smsUri);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi du message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openNavigation() async {
    try {
      final address = widget.order.deliveryAddress;

      if (address.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adresse de livraison non disponible'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Essayer d'ouvrir Google Maps d'abord
      final googleMapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
      );

      final canLaunchGoogleMaps = await canLaunchUrl(googleMapsUri);

      if (canLaunchGoogleMaps) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: essayer Waze
        final wazeUri = Uri.parse(
          'https://waze.com/ul?q=${Uri.encodeComponent(address)}',
        );
        final canLaunchWaze = await canLaunchUrl(wazeUri);

        if (canLaunchWaze) {
          await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Aucune application de navigation trouvée'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture de la navigation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      final appService = Provider.of<AppService>(context, listen: false);
      return await appService.getUserProfile(userId);
    } catch (e) {
      debugPrint('Erreur récupération profil utilisateur: $e');
      return null;
    }
  }
}
