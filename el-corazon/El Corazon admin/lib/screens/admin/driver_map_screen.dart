import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/driver_management_service.dart';
import '../../services/geocoding_service.dart' as geocoding;
import '../../models/driver.dart';
import '../../models/order.dart';
import '../../services/order_management_service.dart';
import '../../services/delivery_zone_service.dart';
import '../../utils/dialog_helper.dart';

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final Map<String, Driver> _selectedDrivers = {};
  bool _showAllDrivers = true;
  String? _selectedZone;
  DriverStatus? _statusFilter;
  bool _showOrders = true;
  bool _showRoutes = true;
  GoogleMapController? _mapController;
  Timer? _refreshTimer;
  StreamSubscription? _driversSubscription;
  late final DeliveryZoneService _zoneService;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(14.6928, -17.4467), // Dakar, Senegal
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _zoneService = DeliveryZoneService();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _driversSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    // Actualiser les positions toutes les 10 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        // Recharger les données
        context.read<DriverManagementService>().refresh();
        // OrderManagementService n'a pas de méthode refresh publique,
        // mais les données sont mises à jour automatiquement via Supabase Realtime
        setState(() {}); // Forcer la reconstruction de la carte
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi des Livreurs'),
        actions: [
          Container(
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterDialog(),
              tooltip: 'Filtres',
            ),
          ),
          Container(
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            child: IconButton(
              icon: Icon(_showOrders
                  ? Icons.shopping_cart
                  : Icons.shopping_cart_outlined),
              onPressed: () {
                setState(() => _showOrders = !_showOrders);
              },
              tooltip: _showOrders ? 'Masquer commandes' : 'Afficher commandes',
            ),
          ),
          Container(
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Recharger les données
                context.read<DriverManagementService>().refresh();
                // OrderManagementService se met à jour automatiquement via Supabase Realtime
                setState(() {}); // Forcer la reconstruction de la carte
              },
              tooltip: 'Actualiser',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de filtres et légende
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('Tous'),
                            icon: Icon(Icons.people),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('Sélectionnés'),
                            icon: Icon(Icons.check_circle),
                          ),
                        ],
                        selected: {_showAllDrivers},
                        onSelectionChanged: (Set<bool> newSelection) {
                          setState(() {
                            _showAllDrivers = newSelection.first;
                          });
                        },
                      ),
                    ),
                    if (_selectedZone != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Chip(
                          label: Text(_selectedZone!),
                          onDeleted: () {
                            setState(() {
                              _selectedZone = null;
                            });
                          },
                        ),
                      ),
                    if (_statusFilter != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Chip(
                          label: Text(_statusFilter!.displayName),
                          avatar: Icon(_statusFilter!.icon, size: 18),
                          onDeleted: () {
                            setState(() {
                              _statusFilter = null;
                            });
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Légende
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _buildLegendItem(
                        DriverStatus.available, 'Disponible', Colors.green),
                    _buildLegendItem(
                        DriverStatus.onDelivery, 'En livraison', Colors.orange),
                    _buildLegendItem(
                        DriverStatus.offline, 'Hors ligne', Colors.grey),
                    _buildLegendItem(
                        DriverStatus.unavailable, 'Indisponible', Colors.red),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Carte
          Expanded(
            child: Consumer2<DriverManagementService, OrderManagementService>(
              builder: (context, driverService, orderService, child) {
                final drivers = _showAllDrivers
                    ? driverService.drivers
                    : _selectedDrivers.values.toList();

                // Filtrer par zone et statut
                var filteredDrivers = drivers;

                if (_selectedZone != null && _zoneService.zones.isNotEmpty) {
                  // Trouver la zone correspondant au nom sélectionné
                  final selectedZone = _zoneService.zones.firstWhere(
                    (zone) => zone.name == _selectedZone,
                    orElse: () => _zoneService.zones.first,
                  );

                  // Filtrer les livreurs qui sont dans la zone sélectionnée
                  filteredDrivers = filteredDrivers.where((driver) {
                    // Si le livreur n'a pas de position, l'exclure
                    if (driver.latitude == null || driver.longitude == null) {
                      return false;
                    }
                    // Vérifier si le livreur est dans le polygone de la zone
                    return _isPointInPolygon(
                      driver.latitude!,
                      driver.longitude!,
                      selectedZone.polygon,
                    );
                  }).toList();
                }

                if (_statusFilter != null) {
                  filteredDrivers = filteredDrivers
                      .where((driver) => driver.status == _statusFilter)
                      .toList();
                }

                // Filtrer les commandes actives
                final activeOrders = _showOrders
                    ? orderService.allOrders
                        .where((order) =>
                            order.status == OrderStatus.confirmed ||
                            order.status == OrderStatus.preparing ||
                            order.status == OrderStatus.ready ||
                            order.status == OrderStatus.pickedUp ||
                            order.status == OrderStatus.onTheWay)
                        .toList()
                    : <Order>[];

                return _buildMapView(filteredDrivers, activeOrders);
              },
            ),
          ),
          // Liste des livreurs
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.list, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Livreurs',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Consumer<DriverManagementService>(
                        builder: (context, service, child) {
                          final onlineCount = service.drivers
                              .where((d) =>
                                  d.status == DriverStatus.available ||
                                  d.status == DriverStatus.onDelivery)
                              .length;
                          return Text(
                            '$onlineCount en ligne',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Consumer<DriverManagementService>(
                    builder: (context, service, child) {
                      final drivers = _showAllDrivers
                          ? service.drivers
                          : _selectedDrivers.values.toList();

                      if (drivers.isEmpty) {
                        return Center(
                          child: Text(
                            'Aucun livreur',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: drivers.length,
                        itemBuilder: (context, index) {
                          final driver = drivers[index];
                          final isSelected =
                              _selectedDrivers.containsKey(driver.id);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(driver.status),
                                child: Icon(
                                  driver.status.icon,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                driver.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driver.status.displayName,
                                    style: TextStyle(
                                      color: _getStatusColor(driver.status),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (driver.vehicleType != null)
                                    Text(
                                      driver.vehicleType!,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedDrivers[driver.id] = driver;
                                      } else {
                                        _selectedDrivers.remove(driver.id);
                                      }
                                    });
                                  },
                                ),
                              ),
                              onTap: () {
                                // Centrer la carte sur ce livreur
                                _centerOnDriver(driver);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView(List<Driver> drivers, List<Order> orders) {
    Set<Marker> markers = {};
    Set<Polyline> polylines = {};

    // Marqueurs pour les livreurs
    for (var driver in drivers) {
      if (driver.latitude != null && driver.longitude != null) {
        markers.add(
          Marker(
            markerId: MarkerId('driver_${driver.id}'),
            position: LatLng(driver.latitude!, driver.longitude!),
            infoWindow: InfoWindow(
              title: driver.name,
              snippet:
                  '${driver.status.displayName} - ${driver.vehicleType ?? "Véhicule"}',
              onTap: () => _showDriverInfo(driver),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _getMarkerHue(driver.status),
            ),
            rotation: driver.status == DriverStatus.onDelivery
                ? 45.0
                : 0.0, // Rotation pour livreurs en course
          ),
        );
      }
    }

    // Marqueurs et itinéraires pour les commandes actives
    if (_showOrders) {
      final geocodingService = geocoding.GeocodingService();

      for (var order in orders) {
        // Si la commande a un livreur assigné et qu'il est en livraison
        if (order.deliveryPersonId != null) {
          final driver = drivers.firstWhere(
            (d) => d.id == order.deliveryPersonId,
            orElse: () => drivers.firstWhere(
              (d) => d.userId == order.deliveryPersonId,
              orElse: () => drivers.firstWhere(
                (d) => d.authUserId == order.deliveryPersonId,
                orElse: () => Driver(
                  id: '',
                  name: 'Livreur inconnu',
                  email: '',
                  phone: '',
                  createdAt: DateTime.now(),
                ),
              ),
            ),
          );

          if (driver.latitude != null && driver.longitude != null) {
            // Géocoder l'adresse de livraison si nécessaire
            _geocodeAndAddOrderMarker(
              order,
              driver,
              markers,
              polylines,
              geocodingService,
            );
          }
        }
      }
    }

    return Stack(
      children: [
        _buildMapWidget(markers, polylines, drivers),
        // Bouton pour ajuster la vue
        Positioned(
          bottom: 80,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'fit_bounds',
            onPressed: () => _fitBounds(drivers),
            tooltip: 'Ajuster la vue',
            child: const Icon(Icons.fit_screen),
          ),
        ),
      ],
    );
  }

  Widget _buildMapWidget(
      Set<Marker> markers, Set<Polyline> polylines, List<Driver> drivers) {
    return GoogleMap(
      initialCameraPosition: _initialPosition,
      markers: markers,
      polylines: polylines,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        // Ajuster la caméra pour afficher tous les marqueurs
        if (drivers.isNotEmpty) {
          _fitBounds(drivers);
        }
      },
      myLocationEnabled: true,
      zoomControlsEnabled: true,
      mapType: MapType.normal,
      compassEnabled: true,
      mapToolbarEnabled: false,
      onTap: (LatLng position) {
        // Fermer les info windows si on clique ailleurs
      },
    );
  }

  Future<void> _geocodeAndAddOrderMarker(
    Order order,
    Driver driver,
    Set<Marker> markers,
    Set<Polyline> polylines,
    geocoding.GeocodingService geocodingService,
  ) async {
    try {
      final deliveryLocation = await geocodingService.geocodeAddress(
        order.deliveryAddress,
      );

      if (deliveryLocation != null) {
        // Convertir geocoding.LatLng en google_maps_flutter.LatLng
        final googleLatLng =
            LatLng(deliveryLocation.latitude, deliveryLocation.longitude);

        // Ajouter marqueur pour la destination
        markers.add(
          Marker(
            markerId: MarkerId('order_${order.id}'),
            position: googleLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(
              title: 'Commande #${order.id.substring(0, 8)}',
              snippet: order.deliveryAddress,
              onTap: () => _showOrderInfo(order),
            ),
          ),
        );

        // Ajouter itinéraire si demandé
        if (_showRoutes &&
            driver.latitude != null &&
            driver.longitude != null) {
          final driverLatLng =
              geocoding.LatLng(driver.latitude!, driver.longitude!);
          final directions = await geocodingService.getDirections(
            driverLatLng,
            deliveryLocation,
          );

          if (directions != null && directions.isNotEmpty) {
            // Convertir les points geocoding.LatLng en google_maps_flutter.LatLng
            final googlePoints = directions
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();

            polylines.add(
              Polyline(
                polylineId: PolylineId('route_${order.id}'),
                points: googlePoints,
                color: Colors.blue,
                width: 4,
                patterns: [
                  PatternItem.dash(20),
                  PatternItem.gap(10),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur géocodage commande ${order.id}: $e');
    }
  }

  void _fitBounds(List<Driver> drivers) {
    if (_mapController == null || drivers.isEmpty) return;

    final validDrivers = drivers
        .where((d) => d.latitude != null && d.longitude != null)
        .toList();

    if (validDrivers.isEmpty) return;

    double minLat = validDrivers.first.latitude!;
    double maxLat = validDrivers.first.latitude!;
    double minLng = validDrivers.first.longitude!;
    double maxLng = validDrivers.first.longitude!;

    for (var driver in validDrivers) {
      if (driver.latitude != null && driver.longitude != null) {
        minLat = minLat < driver.latitude! ? minLat : driver.latitude!;
        maxLat = maxLat > driver.latitude! ? maxLat : driver.latitude!;
        minLng = minLng < driver.longitude! ? minLng : driver.longitude!;
        maxLng = maxLng > driver.longitude! ? maxLng : driver.longitude!;
      }
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  void _showOrderInfo(Order order) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Commande #${order.id.substring(0, 8)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Statut', order.status.displayName),
            _buildInfoRow('Client ID', order.userId.substring(0, 8)),
            _buildInfoRow('Adresse', order.deliveryAddress),
            _buildInfoRow('Montant', '${order.total} CFA'),
            _buildInfoRow('Date',
                '${order.orderTime.day}/${order.orderTime.month}/${order.orderTime.year}'),
          ],
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

  double _getMarkerHue(DriverStatus status) {
    switch (status) {
      case DriverStatus.available:
        return BitmapDescriptor.hueGreen;
      case DriverStatus.onDelivery:
        return BitmapDescriptor.hueOrange;
      case DriverStatus.offline:
        return BitmapDescriptor.hueViolet; // Grey not available as hue
      case DriverStatus.unavailable:
        return BitmapDescriptor.hueRed;
    }
  }

  Widget _buildLegendItem(DriverStatus status, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Color _getStatusColor(DriverStatus status) {
    switch (status) {
      case DriverStatus.available:
        return Colors.green;
      case DriverStatus.onDelivery:
        return Colors.orange;
      case DriverStatus.offline:
        return Colors.grey;
      case DriverStatus.unavailable:
        return Colors.red;
    }
  }

  void _showDriverInfo(Driver driver) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(driver.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Statut', driver.status.displayName),
            _buildInfoRow('Email', driver.email),
            _buildInfoRow('Téléphone', driver.phone),
            if (driver.vehicleType != null)
              _buildInfoRow('Véhicule', driver.vehicleType!),
            if (driver.latitude != null && driver.longitude != null)
              _buildInfoRow(
                'Position',
                '${driver.latitude!.toStringAsFixed(4)}, ${driver.longitude!.toStringAsFixed(4)}',
              ),
            _buildInfoRow('Note', driver.rating.toStringAsFixed(1)),
            _buildInfoRow('Livraisons', '${driver.totalDeliveries}'),
          ],
        ),
        actions: [
          Container(
            constraints: const BoxConstraints(
              minHeight: 48,
            ),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ),
          Container(
            constraints: const BoxConstraints(
              minHeight: 48,
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _centerOnDriver(driver);
              },
              child: const Text('Centrer sur carte'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  void _centerOnDriver(Driver driver) {
    if (driver.latitude != null &&
        driver.longitude != null &&
        _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(driver.latitude!, driver.longitude!),
          15,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Position non disponible pour ${driver.name}'),
        ),
      );
    }
  }

  void _showFilterDialog() {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 500.0);
        final dialogHeight = (screenSize.height * 0.5).clamp(300.0, 500.0);

        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: dialogWidth,
              maxWidth: dialogWidth,
              minHeight: dialogHeight,
              maxHeight: dialogHeight,
            ),
            child: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Filtres',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Zone:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(
                              minHeight: 56,
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedZone,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Sélectionner une zone',
                              ),
                              items: [
                                const DropdownMenuItem(
                                    value: null, child: Text('Toutes')),
                                ...[
                                  'Zone Centre',
                                  'Zone Nord',
                                  'Zone Sud',
                                  'Zone Est',
                                  'Zone Ouest'
                                ].map((zone) => DropdownMenuItem(
                                      value: zone,
                                      child: Text(zone),
                                    )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedZone = value;
                                });
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text('Statut:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(
                              minHeight: 56,
                            ),
                            child: DropdownButtonFormField<DriverStatus>(
                              initialValue: _statusFilter,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Filtrer par statut',
                              ),
                              items: [
                                const DropdownMenuItem(
                                    value: null, child: Text('Tous')),
                                ...DriverStatus.values
                                    .map((status) => DropdownMenuItem(
                                          value: status,
                                          child: Row(
                                            children: [
                                              Icon(status.icon,
                                                  size: 18,
                                                  color: status.color),
                                              const SizedBox(width: 8),
                                              Text(status.displayName),
                                            ],
                                          ),
                                        )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _statusFilter = value;
                                });
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Checkbox(
                                value: _showOrders,
                                onChanged: (value) {
                                  setState(() {
                                    _showOrders = value ?? true;
                                  });
                                },
                              ),
                              const Text('Afficher les commandes actives'),
                            ],
                          ),
                          Row(
                            children: [
                              Checkbox(
                                value: _showRoutes,
                                onChanged: (value) {
                                  setState(() {
                                    _showRoutes = value ?? true;
                                  });
                                },
                              ),
                              const Text('Afficher les itinéraires'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  // Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          constraints: const BoxConstraints(
                            minHeight: 48,
                          ),
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedZone = null;
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('Réinitialiser'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(
                            minHeight: 48,
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Fermer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Vérifier si un point est dans un polygone (algorithme Ray Casting)
  bool _isPointInPolygon(
    double latitude,
    double longitude,
    List<Map<String, double>> polygon,
  ) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i]['longitude']!;
      final yi = polygon[i]['latitude']!;
      final xj = polygon[j]['longitude']!;
      final yj = polygon[j]['latitude']!;

      final intersect = ((yi > latitude) != (yj > latitude)) &&
          (longitude < (xj - xi) * (latitude - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
      j = i;
    }

    return inside;
  }
}
