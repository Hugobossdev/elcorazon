import 'dart:math' as math;

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/statut_livreur.dart';
import 'package:admin/services/admin_auth_service.dart';

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
  List<eccore.CourierProfile> _drivers = [];
  bool _isLoading = false;
  StatutLivreur? _statusFilter;
  String? _sortOption;
  String _searchQuery = '';

  List<eccore.CourierProfile> get drivers => _drivers;
  bool get isLoading => _isLoading;

  /// Liste filtrée et triée des livreurs
  List<eccore.CourierProfile> get filteredDrivers {
    var filtered = _drivers;

    // Filtrer par statut
    if (_statusFilter != null) {
      filtered = filtered.where((d) => d.statut == _statusFilter).toList();
    }

    // Filtrer par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (driver) =>
                driver.fullName.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                driver.email.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
          )
          .toList();
    }

    // Trier
    if (_sortOption != null) {
      switch (_sortOption) {
        case 'name':
          filtered.sort((a, b) => a.fullName.compareTo(b.fullName));
          break;
        case 'nameDesc':
          filtered.sort((a, b) => b.fullName.compareTo(a.fullName));
          break;
        case 'status':
          filtered.sort(
            (a, b) => a.statut.name.compareTo(b.statut.name),
          );
          break;
        case 'rating':
          filtered.sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage));
          break;
        case 'deliveries':
          filtered.sort(
            (a, b) => b.deliveriesCompleted.compareTo(a.deliveriesCompleted),
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
      _drivers = remote
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      eccore.Journal.trace('DriverManagementService: ${_drivers.length} livreur(s)');
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('DriverManagementService: chargement impossible — ${e.code}');
      _drivers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      _drivers = [..._drivers, created]
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('DriverManagementService: embauche refusée — ${e.code}');
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
        _drivers[index] = updated;
        notifyListeners();
      }
      return true;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('DriverManagementService: instruction refusée — ${e.code}');
      return false;
    }
  }

  /// Livreurs éligibles pour une commande, du plus proche au plus loin.
  ///
  /// L'éligibilité est calculée par le serveur : la liste ne se filtre pas ici.
  Future<List<eccore.CourierProfile>> availableForOrder(String orderId) async {
    try {
      final remote = await _couriers.availableFor(orderId);
      return remote;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('DriverManagementService: éligibles indisponibles — ${e.code}');
      return [];
    }
  }

  /// Obtenir les livreurs disponibles
  List<eccore.CourierProfile> getAvailableDrivers() {
    return _drivers
        .where(
          (driver) =>
              driver.statut == StatutLivreur.disponible && driver.estValide,
        )
        .toList();
  }

  /// Obtenir les livreurs en livraison

  /// Obtenir les livreurs hors ligne
  List<eccore.CourierProfile> getOfflineDrivers() {
    return _drivers
        .where(
          (driver) => driver.statut == StatutLivreur.horsLigne && driver.estValide,
        )
        .toList();
  }

  /// Obtenir les livreurs actifs
  List<eccore.CourierProfile> getActiveDrivers() {
    return _drivers.where((driver) => driver.estValide).toList();
  }

  /// Rechercher des livreurs
  void searchDrivers(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Obtenir les livreurs par statut
  List<eccore.CourierProfile> getDriversByStatus(StatutLivreur statut) {
    return _drivers
        .where((driver) => driver.statut == statut && driver.estValide)
        .toList();
  }

  /// Filtrer par statut
  void filterByStatus(StatutLivreur? statut) {
    _statusFilter = statut;
    notifyListeners();
  }

  /// Définir l'option de tri
  void setSortOption(String sortKey) {
    _sortOption = sortKey;
    notifyListeners();
  }

  /// Obtenir les livreurs les mieux notés
  List<eccore.CourierProfile> getTopRatedDrivers({int limit = 10}) {
    final sortedDrivers = List<eccore.CourierProfile>.from(_drivers);
    sortedDrivers.sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage));
    return sortedDrivers.take(limit).toList();
  }

  /// Obtenir les livreurs les plus actifs
  List<eccore.CourierProfile> getMostActiveDrivers({int limit = 10}) {
    final sortedDrivers = List<eccore.CourierProfile>.from(_drivers);
    sortedDrivers.sort(
      (a, b) => b.deliveriesCompleted.compareTo(a.deliveriesCompleted),
    );
    return sortedDrivers.take(limit).toList();
  }

  /// Obtenir les livreurs qui gagnent le plus
  List<eccore.CourierProfile> getTopEarningDrivers({int limit = 10}) {
    final sortedDrivers = List<eccore.CourierProfile>.from(_drivers);
    sortedDrivers.sort(
      (a, b) => (b.totalEarnings?.amountMinor ?? 0)
          .compareTo(a.totalEarnings?.amountMinor ?? 0),
    );
    return sortedDrivers.take(limit).toList();
  }

  /// Obtenir les livreurs proches d'une position
  List<eccore.CourierProfile> getDriversNearLocation(
    double latitude,
    double longitude, {
    double maxDistanceKm = 10.0,
  }) {
    return _drivers
        .where(
          (driver) =>
              driver.aUnePosition &&
              _distanceKm(
                    driver.lastLatitude!,
                    driver.lastLongitude!,
                    latitude,
                    longitude,
                  ) <=
                  maxDistanceKm,
        )
        .toList();
  }

  /// Obtenir les statistiques des livreurs
  Map<String, dynamic> getDriverStats() {
    final totalDrivers = _drivers.length;
    final activeDrivers = _drivers.where((d) => d.estValide).length;
    final availableDrivers =
        _drivers.where((d) => d.statut == StatutLivreur.disponible).length;
    final offlineDrivers =
        _drivers.where((d) => d.statut == StatutLivreur.horsLigne).length;

    final averageRating = _drivers.isNotEmpty
        ? _drivers.map((d) => d.ratingAverage).reduce((a, b) => a + b) /
            _drivers.length
        : 0.0;

    final totalDeliveries = _drivers.fold(
      0,
      (sum, driver) => sum + driver.deliveriesCompleted,
    );
    // Les gains sont des montants : on somme en unité mineure, sans passer par
    // un flottant intermédiaire.
    final totalEarnings = _drivers.fold<int>(
      0,
      (sum, driver) => sum + (driver.totalEarnings?.amountMinor ?? 0),
    );

    return {
      'total_drivers': totalDrivers,
      'active_drivers': activeDrivers,
      'online_drivers': activeDrivers,
      'available_drivers': availableDrivers,
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
      eccore.Journal.trace('DriverManagementService: statistiques indisponibles — ${e.code}');
      return {};
    }
  }

  /// Distance à vol d'oiseau en kilomètres (haversine).
  ///
  /// Le modèle local portait un `isNearTo` ; le dossier livreur du socle ne
  /// décrit que des données, le calcul revient donc à l'appelant.
  static double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const rayonTerrestreKm = 6371.0;
    double radians(double degres) => degres * math.pi / 180;

    final dLat = radians(lat2 - lat1);
    final dLon = radians(lon2 - lon1);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radians(lat1)) *
            math.cos(radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    return rayonTerrestreKm * 2 * math.asin(math.sqrt(h));
  }
}
