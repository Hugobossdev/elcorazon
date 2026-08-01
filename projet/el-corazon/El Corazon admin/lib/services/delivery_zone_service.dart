import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'admin_auth_service.dart';

/// Zone de livraison telle que l'affiche la carte de supervision.
///
/// `deliveryFee` est le **forfait de base** de la zone. Ce n'est pas ce que
/// paiera un client : le serveur y ajoute la distance (`fee_per_km`), applique
/// le seuil de gratuité et le minimum de commande. Un frais calculé côté écran
/// donnerait un second chiffre, différent de celui facturé (C1).
class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.name,
    required this.polygon,
    required this.deliveryFee,
    required this.estimatedTimeMinutes,
    required this.isActive,
  });

  factory DeliveryZone.fromRemote(eccore.DeliveryZone remote) {
    return DeliveryZone(
      id: remote.id,
      name: remote.name,
      polygon: _contour(remote.boundary),
      deliveryFee: remote.baseFee.toMajorUnits(),
      estimatedTimeMinutes: remote.estimatedDeliveryMinutes,
      isActive: remote.isActive,
    );
  }

  final String id;
  final String name;

  /// Contour aplati pour l'affichage — points `{latitude, longitude}`.
  ///
  /// Le serveur rend du GeoJSON, dont les coordonnées sont en `[lon, lat]` ;
  /// l'ordre inverse de celui qu'attendent les cartes. C'est une erreur
  /// classique, et elle place les zones dans l'océan : la conversion est faite
  /// ici, une fois.
  final List<Map<String, double>> polygon;

  /// Forfait de base, en unité majeure et pour l'affichage seul.
  final double deliveryFee;
  final int estimatedTimeMinutes;
  final bool isActive;

  /// Premier anneau du premier polygone.
  ///
  /// Suffisant pour une carte de supervision : les trous et les îlots d'un
  /// `MultiPolygon` ne changent pas le repère visuel qu'on cherche, et le
  /// serveur reste seul juge de l'appartenance d'un point (PostGIS).
  static List<Map<String, double>> _contour(Map<String, dynamic>? geojson) {
    if (geojson == null) return const [];

    final coordonnees = geojson['coordinates'];
    if (coordonnees is! List || coordonnees.isEmpty) return const [];

    dynamic anneau = coordonnees;
    // On descend jusqu'au niveau des paires : un `Polygon` imbrique une fois,
    // un `MultiPolygon` deux.
    while (anneau is List &&
        anneau.isNotEmpty &&
        anneau.first is List &&
        (anneau.first as List).isNotEmpty &&
        (anneau.first as List).first is List) {
      anneau = anneau.first;
    }

    if (anneau is! List) return const [];

    return [
      for (final point in anneau)
        if (point is List && point.length >= 2)
          {
            'latitude': (point[1] as num).toDouble(),
            'longitude': (point[0] as num).toDouble(),
          },
    ];
  }
}

/// Zones de livraison — `/geography/manage/zones/` (Phase 6).
///
/// Deux choses ont changé de côté, et ce sont les deux qui comptaient :
///
/// * **le barème n'est plus dans le client.** L'ancienne version portait des
///   frais en dur, et deux constantes contradictoires selon le fichier. Ce que
///   paie un client se décide dans la zone, en base, et se relève depuis le
///   back-office sans déploiement ;
/// * **l'appartenance d'un point à une zone n'est plus calculée à l'écran.**
///   Un lancer de rayon écrit à la main répondait « dans la zone » là où
///   PostGIS répondait autre chose, sur les points de bordure. Le filtre de la
///   carte reste local — c'est un confort d'affichage — mais aucun frais, aucun
///   délai, aucune couverture ne s'en déduit.
///
/// Ces routes sont réservées au **siège** : une zone n'appartient à aucun
/// établissement, et tarifer les autres n'est pas un pouvoir d'établissement.
/// Un compte cloisonné reçoit un 403 explicite.
class DeliveryZoneService extends ChangeNotifier {
  eccore.ManagedGeographyRepository get _geographie =>
      eccore.ManagedGeographyRepository(apiClient: AdminAuthService().apiClient);

  List<DeliveryZone> _zones = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<DeliveryZone> get zones => _zones;
  List<DeliveryZone> get activeZones =>
      _zones.where((zone) => zone.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  DeliveryZoneService() {
    initialize();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final zones = await _geographie.zones();
      _zones = zones.map(DeliveryZone.fromRemote).toList();
    } on eccore.ApiException catch (e) {
      _error = e.status == 403
          ? 'Les zones relèvent du siège : votre compte est rattaché à un '
                'périmètre.'
          : e.detail;
      debugPrint('Zones : chargement impossible — ${e.code}');
      _zones = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Rouvre ou ferme une zone.
  ///
  /// Il n'y a pas de suppression : des commandes passées portent les frais de
  /// cette zone, et l'effacer rendrait leur addition inexplicable. Une zone
  /// fermée disparaît de la couverture sans réécrire le passé.
  Future<bool> setZoneActive(String zoneId, bool isActive) async {
    try {
      final maj = await _geographie.updateZone(
        zoneId: zoneId,
        isActive: isActive,
      );
      final locale = DeliveryZone.fromRemote(maj);
      final index = _zones.indexWhere((zone) => zone.id == zoneId);
      if (index != -1) _zones[index] = locale;
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Zones : changement d\'état refusé — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  DeliveryZone? zoneByName(String name) {
    for (final zone in _zones) {
      if (zone.name == name) return zone;
    }
    return null;
  }
}
