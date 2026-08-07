import 'package:elcorazon_core/src/models/money.dart';

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
    this.estimatedDeliveryAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason = '',
    this.deliveryInstructions = '',
    this.lines = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final location = json['delivery_location'] as Map<String, dynamic>;
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
      recipientName: json['recipient_name'] as String,
      recipientPhone: json['recipient_phone'] as String,
      placedAt: DateTime.parse(json['placed_at'] as String),
      estimatedDeliveryAt: _parseDate(json['estimated_delivery_at']),
      deliveredAt: _parseDate(json['delivered_at']),
      cancelledAt: _parseDate(json['cancelled_at']),
      cancellationReason: json['cancellation_reason'] as String? ?? '',
      deliveryInstructions: json['delivery_instructions'] as String? ?? '',
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map((line) => OrderLine.fromJson(line as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String reference;
  final String restaurantSlug;
  final String restaurantName;

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
  final DateTime placedAt;
  final DateTime? estimatedDeliveryAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String cancellationReason;
  final String deliveryInstructions;
  final List<OrderLine> lines;
  final DateTime createdAt;
  final DateTime updatedAt;

  static DateTime? _parseDate(Object? value) => value == null ? null : DateTime.parse(value as String);
}
