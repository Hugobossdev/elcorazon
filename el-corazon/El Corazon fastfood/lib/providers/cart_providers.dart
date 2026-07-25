import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/models/menu_item.dart';

/// État du panier
class CartState {
  final List<CartItem> items;
  final double total;
  final int itemCount;

  CartState({
    required this.items,
    required this.total,
    required this.itemCount,
  });

  CartState copyWith({
    List<CartItem>? items,
    double? total,
    int? itemCount,
  }) {
    return CartState(
      items: items ?? this.items,
      total: total ?? this.total,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  /// État initial vide
  factory CartState.empty() {
    return CartState(
      items: [],
      total: 0.0,
      itemCount: 0,
    );
  }
}

/// Notifier pour gérer l'état du panier
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    return CartState.empty();
  }

  /// Ajouter un item au panier
  void addItem(MenuItem item,
      {int quantity = 1, Map<String, dynamic>? customizations,}) {
    final existingIndex = state.items.indexWhere(
      (cartItem) => cartItem.id == item.id,
    );

    if (existingIndex >= 0) {
      // Item existe déjà, mettre à jour la quantité
      final existingItem = state.items[existingIndex];
      final updatedItem = CartItem(
        id: existingItem.id,
        menuItemId: item.id,
        name: item.name,
        price: item.price,
        quantity: existingItem.quantity + quantity,
        imageUrl: item.imageUrl,
        customizations: customizations ?? existingItem.customizations,
      );

      final newItems = List<CartItem>.from(state.items);
      newItems[existingIndex] = updatedItem;

      state = CartState(
        items: newItems,
        total: _calculateTotal(newItems),
        itemCount: _calculateItemCount(newItems),
      );
    } else {
      // Nouvel item
      final newItem = CartItem(
        id: item.id,
        menuItemId: item.id,
        name: item.name,
        price: item.price,
        quantity: quantity,
        imageUrl: item.imageUrl,
        customizations: customizations ?? {},
      );

      final newItems = [...state.items, newItem];

      state = CartState(
        items: newItems,
        total: _calculateTotal(newItems),
        itemCount: _calculateItemCount(newItems),
      );
    }
  }

  /// Retirer un item du panier
  void removeItem(String itemId) {
    final newItems = state.items.where((item) => item.id != itemId).toList();

    state = CartState(
      items: newItems,
      total: _calculateTotal(newItems),
      itemCount: _calculateItemCount(newItems),
    );
  }

  /// Mettre à jour la quantité d'un item
  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }

    final existingIndex = state.items.indexWhere(
      (cartItem) => cartItem.id == itemId,
    );

    if (existingIndex >= 0) {
      final existingItem = state.items[existingIndex];
      final updatedItem = CartItem(
        id: existingItem.id,
        menuItemId: existingItem.menuItemId,
        name: existingItem.name,
        price: existingItem.price,
        quantity: quantity,
        imageUrl: existingItem.imageUrl,
        customizations: existingItem.customizations,
      );

      final newItems = List<CartItem>.from(state.items);
      newItems[existingIndex] = updatedItem;

      state = CartState(
        items: newItems,
        total: _calculateTotal(newItems),
        itemCount: _calculateItemCount(newItems),
      );
    }
  }

  /// Vider le panier
  void clear() {
    state = CartState.empty();
  }

  /// Calculer le total
  double _calculateTotal(List<CartItem> items) {
    return items.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
  }

  /// Calculer le nombre d'items
  int _calculateItemCount(List<CartItem> items) {
    return items.fold(
      0,
      (sum, item) => sum + item.quantity,
    );
  }
}

/// Provider du panier
final cartProvider = NotifierProvider<CartNotifier, CartState>(() {
  return CartNotifier();
});
