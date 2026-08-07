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
  static String _cityId(Object? value) =>
      value is Map ? value['id'].toString() : value.toString();
}
