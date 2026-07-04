import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver.dart';
import '../models/driver_badge.dart';
import 'socket_service.dart';

/// Service de gestion des livreurs
///
/// ⚠️ IMPORTANT: Ce service charge les livreurs directement depuis la table `users`
/// avec `role = 'delivery'` au lieu de la table `drivers`.
/// Les livreurs sont identifiés par leur `users.id` qui est utilisé comme `driver.id`.
class DriverManagementService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SocketService _socketService = SocketService();
  List<Driver> _drivers = [];
  bool _isLoading = false;
  DriverStatus? _statusFilter;
  String? _sortOption;
  String _searchQuery = '';

  List<Driver> get drivers => _drivers;
  bool get isLoading => _isLoading;

  /// Liste filtrée et triée des livreurs
  List<Driver> get filteredDrivers {
    var filtered = _drivers;

    // Filtrer par statut
    if (_statusFilter != null) {
      filtered = filtered.where((d) => d.status == _statusFilter).toList();
    }

    // Filtrer par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (driver) =>
                driver.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                driver.email.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                driver.phone.contains(_searchQuery),
          )
          .toList();
    }

    // Trier
    if (_sortOption != null) {
      switch (_sortOption) {
        case 'name':
          filtered.sort((a, b) => a.name.compareTo(b.name));
          break;
        case 'nameDesc':
          filtered.sort((a, b) => b.name.compareTo(a.name));
          break;
        case 'status':
          filtered.sort(
            (a, b) => a.status.toString().compareTo(b.status.toString()),
          );
          break;
        case 'rating':
          filtered.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case 'deliveries':
          filtered.sort(
            (a, b) => b.totalDeliveries.compareTo(a.totalDeliveries),
          );
          break;
      }
    }

    return filtered;
  }

  DriverManagementService() {
    _loadDrivers();
    _initSocketListeners();
  }

  void _initSocketListeners() {
    if (_socketService.isConnected) {
      _socketService.onDriverLocation((data) {
        _handleDriverLocationUpdate(data);
      });
    } else {
      // Retry listener attachment if socket connects later
      // Note: SocketService usually handles reconnection, but we need to ensure
      // our callback is registered. Since SocketService is a singleton and init()
      // is called in main, it should be ready or connecting.
      // We can periodically check or rely on the fact that onDriverLocation
      // registers the callback on the socket instance.
      _socketService.onDriverLocation((data) {
        _handleDriverLocationUpdate(data);
      });
    }
  }

  void _handleDriverLocationUpdate(dynamic data) {
    if (data == null) return;

    final String? driverId =
        data['driverId']?.toString() ?? data['delivery_id']?.toString();
    final double? lat = double.tryParse(
        data['lat']?.toString() ?? data['latitude']?.toString() ?? '');
    final double? lng = double.tryParse(
        data['lng']?.toString() ?? data['longitude']?.toString() ?? '');

    if (driverId != null && lat != null && lng != null) {
      // Update local state without full reload
      final index =
          _drivers.indexWhere((d) => d.id == driverId || d.userId == driverId);
      if (index != -1) {
        _drivers[index] = _drivers[index].copyWith(
          latitude: lat,
          longitude: lng,
        );
        notifyListeners();
        debugPrint('📍 Driver $driverId moved to $lat, $lng');
      }
    }
  }

  /// Charger tous les livreurs depuis la table users (role = 'delivery')
  Future<void> _loadDrivers() async {
    _isLoading = true;
    notifyListeners();
    try {
      debugPrint(
        '🔍 Chargement des livreurs depuis users (role = delivery)...',
      );

      // Charger directement depuis users avec role = 'delivery'
      final response = await _supabase
          .from('users')
          .select(
            'id, auth_user_id, name, email, phone, is_online, is_active, last_seen, created_at, profile_image',
          )
          .eq('role', 'delivery')
          .order('name', ascending: true);

      // Transformer les données users en format Driver
      _drivers = response.map((userData) {
        final userId = userData['id'] as String;
        final isOnline = userData['is_online'] as bool? ?? false;

        // Mapper le statut depuis is_online et is_active
        DriverStatus status;
        if (!(userData['is_active'] as bool? ?? true)) {
          status = DriverStatus.unavailable;
        } else if (isOnline) {
          // Vérifier s'il a des livraisons actives pour déterminer le statut
          // Pour l'instant, on suppose 'available' si en ligne
          status = DriverStatus.available;
        } else {
          status = DriverStatus.offline;
        }

        // Créer un map compatible avec le modèle Driver
        final driverMap = <String, dynamic>{
          'id': userId, // Utiliser users.id comme identifiant
          'auth_user_id': userData['auth_user_id'],
          'user_id': userId, // user_id = users.id
          'name': userData['name'] ?? '',
          'email': userData['email'] ?? '',
          'phone': userData['phone'] ?? '',
          'status': status.toString().split('.').last,
          'latitude':
              null, // Pas stocké dans users, utiliser delivery_locations si nécessaire
          'longitude': null,
          'vehicle_type': null, // Pas dans users
          'license_plate': null, // Pas dans users
          'rating': 0.0, // À calculer depuis les commandes livrées
          'total_deliveries': 0, // À calculer depuis les commandes
          'total_earnings': 0.0, // À calculer depuis les commandes
          'created_at': userData['created_at']?.toString() ??
              DateTime.now().toIso8601String(),
          'last_online': userData['last_seen']?.toString(),
          'profile_image_url': userData['profile_image'],
          'notes': null,
          'is_active': userData['is_active'] ?? true,
        };

        return Driver.fromMap(driverMap);
      }).toList();

      debugPrint(
        '✅ ${_drivers.length} livreur(s) chargé(s) depuis users (role = delivery)',
      );

      // Optionnel: Enrichir avec des statistiques depuis orders
      await _enrichWithStatistics();
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur lors du chargement des livreurs: $e');
      debugPrint('Stack trace: $stackTrace');
      _drivers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Enrichit les livreurs avec des statistiques depuis orders
  Future<void> _enrichWithStatistics() async {
    try {
      // Récupérer les statistiques pour chaque livreur
      for (var driver in _drivers) {
        if (driver.userId == null) continue;

        // Compter les livraisons complétées
        final deliveredOrders = await _supabase
            .from('orders')
            .select('id, total')
            .eq('delivery_person_id', driver.userId!)
            .eq('status', 'delivered');

        final totalDeliveries = deliveredOrders.length;
        final totalEarnings = deliveredOrders.fold<double>(
          0.0,
          (sum, order) => sum + ((order['total'] as num?)?.toDouble() ?? 0.0),
        );

        // Mettre à jour le driver avec les statistiques
        final index = _drivers.indexWhere((d) => d.userId == driver.userId);
        if (index != -1 && index < _drivers.length) {
          _drivers[index] = _drivers[index].copyWith(
            totalDeliveries: totalDeliveries,
            totalEarnings: totalEarnings,
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de l\'enrichissement des statistiques: $e');
    }
  }

  /// Ajouter un nouveau livreur
  ///
  /// ⚠️ NOTE: Cette méthode utilise encore la table `drivers`.
  /// Pour créer un livreur, utilisez plutôt la table `users` avec `role = 'delivery'`.
  Future<bool> addDriver(Driver driver) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase
          .from('drivers')
          .insert(driver.toMap())
          .select()
          .single();

      _drivers.add(Driver.fromMap(response));
      _drivers.sort((a, b) => a.name.compareTo(b.name));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding driver: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Mettre à jour un livreur
  Future<bool> updateDriver(Driver driver) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase
          .from('drivers')
          .update(driver.toMap())
          .eq('id', driver.id)
          .select()
          .single();

      final index = _drivers.indexWhere((d) => d.id == driver.id);
      if (index != -1) {
        _drivers[index] = Driver.fromMap(response);
        _drivers.sort((a, b) => a.name.compareTo(b.name));
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating driver: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Supprimer un livreur
  Future<bool> deleteDriver(String id) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.from('drivers').delete().eq('id', id);

      _drivers.removeWhere((driver) => driver.id == id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting driver: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Mettre à jour le statut d'un livreur
  Future<bool> updateDriverStatus(String driverId, DriverStatus status) async {
    try {
      await _supabase.from('drivers').update(
          {'status': status.toString().split('.').last}).eq('id', driverId);

      final index = _drivers.indexWhere((d) => d.id == driverId);
      if (index != -1) {
        _drivers[index] = _drivers[index].copyWith(status: status);
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('Error updating driver status: $e');
      return false;
    }
  }

  /// Mettre à jour la position d'un livreur
  Future<bool> updateDriverLocation(
    String driverId,
    double latitude,
    double longitude,
  ) async {
    try {
      await _supabase.from('drivers').update({
        'latitude': latitude,
        'longitude': longitude,
        'last_location_update': DateTime.now().toIso8601String(),
      }).eq('id', driverId);

      final index = _drivers.indexWhere((d) => d.id == driverId);
      if (index != -1) {
        _drivers[index] = _drivers[index].copyWith(
          latitude: latitude,
          longitude: longitude,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('Error updating driver location: $e');
      return false;
    }
  }

  /// Obtenir les livreurs disponibles
  List<Driver> getAvailableDrivers() {
    return _drivers
        .where(
          (driver) =>
              driver.status == DriverStatus.available && driver.isActive,
        )
        .toList();
  }

  /// Obtenir les livreurs en livraison
  List<Driver> getOnDeliveryDrivers() {
    return _drivers
        .where(
          (driver) =>
              driver.status == DriverStatus.onDelivery && driver.isActive,
        )
        .toList();
  }

  /// Obtenir les livreurs hors ligne
  List<Driver> getOfflineDrivers() {
    return _drivers
        .where(
          (driver) => driver.status == DriverStatus.offline && driver.isActive,
        )
        .toList();
  }

  /// Obtenir les livreurs actifs
  List<Driver> getActiveDrivers() {
    return _drivers.where((driver) => driver.isActive).toList();
  }

  /// Rechercher des livreurs
  void searchDrivers(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Obtenir les livreurs par statut
  List<Driver> getDriversByStatus(DriverStatus status) {
    return _drivers
        .where((driver) => driver.status == status && driver.isActive)
        .toList();
  }

  /// Filtrer par statut
  void filterByStatus(DriverStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  /// Définir l'option de tri
  void setSortOption(String sortKey) {
    _sortOption = sortKey;
    notifyListeners();
  }

  /// Suspendre un livreur
  Future<bool> suspendDriver(String driverId, String reason) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.from('drivers').update({
        'status': DriverStatus.offline.toString().split('.').last,
        'is_active': false,
        'suspension_reason': reason,
        'suspended_at': DateTime.now().toIso8601String(),
      }).eq('id', driverId);

      final index = _drivers.indexWhere((d) => d.id == driverId);
      if (index != -1) {
        _drivers[index] = _drivers[index].copyWith(
          status: DriverStatus.offline,
          isActive: false,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error suspending driver: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Réactiver un livreur
  Future<bool> reactivateDriver(String driverId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.from('drivers').update({
        'status': DriverStatus.available.toString().split('.').last,
        'is_active': true,
        'suspension_reason': null,
        'suspended_at': null,
      }).eq('id', driverId);

      final index = _drivers.indexWhere((d) => d.id == driverId);
      if (index != -1) {
        _drivers[index] = _drivers[index].copyWith(
          status: DriverStatus.available,
          isActive: true,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error reactivating driver: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Obtenir les livreurs les mieux notés
  List<Driver> getTopRatedDrivers({int limit = 10}) {
    final sortedDrivers = List<Driver>.from(_drivers);
    sortedDrivers.sort((a, b) => b.rating.compareTo(a.rating));
    return sortedDrivers.take(limit).toList();
  }

  /// Obtenir les livreurs les plus actifs
  List<Driver> getMostActiveDrivers({int limit = 10}) {
    final sortedDrivers = List<Driver>.from(_drivers);
    sortedDrivers.sort(
      (a, b) => b.totalDeliveries.compareTo(a.totalDeliveries),
    );
    return sortedDrivers.take(limit).toList();
  }

  /// Obtenir les livreurs qui gagnent le plus
  List<Driver> getTopEarningDrivers({int limit = 10}) {
    final sortedDrivers = List<Driver>.from(_drivers);
    sortedDrivers.sort((a, b) => b.totalEarnings.compareTo(a.totalEarnings));
    return sortedDrivers.take(limit).toList();
  }

  /// Obtenir les livreurs proches d'une position
  List<Driver> getDriversNearLocation(
    double latitude,
    double longitude, {
    double maxDistanceKm = 10.0,
  }) {
    return _drivers
        .where(
          (driver) =>
              driver.latitude != null &&
              driver.longitude != null &&
              driver.isNearTo(
                latitude,
                longitude,
                maxDistanceKm: maxDistanceKm,
              ),
        )
        .toList();
  }

  /// Obtenir les statistiques des livreurs
  Map<String, dynamic> getDriverStats() {
    final totalDrivers = _drivers.length;
    final activeDrivers = _drivers.where((d) => d.isActive).length;
    final availableDrivers =
        _drivers.where((d) => d.status == DriverStatus.available).length;
    final onDeliveryDrivers =
        _drivers.where((d) => d.status == DriverStatus.onDelivery).length;
    final offlineDrivers =
        _drivers.where((d) => d.status == DriverStatus.offline).length;

    final averageRating = _drivers.isNotEmpty
        ? _drivers.map((d) => d.rating).reduce((a, b) => a + b) /
            _drivers.length
        : 0.0;

    final totalDeliveries = _drivers.fold(
      0,
      (sum, driver) => sum + driver.totalDeliveries,
    );
    final totalEarnings = _drivers.fold(
      0.0,
      (sum, driver) => sum + driver.totalEarnings,
    );

    return {
      'total_drivers': totalDrivers,
      'active_drivers': activeDrivers,
      'online_drivers': activeDrivers,
      'available_drivers': availableDrivers,
      'busy_drivers': onDeliveryDrivers,
      'offline_drivers': offlineDrivers,
      'average_rating': averageRating,
      'total_deliveries': totalDeliveries,
      'total_earnings': totalEarnings,
    };
  }

  /// Recharger les données
  Future<void> refresh() async {
    await _loadDrivers();
  }

  // -----------------------------------------------------------------------------
  // AMÉLIORATIONS FUTURES (Voir lib/database/improve_drivers_system.sql)
  // -----------------------------------------------------------------------------

  /// Ajouter une notation détaillée
  Future<void> addDetailedRating({
    required String driverId,
    required String clientId,
    required int timeRating,
    required int serviceRating,
    required int conditionRating,
    String? comment,
  }) async {
    try {
      final avg = (timeRating + serviceRating + conditionRating) / 3.0;

      await _supabase.from('driver_ratings').insert({
        'driver_id': driverId,
        'client_id': clientId,
        'rating_delivery_time': timeRating,
        'rating_service': serviceRating,
        'rating_condition': conditionRating,
        'rating_average': avg,
        'comment': comment,
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding rating: $e');
    }
  }

  /// Récupérer les badges d'un livreur
  Future<List<DriverBadge>> getDriverBadges(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_earned_badges')
          .select('*, driver_badges(*)')
          .eq('driver_id', driverId);

      return (response as List)
          .map((data) => DriverBadge.fromMap(data))
          .toList();
    } catch (e) {
      debugPrint('Error getting badges: $e');
      return [];
    }
  }

  /// Récupérer toutes les définitions de badges disponibles
  Future<List<Map<String, dynamic>>> getAllBadges() async {
    try {
      final response =
          await _supabase.from('driver_badges').select('*').order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting all badges: $e');
      return [];
    }
  }

  /// Assigner un badge à un livreur
  Future<bool> assignBadgeToDriver(String driverId, String badgeId) async {
    try {
      // Vérifier si le livreur a déjà ce badge
      final existing = await _supabase
          .from('driver_earned_badges')
          .select('id')
          .eq('driver_id', driverId)
          .eq('badge_id', badgeId)
          .maybeSingle();

      if (existing != null) return false;

      await _supabase.from('driver_earned_badges').insert({
        'driver_id': driverId,
        'badge_id': badgeId,
        'earned_at': DateTime.now().toIso8601String(),
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error assigning badge: $e');
      return false;
    }
  }

  /// Récupérer les statistiques détaillées d'un livreur
  Future<Map<String, dynamic>> getDriverDetailedStats(String driverId) async {
    try {
      // Essayer d'utiliser la vue SQL si elle existe
      try {
        final response = await _supabase
            .from('driver_detailed_stats_view')
            .select()
            .eq('driver_id', driverId)
            .maybeSingle();

        if (response != null) return response;
      } catch (_) {
        // La vue n'existe peut-être pas encore
      }

      // Fallback: Calculer manuellement depuis driver_ratings
      final ratings = await _supabase
          .from('driver_ratings')
          .select()
          .eq('driver_id', driverId);

      if ((ratings as List).isEmpty) {
        return {
          'total_reviews': 0,
          'avg_global_rating': 0.0,
          'avg_time_rating': 0.0,
          'avg_service_rating': 0.0,
          'avg_condition_rating': 0.0,
        };
      }

      double totalTime = 0;
      double totalService = 0;
      double totalCondition = 0;
      double totalGlobal = 0;

      for (var r in ratings) {
        totalTime += (r['rating_delivery_time'] as num? ?? 0).toDouble();
        totalService += (r['rating_service'] as num? ?? 0).toDouble();
        totalCondition += (r['rating_condition'] as num? ?? 0).toDouble();
        totalGlobal += (r['rating_average'] as num? ?? 0).toDouble();
      }

      final count = ratings.length;

      return {
        'total_reviews': count,
        'avg_global_rating': totalGlobal / count,
        'avg_time_rating': totalTime / count,
        'avg_service_rating': totalService / count,
        'avg_condition_rating': totalCondition / count,
      };
    } catch (e) {
      debugPrint('Error getting detailed stats: $e');
      return {
        'total_reviews': 0,
        'avg_global_rating': 0.0,
        'avg_time_rating': 0.0,
        'avg_service_rating': 0.0,
        'avg_condition_rating': 0.0,
      };
    }
  }
}
