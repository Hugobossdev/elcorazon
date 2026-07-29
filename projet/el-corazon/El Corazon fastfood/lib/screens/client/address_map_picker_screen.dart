import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:elcora_fast/services/geocoding_service.dart';
import 'package:elcora_fast/services/delivery_fee_service.dart';
import 'package:elcora_fast/models/delivery_fee_breakdown.dart';
import 'package:elcora_fast/config/delivery_config.dart';
import 'package:elcora_fast/utils/price_formatter.dart';

/// Résultat de la sélection de position
class PickedLocation {
  final LatLng location;
  final String? formattedAddress;

  PickedLocation({
    required this.location,
    this.formattedAddress,
  });
}

/// Map Picker amélioré avec zones visuelles et calcul de frais
class EnhancedMapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const EnhancedMapPickerScreen({super.key, this.initialLocation});

  @override
  State<EnhancedMapPickerScreen> createState() =>
      _EnhancedMapPickerScreenState();
}

class _EnhancedMapPickerScreenState extends State<EnhancedMapPickerScreen> {
  GoogleMapController? _mapController;
  final GeocodingService _geocodingService = GeocodingService();
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();

  // Restaurant location (à définir selon votre config)
  static const LatLng _restaurantLocation = LatLng(5.3599, -4.0083);

  LatLng? _currentPosition;
  String? _formattedAddress;
  DeliveryFeeBreakdown? _feeBreakdown;
  bool _isLoadingAddress = false;
  Timer? _debounceTimer;

  final Set<Circle> _circles = {};
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialLocation;
    _initializeMap();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    await _deliveryFeeService.initialize();

    if (_currentPosition == null) {
      await _getCurrentLocation();
    } else {
      await _updateLocationInfo(_currentPosition!);
    }

