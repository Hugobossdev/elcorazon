import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/orders/order.dart';
import 'package:elcorazon_core/src/orders/order_quote.dart';

/// Accès à `/api/v1/orders/*` — voir
/// `backend/apps/orders/{serializers,views,services}.py`. La commande est
/// créée **depuis le panier serveur déjà chargé** (`carts`, tranche
/// précédente) : ce repository ne prend jamais d'articles ni de montants en
/// entrée (invariants C1/C2).
class OrderRepository {
  OrderRepository({required this.apiClient});

  final ApiClient apiClient;

  /// `idempotencyKey` doit être stable sur une même tentative de commande
  /// (ADR-009) : un rejeu avec la même clé renvoie la commande déjà créée au
  /// lieu d'en créer une seconde. À générer une fois par tentative de
  /// paiement/validation côté appelant, jamais par cette méthode elle-même.
  Future<Order> create({
    required String restaurantSlug,
    required String addressId,
    required String paymentMethod,
    required String idempotencyKey,
    String instructions = '',
    String promoCode = '',
  }) async {
    final response = await apiClient.post(
      '/orders/',
      headers: {'Idempotency-Key': idempotencyKey},
      data: {
        'restaurant': restaurantSlug,
        'address': addressId,
        'payment_method': paymentMethod,
        'instructions': instructions,
        'promo_code': promoCode,
      },
    );
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  /// Combien coûterait cette commande — sans rien écrire.
  ///
  /// Le panier n'est pas transmis : il est lu côté serveur depuis le
  /// restaurant désigné. Laisser l'application annoncer son sous-total
  /// permettrait de franchir un minimum de commande avec un montant qui n'est
  /// pas le sien.
  ///
  /// [addressId] est facultatif, et l'écart se paie en exactitude : avec, les
  /// frais sont ceux de la zone qui couvre le point d'arrivée ; sans, ceux de
  /// la zone de l'établissement, ce qui suffit à afficher un ordre de grandeur
  /// tant qu'aucune adresse n'est choisie.
  Future<OrderQuote> preview({
    required String restaurantSlug,
    String? addressId,
    String promoCode = '',
  }) async {
    final response = await apiClient.post(
      '/orders/preview/',
      data: {
        'restaurant': restaurantSlug,
        if (addressId != null) 'address': addressId,
        'promo_code': promoCode,
      },
    );
    return OrderQuote.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Order>> list({String? status}) async {
    final orders = <Order>[];
    String? path = '/orders/';
    Map<String, dynamic>? queryParameters = status == null ? null : {'status': status};

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      orders.addAll(results.map((json) => Order.fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
      queryParameters = null;
    }

    return orders;
  }

  Future<Order> getById(String id) async {
    final response = await apiClient.get('/orders/$id/');
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Order> cancel(String id, {String reason = ''}) async {
    final response = await apiClient.post('/orders/$id/cancel/', data: {'reason': reason});
    return Order.fromJson(response.data as Map<String, dynamic>);
  }
}
