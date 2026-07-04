import 'package:elcora_fast/models/order.dart';

/// Repository abstrait pour les opérations sur les commandes
abstract class OrderRepository {
  /// Crée une nouvelle commande
  Future<Order> createOrder(Order order);

  /// Récupère une commande par son ID
  Future<Order?> getOrderById(String orderId);

  /// Récupère toutes les commandes d'un utilisateur
  Future<List<Order>> getUserOrders(String userId, {String? status});

  /// Met à jour le statut d'une commande
  Future<Order> updateOrderStatus(String orderId, OrderStatus status);

  /// Stream des commandes d'un utilisateur pour la mise à jour en temps réel
  Stream<List<Order>> watchUserOrders(String userId);
}

