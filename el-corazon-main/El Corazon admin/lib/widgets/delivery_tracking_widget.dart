import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/realtime_tracking_service.dart';
import '../models/order.dart';
import '../theme.dart';

class DeliveryTrackingWidget extends StatefulWidget {
  final Order order;
  final VoidCallback? onDeliveryCompleted;

  const DeliveryTrackingWidget({
    super.key,
    required this.order,
    this.onDeliveryCompleted,
  });

  @override
  State<DeliveryTrackingWidget> createState() => _DeliveryTrackingWidgetState();
}

class _DeliveryTrackingWidgetState extends State<DeliveryTrackingWidget> {
  // Web-compatible tracking without Google Maps
  Map<String, double>? _currentLocation;
  Map<String, double>? _destinationLocation;
  StreamSubscription? _orderUpdatesSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeTracking();
      }
    });
  }

  void _initializeTracking() {
    if (!mounted) return;

    final trackingService = context.read<RealtimeTrackingService>();

    // Écouter les mises à jour de position
    _orderUpdatesSubscription = trackingService.orderUpdates.listen((order) {
      if (!mounted) return;

      if (order.id == widget.order.id) {
        setState(() {
          // Mettre à jour l'état de la commande
        });

        if (order.status == OrderStatus.delivered) {
          widget.onDeliveryCompleted?.call();
        }
      }
    });

    // Obtenir la position actuelle
    _getCurrentLocation();

    // Géocoder l'adresse de livraison pour obtenir les coordonnées
    _geocodeDeliveryAddress();

    _updateMarkers();
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    final trackingService = context.read<RealtimeTrackingService>();
    _currentLocation = trackingService.currentPosition != null
        ? {
            'latitude': trackingService.currentPosition!.latitude,
            'longitude': trackingService.currentPosition!.longitude,
          }
        : null;

    if (_currentLocation != null && mounted) {
      _updateMarkers();
      _calculateRoute();
    }
  }

  Future<void> _geocodeDeliveryAddress() async {
    if (!mounted) return;

    try {
      final trackingService = context.read<RealtimeTrackingService>();
      final coordinates = await trackingService.geocodeAddress(
        widget.order.deliveryAddress,
      );

      if (!mounted) return;

      if (coordinates != null) {
        setState(() {
          _destinationLocation = {
            'latitude': coordinates.latitude,
            'longitude': coordinates.longitude,
          };
        });
        _updateMarkers();
        _calculateRoute();
      } else {
        // Coordonnées par défaut si le géocodage échoue
        setState(() {
          _destinationLocation = {
            'latitude': 48.8566,
            'longitude': 2.3522,
          }; // Paris par défaut
        });
        _updateMarkers();
      }
    } catch (e) {
      debugPrint('Erreur de géocodage: $e');
      if (!mounted) return;

      // Coordonnées par défaut en cas d'erreur
      setState(() {
        _destinationLocation = {'latitude': 48.8566, 'longitude': 2.3522};
      });
      _updateMarkers();
    }
  }

  void _updateMarkers() {
    // Web-compatible marker update (simplified)
    if (mounted) {
      setState(() {});
    }
  }

  void _calculateRoute() {
    // Web-compatible route calculation (simplified)
    if (_currentLocation != null && _destinationLocation != null && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: Container avec height définie garantit que le Stack a des contraintes
    // Le Stack nécessite des contraintes de taille pour que Positioned fonctionne correctement
    return Container(
      // Hauteur fixe garantit que le widget a une taille définie avant le layout
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        // Stack nécessite des contraintes de taille de son parent
        child: Stack(
          // fit: StackFit.expand pour que le Stack prenne toute la taille du parent
          fit: StackFit.expand,
          children: [
            // Web-compatible map placeholder
            // Container avec contraintes de taille définies
            if (_currentLocation != null)
              Container(
                // width et height définis explicitement pour garantir une taille
                width: double.infinity,
                height: double.infinity,
                color: AppColors.surfaceContainerHighest,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, size: 48, color: AppColors.textSecondary),
                      SizedBox(height: 8),
                      Text(
                        'Carte de suivi (Web)',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                // width et height définis explicitement pour garantir une taille
                width: double.infinity,
                height: double.infinity,
                color: AppColors.surfaceContainerHighest,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_searching,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Obtention de votre position...',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),

            // Informations de livraison
            // IMPORTANT: Positioned avec Container ayant contraintes de taille explicites
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              // IMPORTANT: Container avec contraintes explicites pour garantir une taille définie
              child: Container(
                constraints: const BoxConstraints(minHeight: 80),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.delivery_dining,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Commande #${widget.order.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(widget.order.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(widget.order.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Destination: ${widget.order.deliveryAddress}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Boutons d'action
            // Positioned nécessite que le Stack ait des contraintes de taille
            Positioned(
              bottom: 8,
              right: 8,
              // IMPORTANT: Container avec taille explicite pour garantir des contraintes
              child: Container(
                constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                // Column sans mainAxisSize.min pour garantir des contraintes
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.order.status == OrderStatus.onTheWay) ...[
                      FloatingActionButton.small(
                        // Callback appelé après que le widget soit complètement rendu
                        onPressed: () => _showDeliveryOptions(context),
                        backgroundColor: AppColors.success,
                        child: const Icon(Icons.check, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                    ],
                    FloatingActionButton.small(
                      // Callback appelé après que le widget soit complètement rendu
                      onPressed: _centerMapOnLocation,
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.my_location, color: Colors.white),
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

  void _centerMapOnLocation() {
    // Web-compatible map centering (simplified)
    debugPrint('Centering map on location: $_currentLocation');
  }

  void _showDeliveryOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Marquer comme livrée',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Êtes-vous sûr d\'avoir livré la commande #${widget.order.id} ?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _markAsDelivered();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirmer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _markAsDelivered() {
    if (!mounted) return;

    final trackingService = context.read<RealtimeTrackingService>();
    trackingService.markAsDelivered(widget.order.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commande marquée comme livrée'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.confirmed:
        return AppColors.primary;
      case OrderStatus.preparing:
        return AppColors.tertiary;
      case OrderStatus.ready:
        return AppColors.secondary;
      case OrderStatus.onTheWay:
        return AppColors.primary;
      case OrderStatus.pickedUp:
        return AppColors.secondary;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
      case OrderStatus.refunded:
        return Colors.grey;
      case OrderStatus.failed:
        return AppColors.error;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.confirmed:
        return 'Confirmée';
      case OrderStatus.preparing:
        return 'Préparation';
      case OrderStatus.ready:
        return 'Prête';
      case OrderStatus.onTheWay:
        return 'En livraison';
      case OrderStatus.pickedUp:
        return 'Récupérée';
      case OrderStatus.delivered:
        return 'Livrée';
      case OrderStatus.cancelled:
        return 'Annulée';
      case OrderStatus.refunded:
        return 'Remboursée';
      case OrderStatus.failed:
        return 'Échouée';
    }
  }

  @override
  void dispose() {
    _orderUpdatesSubscription?.cancel();
    super.dispose();
  }
}
