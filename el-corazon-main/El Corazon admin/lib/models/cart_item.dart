class CartItem {
  final String id;
  final String name;
  final double basePrice;
  final int quantity;
  final String? imageUrl;
  final Map<String, dynamic>? customization;

  CartItem({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.quantity,
    this.imageUrl,
    this.customization,
  });

  double get totalPrice => basePrice * quantity;

  CartItem copyWith({
    String? id,
    String? name,
    double? basePrice,
    int? quantity,
    String? imageUrl,
    Map<String, dynamic>? customization,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      basePrice: basePrice ?? this.basePrice,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      customization: customization ?? this.customization,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': basePrice,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'customization': customization,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      name: json['name'] as String,
      basePrice: (json['price'] as num?)?.toDouble() ?? 0.0,
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
    return 'CartItem(id: $id, name: $name, basePrice: $basePrice, quantity: $quantity)';
  }
}
