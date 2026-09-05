import 'dart:math' as math;

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/services/admin_auth_service.dart';

/// Zone de livraison telle que l'affiche la carte de supervision.
///
/// `deliveryFee` est le **forfait de base** de la zone. Ce n'est pas ce que
/// paiera un client : le serveur y ajoute la distance (`fee_per_km`), applique
/// le seuil de gratuité et le minimum de commande. Un frais calculé côté écran
/// donnerait un second chiffre, différent de celui facturé (C1).
class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.cityId,
    required this.name,
    required this.polygon,
    required this.deliveryFee,
    required this.feePerKm,
    required this.estimatedTimeMinutes,
    required this.isActive,
    required this.currency,
    this.freeDeliveryThreshold,
    this.minOrderAmount,
  });

  factory DeliveryZone.fromRemote(eccore.DeliveryZone remote) {
    return DeliveryZone(
      id: remote.id,
      cityId: remote.cityId,
      name: remote.name,
      polygon: _contour(remote.boundary),
      deliveryFee: remote.baseFee.toMajorUnits(),
      feePerKm: remote.feePerKm.toMajorUnits(),
      freeDeliveryThreshold: remote.freeDeliveryThreshold?.toMajorUnits(),
      minOrderAmount: remote.minOrderAmount?.toMajorUnits(),
      estimatedTimeMinutes: remote.estimatedDeliveryMinutes,
      isActive: remote.isActive,
      // La devise n'est pas choisie au niveau de la zone : elle est héritée du
      // pays (ADR-006). On la relève sur le forfait plutôt que de l'écrire en
      // dur, sans quoi l'ouverture d'un second marché ferait afficher — et
      // envoyer — des francs CFA sur des zones facturées ailleurs.
      currency: remote.baseFee.currency,
    );
  }

  final String id;

  /// Ville de rattachement, par sa clé. Le serveur ne rend pas son nom sur
  /// cette route ; [DeliveryZoneService.cityName] le résout.
  final String cityId;

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

  /// Tarif au kilomètre, en unité majeure. Affiché en lecture : il complète le
  /// forfait pour expliquer ce que paiera un client, sans qu'aucun total ne se
  /// calcule ici.
  final double feePerKm;

  /// Seuil au-delà duquel la zone offre la livraison. `null` = jamais offerte,
  /// ce qui est différent d'un seuil à zéro (offerte dès le premier franc).
  final double? freeDeliveryThreshold;

  /// Montant minimum de commande dans la zone, quand elle en pose un.
  final double? minOrderAmount;

  final int estimatedTimeMinutes;
  final bool isActive;

  /// Devise du barème, héritée du pays (ADR-006). Elle décide de l'unité dans
  /// laquelle une saisie est convertie avant d'être envoyée.
  final String currency;

  bool get hasFreeDelivery => freeDeliveryThreshold != null;

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
  Map<String, String> _cityNames = {};
  final Set<String> _writing = {};
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<DeliveryZone> get zones => _zones;
  List<DeliveryZone> get activeZones =>
      _zones.where((zone) => zone.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Intitulé de repli quand le nom d'une ville manque — la liste des villes
  /// n'est pas encore revenue, ou la route a échoué. Jamais l'UUID, qui ne dit
  /// rien à personne.
  static const String _villeInconnue = 'Ville non rattachée';

  /// Nom de la ville d'une zone.
  String cityName(String cityId) => _cityNames[cityId] ?? _villeInconnue;

  /// Zones regroupées par ville, chaque groupe trié par nom.
  ///
  /// C'est la forme dont a besoin l'écran de sélection : on ouvre ou on ferme
  /// des quartiers **d'une ville**, et deux « Centre-ville » de villes
  /// différentes ne se distinguent que par ce regroupement.
  Map<String, List<DeliveryZone>> get zonesByCity => groupByCity(_zones, _cityNames);

  /// Regroupement pur, exposé à part du service.
  ///
  /// Le service est un singleton qui appelle le réseau dès sa construction :
  /// laisser cette logique dans un accesseur d'instance la rendrait
  /// invérifiable autrement qu'en montant un serveur. Elle décide pourtant du
  /// classement d'un écran d'exploitation, ce qui mérite d'être tenu.
  static Map<String, List<DeliveryZone>> groupByCity(
    List<DeliveryZone> zones,
    Map<String, String> cityNames,
  ) {
    final groupes = <String, List<DeliveryZone>>{};
    for (final zone in zones) {
      final ville = cityNames[zone.cityId] ?? _villeInconnue;
      groupes.putIfAbsent(ville, () => []).add(zone);
    }
    for (final groupe in groupes.values) {
      groupe.sort((a, b) => a.name.compareTo(b.name));
    }

    final ordonne = groupes.keys.toList()..sort();
    return {for (final ville in ordonne) ville: groupes[ville]!};
  }

  /// Filtre une recherche sur le nom de la zone **et** sur celui de la ville.
  ///
  /// On cherche aussi bien « Tokoin » que « Lomé » ; une ville dont le nom
  /// correspond garde donc toutes ses zones, y compris celles dont le nom ne
  /// contient pas la requête. Sans cela, chercher une ville rendrait une liste
  /// vide alors qu'elle est précisément la chose trouvée.
  static Map<String, List<DeliveryZone>> filterGroups(
    Map<String, List<DeliveryZone>> groupes,
    String requete,
  ) {
    final terme = requete.trim().toLowerCase();
    if (terme.isEmpty) return groupes;

    final retenus = <String, List<DeliveryZone>>{};
    for (final entree in groupes.entries) {
      if (entree.key.toLowerCase().contains(terme)) {
        retenus[entree.key] = entree.value;
        continue;
      }
      final zones =
          entree.value.where((zone) => zone.name.toLowerCase().contains(terme)).toList();
      if (zones.isNotEmpty) retenus[entree.key] = zones;
    }
    return retenus;
  }

  /// Une écriture est-elle en cours sur cette zone ?
  ///
  /// L'écran de sélection s'en sert pour neutraliser l'interrupteur le temps de
  /// l'aller-retour. Sans cela, deux bascules rapides partent en concurrence et
  /// c'est la réponse la plus lente qui décide de l'état affiché — donc, une
  /// fois sur deux, l'inverse de ce qui a été demandé en dernier.
  bool isWriting(String zoneId) => _writing.contains(zoneId);

  /// Instance unique. La carte de supervision en construit une de son côté et
  /// le formulaire de barème passe par le fournisseur : deux instances
  /// distinctes laisseraient la carte afficher l'ancien forfait d'une zone
  /// qu'on vient de modifier, jusqu'au prochain rechargement de l'écran.
  static final DeliveryZoneService _instance = DeliveryZoneService._internal();
  factory DeliveryZoneService() => _instance;

  DeliveryZoneService._internal() {
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
      // Les deux appels partent ensemble : la liste des villes ne sert qu'à
      // nommer, et l'enchaîner derrière celle des zones doublerait l'attente
      // avant le premier affichage. `_villes` n'échoue jamais — voir plus bas —
      // ce qui autorise à laisser sa promesse courir pendant qu'on attend
      // l'autre.
      final villesEnCours = _villes();
      final zones = await _geographie.zones();

      _zones = zones.map(DeliveryZone.fromRemote).toList();
      _cityNames = await villesEnCours;
    } on eccore.ApiException catch (e) {
      _error = e.status == 403
          ? 'Les zones relèvent du siège : votre compte est rattaché à un '
                'périmètre.'
          : e.detail;
      eccore.Journal.trace('Zones : chargement impossible — ${e.code}');
      _zones = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Noms des villes, indexés par clé.
  ///
  /// **N'échoue pas.** Une ville sert à regrouper des zones à l'écran ; si la
  /// route répond mal, la sélection des zones doit rester utilisable sous un
  /// intitulé neutre plutôt que de disparaître derrière une erreur. Les zones,
  /// elles, sont la substance : leur échec est signalé.
  Future<Map<String, String>> _villes() async {
    try {
      final villes = await _geographie.cities();
      return {for (final ville in villes) ville.id: ville.name};
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('Zones : villes non nommées — ${e.code}');
      return const {};
    }
  }

  /// Ouvre une zone de livraison dans une ville.
  ///
  /// **C'est ce qui manquait pour ouvrir un restaurant ailleurs.**
  /// `Restaurant.zone` est une clé étrangère non nulle : sans zone, aucun
  /// établissement n'est créable. Le dépôt savait écrire (`createZone`), aucun
  /// écran ne l'appelait, et la seule façon d'ouvrir une ville était de passer
  /// par `django-admin`.
  ///
  /// ## Pourquoi un centre et un rayon, et non un contour tracé
  ///
  /// Le serveur attend un `MultiPolygon` — la forme que produisent les outils
  /// de cartographie, et celle que l'exploitation tracera pour de bon. Un
  /// éditeur de contour sur carte est un travail à part entière, et l'absence
  /// d'un tel éditeur ne doit pas empêcher d'ouvrir un marché : le disque
  /// approché ici couvre un quartier de façon utilisable dès le premier jour,
  /// et se remplace ensuite par le contour réel sans migration — c'est le même
  /// champ.
  ///
  /// Le polygone est fermé explicitement (dernier point = premier) : PostGIS
  /// refuse un anneau ouvert, et l'oubli est l'erreur classique.
  Future<DeliveryZone?> createZone({
    required String cityId,
    required String name,
    required double centerLatitude,
    required double centerLongitude,
    required double radiusKm,
    required String currency,
    required double baseFee,
    required double feePerKm,
    double? freeDeliveryThreshold,
    double? minOrderAmount,
    double? maxDistanceKm,
    int estimatedDeliveryMinutes = 30,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final creee = await _geographie.createZone(
        cityId: cityId,
        name: name,
        boundary: disqueGeoJson(
          latitude: centerLatitude,
          longitude: centerLongitude,
          rayonKm: radiusKm,
        ),
        baseFee: eccore.Money.fromMajorUnits(baseFee, currency),
        feePerKm: eccore.Money.fromMajorUnits(feePerKm, currency),
        freeDeliveryThreshold: freeDeliveryThreshold == null
            ? null
            : eccore.Money.fromMajorUnits(freeDeliveryThreshold, currency),
        minOrderAmount: minOrderAmount == null
            ? null
            : eccore.Money.fromMajorUnits(minOrderAmount, currency),
        // Par défaut, la zone refuse au-delà de son propre rayon : un plafond
        // plus large que le contour ne sert à rien, un plafond plus étroit
        // ferait refuser des points pourtant dans la zone.
        maxDistanceKm: maxDistanceKm ?? radiusKm,
        estimatedDeliveryMinutes: estimatedDeliveryMinutes,
      );

      final locale = DeliveryZone.fromRemote(creee);
      _zones = [..._zones, locale];
      return locale;
    } on eccore.ApiException catch (e) {
      _error = e.status == 403
          ? "L'ouverture d'une zone relève du siège : votre compte est "
                'rattaché à un périmètre.'
          : e.detail;
      eccore.Journal.trace('Zones : ouverture refusée — ${e.code}');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Contour circulaire approché, en GeoJSON `MultiPolygon`.
  ///
  /// Le rayon est converti en degrés séparément sur chaque axe : un degré de
  /// longitude vaut `cos(latitude)` fois un degré de latitude, et l'ignorer
  /// produirait une zone deux fois trop large en longitude sous nos latitudes —
  /// c'est-à-dire une zone qui accepte des courses qu'aucun livreur ne peut
  /// faire.
  ///
  /// Trente-six sommets : un pas de dix degrés, dont l'écart au cercle reste
  /// sous 0,4 % du rayon. Au-delà, on paie des octets sur chaque lecture pour
  /// une précision qu'aucune décision n'utilise — le plafond kilométrique de la
  /// zone tranche les cas limites.
  @visibleForTesting
  static Map<String, dynamic> disqueGeoJson({
    required double latitude,
    required double longitude,
    required double rayonKm,
    int sommets = 36,
  }) {
    const degreDeLatitudeEnKm = 110.574;
    const degreDeLongitudeALEquateurEnKm = 111.320;

    final rayonEnLatitude = rayonKm / degreDeLatitudeEnKm;
    final cosinus = math.cos(latitude * math.pi / 180);
    final rayonEnLongitude =
        rayonKm / (degreDeLongitudeALEquateurEnKm * (cosinus.abs() < 1e-6 ? 1e-6 : cosinus));

    final anneau = <List<double>>[
      for (var i = 0; i < sommets; i++)
        () {
          final angle = 2 * math.pi * i / sommets;
          return <double>[
            longitude + rayonEnLongitude * math.cos(angle),
            latitude + rayonEnLatitude * math.sin(angle),
          ];
        }(),
    ];
    // Fermeture explicite de l'anneau : PostGIS refuse un contour ouvert.
    anneau.add(anneau.first);

    return {
      'type': 'MultiPolygon',
      'coordinates': [
        [anneau],
      ],
    };
  }

  /// Rouvre ou ferme une zone.
  ///
  /// Il n'y a pas de suppression : des commandes passées portent les frais de
  /// cette zone, et l'effacer rendrait leur addition inexplicable. Une zone
  /// fermée disparaît de la couverture sans réécrire le passé.
  Future<bool> setZoneActive(String zoneId, bool isActive) async {
    return _write(zoneId, () => _geographie.updateZone(zoneId: zoneId, isActive: isActive));
  }

  /// Ouvre ou ferme plusieurs zones — « toute la ville », depuis l'écran de
  /// sélection.
  ///
  /// Les écritures sont **séquentielles** et non parallèles : ce sont des
  /// `PATCH` sur une ressource d'enseigne, et en lancer dix d'un coup depuis un
  /// seul geste d'exploitant n'accélère rien qui se voie tout en multipliant
  /// les états intermédiaires affichés.
  ///
  /// Les zones déjà dans l'état demandé sont ignorées : les basculer écrirait
  /// pour rien, et ferait échouer l'ensemble sur un refus qui ne concernait
  /// aucun changement réel.
  ///
  /// L'échec est rendu **avec** le compte plutôt que laissé à lire dans
  /// [error] : ce champ peut porter l'erreur d'un chargement précédent, et un
  /// appelant qui s'y fierait annoncerait un échec là où rien n'a même été
  /// tenté. Une écriture refusée interrompt la série — un 403 sur la première
  /// zone vaudra pour les suivantes, et insister ne ferait qu'empiler les
  /// refus.
  Future<({int modifiees, bool echec})> setZonesActive(
    Iterable<String> zoneIds,
    bool isActive,
  ) async {
    var modifiees = 0;
    for (final zoneId in zoneIds) {
      final zone = zoneById(zoneId);
      if (zone == null || zone.isActive == isActive) continue;

      if (!await setZoneActive(zoneId, isActive)) {
        return (modifiees: modifiees, echec: true);
      }
      modifiees++;
    }
    return (modifiees: modifiees, echec: false);
  }

  /// Enregistre le barème d'une zone tel que l'écran vient de le saisir.
  ///
  /// Les montants arrivent en **unité majeure** — ce que l'exploitant a tapé —
  /// et sont convertis ici dans la devise de la zone. C'est le seul endroit de
  /// l'application où une saisie devient un montant : le serveur n'accepte que
  /// l'unité mineure (ADR-007) et refuse une échelle ambiguë plutôt que de la
  /// deviner.
  ///
  /// [freeDeliveryThreshold] à `null` **ne retire pas** le seuil : c'est
  /// [clearFreeDeliveryThreshold] qui le fait. Confondre les deux rendrait
  /// impossible d'arrêter d'offrir la livraison.
  Future<bool> saveZoneSettings({
    required String zoneId,
    String? name,
    double? deliveryFee,
    double? freeDeliveryThreshold,
    bool clearFreeDeliveryThreshold = false,
    int? estimatedTimeMinutes,
    bool? isActive,
  }) async {
    final zone = zoneById(zoneId);
    if (zone == null) {
      _error = 'Zone introuvable : rechargez la liste.';
      notifyListeners();
      return false;
    }

    eccore.Money? montant(double? saisie) =>
        saisie == null ? null : eccore.Money.fromMajorUnits(saisie, zone.currency);

    return _write(
      zoneId,
      () => _geographie.updateZone(
        zoneId: zoneId,
        name: name,
        baseFee: montant(deliveryFee),
        freeDeliveryThreshold: montant(freeDeliveryThreshold),
        clearFreeDeliveryThreshold: clearFreeDeliveryThreshold,
        estimatedDeliveryMinutes: estimatedTimeMinutes,
        isActive: isActive,
      ),
    );
  }

  /// Écrit, puis remplace la zone locale par **celle que le serveur rend**.
  ///
  /// Recopier la saisie serait plus court et faux : le serveur peut normaliser
  /// un montant ou refuser une devise, et l'écran afficherait alors une valeur
  /// que la base ne porte pas.
  Future<bool> _write(
    String zoneId,
    Future<eccore.DeliveryZone> Function() ecriture,
  ) async {
    _writing.add(zoneId);
    notifyListeners();

    try {
      final maj = await ecriture();
      final index = _zones.indexWhere((zone) => zone.id == zoneId);
      if (index != -1) _zones[index] = DeliveryZone.fromRemote(maj);
      _error = null;
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.status == 403
          ? 'Les barèmes relèvent du siège : votre compte est rattaché à un '
                'périmètre.'
          : e.detail;
      eccore.Journal.trace('Zones : écriture refusée — ${e.code}');
      return false;
    } finally {
      // Dans le `finally` : une écriture refusée qui laisserait la zone
      // marquée « en cours » neutraliserait son interrupteur jusqu'au
      // rechargement de l'écran, c'est-à-dire interdirait la seconde
      // tentative.
      _writing.remove(zoneId);
      notifyListeners();
    }
  }

  DeliveryZone? zoneById(String id) {
    for (final zone in _zones) {
      if (zone.id == id) return zone;
    }
    return null;
  }

  DeliveryZone? zoneByName(String name) {
    for (final zone in _zones) {
      if (zone.name == name) return zone;
    }
    return null;
  }
}
