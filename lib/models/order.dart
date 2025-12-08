import 'package:flutter/foundation.dart';

class Order {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final OrderStatus status;
  final String deliveryAddress;
  final String? deliveryNotes;
  final String? promoCode;
  final double discount;
  final PaymentMethod paymentMethod;
  final DateTime orderTime;
  final DateTime createdAt;
  final DateTime? estimatedDeliveryTime;
  final String? deliveryPersonId;
  final List<OrderStatusUpdate> statusUpdates;
  final String? specialInstructions;

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.total, required this.deliveryAddress, required this.paymentMethod, required this.orderTime, required this.createdAt, this.deliveryFee = 5.0,
    this.status = OrderStatus.pending,
    this.deliveryNotes,
    this.promoCode,
    this.discount = 0.0,
    this.estimatedDeliveryTime,
    this.deliveryPersonId,
    this.statusUpdates = const [],
    this.specialInstructions,
  });

  Order copyWith({
    String? id,
    String? userId,
    List<OrderItem>? items,
    double? subtotal,
    double? deliveryFee,
    double? total,
    OrderStatus? status,
    String? deliveryAddress,
    String? deliveryNotes,
    String? promoCode,
    double? discount,
    PaymentMethod? paymentMethod,
    DateTime? orderTime,
    DateTime? createdAt,
    DateTime? estimatedDeliveryTime,
    String? deliveryPersonId,
    List<OrderStatusUpdate>? statusUpdates,
    String? specialInstructions,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      total: total ?? this.total,
      status: status ?? this.status,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      promoCode: promoCode ?? this.promoCode,
      discount: discount ?? this.discount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderTime: orderTime ?? this.orderTime,
      createdAt: createdAt ?? this.createdAt,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      deliveryPersonId: deliveryPersonId ?? this.deliveryPersonId,
      statusUpdates: statusUpdates ?? this.statusUpdates,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'status': status.toString(),
      'deliveryAddress': deliveryAddress,
      'deliveryNotes': deliveryNotes,
      'promoCode': promoCode,
      'discount': discount,
      'paymentMethod': paymentMethod.toString(),
      'orderTime': orderTime.toIso8601String(),
      'estimatedDeliveryTime': estimatedDeliveryTime?.toIso8601String(),
      'deliveryPersonId': deliveryPersonId,
      'specialInstructions': specialInstructions,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    // Parser les order_items si présents
    List<OrderItem> items = [];
    if (map['order_items'] != null) {
      if (map['order_items'] is List) {
        final itemsList = map['order_items'] as List;
        items = itemsList
            .map((item) {
              try {
                if (item == null || item is! Map<String, dynamic>) {
                  return null;
                }
                return OrderItem(
                  menuItemId: item['menu_item_id']?.toString() ?? item['menuItemId']?.toString() ?? '',
                  menuItemName: item['menu_item_name']?.toString() ?? item['menuItemName']?.toString() ?? '',
                  name: item['name']?.toString() ?? item['menu_item_name']?.toString() ?? item['menuItemName']?.toString() ?? '',
                  category: item['category']?.toString() ?? '',
                  menuItemImage: item['menu_item_image']?.toString() ?? item['menuItemImage']?.toString() ?? '',
                  quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                  unitPrice: (item['unit_price'] as num?)?.toDouble() ?? (item['unitPrice'] as num?)?.toDouble() ?? 0.0,
                  totalPrice: (item['total_price'] as num?)?.toDouble() ?? (item['totalPrice'] as num?)?.toDouble() ?? 0.0,
                  customizations: item['customizations'] is Map 
                      ? Map<String, String>.from((item['customizations'] as Map).map(
                          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
                        ),)
                      : const {},
                  notes: item['notes']?.toString(),
                );
              } catch (e) {
                debugPrint('⚠️ Erreur parsing order item: $e');
                return null;
              }
            })
            .whereType<OrderItem>()
            .toList();
      }
    }
    
    return Order(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? map['userId'] ?? '',
      items: items,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ??
          (map['deliveryFee'] as num?)?.toDouble() ??
          5.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      deliveryAddress: map['delivery_address'] ?? map['deliveryAddress'] ?? '',
      deliveryNotes: map['delivery_notes'] ?? map['deliveryNotes'],
      promoCode: map['promo_code'] ?? map['promoCode'],
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) =>
            e.toString().split('.').last == map['payment_method'] ||
            e.toString().split('.').last == map['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      orderTime: map['order_time'] != null
          ? DateTime.parse(map['order_time'])
          : map['orderTime'] != null
              ? DateTime.parse(map['orderTime'])
              : DateTime.now(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : map['createdAt'] != null
              ? DateTime.parse(map['createdAt'])
              : DateTime.now(),
      estimatedDeliveryTime: map['estimated_delivery_time'] != null
          ? DateTime.parse(map['estimated_delivery_time'])
          : map['estimatedDeliveryTime'] != null
              ? DateTime.parse(map['estimatedDeliveryTime'])
              : null,
      deliveryPersonId: map['delivery_person_id'] ?? map['deliveryPersonId'],
      specialInstructions: map['special_instructions'] ??
          map['specialInstructions'] ??
          map['notes'],
    );
  }
}

class OrderItem {
  final String menuItemId;
  final String menuItemName;
  final String name;
  final String category;
  final String menuItemImage;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final Map<String, String> customizations;
  final String? notes;

  OrderItem({
    required this.menuItemId,
    required this.menuItemName,
    required this.name,
    required this.category,
    required this.menuItemImage,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.customizations = const {},
    this.notes,
  });

  OrderItem copyWith({
    String? menuItemId,
    String? menuItemName,
    String? name,
    String? category,
    String? menuItemImage,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    Map<String, String>? customizations,
    String? notes,
  }) {
    return OrderItem(
      menuItemId: menuItemId ?? this.menuItemId,
      menuItemName: menuItemName ?? this.menuItemName,
      name: name ?? this.name,
      category: category ?? this.category,
      menuItemImage: menuItemImage ?? this.menuItemImage,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      customizations: customizations ?? this.customizations,
      notes: notes ?? this.notes,
    );
  }
}

class OrderStatusUpdate {
  final OrderStatus status;
  final DateTime timestamp;
  final String? message;
  final String? updatedBy;

  OrderStatusUpdate({
    required this.status,
    required this.timestamp,
    this.message,
    this.updatedBy,
  });
}

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  pickedUp,
  onTheWay,
  delivered,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.confirmed:
        return 'Confirmée';
      case OrderStatus.preparing:
        return 'En préparation';
      case OrderStatus.ready:
        return 'Prête';
      case OrderStatus.pickedUp:
        return 'Récupérée';
      case OrderStatus.onTheWay:
        return 'En livraison';
      case OrderStatus.delivered:
        return 'Livrée';
      case OrderStatus.cancelled:
        return 'Annulée';
    }
  }

  String get emoji {
    switch (this) {
      case OrderStatus.pending:
        return '⏳';
      case OrderStatus.confirmed:
        return '✅';
      case OrderStatus.preparing:
        return '👨‍🍳';
      case OrderStatus.ready:
        return '📦';
      case OrderStatus.pickedUp:
        return '🏃‍♂️';
      case OrderStatus.onTheWay:
        return '🛵';
      case OrderStatus.delivered:
        return '🎉';
      case OrderStatus.cancelled:
        return '❌';
    }
  }
}

enum PaymentMethod {
  mobileMoney,
  creditCard,
  debitCard,
  wallet,
  cash,
}

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.mobileMoney:
        return 'Mobile Money';
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.debitCard:
        return 'Debit Card';
      case PaymentMethod.wallet:
        return 'FastFoodGo Wallet';
      case PaymentMethod.cash:
        return 'Cash on Delivery';
    }
  }

  String get description {
    switch (this) {
      case PaymentMethod.mobileMoney:
        return 'Orange Money, MTN Money, Moov Money';
      case PaymentMethod.creditCard:
        return 'Visa, Mastercard, American Express';
      case PaymentMethod.debitCard:
        return 'Carte de débit bancaire';
      case PaymentMethod.wallet:
        return 'Portefeuille FastFoodGo';
      case PaymentMethod.cash:
        return 'Paiement à la livraison';
    }
  }

  String get emoji {
    switch (this) {
      case PaymentMethod.mobileMoney:
        return '📱';
      case PaymentMethod.creditCard:
        return '💳';
      case PaymentMethod.debitCard:
        return '💳';
      case PaymentMethod.wallet:
        return '👛';
      case PaymentMethod.cash:
        return '💵';
    }
  }
}
