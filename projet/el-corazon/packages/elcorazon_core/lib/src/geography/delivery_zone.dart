import 'package:elcorazon_core/src/directions/geo_point.dart';
import 'package:elcorazon_core/src/geography/zone_schedule.dart';
import 'package:elcorazon_core/src/models/money.dart';

/// Zone de livraison et son barème — miroir de `ManagedDeliveryZoneSerializer`.
///
/// **C'est le seul endroit où se décide un frais de livraison.** Le barème vit
/// en donnée : ouvrir un quartier, relever le forfait d'une zone excentrée ou
/// offrir la livraison au-dessus d'un seuil se font depuis le back-office, sans
/// déploiement. L'implémentation précédente portait deux constantes
/// contradictoires dans le code du client (`5.00` d'un côté, `500.0` de
/// l'autre).
///
/// Les montants sont des `Money` (ADR-007) et la devise est héritée du pays :
/// un forfait libellé dans une autre devise est refusé à l'écriture, et non
/// découvert au calcul des frais d'un client.
class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.cityId,
    required this.name,
    required this.baseFee,
    required this.feePerKm,
    required this.maxDistanceKm,
    required this.estimatedDeliveryMinutes,
    required this.isActive,
    this.boundary,
    this.freeDeliveryThreshold,
    this.minOrderAmount,
    this.shape = '',
    this.center,
    this.radiusMeters,
    this.restaurantSlug,
    this.status = StatutZone.publiee,
    this.transitions = const [],
    this.priority = 0,
    this.overlaps = const [],
    this.horaires = const [],
    this.exceptions = const [],
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.publishedBy,
    this.publishedAt,
    this.suspensionReason = '',
    this.suspendedAt,
    this.suspensionExpectedEndAt,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      id: json['id'] as String,
      cityId: _cityId(json['city']),
      name: json['name'] as String,
      boundary: json['boundary'] as Map<String, dynamic>?,
      baseFee: Money.fromJson(json['base_fee'] as Map<String, dynamic>),
      feePerKm: Money.fromJson(json['fee_per_km'] as Map<String, dynamic>),
      freeDeliveryThreshold: _money(json['free_delivery_threshold']),
      minOrderAmount: _money(json['min_order_amount']),
      maxDistanceKm: _decimal(json['max_distance_km']),
      estimatedDeliveryMinutes: json['estimated_delivery_minutes'] as int,
      isActive: json['is_active'] as bool? ?? true,
      shape: json['shape'] as String? ?? '',
      center: _point(json['center']),
      radiusMeters: json['radius_meters'] as int?,
      restaurantSlug: json['restaurant'] as String?,
      // Un serveur antérieur au cycle de vie ne rend pas `status` : la zone
      // est alors ce que disait `is_active`.
      status: json['status'] as String? ??
          ((json['is_active'] as bool? ?? true) ? StatutZone.publiee : StatutZone.suspendue),
      transitions: [
        for (final t in json['transitions'] as List? ?? const []) t as String,
      ],
      priority: json['priority'] as int? ?? 0,
      overlaps: [
        for (final nom in json['overlaps'] as List? ?? const []) nom as String,
      ],
      horaires: [
        for (final h in json['opening_hours'] as List? ?? const [])
          HoraireDeZone.fromJson(h as Map<String, dynamic>),
      ],
      exceptions: [
        for (final e in json['exceptions'] as List? ?? const [])
          ExceptionDeZone.fromJson(e as Map<String, dynamic>),
      ],
      createdBy: json['created_by'] as String?,
      createdAt: _date(json['created_at']),
      updatedBy: json['updated_by'] as String?,
      updatedAt: _date(json['updated_at']),
      publishedBy: json['published_by'] as String?,
      publishedAt: _date(json['published_at']),
      suspensionReason: json['suspension_reason'] as String? ?? '',
      suspendedAt: _date(json['suspended_at']),
      suspensionExpectedEndAt: _date(json['suspension_expected_end_at']),
    );
  }

  final String id;
  final String cityId;
  final String name;

  /// Contour GeoJSON — plusieurs kilo-octets, rendu tel quel par le serveur.
  ///
  /// Il sort d'un outil de dessin cartographique, qui produit du GeoJSON :
  /// inventer une forme maison obligerait à convertir avant chaque envoi. Il
  /// n'est jamais exposé aux applications clientes, qui demandent « suis-je
  /// desservi ? » et non « où passe la frontière ? ».
  final Map<String, dynamic>? boundary;
  final Money baseFee;
  final Money feePerKm;
  final Money? freeDeliveryThreshold;
  final Money? minOrderAmount;
  final double maxDistanceKm;
  final int estimatedDeliveryMinutes;
  final bool isActive;

  /// `circle`, `polygon` ou `administrative` — l'outil avec lequel le contour
  /// a été saisi, donc l'éditeur à rouvrir. Vide d'un serveur antérieur.
  final String shape;

  /// Centre et rayon d'une zone circulaire ; nuls pour un polygone.
  final GeoPoint? center;
  final int? radiusMeters;

  /// La cuisine à laquelle la zone est propre ; nul pour une zone de ville.
  final String? restaurantSlug;

  bool get estCirculaire => shape == 'circle';

  /// Statut serveur — `draft`, `pending_review`, `published`, `suspended`,
  /// `archived` (voir [StatutZone]). Seule `published` livre.
  final String status;

  /// Statuts atteignables depuis [status], **lus dans la machine à états du
  /// serveur** : l'écran ne propose que ceux-là.
  final List<String> transitions;

  /// Départage entre zones qui se recouvrent — la plus haute l'emporte.
  final int priority;

  /// Noms des zones publiées dont le contour recoupe celui-ci.
  final List<String> overlaps;

  /// Plages hebdomadaires ; vide, la zone suit les horaires de sa cuisine.
  final List<HoraireDeZone> horaires;

  /// Exceptions en cours ou à venir.
  final List<ExceptionDeZone> exceptions;

  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;
  final String? publishedBy;
  final DateTime? publishedAt;
  final String suspensionReason;
  final DateTime? suspendedAt;
  final DateTime? suspensionExpectedEndAt;

  bool peutPasserA(String cible) => transitions.contains(cible);

  /// **Tout** le contour : chaque polygone, chacun avec ses anneaux — le
  /// premier est l'extérieur, les suivants des trous (enclaves non
  /// desservies). Sans point de fermeture répété.
  ///
  /// C'est ce que la carte doit dessiner. [sommets] n'en rend que le premier
  /// anneau du premier polygone, ce que rouvre l'éditeur d'une zone tracée à
  /// la main ; afficher une zone importée avec lui cachait ses autres
  /// morceaux et ses trous.
  List<List<List<GeoPoint>>> get polygones {
    final geometrie = boundary;
    if (geometrie == null) return const [];
    final coordonnees = geometrie['coordinates'];
    if (coordonnees is! List) return const [];
    final bruts = geometrie['type'] == 'Polygon' ? [coordonnees] : coordonnees;
    return [
      for (final polygone in bruts)
        if (polygone is List)
          [
            for (final anneau in polygone)
              if (anneau is List) _anneau(anneau),
          ],
    ];
  }

  /// Vrai si le contour a plusieurs morceaux ou des trous — l'éditeur de
  /// polygone ne saurait pas le rouvrir sans le simplifier.
  bool get estComplexe {
    final morceaux = polygones;
    return morceaux.length > 1 || morceaux.any((p) => p.length > 1);
  }

  static List<GeoPoint> _anneau(List<dynamic> points) {
    final anneau = [
      for (final point in points)
        GeoPoint(
          ((point as List)[1] as num).toDouble(),
          (point[0] as num).toDouble(),
        ),
    ];
    if (anneau.length > 1 && anneau.first == anneau.last) anneau.removeLast();
    return anneau;
  }

  static DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;

  /// Les sommets du contour, dans l'ordre, **sans** le point qui ferme
  /// l'anneau — ce que l'éditeur de polygone rouvre.
  ///
  /// Lit le premier anneau du premier polygone : une zone tracée à la main
  /// n'en a qu'un. Vide si le contour n'a pas été rendu.
  List<GeoPoint> get sommets {
    final polygones = boundary?['coordinates'];
    if (polygones is! List || polygones.isEmpty) return const [];
    final anneaux = polygones.first;
    if (anneaux is! List || anneaux.isEmpty) return const [];
    final anneau = [
      for (final point in anneaux.first as List)
        GeoPoint(
          ((point as List)[1] as num).toDouble(),
          (point[0] as num).toDouble(),
        ),
    ];
    if (anneau.length > 1 && anneau.first == anneau.last) anneau.removeLast();
    return anneau;
  }

  static GeoPoint? _point(Object? value) {
    if (value is! Map) return null;
    return GeoPoint((value['lat'] as num).toDouble(), (value['lon'] as num).toDouble());
  }

  static Money? _money(Object? value) =>
      value == null ? null : Money.fromJson(value as Map<String, dynamic>);

  /// Un `DecimalField` de DRF voyage **en chaîne**
  /// (`COERCE_DECIMAL_TO_STRING`, laissé à sa valeur par défaut) : lire
  /// `max_distance_km` comme un nombre plantait à la première zone reçue.
  static double _decimal(Object? value) => double.parse(value.toString());

  /// La ville arrive sous deux formes selon le public de la route : une clé
  /// pour le back-office (`ManagedDeliveryZoneSerializer`), la ville entière
  /// pour un visiteur (`DeliveryZoneSerializer`, qui l'imbrique pour porter la
  /// devise du pays avec elle). Les deux désignent la même ville ; seule sa
  /// clé est retenue ici.
  static String _cityId(Object? value) => value is Map ? value['id'].toString() : value.toString();
}
