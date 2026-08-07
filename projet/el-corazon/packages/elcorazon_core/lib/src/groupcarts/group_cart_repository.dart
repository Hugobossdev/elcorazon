import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/orders/order.dart';
import 'package:elcorazon_core/src/groupcarts/group_cart.dart';

/// Accès à `/api/v1/group-carts/*` — voir `backend/apps/groupcarts/views.py`.
///
/// Deux principes gouvernent ce contrat, et expliquent l'absence de plusieurs
/// paramètres qu'on s'attendrait à trouver :
///
/// * **L'auteur d'une ligne n'est jamais déclaré.** Il vient du jeton. Un champ
///   `member` en entrée laisserait un participant déposer des plats au nom d'un
///   autre — et c'est l'hôte qui paierait.
/// * **Toute écriture rend le panier entier**, sous-total et totaux par
///   participant compris. Rien n'est à recalculer côté client.
class GroupCartRepository {
  GroupCartRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Les paniers auxquels l'appelant participe.
  Future<List<GroupCart>> list() async {
    final response = await apiClient.get('/group-carts/');
    return (response.data as List<dynamic>)
        .map((json) => GroupCart.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<GroupCart> getById(String groupCartId) async {
    final response = await apiClient.get('/group-carts/$groupCartId/');
    return GroupCart.fromJson(response.data as Map<String, dynamic>);
  }

  /// Ouvre un panier. Ni le statut ni le code ne s'écrivent depuis la requête :
  /// le premier naîtrait déjà confirmé, le second permettrait de deviner celui
  /// d'un autre panier.
  ///
  /// [windowMinutes] est facultatif — l'échéance a une valeur par défaut côté
  /// serveur, et l'hôte n'a pas à en choisir une pour commander un déjeuner.
  Future<GroupCart> open({
    required String restaurantSlug,
    String title = '',
    int? windowMinutes,
  }) async {
    final response = await apiClient.post(
      '/group-carts/',
      data: {
        'restaurant': restaurantSlug,
        if (title.isNotEmpty) 'title': title,
        if (windowMinutes != null) 'window_minutes': windowMinutes,
      },
    );
    return GroupCart.fromJson(response.data as Map<String, dynamic>);
  }

  /// Rejoint un panier par son code d'invitation.
  Future<GroupCart> join(String code) async {
    final response = await apiClient.post('/group-carts/join/', data: {'code': code});
    return GroupCart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GroupCart> addLine({
    required String groupCartId,
    required String menuItemId,
    int quantity = 1,
    List<String> optionIds = const [],
    String notes = '',
  }) async {
    final response = await apiClient.post(
      '/group-carts/$groupCartId/lines/',
      data: {
        'menu_item': menuItemId,
        'quantity': quantity,
        'options': optionIds,
        if (notes.isNotEmpty) 'notes': notes,
      },
    );
    return GroupCart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GroupCart> setQuantity({
    required String groupCartId,
    required String lineId,
    required int quantity,
  }) async {
    final response = await apiClient.patch(
      '/group-carts/$groupCartId/lines/$lineId/',
      data: {'quantity': quantity},
    );
    return GroupCart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GroupCart> removeLine({required String groupCartId, required String lineId}) async {
    final response = await apiClient.delete('/group-carts/$groupCartId/lines/$lineId/');
    return GroupCart.fromJson(response.data as Map<String, dynamic>);
  }

  /// Clôt les ajouts sans commander — réservé à l'hôte.
  Future<GroupCart> lock(String groupCartId) async {
    final response = await apiClient.post('/group-carts/$groupCartId/lock/');
    return GroupCart.fromJson(response.data as Map<String, dynamic>);
  }

  /// Transforme le panier en commande — réservé à l'hôte.
  ///
  /// Pas de clé d'idempotence, contrairement à la création de commande : le
  /// panier **est** la clé. Un second appel trouve un panier déjà `confirmed`,
  /// que la machine à états refuse de retransitionner.
  Future<Order> confirm({
    required String groupCartId,
    required String addressId,
    required String paymentMethod,
    String instructions = '',
    String promoCode = '',
  }) async {
    final response = await apiClient.post(
      '/group-carts/$groupCartId/confirm/',
      data: {
        'address': addressId,
        'payment_method': paymentMethod,
        if (instructions.isNotEmpty) 'instructions': instructions,
        if (promoCode.isNotEmpty) 'promo_code': promoCode,
      },
    );
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  /// Renonce au panier — réservé à l'hôte.
  Future<GroupCart> cancel({required String groupCartId, required String reason}) async {
    final response = await apiClient.post(
      '/group-carts/$groupCartId/cancel/',
      data: {'reason': reason},
    );
    return GroupCart.fromJson(response.data as Map<String, dynamic>);
  }
}
