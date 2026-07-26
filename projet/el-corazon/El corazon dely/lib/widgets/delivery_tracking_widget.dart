import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentLocation;
  LatLng? _destinationLocation;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  void _initializeTracking() {
    final trackingService = context.read<RealtimeTrackingService>();

    // Écouter les mises à jour de position
    trackingService.orderUpdates.listen((order) {
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
    final trackingService = context.read<RealtimeTrackingService>();
    _currentLocation = trackingService.currentPosition != null
        ? LatLng(
            trackingService.currentPosition!.latitude,
            trackingService.currentPosition!.longitude,
          )
        : null;

    if (_currentLocation != null) {
      _updateMarkers();
      _calculateRoute();
    }
  }

  Future<void> _geocodeDeliveryAddress() async {
    try {
      final trackingService = context.read<RealtimeTrackingService>();
      final coordinates =
          await trackingService.geocodeAddress(widget.order.deliveryAddress);

      if (coordinates != null) {
        setState(() {
          _destinationLocation =
              LatLng(coordinates.latitude, coordinates.longitude);
        });
        _updateMarkers();
        _calculateRoute();
      } else {
        // Coordonnées par défaut si le géocodage échoue
        setState(() {
          _destinationLocation =
              const LatLng(48.8566, 2.3522); // Paris par défaut
        });
        _updateMarkers();
      }
    } catch (e) {
      debugPrint('Erreur de géocodage: $e');
      // Coordonnées par défaut en cas d'erreur
      setState(() {
        _destinationLocation = const LatLng(48.8566, 2.3522);
      });
      _updateMarkers();
    }
  }

  void _updateMarkers() {
    _markers.clear();

    // Marqueur de position actuelle
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Ma position',
            snippet: 'Position actuelle',
          ),
        ),
      );
    }

    // Marqueur de destination
    if (_destinationLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: widget.order.deliveryAddress,
          ),
        ),
      );
    }

    setState(() {});
  }

  void _calculateRoute() {
    if (_currentLocation != null && _destinationLocation != null) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_currentLocation!, _destinationLocation!],
          color: AppColors.primary,
          width: 4,
          patterns: [PatternItem.dot, PatternItem.gap(10)],
        ),
      };
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.textSecondary.withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Carte Google Maps
            if (_currentLocation != null)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentLocation!,
                  zoom: 15,
                ),
                markers: _markers,
                polylines: _polylines,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
              )
            else
              Container(
                color: AppColors.surfaceVariant,
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
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Informations de livraison
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Container(
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
                        Icon(
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Container(
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
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Destination: ${widget.order.deliveryAddress}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Boutons d'action
            Positioned(
              bottom: 8,
              right: 8,
              child: Column(
                children: [
                  if (widget.order.status == OrderStatus.onTheWay) ...[
                    FloatingActionButton.small(
                      onPressed: () => _showDeliveryOptions(context),
                      backgroundColor: AppColors.success,
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FloatingActionButton.small(
                    onPressed: _centerMapOnLocation,
                    backgroundColor: AppColors.primary,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _centerMapOnLocation() {
    if (_currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_currentLocation!),
      );
    }
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
    final trackingService = context.read<RealtimeTrackingService>();
    trackingService.markAsDelivered(widget.order.id);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Commande marquée comme livrée'),
        backgroundColor: AppColors.success,
      ),
    );
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
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
