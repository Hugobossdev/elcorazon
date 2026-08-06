import '../network/api_client.dart';
import 'cart.dart';

/// Accès à `/api/v1/carts/*` — voir `backend/apps/carts/{serializers,views}.py`.
/// Réservé aux clients authentifiés (`IsCustomer` côté serveur) : passe par
/// [ApiClient] comme le reste, mais échoue en 403 hors session `customer`.
class CartRepository {
  CartRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<Cart> getCart({required String restaurantSlug}) async {
    final response = await apiClient.get('/carts/$restaurantSlug/');
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  /// Ajoute une ligne, ou renforce la ligne identique — même article, mêmes
  /// options **et** même note (`CartService.add_line` côté serveur).
  ///
  /// [optionIds] porte les identifiants d'options du catalogue, jamais leur
  /// supplément : le serveur revalide l'appartenance à l'article et les bornes
  /// de chaque groupe, puis en tire le prix (invariant C1). Envoyer des
  /// identifiants forgés localement est donc refusé, et doit l'être — c'est le
  /// seul moyen de savoir que l'établissement a bien publié ces options.
  Future<Cart> addLine({
    required String restaurantSlug,
    required String menuItemId,
    required int quantity,
    List<String> optionIds = const [],
    String notes = '',
  }) async {
    final response = await apiClient.post(
      '/carts/$restaurantSlug/lines/',
      data: {
        'menu_item': menuItemId,
        'quantity': quantity,
        'options': optionIds,
        'notes': notes,
      },
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
