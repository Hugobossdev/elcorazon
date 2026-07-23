import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/services/api/api_client.dart';

/// Accès au panier serveur via l'API Laravel.
///
/// Note : `CartService` fonctionne en local-first avec une synchronisation
/// « panier complet ». L'API est ici per-article ; on l'utilise pour la lecture
/// et le vidage, et on fournit `replaceAll` pour une resynchronisation complète.
class CartApi {
  CartApi._internal();
  static final CartApi _instance = CartApi._internal();
  factory CartApi() => _instance;

  final ApiClient _client = ApiClient();

  /// Récupère le panier au même format que `DatabaseService.fetchUserCart` :
  /// `{ items: List<CartItem>, deliveryFee, discount, promoCode }`.
  Future<Map<String, dynamic>> getCartSnapshot() async {
    final response = await _client.get('/cart');
    final data = (response['data'] as Map<String, dynamic>? ?? {});
    final cart = (data['cart'] as Map<String, dynamic>? ?? {});
    final rawItems = (data['items'] as List? ?? []);

    return {
      'items': rawItems
          .map((e) => CartItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      'deliveryFee': (cart['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      'discount': (cart['discount'] as num?)?.toDouble() ?? 0.0,
      'promoCode': cart['promo_code'] as String?,
    };
  }

  Future<void> addItem(CartItem item) async {
    await _client.post('/cart/items', body: {
      'menu_item_id': item.menuItemId,
      'name': item.name,
      'price': item.price,
      'quantity': item.quantity,
      if (item.imageUrl != null) 'image_url': item.imageUrl,
      'customizations': item.customizations,
    });
  }

  Future<void> updateItem(String itemId,
      {int? quantity, Map<String, dynamic>? customizations}) async {
    await _client.put('/cart/items/$itemId', body: {
      if (quantity != null) 'quantity': quantity,
      if (customizations != null) 'customizations': customizations,
    });
  }

  Future<void> removeItem(String itemId) async {
    await _client.delete('/cart/items/$itemId');
  }

  Future<void> clear() async {
    await _client.delete('/cart');
  }

  /// Resynchronisation complète : vide puis ré-ajoute tous les articles.
  Future<void> replaceAll(List<CartItem> items) async {
    await clear();
    for (final item in items) {
      await addItem(item);
    }
  }
}
