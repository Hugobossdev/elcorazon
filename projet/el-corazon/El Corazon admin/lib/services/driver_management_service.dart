import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import '../models/driver.dart';
import 'admin_auth_service.dart';

/// Gestion de la flotte — `/api/v1/delivery/couriers/` (Phase 6).
///
/// L'implémentation Supabase lisait la table `users` filtrée sur
/// `role = 'delivery'` et **recomposait** un livreur à partir de champs
/// d'authentification : ni véhicule, ni statut de dossier, ni compteurs — tout
/// était à zéro, puis « enrichi » par une seconde passe sur les commandes. Le
/// dossier livreur existe côté serveur (`CourierProfile`), avec ses pièces, son
/// instruction et ses compteurs officiels : c'est lui qu'on lit.
///
/// Le statut affiché ne se déduit plus de deux booléens : `canAcceptOrders` est
/// calculé par le serveur (L1 — en ligne **et** dossier validé **et** compte
/// actif), et le recomposer ici en oubliant un terme est précisément ce que
/// cette propriété évite.
class DriverManagementService extends ChangeNotifier {
  eccore.ManagedCourierRepository get _couriers =>
      eccore.ManagedCourierRepository(apiClient: AdminAuthService().apiClient);
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
  }

  Future<void> _loadDrivers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final remote = await _couriers.list();
      _drivers = remote.map(_toLocalDriver).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      debugPrint('DriverManagementService: ${_drivers.length} livreur(s)');
    } on eccore.ApiException catch (e) {
      debugPrint('DriverManagementService: chargement impossible — ${e.code}');
      _drivers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Dossier livreur du contrat → modèle local.
  ///
  /// Les compteurs et la note viennent du dossier : ils étaient auparavant
  /// recalculés à partir des commandes, à chaque chargement d'écran.
  Driver _toLocalDriver(eccore.CourierProfile courier) {
    return Driver(
      id: courier.id,
      userId: courier.id,
      name: courier.fullName,
      email: courier.email,
      phone: '',
      status: _toLocalStatus(courier),
      latitude: courier.lastLatitude,
      longitude: courier.lastLongitude,
      vehicleType: courier.vehicleType,
      licensePlate: courier.vehiclePlate,
      rating: courier.ratingAverage,
      totalDeliveries: courier.deliveriesCompleted,
      totalEarnings: courier.totalEarnings?.toMajorUnits() ?? 0,
      createdAt: courier.createdAt,
      lastOnline: courier.lastLocationAt,
      isActive: courier.verificationStatus == 'approved',
    );
  }

  /// Statut d'affichage.
  ///
  /// `onDelivery` n'est pas déductible du dossier : une course en cours est une
  /// information de `delivery/assignments/`, pas du profil. L'ancienne version
  /// ne le déduisait pas davantage — elle mettait « disponible » dès que le
  /// livreur était en ligne.
  DriverStatus _toLocalStatus(eccore.CourierProfile courier) {
    if (courier.verificationStatus == 'suspended' ||
        courier.verificationStatus == 'rejected') {
      return DriverStatus.unavailable;
    }
    if (courier.canAcceptOrders) return DriverStatus.available;
    return courier.isOnline ? DriverStatus.unavailable : DriverStatus.offline;
  }

  /// Embauche un livreur : le compte **et** son dossier, en une requête
  /// (permission `couriers.write`).
  ///
  /// [password] est obligatoire côté serveur — c'est un compte qui se crée. Les
  /// pièces justificatives ne sont pas déposées ici : c'est le livreur qui les
  /// fournit depuis son application, et c'est bien lui qui les a.
  Future<bool> provisionDriver({
    required String email,
    required String password,
    required String fullName,
    required String restaurantSlug,
    required String vehicleType,
    String phone = '',
    String vehiclePlate = '',
  }) async {
    try {
      final created = await _couriers.provision(
        email: email,
        password: password,
        fullName: fullName,
        restaurantSlug: restaurantSlug,
        vehicleType: vehicleType,
        phone: phone,
        vehiclePlate: vehiclePlate,
      );
      _drivers = [..._drivers, _toLocalDriver(created)]
        ..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      debugPrint('DriverManagementService: embauche refusée — ${e.code}');
      return false;
    }
  }

  /// Suspend un livreur — permission `couriers.suspend`, motif obligatoire.
  ///
  /// Distinct de l'instruction du dossier : suspendre retire du service
  /// quelqu'un qui travaillait, et se décide un samedi soir après un incident.
  /// Le serveur exige les deux permissions séparément.
  Future<bool> suspendDriver(String driverId, String reason) async {
    return _setVerification(driverId, 'suspended', reason);
  }

  /// Remet un dossier en service — permission `couriers.approve`.
  Future<bool> reactivateDriver(String driverId) async {
    return _setVerification(driverId, 'approved', '');
  }

  /// Valide ou rejette un dossier — permission `couriers.approve`.
  Future<bool> setVerification(String driverId, String status, {String notes = ''}) {
    return _setVerification(driverId, status, notes);
  }

  Future<bool> _setVerification(String driverId, String status, String notes) async {
    try {
      final updated = await _couriers.setVerification(
        courierId: driverId,
        status: status,
        notes: notes,
      );
      final index = _drivers.indexWhere((driver) => driver.id == driverId);
      if (index != -1) {
        _drivers[index] = _toLocalDriver(updated);
        notifyListeners();
      }
      return true;
    } on eccore.ApiException catch (e) {
      debugPrint('DriverManagementService: instruction refusée — ${e.code}');
      return false;
    }
  }

  /// Livreurs éligibles pour une commande, du plus proche au plus loin.
  ///
  /// L'éligibilité est calculée par le serveur : la liste ne se filtre pas ici.
  Future<List<Driver>> availableForOrder(String orderId) async {
    try {
      final remote = await _couriers.availableFor(orderId);
      return remote.map(_toLocalDriver).toList();
    } on eccore.ApiException catch (e) {
      debugPrint('DriverManagementService: éligibles indisponibles — ${e.code}');
      return [];
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

  /// Statistiques détaillées d'un livreur — lues sur son dossier.
  ///
  /// Les notes par critère (ponctualité, service, soin du colis) et les badges
  /// livreur n'existent pas au contrat v2 : la note est un **agrégat**
  /// (`rating_average`, `rating_count`) alimenté par les notes des clients, et
  /// la gamification est réservée aux comptes clients. L'ancienne version
  /// lisait `driver_ratings`, `driver_badges` et `driver_earned_badges`, trois
  /// tables sans contrepartie.
  Future<Map<String, dynamic>> getDriverDetailedStats(String driverId) async {
    try {
      final courier = await _couriers.getById(driverId);
      return {
        'deliveries_completed': courier.deliveriesCompleted,
        'deliveries_cancelled': courier.deliveriesCancelled,
        'rating_average': courier.ratingAverage,
        'rating_count': courier.ratingCount,
        'total_earnings': courier.totalEarnings?.toMajorUnits() ?? 0,
        'verification_status': courier.verificationStatus,
      };
    } on eccore.ApiException catch (e) {
      debugPrint('DriverManagementService: statistiques indisponibles — ${e.code}');
      return {};
    }
  }
}