    _setupZoneCircles();
  }

  void _setupZoneCircles() {
    setState(() {
      _circles.clear();

      // Cercle zone desservie (vert)
      _circles.add(
        Circle(
          circleId: const CircleId('serviceable_zone'),
          center: _restaurantLocation,
          radius: DeliveryConfig.maxDeliveryDistance * 1000, // km → m
          fillColor: Colors.green.withValues(alpha: 0.1),
          strokeColor: Colors.green,
          strokeWidth: 2,
        ),
      );

      // Cercle limite étendue (rouge léger)
      _circles.add(
        Circle(
          circleId: const CircleId('extended_zone'),
          center: _restaurantLocation,
          radius: (DeliveryConfig.maxDeliveryDistance + 5) * 1000,
          fillColor: Colors.red.withValues(alpha: 0.05),
          strokeColor: Colors.red.withValues(alpha: 0.3),
          strokeWidth: 1,
        ),
      );
    });
  }

  void _updateMarkers(LatLng position) {
    setState(() {
      _markers.clear();

      // Marqueur restaurant
      _markers.add(
        Marker(
          markerId: const MarkerId('restaurant'),
          position: _restaurantLocation,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Restaurant'),
        ),
      );

      // Marqueur position sélectionnée
      _markers.add(
        Marker(
          markerId: const MarkerId('delivery'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _feeBreakdown?.isInServiceableZone == true
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: 'Position de livraison',
            snippet: _formattedAddress ?? 'Chargement...',
          ),
        ),
      );
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentPosition = latLng;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 14),
      );

      await _updateLocationInfo(latLng);
    } catch (e) {
      debugPrint('Erreur obtention position: $e');
      // Fallback vers restaurant
      setState(() {
        _currentPosition = _restaurantLocation;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_restaurantLocation, 14),
      );
    }
  }

  void _onCameraMove(CameraPosition position) {
    // Annuler le timer précédent
    _debounceTimer?.cancel();
  }

  void _onCameraIdle() {
    if (_mapController == null) return;

    // Debounce: attendre 500ms avant de mettre à jour
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final center = await _mapController!.getVisibleRegion();
      final centerPoint = LatLng(
        (center.northeast.latitude + center.southwest.latitude) / 2,
        (center.northeast.longitude + center.southwest.longitude) / 2,
      );

      setState(() {
        _currentPosition = centerPoint;
      });

      await _updateLocationInfo(centerPoint);
    });
  }

  Future<void> _updateLocationInfo(LatLng position) async {
    // Reverse geocode
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      // Geocoding
      final address = await _geocodingService.reverseGeocode(position);

      // Calcul frais
      final breakdown = await _deliveryFeeService.calculateDetailedDeliveryFee(
        deliveryLatitude: position.latitude,
        deliveryLongitude: position.longitude,
      );

      if (mounted) {
        setState(() {
          _formattedAddress = address;
          _feeBreakdown = breakdown;
          _isLoadingAddress = false;
        });

        _updateMarkers(position);
      }
    } catch (e) {
      debugPrint('Erreur mise à jour infos: $e');
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentPosition!, 14),
                );
              }
            },
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? _restaurantLocation,
              zoom: 14,
            ),
            circles: _circles,
            markers: _markers,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Pin central
          Center(
            child: Icon(
              Icons.location_on,
              size: 48,
              color: _feeBreakdown?.isInServiceableZone == true
                  ? Colors.green
                  : Colors.red,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),

          // Top bar
          SafeArea(child: _buildTopBar()),

          // Légende
          _buildLegend(),

          // Bouton Ma position
          _buildMyLocationButton(),

          // Info sheet (glassmorphism)
          _buildInfoSheet(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              'Sélectionnez votre position',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      top: 88,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLegendItem(
              color: Colors.green,
              label: 'Zone desservie',
            ),
            const SizedBox(height: 8),
            _buildLegendItem(
              color: Colors.red,
              label: 'Hors zone',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMyLocationButton() {
    return Positioned(
      right: 16,
      bottom: 200,
      child: FloatingActionButton(
        onPressed: _getCurrentLocation,
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildInfoSheet() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.95),
              Colors.white.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Position détectée',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                      ),
                      const SizedBox(height: 2),
                      _isLoadingAddress
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _formattedAddress ?? 'Recherche en cours...',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ],
                  ),
                ),
              ],
            ),

            if (_feeBreakdown != null) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              _buildFeeInfo(_feeBreakdown!),
            ],

            const SizedBox(height: 20),

            // Bouton validation
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _currentPosition != null &&
                        (_feeBreakdown?.isInServiceableZone ?? false)
                    ? _confirmLocation
                    : null,
                icon: const Icon(Icons.check_circle),
                label: const Text('Utiliser cette position'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeInfo(DeliveryFeeBreakdown breakdown) {
    if (!breakdown.isInServiceableZone) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zone non desservie',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                  Text(
                    'Distance: ${breakdown.distance.toStringAsFixed(1)} km (max ${DeliveryConfig.maxDeliveryDistance.toInt()} km)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (breakdown.isFreeDelivery) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.card_giftcard, color: Colors.green.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Livraison gratuite ! 🎉',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Infos normales
    return Column(
      children: [
        _buildInfoRow(
          icon: Icons.straighten,
          label: 'Distance',
          value: '${breakdown.distance.toStringAsFixed(1)} km',
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          icon: Icons.payments,
          label: 'Frais de livraison',
          value: PriceFormatter.format(breakdown.totalFee),
          bold: true,
        ),
        if (breakdown.estimatedDeliveryTime != null) ...[
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.schedule,
            label: 'Temps estimé',
            value: '~${breakdown.estimatedDeliveryTime} min',
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool bold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color:
                bold ? Theme.of(context).colorScheme.primary : Colors.black87,
          ),
        ),
      ],
    );
  }

  void _confirmLocation() {
    if (_currentPosition == null) return;

    Navigator.of(context).pop(
      PickedLocation(
        location: _currentPosition!,
        formattedAddress: _formattedAddress,
      ),
    );
  }
}
