/// Modèle pour les éléments du panier
class CartItem {
  final String id;
  final String menuItemId;
  final String name;
  final double price;
  int quantity;
  final String? imageUrl;
  final Map<String, dynamic> customizations;

  /// Identifiants des options du catalogue retenues sur cette ligne.
  ///
  /// Distincts de [customizations], qui n'en porte que les **libellés** pour
  /// l'affichage : seuls ces identifiants sont transmis au serveur, qui en
  /// tire le prix de la ligne (invariant C1). Une ligne composée hors
  /// catalogue — l'ancien repli en mémoire du configurateur de gâteaux — en a
  /// donc une liste vide, et n'est pas commandable.
  final List<String> selectedOptionIds;

  CartItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.customizations = const {},
    this.selectedOptionIds = const [],
  });

  /// Prix total pour cet élément (prix × quantité)
  double get totalPrice => price * quantity;

  /// Longueur maximale d'une note de ligne — `CartLineWriteSerializer.notes`
  /// (`max_length=500`). Dépasser produit un 400 qui, au milieu d'une boucle
  /// de synchronisation, se lit comme « le panier a disparu ».
  static const int maxNotesLength = 500;

  /// Ce que la ligne porte de **libre**, tel qu'envoyé dans `CartLine.notes`.
  ///
  /// Quand la ligne a des options structurées, celles-ci sont déjà stockées
  /// par le serveur : n'en garder que la clé `note` évite de répéter les
  /// libellés dans un champ borné — un gâteau entièrement configuré dépassait
  /// les 500 caractères, et le refus emportait la ligne.
  ///
  /// Sinon tout est aplati, trié par clé pour être déterministe : deux
  /// personnalisations équivalentes doivent produire la même note, sans quoi
  /// `CartService._identical_line` (serveur) les traiterait comme deux lignes
  /// distinctes à chaque resynchronisation.
  String get remoteNotes {
    if (customizations.isEmpty) return '';

    final String assembled;
    if (selectedOptionIds.isNotEmpty) {
      assembled = customizations['note']?.toString() ?? '';
    } else {
      final sortedKeys = customizations.keys.toList()..sort();
      assembled =
          sortedKeys.map((key) => '$key: ${customizations[key]}').join(', ');
    }

    return assembled.length <= maxNotesLength
        ? assembled
        : assembled.substring(0, maxNotesLength);
  }

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
    List<String>? selectedOptionIds,
  }) {
    return CartItem(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      customizations: customizations ?? this.customizations,
      selectedOptionIds: selectedOptionIds ?? this.selectedOptionIds,
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
      'selected_option_ids': selectedOptionIds,
    };
  }

  /// Crée depuis un Map
  ///
  /// `selected_option_ids` est absent des paniers écrits par les versions
  /// antérieures : une liste vide les laisse relire sans erreur, quitte à ce
  /// que leurs lignes personnalisées repartent sans options.
  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] as String,
      menuItemId: map['menu_item_id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      imageUrl: map['image_url'] as String?,
      customizations: Map<String, dynamic>.from(map['customizations'] ?? {}),
      selectedOptionIds: (map['selected_option_ids'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .toList(),
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
        other.customizations.toString() == customizations.toString() &&
        other.selectedOptionIds.toString() == selectedOptionIds.toString();
  }

  @override
  int get hashCode {
    return id.hashCode ^
        menuItemId.hashCode ^
        name.hashCode ^
        price.hashCode ^
        quantity.hashCode ^
        imageUrl.hashCode ^
        customizations.hashCode ^
        selectedOptionIds.hashCode;
  }
}
