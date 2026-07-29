import '../models/money.dart';

/// Ligne de panier valorisée — miroir de `PricedLineSerializer`
/// (`backend/apps/carts/serializers.py`). Pas de champ `options` : cette
/// tranche ne porte pas la personnalisation structurée (voir
/// `docs/architecture/04-migration-flutter.md`).
class CartLine {
  const CartLine({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.image,
    required this.quantity,
    required this.notes,
    required this.unitPrice,
    required this.total,
    required this.isOrderable,
    required this.unavailableReason,
  });

  factory CartLine.fromJson(Map<String, dynamic> json) {
    return CartLine(
      id: json['id'] as String,
      menuItemId: json['menu_item'] as String,
      name: json['name'] as String,
      image: json['image'] as String?,
      quantity: json['quantity'] as int,
      notes: json['notes'] as String? ?? '',
      unitPrice: Money.fromJson(json['unit_price'] as Map<String, dynamic>),
      total: Money.fromJson(json['total'] as Map<String, dynamic>),
      isOrderable: json['is_orderable'] as bool,
      unavailableReason: json['unavailable_reason'] as String? ?? '',
    );
  }

  final String id;
  final String menuItemId;
  final String name;
  final String? image;
  final int quantity;
  final String notes;
  final Money unitPrice;
  final Money total;
  final bool isOrderable;
  final String unavailableReason;
}

/// Panier serveur d'un restaurant — miroir de `CartSerializer`. Ne stocke
/// aucun montant côté serveur (invariant C1) : `subtotal` est recalculé à
/// chaque lecture depuis le catalogue.
class Cart {
  const Cart({
    required this.id,
    required this.restaurantSlug,
    required this.restaurantName,
    required this.currency,
    required this.lines,
    required this.subtotal,
    required this.isOrderable,
    required this.updatedAt,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id'] as String,
      restaurantSlug: json['restaurant'] as String,
      restaurantName: json['restaurant_name'] as String,
      currency: json['currency'] as String,
      lines: (json['lines'] as List<dynamic>)
          .map((line) => CartLine.fromJson(line as Map<String, dynamic>))
          .toList(),
      subtotal: Money.fromJson(json['subtotal'] as Map<String, dynamic>),
      isOrderable: json['is_orderable'] as bool,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String restaurantSlug;
  final String restaurantName;
  final String currency;
  final List<CartLine> lines;
  final Money subtotal;
  final bool isOrderable;
  final DateTime updatedAt;
}
