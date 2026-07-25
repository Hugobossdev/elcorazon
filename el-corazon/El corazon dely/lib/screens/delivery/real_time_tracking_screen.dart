import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../services/app_service.dart';
import '../../services/directions_service.dart';
import '../../services/geocoding_service.dart' as geocoding;
import '../../models/order.dart';
import '../../widgets/loading_widget.dart';
import 'driver_profile_screen.dart';
import 'settings_screen.dart';

class RealTimeTrackingScreen extends StatefulWidget {
  final Order order;

  const RealTimeTrackingScreen({
    super.key,
    required this.order,
  });

  @override
  State<RealTimeTrackingScreen> createState() => _RealTimeTrackingScreenState();
}

class _RealTimeTrackingScreenState extends State<RealTimeTrackingScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  LatLng? _driverLocation;
  LatLng? _customerLocation;
  LatLng? _restaurantLocation;

  bool _isTracking = false;
  bool _isLoading = true;
  bool _isCalculatingRoute = false;
  String _estimatedTime = 'Calcul en cours...';
  double _estimatedDistance = 0.0;

  StreamSubscription<Position>? _positionSubscription;
  final DirectionsService _directionsService = DirectionsService();
  final geocoding.GeocodingService _geocodingService = geocoding.GeocodingService();
  
  // Dernière position pour éviter trop de recalculs
  LatLng? _lastCalculatedPosition;
  DateTime? _lastCalculationTime;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    if (!mounted) return;

    try {
      // Get current driver location with timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: Impossible de récupérer la position');
        },
      );

      if (!mounted) return;

      _driverLocation = LatLng(position.latitude, position.longitude);

      // Obtenir les coordonnées de l'adresse de livraison depuis la commande
      try {
        final customerLatLng = await _geocodingService.geocodeAddress(
          widget.order.deliveryAddress,
        );
        
        if (customerLatLng != null) {
          // Convertir geocoding.LatLng en google_maps_flutter.LatLng
          _customerLocation = LatLng(customerLatLng.latitude, customerLatLng.longitude);
          debugPrint('✅ Coordonnées client obtenues: $_customerLocation');
        } else {
          // Fallback: utiliser des coordonnées par défaut si le géocodage échoue
          _customerLocation = const LatLng(5.3599, -4.0083);
          debugPrint('⚠️ Utilisation de coordonnées par défaut pour le client');
        }
      } catch (e) {
        debugPrint('❌ Erreur géocodage adresse client: $e');
        // Fallback: utiliser des coordonnées par défaut
        _customerLocation = const LatLng(5.3599, -4.0083);
      }

      // Position du restaurant (à configurer selon votre restaurant)
      // TODO: Récupérer depuis la base de données ou configuration
      _restaurantLocation = const LatLng(5.3600, -4.0080); // Exemple: Lomé, Togo

      // Start tracking
      if (mounted) {
        await _startTracking();
      }

      // Calculate route and ETA
      if (mounted) {
        await _calculateRoute();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'initialisation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startTracking() async {
    if (_isTracking || !mounted) return;

    setState(() => _isTracking = true);

    // Start position stream
    final positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );

    _positionSubscription = positionStream.listen(
      (Position position) async {
        if (!mounted) return;

        _driverLocation = LatLng(position.latitude, position.longitude);

        // Update map
        if (_mapController != null && mounted) {
          try {
            await _mapController!.animateCamera(
              CameraUpdate.newLatLng(_driverLocation!),
            );
          } catch (e) {
            debugPrint('Error updating camera: $e');
          }
        }

        // Update markers
        if (mounted) {
          _updateMarkers();
        }

        // Send location to backend
        try {
          final appService = Provider.of<AppService>(context, listen: false);
          await appService.updateDeliveryLocation(
            orderId: widget.order.id,
            latitude: _driverLocation!.latitude,
            longitude: _driverLocation!.longitude,
          );
        } catch (e) {
          debugPrint('Erreur envoi position: $e');
        }

        // Recalculate route if needed (throttle to avoid too many calculations)
        if (mounted) {
          await _calculateRoute();
        }

        if (mounted) {
          setState(() {});
        }
      },
      onError: (error) {
        debugPrint('Error in position stream: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de localisation: $error'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    );
  }

  void _stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    
    if (mounted) {
      setState(() => _isTracking = false);
    }
  }

  Future<void> _calculateRoute() async {
    if (_driverLocation == null || _customerLocation == null || !mounted) {
      return;
    }

    // Éviter trop de recalculs (throttling)
    if (_lastCalculatedPosition != null && _lastCalculationTime != null) {
      final distanceSinceLastCalc = _calculateDistance(
        _driverLocation!.latitude,
        _driverLocation!.longitude,
        _lastCalculatedPosition!.latitude,
        _lastCalculatedPosition!.longitude,
      );
      
      final timeSinceLastCalc = DateTime.now().difference(_lastCalculationTime!);
      
      // Ne recalculer que si déplacé de plus de 100m ou après 30 secondes
      if (distanceSinceLastCalc < 0.1 && timeSinceLastCalc.inSeconds < 30) {
        return;
      }
    }

    if (_isCalculatingRoute) return;

    setState(() => _isCalculatingRoute = true);

    try {
      // Utiliser Google Directions API pour obtenir la vraie route
      final routeInfo = await _directionsService.getRoute(
        origin: _driverLocation!,
        destination: _customerLocation!,
        mode: 'driving',
      );

      if (routeInfo != null && mounted) {
        // Mettre à jour les informations
        setState(() {
          _estimatedDistance = routeInfo.distanceKm;
          _estimatedTime = routeInfo.formattedDuration;
          _lastCalculatedPosition = _driverLocation;
          _lastCalculationTime = DateTime.now();
        });

        // Mettre à jour le polyline avec la vraie route
        await _updateRoutePolyline(routeInfo.polylinePoints);
      } else {
        // Fallback: utiliser le calcul Haversine si l'API échoue
        _calculateRouteFallback();
      }
    } catch (e) {
      debugPrint('❌ Erreur calcul route avec Directions API: $e');
      
      // Fallback: utiliser le calcul Haversine
      _calculateRouteFallback();
    } finally {
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
      }
    }
  }

  /// Calcul de route en fallback (Haversine) si l'API échoue
  void _calculateRouteFallback() {
    try {
      double distance = 0.0;
      if (_driverLocation != null && _customerLocation != null) {
        distance = _calculateDistance(
          _driverLocation!.latitude,
          _driverLocation!.longitude,
          _customerLocation!.latitude,
          _customerLocation!.longitude,
        );
      }

      // Estimation basée sur la distance (vitesse moyenne: 30 km/h en ville)
      // Ajouter 5 minutes pour le ramassage
      const averageSpeedKmh = 30.0;
      final minutesPerKm = 60.0 / averageSpeedKmh;
      final estimatedMinutes = (distance * minutesPerKm).round() + 5;
      final duration = Duration(minutes: estimatedMinutes.clamp(5, 60));

      if (mounted) {
        setState(() {
          _estimatedDistance = distance;
          _estimatedTime = _formatDuration(duration);
          _lastCalculatedPosition = _driverLocation;
          _lastCalculationTime = DateTime.now();
        });
      }

      // Créer un polyline simple (ligne droite)
      _updateRoutePolyline([_driverLocation!, _customerLocation!]);
    } catch (e) {
      debugPrint('❌ Erreur calcul route fallback: $e');
    }
  }

  /// Met à jour le polyline de la route sur la carte
  Future<void> _updateRoutePolyline(List<LatLng> points) async {
    if (!mounted || points.isEmpty) return;

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.blue,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    });

    // Ajuster la caméra pour afficher toute la route
    if (_mapController != null && points.length > 1) {
      try {
        final bounds = _calculateBounds(points);
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
      } catch (e) {
        debugPrint('Erreur ajustement caméra: $e');
      }
    }
  }

  /// Calcule les limites (bounds) d'une liste de points
  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _updateMarkers() {
    if (!mounted) return;

    setState(() {
      _markers = {
        if (_driverLocation != null)
          Marker(
            markerId: const MarkerId('driver'),
            position: _driverLocation!,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(
              title: 'Votre position',
              snippet: 'Livreur',
            ),
          ),
        if (_customerLocation != null)
          Marker(
            markerId: const MarkerId('customer'),
            position: _customerLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: 'Client',
              snippet: widget.order.deliveryAddress,
            ),
          ),
        if (_restaurantLocation != null)
          Marker(
            markerId: const MarkerId('restaurant'),
            position: _restaurantLocation!,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(
              title: 'Restaurant',
              snippet: 'Point de départ',
            ),
          ),
      };
    });
  }

  /// Calculate distance between two GPS coordinates using Haversine formula
  /// Returns distance in kilometers
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371.0; // Earth radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.asin(math.sqrt(a));
    final double distance = earthRadius * c;

    return distance;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  Future<void> _updateOrderStatus(OrderStatus status) async {
    try {
      final appService = Provider.of<AppService>(context, listen: false);
      await appService.updateOrderStatus(widget.order.id, status);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut mis à jour: ${status.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back after status update
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de mise à jour: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Suivi - Commande #${widget.order.id.substring(0, 8)}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isTracking ? _stopTracking : _startTracking,
            icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
            tooltip: _isTracking ? 'Arrêter le suivi' : 'Démarrer le suivi',
          ),
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
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Initialisation du suivi...')
          : Column(
              children: [
                // Map
                Expanded(
                  flex: 3,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _driverLocation ?? const LatLng(5.3599, -4.0083),
                      zoom: 15,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      _updateMarkers();
                    },
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: true,
                  ),
                ),

                // Status and controls
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order info
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _isTracking ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isTracking ? 'Suivi actif' : 'Suivi arrêté',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isTracking ? Colors.green : Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ETA and distance
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                'Temps estimé',
                                _isCalculatingRoute ? 'Calcul...' : _estimatedTime,
                                Icons.access_time,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                'Distance',
                                _isCalculatingRoute 
                                    ? 'Calcul...' 
                                    : '${_estimatedDistance.toStringAsFixed(1)} km',
                                Icons.straighten,
                                Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Order status
                        Text(
                          'Statut: ${widget.order.status.displayName}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _updateOrderStatus(OrderStatus.pickedUp),
                                icon: const Icon(Icons.shopping_bag),
                                label: const Text('Commande récupérée'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _updateOrderStatus(OrderStatus.delivered),
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Livré'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
