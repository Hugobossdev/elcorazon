import 'dart:math' as math;

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/flotte.dart';
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

  /// Dernier refus du serveur, tel qu'il l'a formulé. `null` quand tout va
  /// bien. Les écrans d'écriture l'affichent — un formulaire qui échoue sans
  /// dire pourquoi se remplit une seconde fois à l'identique.
  String? _error;
  String _recherche = '';
  TriFlotte _tri = TriFlotte.nomCroissant;

  List<eccore.CourierProfile> get drivers => _drivers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get recherche => _recherche;
  TriFlotte get tri => _tri;

  /// Les livreurs d'un onglet de l'écran, recherche et tri appliqués — voir
  /// [livreursDeLOnglet].
  List<eccore.CourierProfile> livreursDe(OngletFlotte onglet) =>
      livreursDeLOnglet(_drivers, onglet, recherche: _recherche, tri: _tri);

  /// La flotte a-t-elle été demandée au moins une fois ?
  bool _demandee = false;

  /// Charge la flotte si personne ne l'a encore demandée.
  ///
  /// Le constructeur appelait `_loadDrivers()` : **ouvrir n'importe quel écran
  /// du back-office** téléchargeait tous les dossiers livreurs du périmètre,
  /// puisque le fournisseur est monté une fois pour toute l'application. Un
  /// écran des promotions payait la flotte, et l'écran de la carte la payait
  /// une seconde fois en rafraîchissant.
  ///
  /// Les écrans qui affichent la flotte l'appellent à leur ouverture ; le
  /// dialogue d'affectation, lui, ne la charge pas du tout — il demande les
  /// **éligibles** d'une commande ([availableForOrder]).
  Future<void> ensureLoaded() async {
    if (_demandee) return;
    await _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    _demandee = true;
    _isLoading = true;
    notifyListeners();

    try {
      final remote = await _couriers.list();
      _drivers = remote..sort((a, b) => a.fullName.compareTo(b.fullName));
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
      _drivers = [..._drivers, created]..sort((a, b) => a.fullName.compareTo(b.fullName));
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('DriverManagementService: embauche refusée — ${e.code}');
      return false;
    }
  }

  /// Corrige le dossier d'un livreur — permission `couriers.write`.
  ///
  /// Ce geste **n'existait pas** : `StaffCourierViewSet` était en création et
  /// lecture seule, si bien qu'une plaque relevée de travers à l'embauche ou un
  /// numéro qui change n'avait pour seule issue que d'ouvrir un second compte —
  /// c'est-à-dire de dédoubler un livreur et de scinder ses compteurs.
  ///
  /// Le serveur n'accepte qu'une **liste blanche** : identité de contact et
  /// véhicule. Le statut du dossier, les pièces, la disponibilité, les
  /// compteurs, l'établissement et l'adresse électronique lui sont fermés — ce
  /// service ne peut donc pas les proposer, quoi qu'un écran lui passe.
  ///
  /// Les champs laissés à `null` ne sont pas envoyés, donc pas touchés.
  Future<bool> updateDriver({
    required String driverId,
    String? fullName,
    String? phone,
    String? vehicleType,
    String? vehiclePlate,
    String? nationalIdNumber,
    String? licenceNumber,
  }) async {
    try {
      final maj = await _couriers.update(
        courierId: driverId,
        fullName: fullName,
        phone: phone,
        vehicleType: vehicleType,
        vehiclePlate: vehiclePlate,
        nationalIdNumber: nationalIdNumber,
        licenceNumber: licenceNumber,
      );
      final index = _drivers.indexWhere((driver) => driver.id == driverId);
      if (index != -1) {
        // La réponse porte le dossier complet : on remplace la ligne plutôt
        // que d'y recopier les champs saisis, ce qui laisserait diverger
        // l'affichage de ce que le serveur a réellement retenu.
        _drivers[index] = maj;
        _drivers.sort((a, b) => a.fullName.compareTo(b.fullName));
      }
      _error = null;
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      // Le message du serveur est conservé tel quel : il dit lequel des champs
      // est refusé et pourquoi — « ce numéro est déjà associé à un autre
      // compte » se corrige, « une erreur est survenue » non.
      _error = e.detail;
      eccore.Journal.trace('DriverManagementService: correction refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  /// Affecte le livreur à des zones de sa cuisine — permission `couriers.write`.
  ///
  /// La liste est **entière** : une liste vide lève la restriction, et le
  /// livreur roule dans toutes les zones de sa cuisine. Une zone que la cuisine
  /// ne dessert pas est refusée par le serveur, qui dit laquelle.
  Future<bool> setServiceZones(String driverId, List<String> zoneIds) async {
    try {
      final maj = await _couriers.setServiceZones(courierId: driverId, zoneIds: zoneIds);
      final index = _drivers.indexWhere((driver) => driver.id == driverId);
      if (index != -1) _drivers[index] = maj;
      _error = null;
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('DriverManagementService: zones refusées — ${e.code}');
      notifyListeners();
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
      if (index != -1) _drivers[index] = updated;
      _error = null;
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      // Conservé comme pour la correction et les zones. Il ne l'était pas : le
      // formulaire affichait alors « Modification refusée. » — ou, pire, le
      // refus **précédent**, resté dans `_error` — là où le serveur disait
      // pourquoi : un motif manquant, un dossier jamais validé qu'on ne suspend
      // pas, une pièce expirée.
      _error = e.detail;
      eccore.Journal.trace('DriverManagementService: instruction refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  /// Livreurs éligibles pour une commande, du plus proche au plus loin.
  ///
  /// L'éligibilité est calculée par le serveur : la liste ne se filtre pas ici
  /// (`CourierService.available_for` — cuisine, en ligne, dossier validé, zone
  /// desservie, pas déjà engagé).
  ///
  /// **Lève `ApiException`.** Elle retournait une liste vide sur refus : le
  /// dialogue d'affectation affichait alors « aucun livreur éligible » devant
  /// un 403 ou une coupure réseau, et le superviseur attendait un livreur que
  /// personne ne lui avait refusé — il n'avait simplement pas le droit de lire
  /// la liste. Un échec se dit ; il ne se déguise pas en flotte vide.
  Future<List<eccore.CourierProfile>> availableForOrder(String orderId) =>
      _couriers.availableFor(orderId);

  // `getAvailableDrivers` a été retirée le 23 septembre 2026.
  //
  // Elle recomposait ici l'éligibilité d'un livreur — en ligne, dossier
  // validé, pas déjà engagé — sur la flotte déjà chargée. Trois termes sur
  // cinq : il manquait la **cuisine de la commande** (la liste chargée est
  // celle du périmètre du compte, si bien qu'un siège se voyait proposer
  // Douala pour une commande de Lomé) et le **périmètre de zone**. Elle ne
  // pouvait pas non plus trier par distance : la position du livreur n'entre
  // pas dans le calcul, et la distance à la cuisine est un calcul PostGIS.
  //
  // C'est [availableForOrder] qui répond désormais, pour une commande donnée.

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

  /// Nom, courriel, téléphone ou plaque.
  void rechercher(String recherche) {
    if (recherche == _recherche) return;
    _recherche = recherche;
    notifyListeners();
  }

  void trierPar(TriFlotte tri) {
    if (tri == _tri) return;
    _tri = tri;
    notifyListeners();
  }

  /// Les [limite] premiers du classement, **hors recherche** : l'aperçu montre
  /// la tête de la flotte, pas celle d'une recherche tapée sur un autre onglet.
  ///
  /// L'ancienne version triait toute la flotte sur la seule moyenne : un
  /// dossier en attente ou suspendu y figurait, et un livreur jamais noté
  /// (moyenne 0) passait après tout le monde, noté ou non.
  List<eccore.CourierProfile> tetesDeClassement({int limite = 3}) =>
      livreursDeLOnglet(_drivers, OngletFlotte.classement).take(limite).toList();

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

  /// Les compteurs de la flotte chargée — **tels qu'ils se lisent**.
  ///
  /// ## Trois chiffres faux, corrigés le 23 septembre 2026
  ///
  /// * `busy_drivers` **n'était pas produit** : l'écran affichait
  ///   « Courses actives : null ». Le nombre de livreurs en course ne se lit
  ///   pas sur la flotte — le dossier ne porte pas ses affectations — mais sur
  ///   les courses (`AssignmentService.livreursEngages`). Il n'est donc plus
  ///   promis ici.
  /// * « En ligne » comptait les **dossiers validés**, pas les livreurs
  ///   connectés : un livreur validé mais téléphone éteint y figurait, et le
  ///   siège croyait avoir dix personnes en ville.
  /// * La note moyenne divisait par l'effectif entier, **notes nulles
  ///   comprises** : embaucher deux livreurs faisait chuter la note de la
  ///   flotte, alors que personne ne les avait encore notés.
  StatistiquesDeFlotte get statistiques {
    final notes = [for (final d in _drivers) if (d.ratingCount > 0) d];
    return StatistiquesDeFlotte(
      effectif: _drivers.length,
      enLigne: _drivers.where((d) => d.isOnline).length,
      disponibles: _drivers.where((d) => d.canAcceptOrders).length,
      dossiersAInstruire: _drivers.where((d) => d.verificationStatus == 'pending').length,
      livraisons: _drivers.fold(0, (somme, d) => somme + d.deliveriesCompleted),
      noteMoyenne: notes.isEmpty
          ? null
          : notes.map((d) => d.ratingAverage).reduce((a, b) => a + b) / notes.length,
      livreursNotes: notes.length,
    );
  }

  /// Recharger les données
  Future<void> refresh() async {
    await _loadDrivers();
  }

  // -----------------------------------------------------------------------------
  // AMÉLIORATIONS FUTURES (Voir lib/database/improve_drivers_system.sql)
  // -----------------------------------------------------------------------------

  /// Ajouter une notation détaillée

  /// Relit le dossier d'un livreur au serveur. **Lève `ApiException`.**
  ///
  /// Elle rendait une carte à clés libres (`{'rating_average': ..., ...}`) —
  /// un sous-ensemble du dossier, recopié champ par champ — et une carte
  /// **vide** sur refus. L'écran affichait alors les compteurs du dossier
  /// qu'on lui avait passé comme s'ils venaient d'être relus, et ses notes par
  /// critère se repliaient silencieusement sur la note globale.
  ///
  /// Les notes par critère (ponctualité, service, soin du colis) et les badges
  /// livreur n'existent pas au contrat v2 : la note est un **agrégat**
  /// (`rating_average`, `rating_count`) alimenté par les clients, et la
  /// gamification est réservée aux comptes clients. L'ancienne version lisait
  /// `driver_ratings`, `driver_badges` et `driver_earned_badges`, trois tables
  /// sans contrepartie.
  Future<eccore.CourierProfile> relireDossier(String driverId) => _couriers.getById(driverId);

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

/// Les compteurs d'en-tête de l'écran de la flotte.
///
/// Un objet et non une carte à clés libres : l'écran lisait
/// `stats['busy_drivers']`, que personne ne produisait, et affichait « null ».
/// Un champ absent d'une classe ne compile pas.
@immutable
class StatistiquesDeFlotte {
  const StatistiquesDeFlotte({
    required this.effectif,
    required this.enLigne,
    required this.disponibles,
    required this.dossiersAInstruire,
    required this.livraisons,
    required this.noteMoyenne,
    required this.livreursNotes,
  });

  /// Les dossiers du périmètre, tous statuts confondus.
  final int effectif;

  /// Application ouverte — ce qui ne suffit pas à recevoir une course.
  final int enLigne;

  /// `can_accept_orders` : en ligne **et** dossier validé **et** compte actif
  /// (L1, calculé par le serveur).
  final int disponibles;

  /// Dossiers déposés qui attendent une instruction : c'est le seul compteur
  /// qui appelle un geste.
  final int dossiersAInstruire;

  final int livraisons;

  /// Moyenne sur les seuls livreurs **notés**. Nulle quand aucun ne l'est —
  /// « 0,0 » se lirait comme une flotte mal notée.
  final double? noteMoyenne;

  final int livreursNotes;
}
