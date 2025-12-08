import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/realtime_tracking_service.dart';
import 'package:elcora_fast/services/database_service.dart';
import 'package:elcora_fast/services/geocoding_service.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/widgets/custom_button.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/screens/client/chat_screen.dart';

/// Écran de suivi de livraison en temps réel
class DeliveryTrackingScreen extends StatefulWidget {
  final String orderId;

  const DeliveryTrackingScreen({
    required this.orderId,
    super.key,
  });

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  Order? _order;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _deliveryLocation;
  String? _estimatedDeliveryTime;

  StreamSubscription<Order>? _orderUpdatesSubscription;
  StreamSubscription<Map<String, dynamic>>? _deliveryLocationSubscription;
  RealtimeTrackingService? _trackingService;
  DatabaseService? _databaseService;
  GeocodingService? _geocodingService;
  Timer? _estimatedTimeUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
    _startTracking();
  }

  @override
  void dispose() {
    _orderUpdatesSubscription?.cancel();
    _deliveryLocationSubscription?.cancel();
    _estimatedTimeUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrderDetails() async {
    try {
      // Valider l'ID de commande avant de faire la requête
      if (widget.orderId.isEmpty) {
        throw Exception('ID de commande invalide: l\'ID est vide');
      }

      // Valider le format UUID (format basique)
      final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      if (!uuidPattern.hasMatch(widget.orderId)) {
        debugPrint('⚠️ Order ID format may be invalid: ${widget.orderId}');
        // On continue quand même, car certains IDs peuvent avoir un format différent
      }

      final appService = Provider.of<AppService>(context, listen: false);
      _databaseService = appService.databaseService;
      _geocodingService = GeocodingService();

      // Charger la commande depuis la base de données
      try {
        final orderResponse =
            await _databaseService!.supabase.from('orders').select('''
              *,
              order_items(*)
            ''').eq('id', widget.orderId).maybeSingle();

        if (orderResponse != null) {
          _order = Order.fromMap(orderResponse);
        } else {
          // Fallback: chercher dans les commandes locales
          final orders = appService.orders;
          try {
            _order = orders.firstWhere(
              (order) => order.id == widget.orderId,
            );
          } catch (e) {
            throw Exception(
                'Commande non trouvée dans la base de données ni localement');
          }
        }
      } catch (e) {
        // Si c'est une erreur UUID invalide, ne pas essayer le fallback local
        if (e.toString().contains('invalid input syntax for type uuid') ||
            e.toString().contains('22P02')) {
          debugPrint('⚠️ UUID invalide pour la commande: ${widget.orderId}');
          throw Exception('ID de commande invalide. Veuillez réessayer.');
        }

        debugPrint('⚠️ Error loading order from database, using local: $e');
        // Fallback: chercher dans les commandes locales
        final orders = appService.orders;
        try {
          _order = orders.firstWhere(
            (order) => order.id == widget.orderId,
          );
        } catch (e2) {
          throw Exception(
              'Commande non trouvée dans la base de données ni localement');
        }
      }

      // Charger la dernière position de livraison seulement si la commande existe
      if (_order != null) {
        await _loadLatestDeliveryLocation();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading order details: $e');
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Erreur lors du chargement de la commande: ${e.toString()}';
      });
    }
  }

  Future<void> _loadLatestDeliveryLocation() async {
    try {
      if (_databaseService == null) return;

      final locations =
          await _databaseService!.getDeliveryLocations(widget.orderId);
      if (locations.isNotEmpty) {
        final latestLocation = locations.first;
        setState(() {
          _deliveryLocation = {
            'latitude': (latestLocation['latitude'] as num).toDouble(),
            'longitude': (latestLocation['longitude'] as num).toDouble(),
            'timestamp': DateTime.parse(latestLocation['timestamp'] as String),
            'accuracy': latestLocation['accuracy'] != null
                ? (latestLocation['accuracy'] as num).toDouble()
                : null,
            'speed': latestLocation['speed'] != null
                ? (latestLocation['speed'] as num).toDouble()
                : null,
            'heading': latestLocation['heading'] != null
                ? (latestLocation['heading'] as num).toDouble()
                : null,
          };
        });

        // Calculer le temps estimé de livraison
        await _calculateEstimatedDeliveryTime();
      }
    } catch (e) {
      debugPrint('⚠️ Error loading delivery location: $e');
    }
  }

  Future<void> _startTracking() async {
    try {
      final appService = Provider.of<AppService>(context, listen: false);
      final currentUser = appService.currentUser;

      if (currentUser == null) {
        debugPrint('⚠️ User not logged in, cannot start tracking');
        return;
      }

      // Initialiser le service de tracking en temps réel
      _trackingService = RealtimeTrackingService();

      if (!_trackingService!.isConnected) {
        await _trackingService!.initialize(
          userId: currentUser.id,
          userRole: currentUser.role,
        );
      }

      // Suivre cette commande spécifique
      await _trackingService!.trackOrder(widget.orderId);

      // S'abonner aux mises à jour de la commande
      _orderUpdatesSubscription = _trackingService!.orderUpdates.listen(
        (updatedOrder) {
          if (updatedOrder.id == widget.orderId && mounted) {
            setState(() {
              _order = updatedOrder;
            });

            // Si la commande est livrée, arrêter le suivi
            if (updatedOrder.status == OrderStatus.delivered) {
              _estimatedTimeUpdateTimer?.cancel();
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Error in order updates stream: $error');
        },
      );

      // S'abonner aux mises à jour de position du livreur
      _deliveryLocationSubscription =
          _trackingService!.deliveryLocationUpdates.listen(
        (locationUpdate) {
          // Filtrer pour cette commande uniquement
          if (locationUpdate['orderId'] == widget.orderId && mounted) {
            setState(() {
              _deliveryLocation = {
                'latitude': locationUpdate['latitude'] as double,
                'longitude': locationUpdate['longitude'] as double,
                'timestamp':
                    DateTime.parse(locationUpdate['timestamp'] as String),
              };
            });

            // Recalculer le temps estimé
            _calculateEstimatedDeliveryTime();
          }
        },
        onError: (error) {
          debugPrint('❌ Error in delivery location stream: $error');
        },
      );

      // Mettre à jour le temps estimé périodiquement
      _estimatedTimeUpdateTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _calculateEstimatedDeliveryTime(),
      );

      debugPrint('✅ Started real-time tracking for order: ${widget.orderId}');
    } catch (e) {
      debugPrint('❌ Error starting tracking: $e');
    }
  }

  Future<void> _calculateEstimatedDeliveryTime() async {
    if (_order == null ||
        _deliveryLocation == null ||
        _geocodingService == null ||
        _order!.status != OrderStatus.onTheWay) {
      return;
    }

    try {
      // Géocoder l'adresse de livraison
      final deliveryCoords =
          await _geocodingService!.geocodeAddress(_order!.deliveryAddress);

      if (deliveryCoords == null) {
        debugPrint('⚠️ Could not geocode delivery address');
        return;
      }

      // Coordonnées du livreur
      final driverCoords = LatLng(
        _deliveryLocation!['latitude'] as double,
        _deliveryLocation!['longitude'] as double,
      );

      // Calculer le temps de trajet estimé
      final travelTime = await _geocodingService!
          .calculateTravelTime(driverCoords, deliveryCoords);

      if (travelTime != null && mounted) {
        setState(() {
          _estimatedDeliveryTime = '$travelTime min';
        });
      } else {
        // Fallback: calculer la distance et estimer
        final distanceKm =
            _geocodingService!.calculateDistance(driverCoords, deliveryCoords);
        final estimatedMinutes = (distanceKm * 2).round(); // ~2 min/km en ville

        if (mounted) {
          setState(() {
            _estimatedDeliveryTime = '$estimatedMinutes min';
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error calculating estimated delivery time: $e');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Impossible de passer l\'appel vers $phoneNumber')),
        );
      }
    }
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          orderId: widget.orderId,
          driverId: _order?.deliveryPersonId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Suivi de livraison'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Retour',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi de livraison'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrderDetails,
          ),
        ],
      ),
      body: _order == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderHeader(),
                  const SizedBox(height: 24),
                  _buildDeliveryStatus(),
                  const SizedBox(height: 16),
                  _buildActions(),
                  const SizedBox(height: 24),
                  _buildOrderDetails(),
                  const SizedBox(height: 24),
                  _buildDeliveryInfo(),
                  if (_deliveryLocation != null) ...[
                    const SizedBox(height: 24),
                    _buildDeliveryMap(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionItem(
              icon: Icons.chat_bubble_outline,
              label: 'Chat',
              onTap: _openChat,
              color: Colors.blue,
            ),
            _buildActionItem(
              icon: Icons.phone_in_talk,
              label: 'Livreur',
              onTap: () {
                // Placeholder for driver number, assuming we'd fetch it
                // In a real app, you'd get this from the driver object
                _makePhoneCall('+22501010101');
              },
              color: Colors.green,
            ),
            _buildActionItem(
              icon: Icons.headset_mic,
              label: 'Support',
              onTap: () => _makePhoneCall('+22507070707'), // Customer service
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Commande #${widget.orderId.substring(0, 8).toUpperCase()}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _order!.status.displayName,
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Passée le ${_formatDateTime(_order!.orderTime)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${PriceFormatter.format(_order!.total)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statut de livraison',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildStatusTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline() {
    final statuses = [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.pickedUp,
      OrderStatus.onTheWay,
      OrderStatus.delivered,
    ];

    return Column(
      children: statuses.asMap().entries.map((entry) {
        final status = entry.value;
        final isCompleted = status.index <= _order!.status.index;
        final isCurrent = status == _order!.status;

        return Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : Colors.grey[300],
                shape: BoxShape.circle,
                border:
                    isCurrent ? Border.all(color: Colors.blue, width: 2) : null,
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : isCurrent
                      ? const Icon(
                          Icons.radio_button_checked,
                          size: 16,
                          color: Colors.blue,
                        )
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                status.displayName,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? Colors.green : Colors.grey[600],
                ),
              ),
            ),
            if (isCurrent && _estimatedDeliveryTime != null)
              Text(
                _estimatedDeliveryTime!,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildOrderDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détails de la commande',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ..._order!.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('${item.quantity}x'),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.name)),
                    Text(PriceFormatter.format(item.totalPrice)),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sous-total'),
                Text(PriceFormatter.format(_order!.subtotal)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Livraison'),
                Text(PriceFormatter.format(_order!.deliveryFee)),
              ],
            ),
            if (_order!.discount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Remise', style: TextStyle(color: Colors.green)),
                  Text(
                    '-${PriceFormatter.format(_order!.discount)}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  PriceFormatter.format(_order!.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Adresse de livraison',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_order!.deliveryAddress),
            if (_order!.deliveryNotes != null) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${_order!.deliveryNotes}',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryMap() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.map,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Position du livreur',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 48,
                      color: Colors.red[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Livreur en route',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dernière mise à jour: ${_formatDateTime(_deliveryLocation!['timestamp'] as DateTime)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    if (_estimatedDeliveryTime != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Arrivée estimée: $_estimatedDeliveryTime',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_order!.status) {
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
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
