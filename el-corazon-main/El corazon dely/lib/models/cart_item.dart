class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;
  final Map<String, dynamic>? customization;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.customization,
  });

  double get totalPrice => price * quantity;

  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    Map<String, dynamic>? customization,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      customization: customization ?? this.customization,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'customization': customization,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      imageUrl: json['imageUrl'] as String?,
      customization: json['customization'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CartItem(id: $id, name: $name, price: $price, quantity: $quantity)';
  }
}
