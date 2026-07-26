import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver.dart';

/// Modèle pour une zone de livraison
class DeliveryZone {
  final String id;
  final String name;
  final String description;
  final List<Map<String, double>> polygon; // Coordonnées du polygone
  final double deliveryFee;
  final int estimatedTimeMinutes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DeliveryZone({
    required this.id,
    required this.name,
    required this.description,
    required this.polygon,
    required this.deliveryFee,
    required this.estimatedTimeMinutes,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory DeliveryZone.fromMap(Map<String, dynamic> map) {
    return DeliveryZone(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      polygon:
          (map['polygon'] as List?)
              ?.map(
                (p) => {
                  'latitude': (p['latitude'] as num).toDouble(),
                  'longitude': (p['longitude'] as num).toDouble(),
                },
              )
              .toList() ??
          [],
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      estimatedTimeMinutes: map['estimated_time_minutes'] as int? ?? 30,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'polygon': polygon,
      'delivery_fee': deliveryFee,
      'estimated_time_minutes': estimatedTimeMinutes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Service de gestion des zones de livraison
class DeliveryZoneService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<DeliveryZone> _zones = [];
  bool _isLoading = false;

  List<DeliveryZone> get zones => _zones;
  bool get isLoading => _isLoading;

  DeliveryZoneService() {
    _loadZones();
  }

  /// Charger toutes les zones
  Future<void> _loadZones() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('delivery_zones')
          .select()
          .order('name', ascending: true);

      _zones = (response as List)
          .map((data) => DeliveryZone.fromMap(data))
          .toList();

      debugPrint('✅ ${_zones.length} zone(s) de livraison chargée(s)');
    } catch (e) {
      debugPrint(
        '⚠️ Table delivery_zones non trouvée, utilisation des zones par défaut',
      );
      // Zones par défaut si la table n'existe pas
      _zones = _getDefaultZones();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtenir les zones par défaut
  List<DeliveryZone> _getDefaultZones() {
    return [
      DeliveryZone(
        id: 'zone_centre',
        name: 'Zone Centre',
        description: 'Centre-ville',
        polygon: [
          {'latitude': 48.8566, 'longitude': 2.3522},
          {'latitude': 48.8576, 'longitude': 2.3532},
          {'latitude': 48.8556, 'longitude': 2.3542},
          {'latitude': 48.8546, 'longitude': 2.3512},
        ],
        deliveryFee: 2000.0,
        estimatedTimeMinutes: 20,
        createdAt: DateTime.now(),
      ),
      DeliveryZone(
        id: 'zone_nord',
        name: 'Zone Nord',
        description: 'Quartier nord',
        polygon: [
          {'latitude': 48.8600, 'longitude': 2.3500},
          {'latitude': 48.8610, 'longitude': 2.3510},
          {'latitude': 48.8590, 'longitude': 2.3520},
          {'latitude': 48.8580, 'longitude': 2.3490},
        ],
        deliveryFee: 2500.0,
        estimatedTimeMinutes: 30,
        createdAt: DateTime.now(),
      ),
      DeliveryZone(
        id: 'zone_sud',
        name: 'Zone Sud',
        description: 'Quartier sud',
        polygon: [
          {'latitude': 48.8530, 'longitude': 2.3540},
          {'latitude': 48.8540, 'longitude': 2.3550},
          {'latitude': 48.8520, 'longitude': 2.3560},
          {'latitude': 48.8510, 'longitude': 2.3530},
        ],
        deliveryFee: 2500.0,
        estimatedTimeMinutes: 30,
        createdAt: DateTime.now(),
      ),
    ];
  }

  /// Trouver la zone d'une adresse
  Future<DeliveryZone?> findZoneForAddress(
    double latitude,
    double longitude,
  ) async {
    // Si aucune zone n'est chargée, recharger
    if (_zones.isEmpty) {
      await _loadZones();
    }

    // Vérifier chaque zone pour voir si le point est dans le polygone
    for (final zone in _zones) {
      if (zone.isActive &&
          _isPointInPolygon(latitude, longitude, zone.polygon)) {
        return zone;
      }
    }

    return null;
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

      final intersect =
          ((yi > latitude) != (yj > latitude)) &&
          (longitude < (xj - xi) * (latitude - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
      j = i;
    }

    return inside;
  }

  /// Calculer les frais de livraison pour une zone
  double getDeliveryFeeForZone(String? zoneId) {
    if (zoneId == null) {
      return 2000.0; // Frais par défaut
    }

    final zone = _zones.firstWhere(
      (z) => z.id == zoneId,
      orElse: () => _zones.first,
    );

    return zone.deliveryFee;
  }

  /// Obtenir le temps estimé pour une zone
  int getEstimatedTimeForZone(String? zoneId) {
    if (zoneId == null) {
      return 30; // Temps par défaut
    }

    final zone = _zones.firstWhere(
      (z) => z.id == zoneId,
      orElse: () => _zones.first,
    );

    return zone.estimatedTimeMinutes;
  }

  /// Obtenir les livreurs disponibles dans une zone
  List<Driver> getAvailableDriversInZone(
    String zoneId,
    List<Driver> allDrivers,
  ) {
    final zone = _zones.firstWhere(
      (z) => z.id == zoneId,
      orElse: () => _zones.first,
    );

    // Filtrer les livreurs qui sont dans la zone
    return allDrivers.where((driver) {
      if (driver.latitude == null || driver.longitude == null) {
        return false;
      }

      return _isPointInPolygon(
        driver.latitude!,
        driver.longitude!,
        zone.polygon,
      );
    }).toList();
  }

  /// Ajouter une nouvelle zone
  Future<bool> addZone(DeliveryZone zone) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Si la table n'existe pas, ajouter en mémoire seulement
      try {
        await _supabase.from('delivery_zones').insert(zone.toMap());
      } catch (e) {
        debugPrint(
          '⚠️ Table delivery_zones non disponible, zone ajoutée en mémoire',
        );
      }

      _zones.add(zone);
      _zones.sort((a, b) => a.name.compareTo(b.name));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'ajout de la zone: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Mettre à jour une zone
  Future<bool> updateZone(DeliveryZone zone) async {
    try {
      _isLoading = true;
      notifyListeners();

      try {
        await _supabase
            .from('delivery_zones')
            .update(zone.toMap())
            .eq('id', zone.id);
      } catch (e) {
        debugPrint(
          '⚠️ Table delivery_zones non disponible, zone mise à jour en mémoire',
        );
      }

      final index = _zones.indexWhere((z) => z.id == zone.id);
      if (index != -1) {
        _zones[index] = zone;
        _zones.sort((a, b) => a.name.compareTo(b.name));
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Erreur lors de la mise à jour de la zone: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Supprimer une zone
  Future<bool> deleteZone(String zoneId) async {
    try {
      _isLoading = true;
      notifyListeners();

      try {
        await _supabase.from('delivery_zones').delete().eq('id', zoneId);
      } catch (e) {
        debugPrint(
          '⚠️ Table delivery_zones non disponible, zone supprimée en mémoire',
        );
      }

      _zones.removeWhere((z) => z.id == zoneId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Erreur lors de la suppression de la zone: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Recharger les zones
  Future<void> refresh() async {
    await _loadZones();
  }
}








