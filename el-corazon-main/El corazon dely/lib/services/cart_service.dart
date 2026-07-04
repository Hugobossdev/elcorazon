import 'package:flutter/foundation.dart';
import '../models/menu_item.dart';
import '../models/cart_item.dart';

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];
  double _deliveryFee = 500.0;
  double _discount = 0.0;
  String? _promoCode;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  int get totalItems => _items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get deliveryFee => _deliveryFee;
  double get discount => _discount;
  double get total => subtotal + _deliveryFee - _discount;
  String? get promoCode => _promoCode;

  void addItem(
    MenuItem menuItem, {
    int quantity = 1,
    Map<String, dynamic>? customization,
  }) {
    // Check if item already exists
    final existingIndex = _items.indexWhere((item) =>
        item.id == menuItem.id &&
        _mapsEqual(item.customization, customization));

    if (existingIndex >= 0) {
      // Update existing item quantity
      _items[existingIndex] = _items[existingIndex]
          .copyWith(quantity: _items[existingIndex].quantity + quantity);
    } else {
      // Add new item
      _items.add(CartItem(
        id: menuItem.id,
        name: menuItem.name,
        price: menuItem.price,
        quantity: quantity,
        imageUrl: menuItem.imageUrl,
        customization: customization,
      ));
    }
    notifyListeners();
  }

  void updateItemQuantity(int index, int newQuantity) {
    if (index >= 0 && index < _items.length) {
      if (newQuantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: newQuantity);
      }
      notifyListeners();
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void removeItemById(String menuItemId) {
    _items.removeWhere((item) => item.id == menuItemId);
    notifyListeners();
  }

  void updateItemCustomizations(
      int index, Map<String, dynamic>? customization) {
    if (index >= 0 && index < _items.length) {
      _items[index] = _items[index].copyWith(customization: customization);
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _discount = 0.0;
    _promoCode = null;
    notifyListeners();
  }

  // Helper methods for backward compatibility
  int getTotalItems() => itemCount;
  double getTotalPrice() => total;

  void setDeliveryFee(double fee) {
    _deliveryFee = fee;
    notifyListeners();
  }

  Future<bool> validatePromoCode(
      String code, double orderAmount, List<MenuCategory> categories) async {
    // Simulate API call to validate promo code
    await Future.delayed(const Duration(seconds: 1));

    final promoDiscount = _validatePromoCode(code);
    if (promoDiscount > 0) {
      _promoCode = code;
      _discount = promoDiscount;
      notifyListeners();
      return true;
    }
    return false;
  }

  void removePromoCode() {
    _promoCode = null;
    _discount = 0.0;
    notifyListeners();
  }

  double _validatePromoCode(String code) {
    // Simple promo code validation
    switch (code.toUpperCase()) {
      case 'WELCOME10':
        return subtotal * 0.1; // 10% discount
      case 'FIRSTORDER':
        return 1000.0; // 1000 FCFA discount
      case 'STUDENT':
        return subtotal * 0.15; // 15% discount
      case 'WEEKEND':
        return _deliveryFee; // Free delivery
      default:
        return 0.0;
    }
  }

  Map<String, dynamic> toOrderData() {
    return {
      'items': _items
          .map((item) => {
                'menu_item_id': item.id,
                'name': item.name,
                'price': item.price,
                'quantity': item.quantity,
                'customization': item.customization,
              })
          .toList(),
      'subtotal': subtotal,
      'delivery_fee': _deliveryFee,
      'discount': _discount,
      'promo_code': _promoCode,
      'total': total,
    };
  }

  int getItemQuantity(String menuItemId) {
    final item = _items.firstWhere(
      (item) => item.id == menuItemId,
      orElse: () => CartItem(
        id: '',
        name: '',
        price: 0,
        quantity: 0,
      ),
    );
    return item.quantity;
  }

  bool hasItem(String menuItemId) {
    return _items.any((item) => item.id == menuItemId);
  }

  void incrementItemQuantity(String menuItemId) {
    final index = _items.indexWhere((item) => item.id == menuItemId);
    if (index >= 0) {
      _items[index] =
          _items[index].copyWith(quantity: _items[index].quantity + 1);
      notifyListeners();
    }
  }

  void decrementItemQuantity(String menuItemId) {
    final index = _items.indexWhere((item) => item.id == menuItemId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index] =
            _items[index].copyWith(quantity: _items[index].quantity - 1);
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  // Save cart to local storage
  Future<void> saveToStorage() async {
    // Implement local storage save
    // For now, we'll just simulate it
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // Load cart from local storage
  Future<void> loadFromStorage() async {
    // Implement local storage load
    // For now, we'll just simulate it
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // Helper method to compare maps
  bool _mapsEqual(Map<String, dynamic>? map1, Map<String, dynamic>? map2) {
    if (map1 == null && map2 == null) return true;
    if (map1 == null || map2 == null) return false;
    if (map1.length != map2.length) return false;

    for (final key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) {
        return false;
      }
    }
    return true;
  }
}
