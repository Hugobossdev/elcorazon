import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/services/error_handler_service.dart';
import 'package:elcora_dely/presentation/libelles_course.dart';
import 'package:elcorazon_core/elcorazon_core.dart'
    show AppEmoji, AppEmojiToken;
import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcora_dely/screens/delivery/real_time_tracking_screen.dart';
import 'package:elcora_dely/screens/delivery/driver_profile_screen.dart';
import 'package:elcora_dely/screens/delivery/settings_screen.dart';
import 'package:elcora_dely/presentation/messages_erreur.dart';

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
                  order.etape.estEnCours,
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
                  !order.etape.estEnCours,
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

  Widget _buildDeliveryCard(Course order, {required bool isActive}) {
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

  Widget _buildDeliveryHeader(Course order, bool isActive) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getStatusColor(order.etape).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          // Décorative : le libellé de l'étape est juste en dessous.
          child: Center(
            child: AppEmoji(
              order.etape.illustration,
              size: AppEmoji.tailleS,
              decoratif: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Livraison ${order.reference}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDateTime(order.passeeLe),
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
                  color: _getStatusColor(order.etape),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.etape.libelle,
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
                order.total?.format() ?? '—',
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

  Widget _buildDeliveryInfo(Course order) {
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
              const Icon(Icons.location_on, size: 16, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.adresseLivraison,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (order.consignes != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.note, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Note: ${order.consignes}',
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
                  order.livraisonEstimeeA != null
                      ? 'Livraison prévue: ${_formatTime(order.livraisonEstimeeA!)}'
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

  Widget _buildOrderItems(Course order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${order.articles.length} article${order.articles.length > 1 ? 's' : ''} commandé${order.articles.length > 1 ? 's' : ''}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...order.articles
            .take(3)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        item.itemImage ?? '',
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
                        item.itemName,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        if (order.articles.length > 3)
          Text(
            '... et ${order.articles.length - 3} autre${order.articles.length - 3 > 1 ? 's' : ''} article${order.articles.length - 3 > 1 ? 's' : ''}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildDeliveryActions(Course order) {
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
        if (order.prochaineEtape != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateDeliveryStatus(order),
              icon: Icon(_getNextActionIcon(order.prochaineEtape), size: 18),
              label: Text(_getNextActionText(order.prochaineEtape)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
      ],
    );
  }

  void _showDeliveryDetails(Course order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DeliveryDetailsSheet(order: order),
    );
  }

  void _navigateToCustomer(Course order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RealTimeTrackingScreen(order: order),
      ),
    );
  }

  Future<void> _updateDeliveryStatus(Course order) async {
    // L'étape vient de `allowed_transitions`, pas d'un `switch` local. Celui
    // qui était ici n'avait **pas de cas pour `acceptee`** : sur une course
    // fraîchement acceptée — l'étape la plus courante de cet écran — le
    // bouton « Suivant » tombait dans le `default` et ne faisait
    // rigoureusement rien. Le livreur appuyait, rien ne se passait, aucune
    // erreur ne s'affichait.
    final suivante = order.prochaineEtape;
    if (suivante == null) return;

    if (suivante == EtapeCourse.livree && !await _confirmerLivraison(order)) {
      return;
    }
    if (!mounted) return;

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      await appService.updateOrderStatus(order.orderId, suivante);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut mis à jour: ${suivante.libelle}'),
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
        errorHandler.showErrorSnackBar(context, messageErreur(e));
      }
    }
  }

  /// Demande confirmation avant de déclarer la livraison faite — l'étape est
  /// irréversible côté serveur, et c'est elle qui crédite la rémunération.
  Future<bool> _confirmerLivraison(Course order) async {
    final montant =
        order.moyenPaiement.aEncaisser ? order.total?.format() : null;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la livraison'),
        content: Text(
          montant == null
              ? 'La commande ${order.reference} a bien été remise au client ?'
                  '\n\nCette étape est définitive.'
              : 'La commande ${order.reference} a bien été remise, et vous '
                  'avez encaissé $montant ?\n\nCette étape est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Pas encore'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, c\'est livré'),
          ),
        ],
      ),
    );
    return confirme ?? false;
  }

  String _getNextActionText(EtapeCourse? etape) => switch (etape) {
        EtapeCourse.recuperee => 'Récupérée',
        EtapeCourse.enRoute => 'En route',
        EtapeCourse.livree => 'Livré',
        _ => 'Suivant',
      };

  IconData _getNextActionIcon(EtapeCourse? etape) => switch (etape) {
        EtapeCourse.recuperee => Icons.shopping_bag,
        EtapeCourse.enRoute => Icons.delivery_dining,
        EtapeCourse.livree => Icons.check_circle,
        _ => Icons.arrow_forward,
      };

  Color _getStatusColor(EtapeCourse etape) {
    switch (etape) {
      case EtapeCourse.acceptee:
        return Colors.orange;
      case EtapeCourse.recuperee:
        return Colors.teal;
      case EtapeCourse.enRoute:
        return Colors.indigo;
      case EtapeCourse.livree:
        return Colors.green;
      case EtapeCourse.annulee:
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
  final Course order;

  const DeliveryDetailsSheet({required this.order, super.key});

  @override
  State<DeliveryDetailsSheet> createState() => _DeliveryDetailsSheetState();
}

class _DeliveryDetailsSheetState extends State<DeliveryDetailsSheet> {
  /// La course de cette fiche. Raccourci de lecture : la moitié des méthodes
  /// de cette classe la désignaient, chacune par `widget.order`.
  Course get _course => widget.order;

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
              widget.order.reference,
            ),
            _buildInfoRow(
              'Statut',
              widget.order.etape.libelle,
              illustration: widget.order.etape.illustration,
            ),
            _buildInfoRow(
              'Montant',
              widget.order.total?.format() ?? '—',
            ),
            _buildInfoRow(
              'Paiement',
              widget.order.moyenPaiement.libelle,
              icone: widget.order.moyenPaiement.icone,
            ),
            if (widget.order.livraisonEstimeeA != null)
              _buildInfoRow(
                'Livraison prévue',
                _formatTime(widget.order.livraisonEstimeeA!),
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
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.order.adresseLivraison,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            if (widget.order.consignes != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.note, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Instructions: ${widget.order.consignes}',
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
            ...widget.order.articles.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.itemImage ?? '',
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
                            item.itemName,
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
                      item.lineTotal.format(),
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
            // Le carré gris « Carte interactive — fonctionnalité à venir » qui
            // occupait cette place a disparu : il tenait 150 pixels de haut
            // pour ne rien montrer. La carte existe, elle est dans l'écran de
            // suivi, et le bouton ci-dessous y mène.
            Text(
              _course.repasRecupere
                  ? 'Vers ${_course.destinataire.isEmpty ? 'le client' : _course.destinataire} — ${_course.adresseLivraison}'
                  : 'Vers ${_course.assignment.restaurantName} pour le retrait',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RealTimeTrackingScreen(order: _course),
                      ),
                    ),
                    icon: const Icon(Icons.map),
                    label: const Text('Suivi'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openNavigation(),
                    icon: const Icon(Icons.navigation),
                    label: const Text('Itinéraire'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Une ligne de la fiche de course.
  ///
  /// [illustration] et [icone] remplacent les emojis Unicode que deux de ces
  /// lignes collaient devant leur valeur — `'🛵 En route'`, `'💵 Espèces'`.
  /// Concaténés dans la chaîne, ils se lisaient à voix haute au milieu du mot
  /// et dépendaient de la police du téléphone. Les deux restent facultatifs :
  /// numéro, montant et heure n'illustrent rien.
  Widget _buildInfoRow(
    String label,
    String value, {
    AppEmojiToken? illustration,
    IconData? icone,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (illustration != null) ...[
                // Décorative : la valeur juste à côté porte l'information.
                AppEmoji(
                  illustration,
                  size: AppEmoji.tailleXS,
                  decoratif: true,
                ),
                const SizedBox(width: 6),
              ] else if (icone != null) ...[
                Icon(icone, size: 18, color: Colors.grey[700]),
                const SizedBox(width: 6),
              ],
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
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
      final phoneNumber = _recipientPhone();

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
      if (mounted) {
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
      final phoneNumber = _recipientPhone();

      if (phoneNumber == null || phoneNumber.isEmpty) {
        if (context.mounted) {
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
          'Bonjour, je suis votre livreur pour la commande #${widget.order.orderId}.';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi du message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Ouvre l'itinéraire vers l'étape en cours, **par coordonnées**.
  ///
  /// La version précédente lançait une *recherche textuelle* Google Maps sur
  /// la chaîne d'adresse de livraison — `maps/search/?query=Rue%20...`. Deux
  /// conséquences : la recherche pouvait tomber sur une homonymie à l'autre
  /// bout de la ville, et elle visait le client même quand le livreur devait
  /// d'abord passer au restaurant.
  ///
  /// L'affectation porte les deux points en clair (`pickup_location`,
  /// `delivery_location`) : un couple latitude/longitude ne s'interprète pas.
  /// L'adresse reste jointe en libellé, pour que le livreur lise où il va.
  Future<void> _openNavigation() async {
    try {
      final vaChezLeClient = _course.repasRecupere;
      final latitude = vaChezLeClient
          ? _course.latitudeLivraison
          : _course.latitudeRetrait;
      final longitude = vaChezLeClient
          ? _course.longitudeLivraison
          : _course.longitudeRetrait;
      final libelle = vaChezLeClient
          ? _course.adresseLivraison
          : _course.assignment.restaurantName;

      // Google Maps d'abord, Waze ensuite, puis le schéma `geo:` — que toute
      // application de cartographie Android déclare, y compris hors ligne.
      final destinations = [
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&destination=$latitude,$longitude&travelmode=driving',
        ),
        Uri.parse('https://waze.com/ul?ll=$latitude,$longitude&navigate=yes'),
        Uri.parse(
          'geo:$latitude,$longitude?q=$latitude,$longitude'
          '(${Uri.encodeComponent(libelle)})',
        ),
      ];

      for (final uri in destinations) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune application de navigation trouvée'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture de la navigation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Téléphone du destinataire, lu sur la course.
  String? _recipientPhone() {
    return Provider.of<AppService>(context, listen: false)
        .recipientPhoneFor(widget.order.orderId);
  }
}
