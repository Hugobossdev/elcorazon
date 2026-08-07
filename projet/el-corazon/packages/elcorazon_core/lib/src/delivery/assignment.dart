import 'package:elcorazon_core/src/models/money.dart';
import 'package:elcorazon_core/src/delivery/courier_profile.dart';

/// Étapes d'une course — miroir de `DeliveryStatus`
/// (`backend/apps/delivery/states.py`). Constantes de chaînes plutôt qu'une
/// énumération Dart : le serveur reste seul maître des transitions, et une
/// valeur nouvelle côté serveur ne doit pas faire planter le parsing.
abstract final class DeliveryStatus {
  static const offered = 'offered';
  static const accepted = 'accepted';
  static const pickedUp = 'picked_up';
  static const onTheWay = 'on_the_way';
  static const delivered = 'delivered';
  static const declined = 'declined';
  static const cancelled = 'cancelled';
}

/// Course affectée à un livreur — miroir de `AssignmentSerializer`
/// (`backend/apps/delivery/serializers.py`).
///
/// Porte à plat ce que le livreur doit voir de la commande (référence,
/// enlèvement, adresse, destinataire) : il n'a pas besoin d'aller lire
/// `/orders/{id}/`, et le contrat ne le lui permettrait pas — une commande
/// appartient à son client.
class Assignment {
  const Assignment({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.restaurantName,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.deliveryAddressLine,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.recipientName,
    required this.recipientPhone,
    required this.courier,
    required this.status,
    required this.allowedTransitions,
    required this.offeredAt,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryLandmark = '',
    this.courierFee,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.declineReason = '',
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    final pickup = json['pickup_location'] as Map<String, dynamic>;
    final dropoff = json['delivery_location'] as Map<String, dynamic>;
    final fee = json['courier_fee'] as Map<String, dynamic>?;
    return Assignment(
      id: json['id'] as String,
      orderId: json['order'] as String,
      orderReference: json['order_reference'] as String,
      restaurantName: json['restaurant_name'] as String,
      pickupLatitude: (pickup['lat'] as num).toDouble(),
      pickupLongitude: (pickup['lon'] as num).toDouble(),
      deliveryAddressLine: json['delivery_address_line'] as String,
      deliveryLandmark: json['delivery_landmark'] as String? ?? '',
      deliveryLatitude: (dropoff['lat'] as num).toDouble(),
      deliveryLongitude: (dropoff['lon'] as num).toDouble(),
      recipientName: json['recipient_name'] as String,
      recipientPhone: json['recipient_phone'] as String,
      courier: CourierSummary.fromJson(json['courier'] as Map<String, dynamic>),
      status: json['status'] as String,
      allowedTransitions: (json['allowed_transitions'] as List<dynamic>)
          .map((transition) => transition.toString())
          .toList(),
      courierFee: fee == null ? null : Money.fromJson(fee),
      offeredAt: DateTime.parse(json['offered_at'] as String),
      acceptedAt: _parseDate(json['accepted_at']),
      pickedUpAt: _parseDate(json['picked_up_at']),
      deliveredAt: _parseDate(json['delivered_at']),
      declineReason: json['decline_reason'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String orderId;
  final String orderReference;
  final String restaurantName;
  /// Point de retrait — `Restaurant.location`, obligatoire côté serveur.
  final double pickupLatitude;
  final double pickupLongitude;
  final String deliveryAddressLine;
  final String deliveryLandmark;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String recipientName;
  final String recipientPhone;
  final CourierSummary courier;

  /// Voir [DeliveryStatus].
  final String status;

  /// Étapes atteignables depuis [status], telles que le serveur les déclare.
  /// C'est **la** source des boutons à afficher : refaire la table des
  /// transitions côté client la ferait diverger au premier changement.
  final List<String> allowedTransitions;

  /// Rémunération figée à l'acceptation — nulle tant que la course est
  /// seulement proposée.
  final Money? courierFee;
  final DateTime offeredAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final String declineReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Course encore en cours de vie — miroir de `Assignment.is_active`.
  bool get isActive => const {
    DeliveryStatus.offered,
    DeliveryStatus.accepted,
    DeliveryStatus.pickedUp,
    DeliveryStatus.onTheWay,
  }.contains(status);

  static DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
