import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async'; // Added for StreamSubscription
import '../services/realtime_tracking_service.dart';
import '../models/order.dart';
import '../theme.dart';

class RealTimeOrderTracker extends StatefulWidget {
  final Order order;
  final VoidCallback? onOrderDelivered;

  const RealTimeOrderTracker({
    super.key,
    required this.order,
    this.onOrderDelivered,
  });

  @override
  State<RealTimeOrderTracker> createState() => _RealTimeOrderTrackerState();
}

class _RealTimeOrderTrackerState extends State<RealTimeOrderTracker> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _deliveryLocation;
  bool _isTracking = false;
  StreamSubscription? _orderSubscription;
  StreamSubscription? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() {
    final trackingService = context.read<RealtimeTrackingService>();

    // Annuler les souscriptions existantes pour éviter les doublons
    _orderSubscription?.cancel();
    _locationSubscription?.cancel();

    // Suivre cette commande
    trackingService.trackOrder(widget.order.id);
    if (mounted) {
      setState(() {
        _isTracking = true;
      });
    }

    // Écouter les mises à jour de la commande
    _orderSubscription = trackingService.orderUpdates.listen((order) {
      if (!mounted) return;

      if (order.id == widget.order.id) {
        setState(() {
          // Mettre à jour l'état local
        });

        // Si la commande est livrée, appeler le callback
        if (order.status == OrderStatus.delivered) {
          widget.onOrderDelivered?.call();
        }
      }
    });

    // Écouter les mises à jour de position des livreurs
    _locationSubscription = trackingService.deliveryLocationUpdates.listen((
      locationData,
    ) {
      if (!mounted) return;

      if (locationData['orderId'] == widget.order.id) {
        _updateDeliveryLocation(
          LatLng(locationData['latitude'], locationData['longitude']),
        );
      }
    });
  }

  void _updateDeliveryLocation(LatLng location) {
    setState(() {
      _deliveryLocation = location;
      _markers = {
        Marker(
          markerId: const MarkerId('delivery_location'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(
            title: 'Votre commande',
            snippet: 'En cours de livraison',
          ),
        ),
      };
    });

    // Centrer la carte sur la position du livreur
    _mapController?.animateCamera(CameraUpdate.newLatLng(location));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Suivi de commande #${widget.order.id}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isTracking ? Icons.location_on : Icons.location_off),
            onPressed: () {
              setState(() {
                _isTracking = !_isTracking;
              });

              if (_isTracking) {
                _startTracking();
              } else {
                context.read<RealtimeTrackingService>().untrackOrder(
                  widget.order.id,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Informations de la commande
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getStatusIcon(widget.order.status),
                      color: _getStatusColor(widget.order.status),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getStatusText(widget.order.status),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(widget.order.status),
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Commande passée le ${_formatDateTime(widget.order.createdAt)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (widget.order.estimatedDeliveryTime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Livraison estimée: ${_formatDateTime(widget.order.estimatedDeliveryTime!)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Carte de suivi
          Expanded(
            child: _deliveryLocation != null
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _deliveryLocation!,
                      zoom: 15,
                    ),
                    markers: _markers,
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                  )
                : Container(
                    color: AppColors.surfaceVariant,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_searching,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'En attente de la position du livreur',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Timeline de statut
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: _buildStatusTimeline(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline() {
    final statuses = [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.onTheWay,
      OrderStatus.delivered,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progression de votre commande',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...statuses.asMap().entries.map((entry) {
          final status = entry.value;
          final isCompleted = _isStatusCompleted(status);
          final isCurrent = widget.order.status == status;

          return Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted || isCurrent
                      ? AppColors.primary
                      : AppColors.textSecondary.withValues(alpha: 0.3),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : isCurrent
                    ? const Icon(
                        Icons.radio_button_unchecked,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    color: isCompleted || isCurrent
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  bool _isStatusCompleted(OrderStatus status) {
    final statusIndex = [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.onTheWay,
      OrderStatus.delivered,
    ].indexOf(status);

    final currentIndex = [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.onTheWay,
      OrderStatus.delivered,
    ].indexOf(widget.order.status);

    return statusIndex < currentIndex;
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.access_time;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return Icons.restaurant_menu;
      case OrderStatus.onTheWay:
        return Icons.delivery_dining;
      case OrderStatus.pickedUp:
        return Icons.inventory;
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
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
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'En attente de confirmation';
      case OrderStatus.confirmed:
        return 'Commande confirmée';
      case OrderStatus.preparing:
        return 'En cours de préparation';
      case OrderStatus.ready:
        return 'Prête pour la livraison';
      case OrderStatus.onTheWay:
        return 'En cours de livraison';
      case OrderStatus.pickedUp:
        return 'Récupérée par le livreur';
      case OrderStatus.delivered:
        return 'Livrée';
      case OrderStatus.cancelled:
        return 'Annulée';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} à ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _locationSubscription?.cancel();
    _mapController?.dispose();

    if (_isTracking) {
      // Nous ne pouvons pas utiliser context.read() de manière fiable ici si le widget est démonté
      // Idéalement, nous devrions avoir une référence au service, mais pour l'instant, nous ignorons l'erreur potentielle
      try {
        context.read<RealtimeTrackingService>().untrackOrder(widget.order.id);
      } catch (e) {
        // Ignorer si le contexte n'est plus valide
      }
    }
    super.dispose();
  }
}
