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

/// Un article du sac, tel que le livreur le vérifie au retrait.
class AssignmentItem {
  const AssignmentItem({
    required this.name,
    required this.quantity,
    this.itemImage = '',
    this.options = const [],
    this.notes = '',
  });

  factory AssignmentItem.fromJson(Map<String, dynamic> json) => AssignmentItem(
    name: json['name'] as String? ?? '',
    quantity: json['quantity'] as int? ?? 1,
    itemImage: json['item_image'] as String? ?? '',
    options: (json['options'] as List<dynamic>? ?? const [])
        .map((option) => option.toString())
        .where((option) => option.isNotEmpty)
        .toList(growable: false),
    notes: json['notes'] as String? ?? '',
  );

  final String name;
  final int quantity;
  final String itemImage;
  final List<String> options;
  final String notes;

  /// Alias aligné sur [OrderLine] : les écrans livreur manipulent un article
  /// de course sans avoir à relire la commande client.
  String get itemName => name;

  /// « 2 × Poulet braisé (Fort) ».
  String get label =>
      '$quantity × $name${options.isEmpty ? '' : ' (${options.join(', ')})'}';
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
    this.deliveryInstructions = '',
    this.deliveryZoneName = '',
    this.cityName = '',
    this.paymentMethod = '',
    this.orderStatus = '',
    this.orderTotal,
    this.estimatedDeliveryAt,
    this.amountToCollect,
    this.items = const [],
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    final pickup = json['pickup_location'] as Map<String, dynamic>;
    final dropoff = json['delivery_location'] as Map<String, dynamic>;
    final fee = json['courier_fee'] as Map<String, dynamic>?;
    final total = json['order_total'] as Map<String, dynamic>?;
    final aEncaisser = json['amount_to_collect'] as Map<String, dynamic>?;
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
      // Tous facultatifs : un serveur antérieur rend une course sans eux, et
      // elle doit rester lisible.
      deliveryInstructions: json['delivery_instructions'] as String? ?? '',
      deliveryZoneName: json['delivery_zone_name'] as String? ?? '',
      cityName: json['city_name'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? '',
      orderStatus: json['order_status'] as String? ?? '',
      orderTotal: total == null ? null : Money.fromJson(total),
      estimatedDeliveryAt: _parseDate(json['estimated_delivery_at']),
      amountToCollect: aEncaisser == null ? null : Money.fromJson(aEncaisser),
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((item) => AssignmentItem.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
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

  /// La consigne du client — « portail bleu, sonnez deux fois ».
  final String deliveryInstructions;

  /// Zone et ville de livraison, figées sur la commande.
  final String deliveryZoneName;
  final String cityName;

  /// `cash` | `mobile_money` | … — et, en espèces, **ce qu'il faut encaisser**.
  final String paymentMethod;

  /// L'étape de la **commande** — `OrderStatus` côté serveur.
  ///
  /// Distincte de [status], qui est celle de la course, et indispensable pour
  /// une raison précise : [allowedTransitions] est calculé sur la seule machine
  /// de la course, si bien que « récupérée » y apparaît dès l'acceptation,
  /// quelle que soit l'avancée de la cuisine. Le serveur refuse ce geste tant
  /// que la commande n'est pas prête ; ce champ permet de ne pas le proposer.
  ///
  /// Vide d'un serveur antérieur — voir [repasPretARetirer], qui préfère alors
  /// laisser le geste possible plutôt que de bloquer un livreur sur un champ
  /// absent.
  final String orderStatus;
  final Money? orderTotal;

  /// La cuisine a-t-elle déclaré le repas prêt ?
  ///
  /// `true` aussi lorsque la commande est déjà plus loin — récupérée, en route,
  /// livrée : le repas est alors sorti de cuisine depuis longtemps, et un
  /// livreur qui rejoue son geste après une coupure réseau ne doit pas se voir
  /// opposer un refus.
  ///
  /// `true` également quand le statut est **inconnu** : un serveur antérieur ne
  /// le rend pas, et masquer le bouton dans ce cas immobiliserait le livreur
  /// alors que le serveur, lui, accepterait. Le refus métier reste le filet.
  bool get repasPretARetirer =>
      orderStatus.isEmpty ||
      const {'ready', 'picked_up', 'on_the_way', 'delivered'}.contains(orderStatus);

  /// Promesse calculée sur la commande au moment de l'affectation.
  final DateTime? estimatedDeliveryAt;

  /// Le montant à encaisser à la porte ; nul quand la commande est déjà payée.
  final Money? amountToCollect;

  /// Ce qu'il y a dans le sac, pour le vérifier au retrait — sans les prix.
  final List<AssignmentItem> items;

  /// Le livreur doit-il encaisser à la livraison ?
  bool get collectsCash => amountToCollect != null;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Course encore en cours de vie — miroir de `Assignment.is_active`.
  bool get isActive => const {
    DeliveryStatus.offered,
    DeliveryStatus.accepted,
    DeliveryStatus.pickedUp,
    DeliveryStatus.onTheWay,
  }.contains(status);

  /// Le livreur **porte** cette course — miroir de `ENGAGED_STATUSES`
  /// (`backend/apps/delivery/states.py`).
  ///
  /// ## Pourquoi c'est distinct d'[isActive]
  ///
  /// Une proposition est vivante sans occuper personne : le livreur peut en
  /// recevoir plusieurs et choisir. Ce sont les trois étapes suivantes qui le
  /// mobilisent — il roule vers un restaurant, puis vers un client.
  ///
  /// C'est sur cette distinction que porte l'invariant L6 : **le serveur ne
  /// laisse plus un livreur engager deux courses à la fois**, et le garantit par
  /// une contrainte de base (`one_engaged_assignment_per_courier`) autant que
  /// par un refus métier à la proposition comme à l'acceptation.
  ///
  /// Rien ne le garantissait auparavant. Seule l'unicité par *commande* était
  /// tenue, et `Dely` s'y référait pourtant pour ne suivre qu'une course : les
  /// relevés de position ne partaient que pour la première trouvée, et le client
  /// de l'autre commande voyait un livreur immobile.
  bool get isEngaged => const {
    DeliveryStatus.accepted,
    DeliveryStatus.pickedUp,
    DeliveryStatus.onTheWay,
  }.contains(status);

  static DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
