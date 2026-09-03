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
      reference: remote.reference,
      userId: userId,
      items: remote.lines.map(_toLocalItem).toList(),
      subtotal: remote.subtotal.toMajorUnits(),
      deliveryFee: remote.deliveryFee.toMajorUnits(),
      total: remote.total.toMajorUnits(),
      status: _toLocalStatus(remote.status),
      deliveryAddress: remote.deliveryAddressLine,
      // Le point figé à la commande, et celui d'où part le repas. L'adaptateur
      // les jetait tous les deux : l'écran de suivi re-géocodait la ligne
      // d'adresse à chaque ouverture pour retrouver ce que le serveur venait de
      // lui dire, et n'avait aucun moyen de placer le restaurant.
      deliveryLatitude: remote.deliveryLatitude,
      deliveryLongitude: remote.deliveryLongitude,
      restaurantLatitude: remote.restaurantLatitude,
      restaurantLongitude: remote.restaurantLongitude,
      deliveryNotes: remote.deliveryInstructions,
      discount: remote.discount.toMajorUnits(),
      paymentMethod: _toLocalPaymentMethod(remote.paymentMethod),
      orderTime: remote.placedAt,
      createdAt: remote.createdAt,
      estimatedDeliveryTime: remote.estimatedDeliveryAt,
      specialInstructions: remote.deliveryInstructions,
      statusUpdates: remote.statusEvents.map(_toLocalStatusUpdate).toList(),
    );
  }

  /// Une étape du cycle de vie, telle que le serveur l'a horodatée.
  ///
  /// ## Ce qui était perdu
  ///
  /// `OrderSerializer` publie `status_events` — chaque passage d'un statut à
  /// un autre, avec son motif et son horodatage — et l'adaptateur les jetait :
  /// `statusUpdates` retombait sur sa valeur par défaut, la liste vide. La
  /// chronologie du détail de commande ne pouvait donc afficher aucune heure,
  /// alors que le serveur les connaissait toutes.
  static OrderStatusUpdate _toLocalStatusUpdate(eccore.OrderStatusEvent event) {
    return OrderStatusUpdate(
      status: _toLocalStatus(event.toStatus),
      timestamp: event.createdAt,
      message: event.reason.isEmpty ? null : event.reason,
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
      customizations: _toLocalOptions(line.options),
    );
  }

  /// Les options retenues, groupe par groupe.
  ///
  /// ## Ce qui était perdu
  ///
  /// `OrderLineSerializer` publie `options` — chaque choix avec son groupe
  /// (« Cuisson », « Suppléments ») et son écart de prix. L'adaptateur ne les
  /// lisait pas, si bien que `customizations` restait vide : le détail d'une
  /// commande affichait « Le Classique Burger » sans jamais dire qu'il avait
  /// été commandé sans oignons. L'information avait pourtant traversé tout le
  /// chemin, du panier au serveur, pour être jetée à la dernière marche.
  ///
  /// Plusieurs choix dans un même groupe sont réunis sur une ligne, séparés
  /// par une virgule — c'est ainsi que le panier les montre déjà.
  static Map<String, String> _toLocalOptions(List<eccore.ChosenOption> options) {
    final parGroupe = <String, List<String>>{};
    for (final option in options) {
      parGroupe.putIfAbsent(option.groupName, () => <String>[]).add(option.optionName);
    }
    return {
      for (final entree in parGroupe.entries) entree.key: entree.value.join(', '),
    };
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
