import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/client_management_service.dart';
import '../../services/app_service.dart';
import '../../models/user.dart';
import '../../models/order.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/dialog_helper.dart';
import '../../utils/price_formatter.dart';
import '../../ui/ui.dart';

class ClientManagementScreen extends StatefulWidget {
  const ClientManagementScreen({super.key});

  @override
  State<ClientManagementScreen> createState() => _ClientManagementScreenState();
}

class _ClientManagementScreenState extends State<ClientManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, active, suspended, vip
  List<User> _filteredClients = [];
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    // Reporter setState après le build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filterClients();
      });
    });
  }

  void _filterClients() {
    final clientService = Provider.of<ClientManagementService>(
      context,
      listen: false,
    );
    final allClients = clientService.clients;

    _filteredClients = allClients.where((client) {
      // Filtre de recherche
      final matchesSearch = _searchQuery.isEmpty ||
          client.name.toLowerCase().contains(_searchQuery) ||
          client.email.toLowerCase().contains(_searchQuery) ||
          (client.phone.toLowerCase().contains(_searchQuery));

      // Filtre par statut
      final matchesFilter = _selectedFilter == 'all' ||
          (_selectedFilter == 'active' && !_isSuspended(client)) ||
          (_selectedFilter == 'suspended' && _isSuspended(client)) ||
          (_selectedFilter == 'vip' && _isVIP(client));

      return matchesSearch && matchesFilter;
    }).toList();
  }

  bool _isSuspended(User client) {
    // Vérifier si le client est suspendu (is_active = false dans la DB)
    return !client.isActive;
  }

  bool _isVIP(User client) {
    // Vérifier si le client a un badge VIP
    if (client.badges.any((badge) => badge.toLowerCase().contains('vip'))) {
      return true;
    }

    // Vérifier les critères basés sur les statistiques
    final appService = Provider.of<AppService>(context, listen: false);
    final orders =
        appService.allOrders.where((o) => o.userId == client.id).toList();
    final completedOrders =
        orders.where((o) => o.status == OrderStatus.delivered).toList();
    final totalSpent = completedOrders.fold(0.0, (sum, o) => sum + o.total);

    // Critères VIP:
    // - Points de fidélité > 10000
    // - Niveau > 5
    // - Total dépensé > 100000 FCFA
    // - Plus de 50 commandes complétées
    return client.loyaltyPoints > 10000 ||
        (client.stats?.level ?? 0) > 5 ||
        totalSpent > 100000 ||
        completedOrders.length > 50;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer2<ClientManagementService, AppService>(
      builder: (context, clientService, appService, child) {
        // Initialiser le service au premier build (une seule fois)
        if (!_hasInitialized &&
            !clientService.isLoading &&
            clientService.clients.isEmpty) {
          _hasInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            clientService.initialize();
          });
        }

        _filterClients();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Gestion des Clients'),
            actions: [
              Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _exportClients(),
                  tooltip: 'Exporter en CSV',
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Barre de recherche et filtres
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CustomTextField(
                      label: 'Rechercher un client',
                      controller: _searchController,
                      prefixIcon: Icons.search,
                      onChanged: (_) => _onSearchChanged(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'all',
                                label: Text('Tous'),
                                icon: Icon(Icons.people),
                              ),
                              ButtonSegment(
                                value: 'active',
                                label: Text('Actifs'),
                                icon: Icon(Icons.check_circle),
                              ),
                              ButtonSegment(
                                value: 'suspended',
                                label: Text('Suspendus'),
                                icon: Icon(Icons.block),
                              ),
                              ButtonSegment(
                                value: 'vip',
                                label: Text('VIP'),
                                icon: Icon(Icons.star),
                              ),
                            ],
                            selected: {_selectedFilter},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _selectedFilter = newSelection.first;
                                _filterClients();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Liste des clients
              Expanded(
                child: clientService.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredClients.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun client trouvé',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredClients.length,
                            itemBuilder: (context, index) {
                              final client = _filteredClients[index];
                              final orders = appService.allOrders
                                  .where((o) => o.userId == client.id)
                                  .toList();
                              final totalSpent = orders
                                  .where(
                                      (o) => o.status == OrderStatus.delivered)
                                  .fold(0.0, (sum, o) => sum + o.total);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    child: Text(
                                      client.name.substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    client.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(client.email),
                                      Text(client.phone),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.receipt,
                                            size: 14,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${orders.length} commande(s)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(
                                            Icons.monetization_on,
                                            size: 14,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            PriceFormatter.format(totalSpent),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: PopupMenuButton(
                                      icon: const Icon(Icons.more_vert),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'view',
                                          child: Row(
                                            children: [
                                              Icon(Icons.visibility),
                                              SizedBox(width: 8),
                                              Text('Voir détails'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'orders',
                                          child: Row(
                                            children: [
                                              Icon(Icons.receipt_long),
                                              SizedBox(width: 8),
                                              Text('Historique commandes'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'suspend',
                                          child: Row(
                                            children: [
                                              Icon(Icons.block),
                                              SizedBox(width: 8),
                                              Text('Suspendre'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'points',
                                          child: Row(
                                            children: [
                                              Icon(Icons.stars),
                                              SizedBox(width: 8),
                                              Text('Points fidélité'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        _handleClientAction(value, client);
                                      },
                                    ),
                                  ),
                                  onTap: () =>
                                      _showClientDetails(client, appService),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleClientAction(String action, User client) {
    switch (action) {
      case 'view':
        _showClientDetails(client, context.read<AppService>());
        break;
      case 'orders':
        _showClientOrders(client);
        break;
      case 'suspend':
        _suspendClient(client);
        break;
      case 'points':
        _showLoyaltyPoints(client);
        break;
    }
  }

  Future<void> _showClientDetails(User client, AppService appService) async {
    final clientService = context.read<ClientManagementService>();

    // Charger les statistiques du client
    final stats = await clientService.getClientStats(client.id);

    if (!mounted) return;

    // Gérer les valeurs null de manière sécurisée
    // Note: Le service utilise des clés avec underscore
    final totalSpent = (stats['total_spent'] as num?)?.toDouble() ??
        (stats['totalSpent'] as num?)?.toDouble() ??
        0.0;
    final totalOrders =
        stats['total_orders'] as int? ?? stats['totalOrders'] as int? ?? 0;
    final completedOrders = stats['completed_orders'] as int? ??
        stats['completedOrders'] as int? ??
        0;
    final cancelledOrders = stats['cancelled_orders'] as int? ??
        stats['cancelledOrders'] as int? ??
        0;
    final averageOrderValue =
        (stats['average_order_value'] as num?)?.toDouble() ??
            (stats['averageOrderValue'] as num?)?.toDouble() ??
            0.0;

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails du client: ${client.name}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', client.email),
              _buildDetailRow('Téléphone', client.phone),
              _buildDetailRow('Total commandes', '$totalOrders'),
              _buildDetailRow('Commandes complétées', '$completedOrders'),
              _buildDetailRow('Commandes annulées', '$cancelledOrders'),
              _buildDetailRow(
                'Total dépensé',
                PriceFormatter.format(totalSpent),
              ),
              _buildDetailRow(
                'Panier moyen',
                PriceFormatter.format(averageOrderValue),
              ),
              _buildDetailRow(
                'Membre depuis',
                '${client.createdAt.day}/${client.createdAt.month}/${client.createdAt.year}',
              ),
            ],
          ),
        ),
        actions: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showClientOrders(client);
              },
              child: const Text('Voir commandes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _showClientOrders(User client) async {
    final clientService = context.read<ClientManagementService>();
    final orders = await clientService.getClientOrders(client.id);

    if (!mounted) return;

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Historique des commandes: ${client.name}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: orders.isEmpty
              ? const Center(child: Text('Aucune commande'))
              : ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: ListTile(
                          leading: Icon(
                            _getOrderStatusIcon(order.status),
                            color: _getOrderStatusColor(context, order.status),
                          ),
                          title: Text(
                            'Commande #${order.id.substring(0, 8).toUpperCase()}',
                          ),
                          subtitle: Text(
                            '${PriceFormatter.format(order.total)} - ${order.status.displayName}',
                          ),
                          trailing: Text(
                            '${order.orderTime.day}/${order.orderTime.month}/${order.orderTime.year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getOrderStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.refunded:
        return Icons.payment;
      default:
        return Icons.pending;
    }
  }

  Color _getOrderStatusColor(BuildContext context, OrderStatus status) {
    final sem = AdminColorTokens.semantic(Theme.of(context).colorScheme);
    switch (status) {
      case OrderStatus.delivered:
        return sem.success;
      case OrderStatus.cancelled:
        return sem.danger;
      case OrderStatus.refunded:
        return sem.warning;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Future<void> _suspendClient(User client) async {
    final reasonController = TextEditingController();
    final confirmed = await DialogHelper.showSafeDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspendre le client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client: ${client.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Raison de la suspension (optionnel):'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Entrez la raison de la suspension...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Suspendre'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      // Capturer les valeurs nécessaires avant le gap async
      final inverseSurfaceColor = Theme.of(context).colorScheme.inverseSurface;
      final clientService = context.read<ClientManagementService>();
      final success = await clientService.suspendClient(
        client.id,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '✅ ${client.name} a été suspendu'
                  : '❌ Erreur lors de la suspension',
            ),
            backgroundColor: inverseSurfaceColor,
          ),
        );
      }
    }
  }

  void _showLoyaltyPoints(User client) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Note: on récupère les tokens ici car on est dans le builder du dialog
        title: Text('Points Fidélité: ${client.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.stars,
              size: 64,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '${client.loyaltyPoints} points',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Niveau: ${client.stats?.level ?? 1}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
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

  Future<void> _exportClients() async {
    final clientService =
        Provider.of<ClientManagementService>(context, listen: false);
    final clients = clientService.clients;

    final csvBuffer = StringBuffer();
    csvBuffer.writeln('ID,Nom,Email,Téléphone,Points,Date Création');

    for (final client in clients) {
      csvBuffer.writeln(
          '${client.id},"${client.name}","${client.email}","${client.phone}",${client.loyaltyPoints},${client.createdAt.toIso8601String()}');
    }

    final csvContent = csvBuffer.toString();

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export CSV'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Copiez le contenu CSV ci-dessous:'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(8),
                height: 200,
                child: SingleChildScrollView(
                  child: SelectableText(csvContent),
                ),
              ),
            ],
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
}
