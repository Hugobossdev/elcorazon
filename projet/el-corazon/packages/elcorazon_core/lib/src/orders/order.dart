import 'package:elcorazon_core/src/models/money.dart';

/// Option retenue sur une ligne de commande — copie figée du choix du client.
///
/// Miroir du JSON écrit par `OrderService` :
/// `{"group": "Cuisson", "option": "À point", "delta": 0, "currency": "XOF"}`.
///
/// C'est ce que le client a demandé : « sans oignon », « bien cuit », « taille
/// L ». Une cuisine qui ne le voit pas prépare autre chose que ce qui a été
/// commandé — le socle ne le lisait pas, et le back-office ne pouvait donc rien
/// en montrer.
class ChosenOption {
  const ChosenOption({
    required this.groupName,
    required this.optionName,
    required this.priceDelta,
  });

  factory ChosenOption.fromJson(Map<String, dynamic> json) {
    return ChosenOption(
      groupName: json['group'] as String? ?? '',
      optionName: json['option'] as String? ?? '',
      priceDelta: Money(
        amountMinor: (json['delta'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'XOF',
      ),
    );
  }

  /// Le groupe d'options — « Cuisson », « Taille », « Suppléments ».
  final String groupName;

  final String optionName;

  /// Ce que l'option ajoute au prix unitaire. Souvent nul.
  final Money priceDelta;
}

/// Ligne de commande figée — miroir de `OrderLineSerializer`
/// (`backend/apps/orders/serializers.py`). Copie gelée au moment de la
/// commande : contrairement au panier, elle ne se recalcule jamais depuis le
/// catalogue.
class OrderLine {
  const OrderLine({
    required this.id,
    required this.menuItemId,
    required this.itemName,
    required this.itemImage,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.notes,
    this.options = const [],
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    return OrderLine(
      id: json['id'] as String,
      menuItemId: json['menu_item'] as String,
      itemName: json['item_name'] as String,
      itemImage: json['item_image'] as String?,
      unitPrice: Money.fromJson(json['unit_price'] as Map<String, dynamic>),
      quantity: json['quantity'] as int,
      lineTotal: Money.fromJson(json['line_total'] as Map<String, dynamic>),
      notes: json['notes'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((o) => ChosenOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String menuItemId;
  final String itemName;
  final String? itemImage;
  final Money unitPrice;
  final int quantity;
  final Money lineTotal;
  final String notes;

  /// Ce que le client a choisi sur cette ligne, figé au moment de la commande.
  final List<ChosenOption> options;
}

/// Transition de statut — miroir de `OrderStatusEventSerializer`
/// (`backend/apps/orders/serializers.py`).
///
/// La machine à états l'écrit dans la même transaction que le changement de
/// statut : l'historique d'une commande est un sous-produit du service, pas
/// une écriture séparée qu'on peut oublier. C'est la **seule** source
/// d'horodatage par étape ; une application qui affiche un historique sans
/// lire ceci l'invente.
///
/// Renseigné sur la forme détail (`GET /orders/{id}/`) uniquement.
class OrderStatusEvent {
  const OrderStatusEvent({
    required this.id,
    required this.fromStatus,
    required this.toStatus,
    required this.reason,
    required this.createdAt,
  });

  factory OrderStatusEvent.fromJson(Map<String, dynamic> json) {
    return OrderStatusEvent(
      id: json['id'] as String,
      fromStatus: json['from_status'] as String,
      toStatus: json['to_status'] as String,
      reason: json['reason'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;

  /// Vide sur la toute première transition, la commande n'ayant pas d'avant.
  final String fromStatus;

  final String toStatus;

  /// Motif saisi par le personnel, ou vide si la transition vient du système.
  final String reason;

  final DateTime createdAt;
}

/// Commande — miroir de `OrderSerializer`/`OrderDetailSerializer`
/// (`backend/apps/orders/serializers.py`). `lines`/`statusEvents` ne sont
/// renseignés que sur la forme détail (`GET /orders/{id}/`) — vides sur la
/// forme liste (`GET /orders/`).
class Order {
  const Order({
    required this.id,
    required this.reference,
    required this.restaurantSlug,
    required this.restaurantName,
    required this.status,
    required this.allowedTransitions,
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.deliveryAddressLine,
    required this.deliveryLandmark,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.recipientName,
    required this.recipientPhone,
    required this.placedAt,
    required this.createdAt,
    required this.updatedAt,
    this.linesCount = 0,
    this.itemsCount = 0,
    this.estimatedDeliveryAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason = '',
    this.deliveryInstructions = '',
    this.lines = const [],
    this.statusEvents = const [],
    this.restaurantLatitude,
    this.restaurantLongitude,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final location = json['delivery_location'] as Map<String, dynamic>;
    // Optionnel, contrairement à `delivery_location` : un serveur antérieur à
    // ce champ rend une commande sans lui, et une carte à deux repères vaut
    // mieux qu'un écran de suivi qui refuse de s'ouvrir.
    final pickup = json['restaurant_location'] as Map<String, dynamic>?;
    return Order(
      id: json['id'] as String,
      reference: json['reference'] as String,
      restaurantSlug: json['restaurant'] as String,
      restaurantName: json['restaurant_name'] as String,
      status: json['status'] as String,
      allowedTransitions: (json['allowed_transitions'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      subtotal: Money.fromJson(json['subtotal'] as Map<String, dynamic>),
      deliveryFee: Money.fromJson(json['delivery_fee'] as Map<String, dynamic>),
      discount: Money.fromJson(json['discount'] as Map<String, dynamic>),
      total: Money.fromJson(json['total'] as Map<String, dynamic>),
      paymentMethod: json['payment_method'] as String,
      deliveryAddressLine: json['delivery_address_line'] as String,
      deliveryLandmark: json['delivery_landmark'] as String? ?? '',
      deliveryLatitude: (location['lat'] as num).toDouble(),
      deliveryLongitude: (location['lon'] as num).toDouble(),
      restaurantLatitude:
          pickup == null ? null : (pickup['lat'] as num).toDouble(),
      restaurantLongitude:
          pickup == null ? null : (pickup['lon'] as num).toDouble(),
      recipientName: json['recipient_name'] as String,
      recipientPhone: json['recipient_phone'] as String,
      // Comptés **par le serveur**, et présents sur les deux formes.
      //
      // C'est ce qui permet à une liste d'annoncer « 6 articles » sans porter
      // les lignes : `OrderSerializer` ne les rend pas, et les compter à
      // partir de `lines` donnait donc zéro sur toutes les commandes.
      linesCount: json['lines_count'] as int? ?? 0,
      itemsCount: json['items_count'] as int? ?? 0,
      placedAt: DateTime.parse(json['placed_at'] as String),
      estimatedDeliveryAt: _parseDate(json['estimated_delivery_at']),
      deliveredAt: _parseDate(json['delivered_at']),
      cancelledAt: _parseDate(json['cancelled_at']),
      cancellationReason: json['cancellation_reason'] as String? ?? '',
      deliveryInstructions: json['delivery_instructions'] as String? ?? '',
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map((line) => OrderLine.fromJson(line as Map<String, dynamic>))
          .toList(),
      statusEvents: (json['status_events'] as List<dynamic>? ?? const [])
          .map((e) => OrderStatusEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String reference;
  final String restaurantSlug;
  final String restaurantName;

  /// Point d'enlèvement — `Restaurant.location`, miroir de
  /// `OrderSerializer.restaurant_location`.
  ///
  /// Nul quand le serveur ne le rend pas encore. L'écran de suivi montre alors
  /// deux repères au lieu de trois, ce qui reste juste ; le suppléer par une
  /// constante d'application désignerait le premier établissement et
  /// deviendrait faux au deuxième.
  final double? restaurantLatitude;
  final double? restaurantLongitude;

  /// `pending` | `confirmed` | ... (`OrderStatus` côté serveur, ADR-010).
  final String status;
  final List<String> allowedTransitions;
  final Money subtotal;
  final Money deliveryFee;
  final Money discount;
  final Money total;

  /// `mobile_money` | `cash` | `wallet` | `card` (`PaymentMethod` côté serveur).
  final String paymentMethod;
  final String deliveryAddressLine;
  final String deliveryLandmark;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String recipientName;
  final String recipientPhone;

  /// Nombre de **lignes** — trois produits distincts font trois lignes.
  ///
  /// Rendu sur la forme liste comme sur la forme détail : c'est une valeur
  /// calculée en base, pas une longueur de tableau. Compter [lines] à la
  /// place donne zéro partout où le serveur ne rend pas les lignes, ce qui est
  /// le cas de toutes les listes.
  final int linesCount;

  /// Nombre d'**articles** — la somme des quantités.
  ///
  /// Deux burgers, une pizza et trois donuts font six articles et trois
  /// lignes. C'est ce chiffre qu'affiche une carte de commande, et [linesCount]
  /// qu'affiche une facture.
  final int itemsCount;
  final DateTime placedAt;
  final DateTime? estimatedDeliveryAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String cancellationReason;
  final String deliveryInstructions;
  final List<OrderLine> lines;

  /// Les transitions qu'a connues la commande, dans l'ordre où le serveur les
  /// rend. Vide sur la forme liste.
  final List<OrderStatusEvent> statusEvents;
  final DateTime createdAt;
  final DateTime updatedAt;

  static DateTime? _parseDate(Object? value) => value == null ? null : DateTime.parse(value as String);
}
