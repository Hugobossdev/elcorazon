import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:admin/services/app_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/statut_commande.dart';
import 'package:admin/presentation/anciennete_commande.dart';
import 'package:admin/presentation/apparence_statut.dart';
import 'package:admin/presentation/barre_de_filtres.dart';
import 'package:admin/presentation/dialogues/fiche_commande.dart';
import 'package:admin/presentation/cartes/commande_deployee.dart';
import 'package:admin/presentation/filtres_commandes.dart';
import 'package:admin/widgets/custom_button.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/screens/admin/driver_assignment_dialog.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/services/payments_service.dart';
import 'package:admin/utils/price_formatter.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show AppEmoji;

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  FenetreCommandes _fenetre = FenetreCommandes.aujourdHui;
  ZoneCommandes _zone = ZoneCommandes.toutes;
  final _searchController = TextEditingController();

  // Cache des noms de clients (userId -> name)

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
          final filteredOrders = commandesFiltrees(
            allOrders,
            recherche: _searchController.text,
            zone: _zone,
            fenetre: _fenetre,
          );
          final isLoading = orderService.isLoading;

          return Column(
            children: [
              // Filters
              BarreDeFiltres(
                recherche: _searchController,
                fenetre: _fenetre,
                zone: _zone,
                surRecherche: () => setState(() {}),
                surFenetre: (choix) => setState(() => _fenetre = choix),
                surZone: (choix) => setState(() => _zone = choix),
              ),

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
                                        (o) => o.statut == StatutCommande.enAttente,
                                      )
                                      .toList(),
                                  appService,
                                );
                              case 2:
                                return _buildOrdersList(
                                  filteredOrders
                                      .where(
                                        (o) =>
                                            o.statut == StatutCommande.enPreparation,
                                      )
                                      .toList(),
                                  appService,
                                );
                              case 3:
                                return _buildOrdersList(
                                  filteredOrders
                                      .where(
                                        (o) => o.statut == StatutCommande.enRoute,
                                      )
                                      .toList(),
                                  appService,
                                );
                              case 4:
                                return _buildOrdersList(
                                  filteredOrders
                                      .where(
                                        (o) =>
                                            o.statut == StatutCommande.livree,
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

  Widget _buildOrdersList(List<eccore.Order> orders, AppService appService) {
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
        final statusColor = couleurDeStatutFixe(order.statut);

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
                  // Portante : c'est le seul repère visuel de l'étape sur
                  // cette ligne, et l'opérateur balaie la liste des yeux.
                  child: AppEmoji(order.statut.illustration),
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
                        order.statut.libelle,
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
                              PriceFormatter.format(order.totalAffiche),
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
                              '${order.lines.length} ${order.lines.length > 1 ? 'articles' : 'article'}',
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
                              ancienneteCommande(order.passeeLe),
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
                // eccore.Order details
                SizedBox(
                  width: double.infinity,
                  child: DetailsCommande(order: order),
                ),
                const SizedBox(height: 16),

                // eccore.Order items
                SizedBox(
                  width: double.infinity,
                  child: ArticlesCommande(order: order),
                ),
                const SizedBox(height: 16),

                // eccore.Order timeline
                SizedBox(
                  width: double.infinity,
                  child: ChronologieCommande(order: order),
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

  Widget _buildOrderActions(eccore.Order order, AppService appService) {
    return SizedBox(
      width: 40,
      height: 40,
      child: PopupMenuButton(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        itemBuilder: (context) {
          final actions = <PopupMenuEntry>[];

          switch (order.statut) {
            case StatutCommande.enAttente:
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
            case StatutCommande.confirmee:
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
            case StatutCommande.enPreparation:
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
            case StatutCommande.prete:
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
            case StatutCommande.enRoute:
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
              afficherFicheCommande(context, order);
              break;
          }
        },
      ),
    );
  }

  Widget _buildOrderActionButtons(eccore.Order order, AppService appService) {
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




  // eccore.Order action methods
  Future<void> _acceptOrder(eccore.Order order) async {
    final orderService = context.read<OrderManagementService>();
    final success = await orderService.acceptOrder(order.id);

    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Commande #${order.id.substring(0, 8).toUpperCase()} acceptée'
                : 'Erreur lors de l\'acceptation',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectOrder(eccore.Order order) async {
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
                ? 'Commande #${order.id.substring(0, 8).toUpperCase()} refusée'
                : 'Erreur lors du refus',
          ),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
    }
  }

  Future<void> _prepareOrder(eccore.Order order, AppService appService) async {
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
                ? 'Commande #${order.id.substring(0, 8).toUpperCase()} mise en préparation'
                : 'Erreur lors de la mise en préparation',
          ),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
    }
  }

  Future<void> _readyOrder(eccore.Order order, AppService appService) async {
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
                ? 'Commande #${order.id.substring(0, 8).toUpperCase()} marquée comme prête'
                : 'Erreur lors de la mise à jour',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _assignDriver(eccore.Order order, AppService appService) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => DriverAssignmentDialog(order: order),
    );
  }

  Future<void> _deliverOrder(eccore.Order order, AppService appService) async {
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
                ? 'Commande #${order.id.substring(0, 8).toUpperCase()} marquée comme livrée'
                : 'Erreur lors de la mise à jour',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _refundOrder(eccore.Order order, AppService appService) async {
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
              'Montant total: ${PriceFormatter.format(order.totalAffiche)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text('Type de remboursement:'),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text('Remboursement total'),
              subtitle: Text(PriceFormatter.format(order.totalAffiche)),
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

    double refundAmount = order.totalAffiche;
    if (refundType == 'partial') {
      final amountController = TextEditingController(
        text: order.totalAffiche.toStringAsFixed(2),
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
                if (amount != null && amount > 0 && amount <= order.totalAffiche) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      refundAmount = double.tryParse(amountController.text) ?? order.totalAffiche;
    }

    if (!mounted || !context.mounted) return;

    final paymentsService = context.read<PaymentsService>();

    // L'encaissement à rembourser se demande au serveur : une commande peut en
    // porter plusieurs (paiement partagé), et « rembourser la commande » sans
    // dire lequel ne voudrait rien dire. L'ancien écran lisait un identifiant
    // posé sur la commande, qui n'existait que pour le premier paiement.
    final encaissements = await paymentsService.transactionsOf(order.id);
    final regle = encaissements
        .where((t) => t.status == 'succeeded')
        .firstOrNull;

    if (!mounted || !context.mounted) return;

    if (regle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun encaissement abouti sur cette commande : il n\'y a rien à '
            'rembourser.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Le remboursement passe par le serveur, qui détient les clés du
    // prestataire, vérifie le rattachement de la commande et applique le
    // plafond P3. L'écran ne joint plus PayDunya lui-même.
    final rembourse = await paymentsService.refund(
      orderId: order.id,
      transactionId: regle.id,
      amountMajor: refundAmount,
      reason: refundType == 'partial'
          ? 'Remboursement partiel'
          : 'Remboursement total',
    );

    if (!mounted || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          rembourse != null
              ? 'Remboursement de ${PriceFormatter.format(refundAmount)} enregistré'
              : paymentsService.error ?? 'Remboursement refusé',
        ),
        backgroundColor: rembourse != null ? Colors.green : Colors.red,
      ),
    );
  }


  Future<void> _showOnMap(eccore.Order order) async {
    try {
      // Encoder l'adresse pour l'URL Google Maps
      final encodedAddress = Uri.encodeComponent(order.adresseComplete);
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

  Future<void> _contactCustomer(eccore.Order order) async {
    try {
      // Le destinataire est porté par la commande : c'est lui qu'on appelle,
      // et pas forcément le titulaire du compte — on commande pour un collègue,
      // pour ses parents. Aller chercher le compte, comme le faisait l'ancien
      // écran, affichait la mauvaise personne dans ce cas-là.
      final phone = order.recipientPhone.isEmpty ? null : order.recipientPhone;
      // L'adresse électronique n'est pas sur la commande : écrire au titulaire
      // d'un compte à propos d'une livraison faite pour un tiers n'aurait pas
      // de destinataire évident.
      const String? email = null;
      final name = order.recipientName.isEmpty ? 'Client' : order.recipientName;

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

  /// Échappe une valeur selon RFC 4180.
  ///
  /// L'export remplaçait les virgules par des points-virgules. Cela sauvait la
  /// colonne mais abîmait la donnée — une adresse rendue « Rue X; Quartier Y »
  /// n'est plus celle du client — et surtout cela ne traitait pas le vrai
  /// casseur de fichier : un **retour à la ligne** dans une adresse, qui coupe
  /// la commande en deux lignes et décale tout le reste du tableau. Guillemets
  /// et virgules d'origine sont donc conservés, et c'est le champ qui est
  /// entouré.
  static String _csvChamp(Object? valeur) {
    final texte = valeur?.toString() ?? '';
    if (!texte.contains(RegExp('[",\n\r]'))) return texte;
    return '"${texte.replaceAll('"', '""')}"';
  }

  Future<void> _exportOrders() async {
    try {
      final orderService = context.read<OrderManagementService>();
      final allOrders = orderService.allOrders;
      final filteredOrders = commandesFiltrees(
        allOrders,
        recherche: _searchController.text,
        zone: _zone,
        fenetre: _fenetre,
      );

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
        // Le nom vient de la commande : une requête par ligne exportée rendait
        // l'export d'un mois de commandes interminable.
        final clientName = order.recipientName.isEmpty
            ? 'Inconnu'
            : order.recipientName;

        csvBuffer.writeln(
          [
            order.id,
            order.passeeLe.toIso8601String(),
            clientName,
            order.adresseComplete,
            order.statut.libelle,
            // `\s` et non l'espace ordinaire : le socle sépare les milliers par
            // une espace insécable étroite (U+202F), qu'un `replaceAll(' ')`
            // laisserait filer jusque dans la cellule du tableur.
            PriceFormatter.format(order.totalAffiche).replaceAll(RegExp(r'\s'), ''),
            order.lines.length,
          ].map(_csvChamp).join(','),
        );
      }

      // L'export aboutit dans le presse-papier, d'où il se colle dans un
      // tableur. C'était jusqu'ici la seule sortie manquante : le CSV était
      // construit puis écrit dans la console de débogage, si bien que le
      // bouton « Exporter » annonçait un succès dont rien ne sortait.
      //
      // `Clipboard` vient de `flutter/services.dart` : aucun paquet
      // supplémentaire, et cela fonctionne sur les six plateformes — ce que ne
      // ferait pas un téléchargement de fichier, qui demanderait un chemin sur
      // bureau et une permission sur mobile.
      await Clipboard.setData(ClipboardData(text: csvBuffer.toString()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${filteredOrders.length} commande(s) copiée(s) dans le '
              'presse-papier — collez dans un tableur',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
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
  /// Charger les noms de clients manquants si nécessaire (pour la recherche)
}
