import '../network/api_client.dart';
import 'cart.dart';

/// Accès à `/api/v1/carts/*` — voir `backend/apps/carts/{serializers,views}.py`.
/// Réservé aux clients authentifiés (`IsCustomer` côté serveur) : passe par
/// [ApiClient] comme le reste, mais échoue en 403 hors session `customer`.
///
/// Pas de support des options structurées dans cette tranche (voir
/// `docs/architecture/04-migration-flutter.md`) — [addLine] envoie toujours
/// `options: []`.
class CartRepository {
  CartRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<Cart> getCart({required String restaurantSlug}) async {
    final response = await apiClient.get('/carts/$restaurantSlug/');
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> addLine({
    required String restaurantSlug,
    required String menuItemId,
    required int quantity,
    String notes = '',
  }) async {
    final response = await apiClient.post(
      '/carts/$restaurantSlug/lines/',
      data: {'menu_item': menuItemId, 'quantity': quantity, 'options': const [], 'notes': notes},
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> setQuantity({
    required String restaurantSlug,
    required String lineId,
    required int quantity,
  }) async {
    final response = await apiClient.patch(
      '/carts/$restaurantSlug/lines/$lineId/',
      data: {'quantity': quantity},
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> removeLine({required String restaurantSlug, required String lineId}) async {
    final response = await apiClient.delete('/carts/$restaurantSlug/lines/$lineId/');
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> clear({required String restaurantSlug}) async {
    final response = await apiClient.delete('/carts/$restaurantSlug/lines/');
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }
}
