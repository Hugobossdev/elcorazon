import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/services/api/api_client.dart';
import 'package:elcora_fast/services/api/paged_result.dart';

/// Un article à commander (payload de création côté API).
class OrderItemInput {
  OrderItemInput({
    required this.menuItemId,
    required this.quantity,
    this.customizations,
    this.notes,
  });

  final String menuItemId;
  final int quantity;
  final Map<String, dynamic>? customizations;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'menu_item_id': menuItemId,
        'quantity': quantity,
        if (customizations != null) 'customizations': customizations,
        if (notes != null) 'notes': notes,
      };
}

/// Accès aux commandes via l'API Laravel.
///
/// La **création** délègue le calcul des montants au serveur (source de vérité) :
/// on n'envoie que les articles + l'adresse + le mode de paiement.
class OrderApi {
  OrderApi._internal();
  static final OrderApi _instance = OrderApi._internal();
  factory OrderApi() => _instance;

  final ApiClient _client = ApiClient();

  /// Commandes de l'utilisateur courant (paginées, filtrables par statut).
  Future<PagedResult<Order>> getMyOrders({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _client.get('/orders', query: {
      'page': page,
      'per_page': perPage,
      if (status != null) 'status': status,
    });
    return PagedResult<Order>.fromResponse(
      response as Map<String, dynamic>,
      (m) => Order.fromMap(_normalize(m)),
      fallbackPage: page,
    );
  }

  /// Liste simple (première page élargie) pour les écrans d'historique.
  Future<List<Order>> getMyOrdersList({int perPage = 50}) async {
    final result = await getMyOrders(perPage: perPage);
    return result.items;
  }

  Future<Order> getOrder(String id) async {
    final response = await _client.get('/orders/$id');
    return Order.fromMap(_normalize(response['data'] as Map<String, dynamic>));
  }

  /// Crée une commande. Les montants sont recalculés côté serveur.
  Future<Order> createOrder({
    required List<OrderItemInput> items,
    required String deliveryAddress,
    required String paymentMethod,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryNotes,
    String? specialInstructions,
    double? deliveryFee,
    String? promoCode,
  }) async {
    final response = await _client.post('/orders', body: {
      'items': items.map((e) => e.toJson()).toList(),
      'delivery_address': deliveryAddress,
      'payment_method': paymentMethod,
      if (deliveryLatitude != null) 'delivery_latitude': deliveryLatitude,
      if (deliveryLongitude != null) 'delivery_longitude': deliveryLongitude,
      if (deliveryNotes != null) 'delivery_notes': deliveryNotes,
      if (specialInstructions != null) 'special_instructions': specialInstructions,
      if (deliveryFee != null) 'delivery_fee': deliveryFee,
      if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
    });
    return Order.fromMap(_normalize(response['data'] as Map<String, dynamic>));
  }

  Future<Order> cancelOrder(String id, {String? reason}) async {
    final response = await _client.post('/orders/$id/cancel', body: {
      if (reason != null) 'reason': reason,
    });
    return Order.fromMap(_normalize(response['data'] as Map<String, dynamic>));
  }

  /// L'API imbrique les lignes sous `items` ; `Order.fromMap` attend la clé
  /// Supabase `order_items`. On adapte.
  Map<String, dynamic> _normalize(Map<String, dynamic> order) {
    if (order['items'] != null && order['order_items'] == null) {
      return {...order, 'order_items': order['items']};
    }
    return order;
  }
}
