import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:admin/models/order.dart';

/// Traduit une commande du contrat Django vers le modèle local du back-office.
///
/// Un seul point de traduction, partagé par tous les services qui lisent des
/// commandes : deux conversions écrites séparément finiraient par ne plus
/// afficher la même chose sur deux écrans du même produit.
///
/// Les montants arrivent en unité mineure (ADR-007) et sont rendus en unité
/// majeure pour l'affichage — jamais pour recalculer un total, que le serveur
/// est seul à établir.
abstract final class DjangoOrderMapper {
  static Order toLocal(eccore.Order remote) {
    return Order(
      id: remote.id,
      // Le contrat de supervision ne rend pas l'identifiant du client sur la
      // liste : l'écran affiche une commande, pas un dossier client.
      userId: '',
      items: [
        for (final line in remote.lines)
          OrderItem(
            menuItemId: line.menuItemId,
            menuItemName: line.itemName,
            name: line.itemName,
            categoryId: '',
            menuItemImage: line.itemImage ?? '',
            quantity: line.quantity,
            unitPrice: line.unitPrice.toMajorUnits(),
            totalPrice: line.lineTotal.toMajorUnits(),
            notes: line.notes.isEmpty ? null : line.notes,
          ),
      ],
      subtotal: remote.subtotal.toMajorUnits(),
      deliveryFee: remote.deliveryFee.toMajorUnits(),
      discount: remote.discount.toMajorUnits(),
      total: remote.total.toMajorUnits(),
      status: _toLocalStatus(remote.status),
      deliveryAddress: remote.deliveryLandmark.isEmpty
          ? remote.deliveryAddressLine
          : '${remote.deliveryAddressLine} (${remote.deliveryLandmark})',
      deliveryNotes:
          remote.deliveryInstructions.isEmpty ? null : remote.deliveryInstructions,
      paymentMethod: _toLocalPaymentMethod(remote.paymentMethod),
      recipientName: remote.recipientName,
      recipientPhone: remote.recipientPhone,
      orderTime: remote.placedAt,
      createdAt: remote.createdAt,
      estimatedDeliveryTime: remote.estimatedDeliveryAt,
      specialInstructions:
          remote.deliveryInstructions.isEmpty ? null : remote.deliveryInstructions,
    );
  }

  /// Statut serveur → énumération locale.
  ///
  /// `failed` n'existe pas côté serveur : une commande qui n'aboutit pas est
  /// **annulée**, avec un motif. La distinction locale n'avait pas de
  /// contrepartie et se traduisait par un statut que rien ne produisait.
  static OrderStatus _toLocalStatus(String status) {
    switch (status) {
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'picked_up':
        return OrderStatus.pickedUp;
      case 'on_the_way':
        return OrderStatus.onTheWay;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  /// Énumération locale → valeur attendue par `POST .../status/`.
  static String toRemoteStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.pickedUp:
        return 'picked_up';
      case OrderStatus.onTheWay:
        return 'on_the_way';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.pending:
        return 'pending';
      // `refunded` et `failed` n'existent pas comme statuts de commande côté
      // serveur : le remboursement est un mouvement de paiement, et ce qui
      // n'aboutit pas est **annulé**, avec un motif.
      case OrderStatus.refunded:
      case OrderStatus.failed:
        return 'cancelled';
    }
  }

  static PaymentMethod _toLocalPaymentMethod(String method) {
    switch (method) {
      case 'card':
        return PaymentMethod.creditCard;
      case 'wallet':
        return PaymentMethod.wallet;
      case 'cash':
        return PaymentMethod.cash;
      default:
        return PaymentMethod.mobileMoney;
    }
  }
}
