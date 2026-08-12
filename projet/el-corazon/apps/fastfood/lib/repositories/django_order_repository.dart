import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/repositories/order_repository.dart';
import 'package:uuid/uuid.dart';

/// Commandes contre le backend Django (Phase 6). Le paiement réel (PayDunya
/// via le backend) est une tranche à venir — créer une commande ici ne
/// déclenche aucun paiement, elle naît `pending` comme le fait déjà
/// `OrderService.create_from_cart` côté serveur.
///
/// `createOrder`/`updateOrderStatus` de [OrderRepository] ne correspondent pas
/// au contrat Django (la commande naît du panier serveur, jamais d'un
/// `Order` construit côté client ; faire avancer un statut est réservé au
/// personnel, permission `orders.update_status`) — implémentées uniquement
/// pour satisfaire l'interface, jamais appelées en pratique (voir
/// [createFromServerCart], utilisée à la place par `AppService`).
class DjangoOrderRepository implements OrderRepository {
  DjangoOrderRepository() : _orders = eccore.OrderRepository(apiClient: apiClient);

  final eccore.OrderRepository _orders;
  final Uuid _uuid = const Uuid();

  /// Django n'a qu'un moyen de paiement « carte » — `creditCard`/`debitCard`
  /// s'y confondent (`common/models.py PaymentMethod`).
  static String _toRemotePaymentMethod(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.mobileMoney:
        return 'mobile_money';
      case PaymentMethod.creditCard:
      case PaymentMethod.debitCard:
        return 'card';
      case PaymentMethod.wallet:
        return 'wallet';
      case PaymentMethod.cash:
        return 'cash';
    }
  }

  /// Crée la commande depuis le panier serveur déjà synchronisé
  /// (`CartService.ensureSynced`, à appeler par l'appelant avant celle-ci) —
  /// voir `docs/architecture/04-migration-flutter.md`.
  Future<Order> createFromServerCart({
    required eccore.Address address,
    required PaymentMethod paymentMethod,
    String? instructions,
    String promoCode = '',
  }) async {
    // L'assertion qui se trouvait ici — « adresse déjà synchronisée côté
    // serveur » — était doublement inutile : `assert` disparaît en production,
    // donc elle ne protégeait que le mode debug, et elle vérifiait la présence
    // d'un point, ce qui ne dit rien de la présence de l'adresse *chez le
    // serveur*. C'est cette confusion qui laissait partir des identifiants
    // locaux. Le carnet garantit désormais l'invariant à la source : toute
    // `eccore.Address` vient de `/profiles/addresses/`.
    final remote = await _orders.create(
      restaurantSlug: AppConstants.restaurantSlug,
      addressId: address.id!,
      paymentMethod: _toRemotePaymentMethod(paymentMethod),
      instructions: instructions ?? '',
      promoCode: promoCode,
      idempotencyKey: _uuid.v4(),
    );
    return _toLocal(remote, userId: '');
  }

  @override
  Future<List<Order>> getUserOrders(String userId, {String? status}) async {
    final remote = await _orders.list(status: status);
    return remote.map((order) => _toLocal(order, userId: userId)).toList();
  }

  @override
  Future<Order?> getOrderById(String orderId) async {
    try {
      final remote = await _orders.getById(orderId);
      return _toLocal(remote, userId: '');
    } on eccore.ApiException catch (error) {
      if (error.status == 404) return null;
      rethrow;
    }
  }

  @override
  Stream<List<Order>> watchUserOrders(String userId) {
    // Pas de WebSocket commandes côté historique (le suivi temps réel d'une
    // commande précise est un domaine à part, pas encore migré) — même
    // polling que l'ancienne implémentation Supabase.
    return Stream.periodic(const Duration(seconds: 30), (_) => null)
        .asyncMap((_) => getUserOrders(userId));
  }

  @override
  Future<Order> createOrder(Order order) {
    throw UnsupportedError(
      'Utiliser DjangoOrderRepository.createFromServerCart — la commande '
      'Django naît du panier serveur, jamais d\'un Order construit côté client.',
    );
  }

  @override
  Future<Order> updateOrderStatus(String orderId, OrderStatus status) {
    throw UnsupportedError(
      'Faire avancer le statut d\'une commande est réservé au personnel '
      '(permission orders.update_status) — jamais depuis l\'app client.',
    );
  }

  Order _toLocal(eccore.Order remote, {required String userId}) {
    return Order(
      id: remote.id,
      userId: userId,
      items: remote.lines.map(_toLocalItem).toList(),
      subtotal: remote.subtotal.toMajorUnits(),
      deliveryFee: remote.deliveryFee.toMajorUnits(),
      total: remote.total.toMajorUnits(),
      status: _toLocalStatus(remote.status),
      deliveryAddress: remote.deliveryAddressLine,
      deliveryNotes: remote.deliveryInstructions,
      discount: remote.discount.toMajorUnits(),
      paymentMethod: _toLocalPaymentMethod(remote.paymentMethod),
      orderTime: remote.placedAt,
      createdAt: remote.createdAt,
      estimatedDeliveryTime: remote.estimatedDeliveryAt,
      specialInstructions: remote.deliveryInstructions,
    );
  }

  OrderItem _toLocalItem(eccore.OrderLine line) {
    return OrderItem(
      menuItemId: line.menuItemId,
      menuItemName: line.itemName,
      name: line.itemName,
      category: '',
      menuItemImage: line.itemImage ?? '',
      quantity: line.quantity,
      unitPrice: line.unitPrice.toMajorUnits(),
      totalPrice: line.lineTotal.toMajorUnits(),
      notes: line.notes,
    );
  }

  static OrderStatus _toLocalStatus(String remote) {
    return OrderStatus.values.firstWhere(
      (s) => s.dbValue == remote,
      orElse: () => OrderStatus.pending,
    );
  }

  static PaymentMethod _toLocalPaymentMethod(String remote) {
    switch (remote) {
      case 'mobile_money':
        return PaymentMethod.mobileMoney;
      case 'wallet':
        return PaymentMethod.wallet;
      case 'card':
        return PaymentMethod.creditCard;
      case 'cash':
      default:
        return PaymentMethod.cash;
    }
  }
}
