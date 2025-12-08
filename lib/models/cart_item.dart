/// Modèle pour les éléments du panier
class CartItem {
  final String id;
  final String menuItemId;
  final String name;
  final double price;
  int quantity;
  final String? imageUrl;
  final Map<String, dynamic> customizations;

  CartItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.customizations = const {},
  });

  /// Prix total pour cet élément (prix × quantité)
  double get totalPrice => price * quantity;

  /// Alias pour customizations (pour compatibilité)
  Map<String, dynamic>? get customization =>
      customizations.isNotEmpty ? customizations : null;

  /// Crée une copie avec des valeurs modifiées
  CartItem copyWith({
    String? id,
    String? menuItemId,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    Map<String, dynamic>? customizations,
  }) {
    return CartItem(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      customizations: customizations ?? this.customizations,
    );
  }

  /// Convertit en Map pour la sérialisation
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menu_item_id': menuItemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'image_url': imageUrl,
      'customizations': customizations,
    };
  }

  /// Crée depuis un Map
  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] as String,
      menuItemId: map['menu_item_id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      imageUrl: map['image_url'] as String?,
      customizations: Map<String, dynamic>.from(map['customizations'] ?? {}),
    );
  }

  @override
  String toString() {
    return 'CartItem(id: $id, name: $name, price: $price, quantity: $quantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem &&
        other.id == id &&
        other.menuItemId == menuItemId &&
        other.name == name &&
        other.price == price &&
        other.quantity == quantity &&
        other.imageUrl == imageUrl &&
        other.customizations.toString() == customizations.toString();
  }

  @override
  int get hashCode {
    return id.hashCode ^
        menuItemId.hashCode ^
        name.hashCode ^
        price.hashCode ^
        quantity.hashCode ^
        imageUrl.hashCode ^
        customizations.hashCode;
  }
}
